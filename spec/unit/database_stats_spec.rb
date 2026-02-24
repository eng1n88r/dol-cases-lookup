require "spec_helper"
require "tmpdir"

RSpec.describe DolLookup::Database do
  let(:tmpdir) { Dir.mktmpdir("dol_stats_test") }
  let(:db) { described_class.new(program: "lca", year: 2024, quarter: 3) }
  let(:fixture_path) { File.join(FIXTURE_DIR, "lca_sample.xlsx") }

  before do
    allow(DolLookup::Config).to receive(:cache_dir).and_return(tmpdir)
    db.import(fixture_path)
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#count" do
    it "returns total count with no filters" do
      expect(db.count).to eq(10)
    end

    it "returns filtered count" do
      expect(db.count(employer: "GOOGLE")).to eq(2)
    end

    it "returns zero for no matches" do
      expect(db.count(employer: "NONEXISTENT")).to eq(0)
    end

    it "accepts keyword arguments" do
      expect(db.count(state: "CA")).to be > 0
    end
  end

  describe "#query with pagination" do
    it "limits results" do
      results = db.query({}, limit: 3)
      expect(results.length).to eq(3)
    end

    it "offsets results" do
      all_results = db.query({})
      offset_results = db.query({}, limit: 5, offset: 5)
      expect(offset_results.length).to eq(5)
      expect(offset_results.first).not_to eq(all_results.first)
    end

    it "returns remaining rows when offset exceeds count" do
      results = db.query({}, limit: 5, offset: 8)
      expect(results.length).to eq(2)
    end
  end

  describe "#stats" do
    it "returns summary with wage statistics" do
      result = db.stats
      expect(result).to have_key(:summary)
      summary = result[:summary]
      expect(summary).to be_an(Array)
      # [total_cases, min_wage, max_wage, avg_wage, median_wage]
      expect(summary[0]).to be > 0  # total_cases
      expect(summary[1]).to be > 0  # min_wage
      expect(summary[2]).to be > 0  # max_wage
    end

    it "returns histogram data" do
      result = db.stats
      expect(result).to have_key(:histogram)
      expect(result[:histogram]).to be_an(Array)
      expect(result[:histogram].first).to have_key("wage_range")
      expect(result[:histogram].first).to have_key("case_count")
    end

    it "returns status breakdown" do
      result = db.stats
      expect(result).to have_key(:by_status)
      expect(result[:by_status]).to be_an(Array)
      expect(result[:by_status].first).to have_key("case_status")
      expect(result[:by_status].first).to have_key("count")
    end

    it "filters stats by employer" do
      result = db.stats(employer: "GOOGLE")
      expect(result[:summary][0]).to be < db.stats[:summary][0]
    end

    it "accepts keyword arguments" do
      result = db.stats(state: "CA")
      expect(result[:summary]).to be_an(Array)
    end
  end

  describe "#top_employers" do
    it "returns a list of employers" do
      result = db.top_employers
      expect(result).to be_an(Array)
      expect(result.first).to have_key("employer_name")
      expect(result.first).to have_key("case_count")
      expect(result.first).to have_key("avg_wage")
      expect(result.first).to have_key("median_wage")
    end

    it "respects limit" do
      result = db.top_employers(limit: 3)
      expect(result.length).to be <= 3
    end

    it "filters by employer" do
      result = db.top_employers(employer: "GOOGLE")
      expect(result.length).to eq(1)
      expect(result.first["employer_name"]).to include("GOOGLE")
    end
  end

  describe "#import_with_progress" do
    let(:new_db) { described_class.new(program: "lca", year: 2025, quarter: 1) }

    it "imports with progress callback" do
      progress_values = []
      new_db.import_with_progress(fixture_path) { |rows| progress_values << rows }
      expect(progress_values).not_to be_empty
      expect(progress_values.last).to eq(10)
    end

    it "creates a working database" do
      new_db.import_with_progress(fixture_path) {}
      expect(new_db.ready?).to be true
      expect(new_db.count).to eq(10)
    end

    it "uses atomic replacement (preserves old DB on failure)" do
      # First import succeeds
      new_db.import_with_progress(fixture_path) {}
      expect(new_db.ready?).to be true

      # Create a second DB that will fail import
      bad_db = described_class.new(program: "lca", year: 2025, quarter: 1)
      expect {
        bad_db.import_with_progress("/nonexistent/file.xlsx") {}
      }.to raise_error(StandardError)

      # Original DB should still be intact
      expect(new_db.ready?).to be true
      expect(new_db.count).to eq(10)
    end
  end

  describe "sanitize_like" do
    it "escapes LIKE wildcards in employer search" do
      # Searching for "50%" should not match everything
      results = db.query(employer: "50%")
      expect(results).to be_empty
    end

    it "escapes underscore in searches" do
      results = db.query(employer: "G_OGLE")
      expect(results).to be_empty
    end
  end
end
