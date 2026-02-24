"""
Lightcast Open Skills JSON loader.

Streams a user-provided Lightcast JSON export into PostgreSQL raw tables,
resolving stable internal skill IDs via a persistent mapping table.

Usage:
    uv run python scripts/load_lightcast.py \
        --meta data/lightcast/import_meta.json \
        --db-url postgresql://user:pass@localhost:5432/dbname
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone

import ijson
import psycopg2
import psycopg2.extras

# ---------------------------------------------------------------------------
# Preflight check
# ---------------------------------------------------------------------------

REQUIRED_TABLES = [
    "raw.lightcast_import_batches",
    "raw.lightcast_skill_id_map",
    "raw.lightcast_skills",
    "raw.lightcast_attributions",
]


def check_raw_tables_exist(cur) -> None:
    """Verify that all required raw tables exist, or exit with guidance."""
    cur.execute(
        """
        SELECT table_schema || '.' || table_name
        FROM information_schema.tables
        WHERE table_schema = 'raw'
          AND table_name LIKE 'lightcast_%'
        """
    )
    existing = {row[0] for row in cur.fetchall()}
    missing = [t for t in REQUIRED_TABLES if t not in existing]
    if missing:
        sys.exit(
            "ERROR: Required raw tables not found: "
            + ", ".join(missing)
            + "\nRun:  dbt run-operation create_lightcast_raw_tables"
        )


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_SLUG_RE = re.compile(r"[^a-z0-9]+")


def slugify(text: str) -> str:
    """Convert text to a URL-safe slug matching the dbt macro intent."""
    text = text.replace("++", "-plus-plus")
    text = text.replace("#", "-sharp")
    slug = _SLUG_RE.sub("-", text.lower()).strip("-")
    # Collapse multiple hyphens
    slug = re.sub(r"-+", "-", slug)
    return slug or "unnamed"


def file_sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Stable ID resolution
# ---------------------------------------------------------------------------


def load_skill_id_map(cur) -> dict[str, str]:
    """Load the full skill_id map into memory: source_id -> skill_id."""
    cur.execute("SELECT source_id, skill_id FROM raw.lightcast_skill_id_map")
    return dict(cur.fetchall())


def load_existing_skill_ids(cur) -> set[str]:
    """Load all existing skill_ids for collision detection."""
    cur.execute("SELECT skill_id FROM raw.lightcast_skill_id_map")
    return {row[0] for row in cur.fetchall()}


def resolve_skill_id(
    source_id: str,
    name: str,
    id_map: dict[str, str],
    all_skill_ids: set[str],
    new_mappings: list[tuple],
    updated_mappings: list[tuple],
    now: datetime,
) -> str:
    """Resolve a stable skill_id for a given Lightcast source_id."""
    if source_id in id_map:
        skill_id = id_map[source_id]
        updated_mappings.append((now, name, source_id))
        return skill_id

    # Generate new skill_id with collision handling
    base = slugify(name)
    candidate = base
    suffix = 2
    while candidate in all_skill_ids:
        candidate = f"{base}-{suffix}"
        suffix += 1

    id_map[source_id] = candidate
    all_skill_ids.add(candidate)
    new_mappings.append((source_id, candidate, now, now, name, name))
    return candidate


# ---------------------------------------------------------------------------
# Streaming loader
# ---------------------------------------------------------------------------

SKILL_INSERT = """
    INSERT INTO raw.lightcast_skills (
        import_batch_id, source_id, skill_id, name,
        type_id, type_name, info_url,
        description, description_source,
        category_id, category_name,
        subcategory_id, subcategory_name,
        is_software, is_language,
        payload, imported_at
    ) VALUES %s
"""

ATTR_INSERT = """
    INSERT INTO raw.lightcast_attributions (
        import_batch_id, name, text, imported_at
    ) VALUES %s
"""

BATCH_SIZE = 2000


def extract_skill_row(item: dict, batch_id: str, skill_id: str, now: datetime) -> tuple:
    type_obj = item.get("type") or {}
    cat_obj = item.get("category") or {}
    subcat_obj = item.get("subcategory") or {}

    return (
        batch_id,
        item["id"],
        skill_id,
        item["name"],
        str(type_obj.get("id")) if type_obj.get("id") is not None else None,
        type_obj.get("name"),
        item.get("infoUrl"),
        item.get("description"),
        item.get("descriptionSource"),
        int(cat_obj["id"]) if cat_obj.get("id") is not None else None,
        cat_obj.get("name"),
        int(subcat_obj["id"]) if subcat_obj.get("id") is not None else None,
        subcat_obj.get("name"),
        item.get("isSoftware"),
        item.get("isLanguage"),
        json.dumps(item),
        now,
    )


def load(meta_path: str, db_url: str, set_current: bool = True) -> None:
    # -- Read meta ---------------------------------------------------------
    with open(meta_path) as f:
        meta = json.load(f)

    version_label = meta["version"]
    filename = meta["filename"]
    data_dir = os.path.dirname(meta_path)
    file_path = os.path.join(data_dir, filename)

    if not os.path.isfile(file_path):
        sys.exit(f"ERROR: Data file not found: {file_path}")

    print(f"Loading Lightcast {version_label} from {file_path}")

    # -- Compute SHA256 ----------------------------------------------------
    sha = file_sha256(file_path)
    print(f"  SHA256: {sha}")

    now = datetime.now(timezone.utc)
    batch_id = f"lightcast_{version_label}_{now.strftime('%Y%m%d%H%M%S')}"

    # -- Connect -----------------------------------------------------------
    conn = psycopg2.connect(db_url)
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            # Verify raw tables exist (created via dbt run-operation)
            check_raw_tables_exist(cur)

            # -- Load id map -----------------------------------------------
            id_map = load_skill_id_map(cur)
            all_skill_ids = load_existing_skill_ids(cur)
            new_mappings: list[tuple] = []
            updated_mappings: list[tuple] = []

            # -- Find previous current batch id ----------------------------
            cur.execute(
                "SELECT import_batch_id FROM raw.lightcast_import_batches "
                "WHERE is_current = true"
            )
            prev_row = cur.fetchone()
            previous_batch_id = prev_row[0] if prev_row else None

            # -- Insert batch row (counts updated later) -------------------
            cur.execute(
                """
                INSERT INTO raw.lightcast_import_batches
                    (import_batch_id, version_label, file_path, file_sha256,
                     imported_at, skill_count, attribution_count,
                     is_current, previous_batch_id)
                VALUES (%s, %s, %s, %s, %s, 0, 0, false, %s)
                """,
                (batch_id, version_label, file_path, sha, now, previous_batch_id),
            )

            # -- Stream attributions ---------------------------------------
            attr_count = 0
            attr_buffer: list[tuple] = []
            with open(file_path, "rb") as f:
                for item in ijson.items(f, "attributions.item"):
                    attr_buffer.append((
                        batch_id,
                        item.get("name", ""),
                        item.get("text", ""),
                        now,
                    ))
                    attr_count += 1
                    if len(attr_buffer) >= BATCH_SIZE:
                        psycopg2.extras.execute_values(cur, ATTR_INSERT, attr_buffer)
                        attr_buffer.clear()

            if attr_buffer:
                psycopg2.extras.execute_values(cur, ATTR_INSERT, attr_buffer)
                attr_buffer.clear()

            print(f"  Attributions loaded: {attr_count}")

            # -- Stream skills ---------------------------------------------
            skill_count = 0
            skill_buffer: list[tuple] = []
            with open(file_path, "rb") as f:
                for item in ijson.items(f, "data.item"):
                    source_id = item["id"]
                    name = item["name"]
                    skill_id = resolve_skill_id(
                        source_id, name, id_map, all_skill_ids,
                        new_mappings, updated_mappings, now,
                    )
                    skill_buffer.append(
                        extract_skill_row(item, batch_id, skill_id, now)
                    )
                    skill_count += 1

                    if len(skill_buffer) >= BATCH_SIZE:
                        psycopg2.extras.execute_values(cur, SKILL_INSERT, skill_buffer)
                        skill_buffer.clear()
                        if skill_count % 10000 == 0:
                            print(f"    ... {skill_count} skills processed")

            if skill_buffer:
                psycopg2.extras.execute_values(cur, SKILL_INSERT, skill_buffer)
                skill_buffer.clear()

            print(f"  Skills loaded: {skill_count}")

            # -- Flush id map changes --------------------------------------
            if new_mappings:
                psycopg2.extras.execute_values(
                    cur,
                    """
                    INSERT INTO raw.lightcast_skill_id_map
                        (source_id, skill_id, first_seen_at, last_seen_at,
                         first_name, last_name)
                    VALUES %s
                    """,
                    new_mappings,
                )
                print(f"  New skill ID mappings: {len(new_mappings)}")

            if updated_mappings:
                psycopg2.extras.execute_values(
                    cur,
                    """
                    UPDATE raw.lightcast_skill_id_map AS m
                    SET last_seen_at = v.last_seen_at,
                        last_name = v.last_name
                    FROM (VALUES %s) AS v(last_seen_at, last_name, source_id)
                    WHERE m.source_id = v.source_id
                    """,
                    updated_mappings,
                )
                print(f"  Updated skill ID mappings: {len(updated_mappings)}")

            # -- Update batch counts ---------------------------------------
            cur.execute(
                """
                UPDATE raw.lightcast_import_batches
                SET skill_count = %s, attribution_count = %s
                WHERE import_batch_id = %s
                """,
                (skill_count, attr_count, batch_id),
            )

            # -- Set current batch (transactionally) -----------------------
            if set_current:
                cur.execute(
                    "UPDATE raw.lightcast_import_batches "
                    "SET is_current = false WHERE is_current = true"
                )
                cur.execute(
                    "UPDATE raw.lightcast_import_batches "
                    "SET is_current = true WHERE import_batch_id = %s",
                    (batch_id,),
                )
                print(f"  Current batch set to: {batch_id}")

            conn.commit()
            print(f"\nBatch {batch_id} committed successfully.")

            # -- Version diff summary --------------------------------------
            if previous_batch_id and set_current:
                print_diff_summary(conn, batch_id, previous_batch_id)

    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Diff summary
# ---------------------------------------------------------------------------


def print_diff_summary(conn, current_batch_id: str, previous_batch_id: str) -> None:
    """Print a summary comparing the current batch against the previous one."""
    with conn.cursor() as cur:
        cur.execute(
            """
            WITH curr AS (
                SELECT source_id, name, type_name, description,
                       category_id, subcategory_id
                FROM raw.lightcast_skills
                WHERE import_batch_id = %s
            ),
            prev AS (
                SELECT source_id, name, type_name, description,
                       category_id, subcategory_id
                FROM raw.lightcast_skills
                WHERE import_batch_id = %s
            ),
            joined AS (
                SELECT
                    coalesce(c.source_id, p.source_id) AS source_id,
                    CASE
                        WHEN p.source_id IS NULL THEN 'added'
                        WHEN c.source_id IS NULL THEN 'removed'
                        WHEN p.name IS DISTINCT FROM c.name THEN 'renamed'
                        WHEN p.type_name IS DISTINCT FROM c.type_name THEN 'type_changed'
                        WHEN p.description IS DISTINCT FROM c.description THEN 'description_changed'
                        WHEN p.category_id IS DISTINCT FROM c.category_id THEN 'category_changed'
                        WHEN p.subcategory_id IS DISTINCT FROM c.subcategory_id THEN 'subcategory_changed'
                        ELSE 'unchanged'
                    END AS change_type
                FROM curr c
                FULL OUTER JOIN prev p USING (source_id)
            )
            SELECT change_type, count(*) AS cnt
            FROM joined
            WHERE change_type != 'unchanged'
            GROUP BY change_type
            ORDER BY change_type
            """,
            (current_batch_id, previous_batch_id),
        )

        rows = cur.fetchall()
        if rows:
            print("\n--- Version Update Summary ---")
            for change_type, cnt in rows:
                print(f"  {change_type}: {cnt}")
        else:
            print("\n--- No changes detected between versions ---")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description="Load Lightcast JSON into PostgreSQL")
    parser.add_argument(
        "--meta",
        default="data/lightcast/import_meta.json",
        help="Path to import_meta.json (default: data/lightcast/import_meta.json)",
    )
    parser.add_argument(
        "--db-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="PostgreSQL connection URL (or set DATABASE_URL env var)",
    )
    parser.add_argument(
        "--no-set-current",
        action="store_true",
        help="Do not mark this batch as current",
    )
    args = parser.parse_args()

    if not args.db_url:
        sys.exit("ERROR: --db-url or DATABASE_URL env var is required")

    load(args.meta, args.db_url, set_current=not args.no_set_current)


if __name__ == "__main__":
    main()
