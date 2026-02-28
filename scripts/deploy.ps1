# Incremental deploy to production (Windows).
# Set production env vars before running (see README).
# Usage:
#   .\scripts\deploy.ps1
#   .\scripts\deploy.ps1 -FullRefresh

param(
    [string]$Target = "prod",
    [switch]$FullRefresh
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

# Ensure raw schema and raw tables exist (Lightcast + MIND). Safe to run every time (IF NOT EXISTS).
Write-Host "Creating raw schema and raw tables if missing..."
uv run dbt run-operation create_lightcast_raw_tables --profiles-dir . --target $Target
uv run dbt run-operation create_mind_raw_tables --profiles-dir . --target $Target

Write-Host "Installing packages (target=$Target)..."
uv run dbt deps --profiles-dir . --target $Target

if ($FullRefresh) {
    Write-Host "Full-refresh seeds..."
    uv run dbt seed --profiles-dir . --target $Target --full-refresh
    Write-Host "Full-refresh models..."
    uv run dbt run --profiles-dir . --target $Target --full-refresh
} else {
    Write-Host "Loading seed data..."
    uv run dbt seed --profiles-dir . --target $Target
    Write-Host "Building models..."
    uv run dbt run --profiles-dir . --target $Target
}

Write-Host "Running tests..."
uv run dbt test --profiles-dir . --target $Target

Write-Host "Deploy complete."
