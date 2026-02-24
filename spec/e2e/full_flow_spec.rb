require "spec_helper"
require "open3"
require "tmpdir"

RSpec.describe "dol-lookup CLI (e2e)" do
  let(:bin_path) { File.expand_path("../../bin/dol-lookup", __dir__) }
  let(:tmpdir) { Dir.mktmpdir("dol_e2e") }

  after { FileUtils.rm_rf(tmpdir) }

  # Sets up a temp cache dir with the fixture pre-copied so no HTTP calls are needed.
  # The CLI will detect no SQLite DB and import from the XLSX on first run.
  def run_cli(*args)
    program = "lca"
    year = Time.now.year.to_s
    quarter = ((Time.now.month - 1) / 3).clamp(1, 4).to_s

    args.each_with_index do |arg, i|
      case arg
      when "--program", "-p" then program = args[i + 1]
      when "--year", "-y" then year = args[i + 1]
      when "--quarter", "-q" then quarter = args[i + 1]
      end
    end

    cache_file = File.join(tmpdir, "#{program}_FY#{year}_Q#{quarter}.xlsx")
    source = case program
             when "perm" then File.join(FIXTURE_DIR, "perm_sample.xlsx")
             else File.join(FIXTURE_DIR, "lca_sample.xlsx")
             end
    FileUtils.cp(source, cache_file)

    env = { "DOL_LOOKUP_CACHE_DIR" => tmpdir }
    cmd = ["ruby", bin_path] + args
    Open3.capture3(env, *cmd)
  end

  describe "help" do
    it "displays usage information" do
      stdout, _, status = Open3.capture3("ruby", bin_path, "--help")
      expect(status.success?).to be true
      expect(stdout).to include("Usage: dol-lookup")
      expect(stdout).to include("--employer")
      expect(stdout).to include("--program")
    end
  end

  describe "version" do
    it "displays the version" do
      stdout, _, status = Open3.capture3("ruby", bin_path, "--version")
      expect(status.success?).to be true
      expect(stdout.strip).to eq("dol-lookup #{DolLookup::VERSION}")
    end
  end

  describe "search with cached data" do
    it "finds results by employer name" do
      stdout, stderr, status = run_cli("--employer", "GOOGLE")
      expect(status.success?).to be(true), "stderr: #{stderr}"
      expect(stdout).to include("GOOGLE LLC")
    end

    it "returns no results message for unknown employer" do
      stdout, stderr, status = run_cli("--employer", "ZZZZNONEXISTENT")
      expect(status.success?).to be(true), "stderr: #{stderr}"
      expect(stdout).to include("No results found")
    end

    it "outputs JSON format" do
      stdout, stderr, status = run_cli("--employer", "GOOGLE", "--format", "json")
      expect(status.success?).to be(true), "stderr: #{stderr}"
      parsed = JSON.parse(stdout)
      expect(parsed).to be_an(Array)
      expect(parsed.any? { |r| r["Employer"]&.include?("GOOGLE") }).to be true
    end

    it "outputs CSV format" do
      stdout, stderr, status = run_cli("--employer", "GOOGLE", "--format", "csv")
      expect(status.success?).to be(true), "stderr: #{stderr}"
      expect(stdout).to include("Case Number")
      expect(stdout).to include("GOOGLE")
    end

    it "filters by state" do
      stdout, stderr, status = run_cli("--state", "WA")
      expect(status.success?).to be(true), "stderr: #{stderr}"
      expect(stdout).to include("MICROSOFT")
    end

    it "supports PERM program" do
      stdout, stderr, status = run_cli("--program", "perm", "--employer", "GOOGLE")
      expect(status.success?).to be(true), "stderr: #{stderr}"
      expect(stdout).to include("GOOGLE")
    end

    it "creates a SQLite database on first run" do
      run_cli("--employer", "GOOGLE")
      db_files = Dir.glob(File.join(tmpdir, "*.db"))
      expect(db_files).not_to be_empty
    end

    it "uses existing SQLite database on second run" do
      # First run creates the DB
      _, stderr1, _ = run_cli("--employer", "GOOGLE")
      expect(stderr1).to include("Importing")

      # Second run should NOT re-import (no "Importing" in stderr)
      _, stderr2, _ = run_cli("--employer", "GOOGLE")
      expect(stderr2).not_to include("Importing")
    end
  end
end
