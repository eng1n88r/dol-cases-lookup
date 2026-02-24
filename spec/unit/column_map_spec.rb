require "spec_helper"

RSpec.describe DolLookup::ColumnMap do
  describe ".columns_for" do
    it "returns mappings for lca" do
      cols = described_class.columns_for("lca")
      expect(cols[:case_number]).to eq("CASE_NUMBER")
      expect(cols[:employer_name]).to eq("EMPLOYER_NAME")
      expect(cols[:wage_from]).to eq("WAGE_RATE_OF_PAY_FROM")
    end

    it "returns mappings for perm" do
      cols = described_class.columns_for("perm")
      expect(cols[:case_number]).to eq("CASE_NUMBER")
      expect(cols[:wage_from]).to eq("WAGE_OFFER_FROM")
      expect(cols[:soc_title]).to eq("PW_SOC_TITLE")
    end

    it "returns mappings for h2a" do
      cols = described_class.columns_for("h2a")
      expect(cols[:employer_name]).to eq("EMPLOYER_NAME")
      expect(cols[:wage_from]).to eq("BASIC_RATE_OF_PAY")
    end

    it "returns mappings for h2b" do
      cols = described_class.columns_for("h2b")
      expect(cols[:employer_name]).to eq("EMPLOYER_NAME")
      expect(cols[:wage_from]).to eq("BASIC_RATE_OF_PAY")
    end

    it "raises ArgumentError for unknown program" do
      expect { described_class.columns_for("unknown") }.to raise_error(ArgumentError)
    end
  end

  describe ".xlsx_column" do
    it "returns the column header for a given field" do
      expect(described_class.xlsx_column("lca", :employer_name)).to eq("EMPLOYER_NAME")
    end

    it "raises for unknown field" do
      expect { described_class.xlsx_column("lca", :nonexistent) }.to raise_error(ArgumentError)
    end
  end

  describe "DISPLAY_COLUMNS" do
    it "defines display labels for common fields" do
      expect(described_class::DISPLAY_COLUMNS[:case_number]).to eq("Case Number")
      expect(described_class::DISPLAY_COLUMNS[:employer_name]).to eq("Employer")
    end
  end
end
