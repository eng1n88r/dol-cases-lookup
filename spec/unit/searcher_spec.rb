require "spec_helper"
require "tmpdir"

RSpec.describe DolLookup::Searcher do
  let(:tmpdir) { Dir.mktmpdir("dol_searcher_test") }
  let(:fixture_path) { File.join(FIXTURE_DIR, "lca_sample.xlsx") }
  let(:db) { DolLookup::Database.new(program: "lca", year: 2024, quarter: 3) }
  let(:searcher) { described_class.new(db, program: "lca") }

  before do
    allow(DolLookup::Config).to receive(:cache_dir).and_return(tmpdir)
    db.import(fixture_path)
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#search" do
    it "returns all rows with no filters" do
      results = searcher.search({})
      expect(results.length).to eq(10)
    end

    it "filters by employer name (substring, case-insensitive)" do
      results = searcher.search(employer: "google")
      expect(results.length).to eq(2)
      expect(results.first["EMPLOYER_NAME"]).to include("GOOGLE")
    end

    it "filters by case number (exact match)" do
      results = searcher.search(case_number: "I-200-12345-678903")
      expect(results.length).to eq(1)
      expect(results.first["EMPLOYER_NAME"]).to eq("META PLATFORMS INC")
    end

    it "filters by state" do
      results = searcher.search(state: "WA")
      expect(results.length).to eq(2)
    end

    it "filters by status (exact match, case-insensitive)" do
      results = searcher.search(status: "denied")
      expect(results.length).to eq(1)
      expect(results.first["EMPLOYER_NAME"]).to eq("META PLATFORMS INC")
    end

    it "filters by job title (substring match)" do
      results = searcher.search(job_title: "software")
      expect(results.length).to eq(4)
    end

    it "filters by visa class" do
      results = searcher.search(visa_class: "H-1B1 Chile")
      expect(results.length).to eq(1)
      expect(results.first["EMPLOYER_NAME"]).to eq("AMAZON.COM SERVICES LLC")
    end

    it "combines multiple filters" do
      results = searcher.search(state: "CA", status: "Certified")
      expect(results.length).to eq(3)
      expect(results.map { |r| r["EMPLOYER_NAME"] }).to contain_exactly("GOOGLE LLC", "APPLE INC", "UBER TECHNOLOGIES INC")
    end

    it "returns empty array when no results match" do
      results = searcher.search(employer: "nonexistent")
      expect(results).to be_empty
    end
  end
end
