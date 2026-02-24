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

## Usage

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
bundle exec rspec
```

## History

- 2.0.0 — Rewrite to use OFLC disclosure data (XLSX files) instead of decommissioned iCERT API
- 1.0.0 — Initial implementation using iCERT API
