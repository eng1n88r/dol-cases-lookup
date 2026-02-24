require "spec_helper"
require "tmpdir"

RSpec.describe DolLookup::CLI do
  describe "option parsing" do
    it "shows version" do
      expect {
        begin
          DolLookup::CLI.new(["--version"]).run
        rescue SystemExit
        end
      }.to output(/#{DolLookup::VERSION}/).to_stdout
    end

    it "shows help" do
      expect {
        begin
          DolLookup::CLI.new(["--help"]).run
        rescue SystemExit
        end
      }.to output(/Usage: dol-lookup/).to_stdout
    end
  end

  describe "validation" do
    it "rejects invalid quarter" do
      cli = DolLookup::CLI.new(["--quarter", "5", "--employer", "test"])
      expect { cli.run }.to raise_error(SystemExit)
    end

    it "rejects invalid year" do
      cli = DolLookup::CLI.new(["--year", "1999", "--employer", "test"])
      expect { cli.run }.to raise_error(SystemExit)
    end
  end

  describe "full run with stubbed data" do
    let(:tmpdir) { Dir.mktmpdir("dol_cli_test") }
    let(:fixture_path) { File.join(FIXTURE_DIR, "lca_sample.xlsx") }

    before do
      allow(DolLookup::Config).to receive(:cache_dir).and_return(tmpdir)
      allow_any_instance_of(DolLookup::Downloader).to receive(:download).and_return(fixture_path)
    end

    after { FileUtils.rm_rf(tmpdir) }

    it "searches and outputs results" do
      output = capture_stdout { DolLookup::CLI.new(["--employer", "GOOGLE"]).run }
      expect(output).to include("GOOGLE LLC")
    end

    it "outputs JSON format" do
      output = capture_stdout { DolLookup::CLI.new(["--employer", "GOOGLE", "--format", "json"]).run }
      parsed = JSON.parse(output)
      expect(parsed).to be_an(Array)
      expect(parsed.length).to be >= 1
    end

    it "outputs CSV format" do
      output = capture_stdout { DolLookup::CLI.new(["--employer", "GOOGLE", "--format", "csv"]).run }
      expect(output).to include("Case Number")
      expect(output).to include("GOOGLE LLC")
    end

    it "handles no results" do
      output = capture_stdout { DolLookup::CLI.new(["--employer", "NONEXISTENT_CORP"]).run }
      expect(output).to include("No results found")
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
