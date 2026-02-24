# DOL Cases Lookup

Search DOL OFLC disclosure data for visa certification cases (H-1B, PERM, H-2A, H-2B).

Uses the [OFLC Quarterly Disclosure Data](https://www.dol.gov/agencies/eta/foreign-labor/performance) XLSX files published by the Department of Labor.

> **Note:** The original iCERT system (`icert.doleta.gov`) was decommissioned in December 2024. This tool now uses the quarterly disclosure data files as its data source.

## Requirements

Ruby >= 3.3 (install via [rbenv](https://github.com/rbenv/rbenv) or similar)

## Installation

```bash
git clone <repo-url>
cd dol-cases-lookup
bundle install
```

## Web Dashboard

Interactive dark-themed dashboard with search, wage analytics, and real-time import progress.

```bash
# Start locally
bin/dol-web

# Or with Docker
docker compose up -d
```

Open [http://localhost:9292](http://localhost:9292) in your browser.

### Features

- **Dark theme** — Pico CSS v2 dark mode with Chart.js dark palette
- **Wage analytics** — total cases, average/median/min/max wages, wage distribution histogram
- **Case status breakdown** — doughnut chart of certified/denied/withdrawn
- **Top employers chart** — horizontal bar chart of employers by case count
- **Real-time import progress** — SSE-powered progress updates during data import
- **htmx search** — partial page updates without full reloads
- **Empty state guidance** — prompts first-time users to import data
- **Security** — CSRF protection, security headers, optional HTTP Basic Auth, SRI on all CDN resources

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOL_LOOKUP_CACHE_DIR` | Cache directory for XLSX + SQLite files | `~/.dol_lookup/cache/` |
| `PORT` | Web server port | `9292` |
| `SESSION_SECRET` | Session secret for CSRF tokens (min 64 chars) | Auto-generated |
| `DOL_AUTH_USER` | HTTP Basic Auth username (enables auth when set) | — |
| `DOL_AUTH_PASS` | HTTP Basic Auth password | — |

### Docker

```bash
# Build and start
docker compose up -d

# Use CLI inside container
docker compose exec web bin/dol-lookup --employer Google

# Stop (data persists in volume)
docker compose down

# Stop and destroy data
docker compose down -v
```

Data is stored in a Docker volume (`dol-data`). The container runs with a 512MB memory limit.

## CLI Usage

```bash
# Search H-1B (LCA) cases by employer
bin/dol-lookup --employer Google

# Search PERM cases
bin/dol-lookup --program perm --employer Microsoft

# Filter by state
bin/dol-lookup --employer Meta --state CA

# Specific fiscal year and quarter
bin/dol-lookup --program lca --year 2024 --quarter 4 --employer Apple

# Output as JSON
bin/dol-lookup --employer Google --format json

# Output as CSV
bin/dol-lookup --employer Google --format csv

# Force re-download of cached data
bin/dol-lookup --refresh --employer Google

# Search by case number
bin/dol-lookup --case-number I-200-12345-678901

# Search by job title
bin/dol-lookup --job-title "software engineer" --state WA
```

## Options

```
Data source options:
    -p, --program PROGRAM     Program: lca, perm, h2a, h2b (default: lca)
    -y, --year YEAR           Fiscal year (default: current year)
    -q, --quarter QUARTER     Quarter 1-4 (default: current quarter)
        --refresh             Force re-download of data file

Search filters:
    -e, --employer NAME       Employer name (substring match)
    -c, --case-number NUMBER  Case number (exact match)
    -s, --state STATE         Worksite state abbreviation, e.g. CA
    -j, --job-title TITLE     Job title (substring match)
        --status STATUS       Case status (exact match, e.g. Certified)
        --visa-class CLASS    Visa class (exact match, e.g. H-1B)

Output options:
    -f, --format FORMAT       Output format: table, csv, json (default: table)

    -v, --version             Show version
    -h, --help                Show this help
```

## Programs

| Flag   | Program | Description |
|--------|---------|-------------|
| `lca`  | LCA     | H-1B / H-1B1 / E-3 Labor Condition Applications |
| `perm` | PERM    | Permanent Labor Certification |
| `h2a`  | H-2A    | Temporary Agricultural Workers |
| `h2b`  | H-2B    | Temporary Non-Agricultural Workers |

## Data Source

Data files are downloaded from `https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/` and cached locally at `~/.dol_lookup/cache/`. Use `--refresh` to force a re-download.

## Development

```bash
# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/unit/web_spec.rb

# Regenerate XLSX test fixtures
ruby spec/generate_fixtures.rb
```

## Changelog

### 3.0.0

- **Web dashboard** — Sinatra-based interactive UI with dark theme (Pico CSS v2)
- **Wage analytics** — summary stats, wage distribution histogram, case status doughnut chart
- **Top employers chart** — horizontal bar chart showing employers by case volume
- **Real-time import** — SSE progress updates via native EventSource during XLSX import
- **htmx search** — partial page updates with pagination, filters, and live results
- **Empty state** — guides first-time users to the import page when no data is loaded
- **Docker support** — `docker compose up -d` with persistent data volume and 512MB memory limit
- **Security hardened** — CSRF protection, SRI integrity on CDN resources, security headers, optional HTTP Basic Auth

### 2.1.0

- **SAX XLSX parser** — replaced Creek with custom `XlsxReader` using Nokogiri SAX + rubyzip for streaming XLSX parsing directly from zip; reduced import memory from >4GB to ~84MB for 900K-row files

### 2.0.0

- Rewrite to use OFLC disclosure data (XLSX files) instead of decommissioned iCERT API

### 1.0.0

- Initial implementation using iCERT API
