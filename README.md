# Department of Labor Cases Lookup

Search U.S. Department of Labor (DOL) foreign labor certification records for H-1B, PERM, H-2A, and H-2B visa cases. Look up any employer's visa sponsorship history, including wages offered, job titles, case outcomes, and work locations.

Data comes from the [OFLC Quarterly Disclosure Data](https://www.dol.gov/agencies/eta/foreign-labor/performance) files published by the Office of Foreign Labor Certification. These are the official public records of every employer's labor condition application and permanent labor certification filing.

> **Note:** The original iCERT system (`icert.doleta.gov`) was decommissioned in December 2024. This tool uses the quarterly disclosure data files as its data source.

## What Can You Look Up?

- Which companies are sponsoring H-1B visas and how many
- What salaries employers are offering for sponsored positions
- Whether a specific case was certified, denied, or withdrawn
- Sponsorship activity filtered by state, job title, or visa type
- Wage trends and distributions across employers and roles

## Quick Start

### Web Dashboard

The easiest way to use this tool is through the web dashboard -- a dark-themed interface with search, wage charts, and real-time data import.

```bash
# With Docker (no Ruby installation needed)
docker compose up -d
# Open http://localhost:9292

# Or run directly with Ruby
bin/dol-web
```

On first use, you'll be prompted to import data for the program and quarter you want to search. The import downloads the disclosure file from DOL and loads it into a local database. Subsequent searches are instant.

### Command Line

```bash
# Search H-1B cases by employer
bin/dol-lookup --employer Google

# Search permanent labor certification (PERM) cases
bin/dol-lookup --program perm --employer Microsoft

# Filter by state
bin/dol-lookup --employer Meta --state CA

# Search by job title
bin/dol-lookup --job-title "software engineer" --state WA

# Output as JSON or CSV
bin/dol-lookup --employer Google --format json
bin/dol-lookup --employer Google --format csv
```

## Requirements

Ruby >= 3.3 (install via [rbenv](https://github.com/rbenv/rbenv) or similar)

## Installation

```bash
git clone <repo-url>
cd dol-cases-lookup
bundle install
```

## Visa Programs

| Program | Flag | What It Covers |
|---------|------|----------------|
| **LCA** (Labor Condition Application) | `lca` | H-1B, H-1B1, and E-3 specialty occupation workers -- the most common employer-sponsored work visa |
| **PERM** (Permanent Labor Certification) | `perm` | Employer-sponsored green card applications -- the first step in employment-based permanent residency |
| **H-2A** | `h2a` | Temporary agricultural workers -- seasonal farm labor |
| **H-2B** | `h2b` | Temporary non-agricultural workers -- seasonal hospitality, landscaping, forestry, etc. |

## Web Dashboard Features

- **Search with filters** -- employer name, job title, state, visa class, case status, and more
- **Wage analytics** -- average, median, min/max wages with a distribution histogram
- **Case status breakdown** -- visual chart of certified vs. denied vs. withdrawn cases
- **Top employers** -- ranked by number of filings with certification rates and median wages
- **Real-time import** -- progress bar with live updates while loading disclosure data
- **Security** -- CSRF protection, security headers, optional HTTP Basic Auth, SRI on CDN resources

## CLI Reference

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

### CLI Examples

```bash
# Specific fiscal year and quarter
bin/dol-lookup --program lca --year 2024 --quarter 4 --employer Apple

# Look up a specific case by number
bin/dol-lookup --case-number I-200-12345-678901

# Force re-download of cached data
bin/dol-lookup --refresh --employer Google
```

## How It Works

1. **Download** -- Quarterly XLSX disclosure files are fetched from the DOL website and cached locally
2. **Parse** -- The XLSX file is streamed through a SAX parser (Nokogiri + rubyzip) with minimal memory usage (~84MB for 900K rows)
3. **Store** -- Parsed rows are batch-inserted into a local SQLite database for fast querying
4. **Search** -- Queries run against SQLite with indexes on employer name, case number, state, job title, and wages

Data is cached at `~/.dol_lookup/cache/`. Once imported, searches are instant. Use `--refresh` (CLI) or the import page (web) to re-download when new quarterly data is published.

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `DOL_LOOKUP_CACHE_DIR` | Directory for cached XLSX and SQLite files | `~/.dol_lookup/cache/` |
| `PORT` | Web server port | `9292` |
| `SESSION_SECRET` | Session secret for CSRF tokens (min 64 chars) | Auto-generated |
| `DOL_AUTH_USER` | HTTP Basic Auth username (enables auth when set) | -- |
| `DOL_AUTH_PASS` | HTTP Basic Auth password | -- |

## Docker

```bash
# Build and start the web dashboard
docker compose up -d

# Use the CLI inside the container
docker compose exec web bin/dol-lookup --employer Google

# Stop (imported data persists in volume)
docker compose down

# Stop and delete all imported data
docker compose down -v
```

Data is stored in a Docker volume (`dol-data`). The container runs with a 512MB memory limit.

## Development

```bash
# Run all tests (121 specs, no network access required)
bundle exec rspec

# Run a single test file
bundle exec rspec spec/unit/web_spec.rb

# Regenerate XLSX test fixtures
ruby spec/generate_fixtures.rb
```

### Architecture

```
Download XLSX --> SAX-parse with Nokogiri --> Batch-insert into SQLite --> Query with SQL
```

Key design decisions:

- **Two-layer cache** -- XLSX files cached on disk to avoid re-downloading; SQLite databases cached alongside to avoid re-parsing
- **Streaming parser** -- Custom `XlsxReader` uses Nokogiri SAX + rubyzip to stream rows directly from the zip archive with ~84MB memory for 900K rows
- **Prepared statements** -- INSERT statements are prepared once and reused across all batch inserts for throughput
- **Import-specific SQLite tuning** -- Aggressive PRAGMAs (`journal_mode=OFF`, `synchronous=OFF`) during import to a temp file, with atomic rename on success

### Data Source

Disclosure files are downloaded from:
```
https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/{PREFIX}_Disclosure_Data_FY{YEAR}_Q{QUARTER}.xlsx
```

Column names differ per program -- see `lib/dol_lookup/column_map.rb` for the mapping between XLSX headers and internal field names.

## Changelog

### 3.2.0

- **Parser optimization** -- replaced O(n) column lookup with O(1) hash-based extraction, ~2-3x faster parsing
- **Prepared statement reuse** -- INSERT statements prepared once and reused across all batch inserts
- **SQLite import tuning** -- aggressive PRAGMAs during bulk import (journal off, synchronous off, 64MB cache)
- **Batch size increase** -- 1,000 to 5,000 rows per transaction for reduced commit overhead
- **YJIT enabled** -- automatic JIT compilation on Ruby 3.3+ for ~15-30% overall speedup

### 3.1.0

- **Compact UI overhaul** -- dense 2-row search form, stats strip, compact charts, reduced spacing via Pico CSS variable overrides
- **Import spinner fix** -- reuse DOM element during SSE progress updates so `aria-busy` spinner animation is not interrupted
- **Playwright E2E tests** -- 12 tests covering dashboard, import, search, charts, htmx partials, pagination, security headers, and CSRF

### 3.0.0

- **Web dashboard** -- Sinatra-based interactive UI with dark theme (Pico CSS v2)
- **Wage analytics** -- summary stats, wage distribution histogram, case status doughnut chart
- **Top employers chart** -- horizontal bar chart showing employers by case volume
- **Real-time import** -- SSE progress updates via native EventSource during XLSX import
- **htmx search** -- partial page updates with pagination, filters, and live results
- **Empty state** -- guides first-time users to the import page when no data is loaded
- **Docker support** -- `docker compose up -d` with persistent data volume and 512MB memory limit
- **Security hardened** -- CSRF protection, SRI integrity on CDN resources, security headers, optional HTTP Basic Auth

### 2.1.0

- **SAX XLSX parser** -- replaced Creek with custom `XlsxReader` using Nokogiri SAX + rubyzip for streaming XLSX parsing directly from zip; reduced import memory from >4GB to ~84MB for 900K-row files

### 2.0.0

- Rewrite to use OFLC disclosure data (XLSX files) instead of decommissioned iCERT API

### 1.0.0

- Initial implementation using iCERT API
