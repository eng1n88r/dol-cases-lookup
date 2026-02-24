require "spec_helper"

RSpec.describe DolLookup::Parser do
  describe "#each_row" do
    context "with LCA fixture" do
      let(:parser) { described_class.new(File.join(FIXTURE_DIR, "lca_sample.xlsx"), program: "lca") }

      it "yields hashes" do
        first_row = parser.each_row.first
        expect(first_row).to be_a(Hash)
      end

      it "parses all rows" do
        rows = parser.each_row.to_a
        expect(rows.length).to eq(10)
      end

      it "only includes mapped columns" do
        row = parser.each_row.first
        lca_columns = DolLookup::ColumnMap.columns_for("lca").values
        row.each_key do |key|
          expect(lca_columns).to include(key)
        end
      end

      it "reads correct values" do
        rows = parser.each_row.to_a
        google_row = rows.find { |r| r["CASE_NUMBER"] == "I-200-12345-678901" }
        expect(google_row["EMPLOYER_NAME"]).to eq("GOOGLE LLC")
        expect(google_row["WORKSITE_STATE"]).to eq("CA")
      end
    end

    context "with PERM fixture" do
      let(:parser) { described_class.new(File.join(FIXTURE_DIR, "perm_sample.xlsx"), program: "perm") }

      it "parses all rows" do
        rows = parser.each_row.to_a
        expect(rows.length).to eq(5)
      end

      it "has PERM-specific columns" do
        row = parser.each_row.first
        expect(row).to have_key("CASE_NUMBER")
        expect(row).to have_key("WAGE_OFFER_FROM")
        expect(row).to have_key("PW_SOC_TITLE")
      end
    end
  end
end
