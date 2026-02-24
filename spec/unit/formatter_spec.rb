require "spec_helper"

RSpec.describe DolLookup::Formatter do
  let(:rows) do
    [
      { "CASE_NUMBER" => "I-200-12345-678901", "CASE_STATUS" => "Certified",
        "EMPLOYER_NAME" => "GOOGLE LLC", "JOB_TITLE" => "SOFTWARE ENGINEER",
        "WORKSITE_CITY" => "MOUNTAIN VIEW", "WORKSITE_STATE" => "CA",
        "WAGE_RATE_OF_PAY_FROM" => "180000", "DECISION_DATE" => "02/01/2024",
        "VISA_CLASS" => "H-1B" },
      { "CASE_NUMBER" => "I-200-12345-678902", "CASE_STATUS" => "Denied",
        "EMPLOYER_NAME" => "META PLATFORMS INC", "JOB_TITLE" => "DATA SCIENTIST",
        "WORKSITE_CITY" => "MENLO PARK", "WORKSITE_STATE" => "CA",
        "WAGE_RATE_OF_PAY_FROM" => "190000", "DECISION_DATE" => "02/15/2024",
        "VISA_CLASS" => "H-1B" }
    ]
  end

  let(:formatter) { described_class.new(rows, program: "lca") }

  describe "#format" do
    context "table format" do
      it "returns a table string" do
        output = formatter.format(:table)
        expect(output).to include("GOOGLE LLC")
        expect(output).to include("META PLATFORMS INC")
        expect(output).to include("2 result(s) found")
      end

      it "shows column headers" do
        output = formatter.format(:table)
        expect(output).to include("Case Number")
        expect(output).to include("Employer")
        expect(output).to include("Status")
      end
    end

    context "csv format" do
      it "returns CSV with headers" do
        output = formatter.format(:csv)
        lines = output.split("\n")
        expect(lines.first).to include("Case Number")
        expect(lines.length).to eq(3) # header + 2 rows
      end

      it "includes data values" do
        output = formatter.format(:csv)
        expect(output).to include("GOOGLE LLC")
        expect(output).to include("I-200-12345-678901")
      end
    end

    context "json format" do
      it "returns valid JSON" do
        output = formatter.format(:json)
        parsed = JSON.parse(output)
        expect(parsed).to be_an(Array)
        expect(parsed.length).to eq(2)
      end

      it "uses display labels as keys" do
        output = formatter.format(:json)
        parsed = JSON.parse(output)
        expect(parsed.first).to have_key("Case Number")
        expect(parsed.first).to have_key("Employer")
      end
    end

    context "with no results" do
      let(:formatter) { described_class.new([], program: "lca") }

      it "returns no results message for table" do
        expect(formatter.format(:table)).to eq("No results found.")
      end

      it "returns empty string for csv" do
        expect(formatter.format(:csv)).to eq("")
      end

      it "returns empty JSON array" do
        expect(formatter.format(:json)).to eq("[\n\n]")
      end
    end

    it "raises for unknown format" do
      expect { formatter.format(:xml) }.to raise_error(ArgumentError, /Unknown format/)
    end
  end
end
