require "spec_helper"

RSpec.describe DolLookup::Config do
  describe ".disclosure_url" do
    it "builds the correct URL for LCA" do
      url = described_class.disclosure_url(program: "lca", year: 2024, quarter: 3)
      expect(url).to eq("https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/LCA_Disclosure_Data_FY2024_Q3.xlsx")
    end

    it "builds the correct URL for PERM" do
      url = described_class.disclosure_url(program: "perm", year: 2024, quarter: 1)
      expect(url).to eq("https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/PERM_Disclosure_Data_FY2024_Q1.xlsx")
    end

    it "builds the correct URL for H-2A" do
      url = described_class.disclosure_url(program: "h2a", year: 2023, quarter: 4)
      expect(url).to eq("https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/H-2A_Disclosure_Data_FY2023_Q4.xlsx")
    end

    it "builds the correct URL for H-2B" do
      url = described_class.disclosure_url(program: "h2b", year: 2024, quarter: 2)
      expect(url).to eq("https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs/H-2B_Disclosure_Data_FY2024_Q2.xlsx")
    end

    it "raises ArgumentError for unknown program" do
      expect { described_class.disclosure_url(program: "unknown", year: 2024, quarter: 1) }
        .to raise_error(ArgumentError, /Unknown program/)
    end
  end

  describe ".cache_path" do
    it "returns a path under the cache directory" do
      path = described_class.cache_path(program: "lca", year: 2024, quarter: 3)
      expect(path).to end_with("lca_FY2024_Q3.xlsx")
      expect(path).to include(".dol_lookup/cache")
    end
  end

  describe ".db_path" do
    it "returns a .db path under the cache directory" do
      path = described_class.db_path(program: "lca", year: 2024, quarter: 3)
      expect(path).to end_with("lca_FY2024_Q3.db")
      expect(path).to include(".dol_lookup/cache")
    end
  end

  describe "PROGRAMS" do
    it "contains all four programs" do
      expect(described_class::PROGRAMS.keys).to contain_exactly("lca", "perm", "h2a", "h2b")
    end
  end

  describe "defaults" do
    it "has a default program" do
      expect(described_class::DEFAULT_PROGRAM).to eq("lca")
    end

    it "has a default year" do
      expect(described_class::DEFAULT_YEAR).to be_a(Integer)
    end

    it "has a default quarter between 1 and 4" do
      expect(described_class::DEFAULT_QUARTER).to be_between(1, 4)
    end
  end
end
