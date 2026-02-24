"""
MIND Tech Ontology loader.

Loads __aggregated_skills.json and __aggregated_concepts.json into
PostgreSQL raw tables (full replace each run).

Usage:
    uv run python scripts/load_mind_ontology.py \
        --data-dir data/mind \
        --db-url postgresql://user:pass@localhost:5432/dbname
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

import psycopg2
import psycopg2.extras

REQUIRED_TABLES = [
    "raw.mind_skills",
    "raw.mind_concepts",
]


def check_raw_tables_exist(cur) -> None:
    """Verify that all required raw tables exist, or exit with guidance."""
    cur.execute(
        """
        SELECT table_schema || '.' || table_name
        FROM information_schema.tables
        WHERE table_schema = 'raw'
          AND table_name LIKE 'mind_%'
        """
    )
    existing = {row[0] for row in cur.fetchall()}
    missing = [t for t in REQUIRED_TABLES if t not in existing]
    if missing:
        sys.exit(
            "ERROR: Required raw tables not found: "
            + ", ".join(missing)
            + "\nRun:  dbt run-operation create_mind_raw_tables"
        )


def load(data_dir: str, db_url: str) -> None:
    skills_path = os.path.join(data_dir, "__aggregated_skills.json")
    concepts_path = os.path.join(data_dir, "__aggregated_concepts.json")
    meta_path = os.path.join(data_dir, "import_meta.json")

    for path in [skills_path, concepts_path]:
        if not os.path.isfile(path):
            sys.exit(f"ERROR: File not found: {path}")

    # Read import ref from meta if available
    import_ref = None
    if os.path.isfile(meta_path):
        with open(meta_path) as f:
            meta = json.load(f)
        import_ref = meta.get("ref")

    now = datetime.now(timezone.utc)

    print(f"Loading MIND ontology from {data_dir}")
    if import_ref:
        print(f"  Ref: {import_ref}")

    # Load JSON files
    with open(skills_path) as f:
        skills = json.load(f)
    print(f"  Skills in file: {len(skills)}")

    with open(concepts_path) as f:
        concepts = json.load(f)
    print(f"  Concepts in file: {len(concepts)}")

    conn = psycopg2.connect(db_url)
    conn.autocommit = False

    try:
        with conn.cursor() as cur:
            check_raw_tables_exist(cur)

            # Full replace: truncate and reload
            cur.execute("TRUNCATE raw.mind_skills")
            cur.execute("TRUNCATE raw.mind_concepts")

            # Insert skills
            skill_rows = [
                (s["name"], json.dumps(s), import_ref, now)
                for s in skills
            ]
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO raw.mind_skills (name, payload, import_ref, imported_at)
                VALUES %s
                """,
                skill_rows,
                page_size=2000,
            )
            print(f"  Skills loaded: {len(skill_rows)}")

            # Insert concepts
            concept_rows = [
                (c["name"], json.dumps(c), import_ref, now)
                for c in concepts
            ]
            psycopg2.extras.execute_values(
                cur,
                """
                INSERT INTO raw.mind_concepts (name, payload, import_ref, imported_at)
                VALUES %s
                """,
                concept_rows,
                page_size=2000,
            )
            print(f"  Concepts loaded: {len(concept_rows)}")

            conn.commit()
            print("\nMIND ontology loaded successfully.")

    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Load MIND Tech Ontology into PostgreSQL"
    )
    parser.add_argument(
        "--data-dir",
        default="data/mind",
        help="Directory containing MIND JSON files (default: data/mind)",
    )
    parser.add_argument(
        "--db-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="PostgreSQL connection URL (or set DATABASE_URL env var)",
    )
    args = parser.parse_args()

    if not args.db_url:
        sys.exit("ERROR: --db-url or DATABASE_URL env var is required")

    load(args.data_dir, args.db_url)


if __name__ == "__main__":
    main()
