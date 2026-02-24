require "spec_helper"
require "tmpdir"

RSpec.describe DolLookup::Database do
  let(:tmpdir) { Dir.mktmpdir("dol_db_test") }
  let(:db) { described_class.new(program: "lca", year: 2024, quarter: 3) }
  let(:fixture_path) { File.join(FIXTURE_DIR, "lca_sample.xlsx") }

  before do
    allow(DolLookup::Config).to receive(:cache_dir).and_return(tmpdir)
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe "#ready?" do
    it "returns false when no database exists" do
      expect(db.ready?).to be false
    end

    it "returns true after import" do
      db.import(fixture_path)
      expect(db.ready?).to be true
    end
  end

  describe "#import" do
    it "creates a SQLite database file" do
      db.import(fixture_path)
      expect(File.exist?(db.db_path)).to be true
    end

    it "imports all rows from the fixture" do
      db.import(fixture_path)
      results = db.query({})
      expect(results.length).to eq(10)
    end

    it "re-imports cleanly (drops old data)" do
      db.import(fixture_path)
      db.import(fixture_path)
      results = db.query({})
      expect(results.length).to eq(10)
    end
  end

  describe "#query" do
    before { db.import(fixture_path) }

    it "returns all rows with no filters" do
      results = db.query({})
      expect(results.length).to eq(10)
    end

    it "returns hashes keyed by XLSX column headers" do
      results = db.query({})
      expect(results.first).to have_key("CASE_NUMBER")
      expect(results.first).to have_key("EMPLOYER_NAME")
    end

    it "filters by employer (substring, case-insensitive)" do
      results = db.query(employer: "google")
      expect(results.length).to eq(2)
      results.each { |r| expect(r["EMPLOYER_NAME"]).to include("GOOGLE") }
    end

    it "filters by case number (exact, case-insensitive)" do
      results = db.query(case_number: "I-200-12345-678903")
      expect(results.length).to eq(1)
      expect(results.first["EMPLOYER_NAME"]).to eq("META PLATFORMS INC")
    end

    it "filters by state (worksite or employer)" do
      results = db.query(state: "WA")
      expect(results.length).to eq(2)
    end

    it "filters by status" do
      results = db.query(status: "Denied")
      expect(results.length).to eq(1)
      expect(results.first["EMPLOYER_NAME"]).to eq("META PLATFORMS INC")
    end

    it "filters by job title (substring)" do
      results = db.query(job_title: "software")
      expect(results.length).to eq(4)
    end

    it "filters by visa class" do
      results = db.query(visa_class: "H-1B1 Chile")
      expect(results.length).to eq(1)
      expect(results.first["EMPLOYER_NAME"]).to eq("AMAZON.COM SERVICES LLC")
    end

    it "combines multiple filters" do
      results = db.query(state: "CA", status: "Certified")
      expect(results.length).to eq(3)
      names = results.map { |r| r["EMPLOYER_NAME"] }
      expect(names).to contain_exactly("GOOGLE LLC", "APPLE INC", "UBER TECHNOLOGIES INC")
    end

    it "returns empty array when no results match" do
      results = db.query(employer: "nonexistent")
      expect(results).to be_empty
    end
  end

  context "with PERM program" do
    let(:db) { described_class.new(program: "perm", year: 2024, quarter: 1) }
    let(:fixture_path) { File.join(FIXTURE_DIR, "perm_sample.xlsx") }

    it "imports and queries PERM data" do
      db.import(fixture_path)
      results = db.query(employer: "GOOGLE")
      expect(results.length).to eq(1)
      expect(results.first["CASE_NUMBER"]).to eq("A-12345-67890")
    end
  end
end
