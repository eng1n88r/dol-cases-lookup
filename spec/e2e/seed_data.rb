#!/usr/bin/env ruby
# Imports fixture XLSX into SQLite so Playwright tests have data to query.
#
# In Docker: ruby /e2e/seed_data.rb (app at /app, fixtures at /fixtures)
# Locally:   ruby spec/e2e/seed_data.rb (from project root)

# Resolve app root: in Docker WORKDIR is /app, locally it's the project root
app_root = ENV["APP_ROOT"] || (File.exist?("/app/lib/dol_lookup.rb") ? "/app" : File.expand_path("../..", __dir__))
$LOAD_PATH.unshift(File.join(app_root, "lib"))

require "dol_lookup"

cache_dir = DolLookup::Config.cache_dir
FileUtils.mkdir_p(cache_dir)

# Find the fixture XLSX
fixture_paths = [
  "/fixtures/lca_sample.xlsx",                                    # Docker mount
  File.join(app_root, "spec", "fixtures", "lca_sample.xlsx"),     # Local / app copy
]
fixture = fixture_paths.find { |p| File.exist?(p) }

unless fixture
  $stderr.puts "Fixture not found at any of: #{fixture_paths.join(', ')}"
  exit 1
end

# Copy fixture XLSX to cache dir
xlsx_dest = File.join(cache_dir, "lca_FY2024_Q3.xlsx")
FileUtils.cp(fixture, xlsx_dest)

# Import into SQLite
db = DolLookup::Database.new(program: "lca", year: 2024, quarter: 3)
if db.ready?
  puts "Database already exists at #{db.db_path}, skipping import."
else
  puts "Importing #{fixture} -> #{db.db_path}"
  db.import(xlsx_dest)
  puts "Imported successfully. DB at #{db.db_path}"
end
