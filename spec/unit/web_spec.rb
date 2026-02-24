require "spec_helper"
require "rack/test"
require "tmpdir"
require_relative "../../lib/dol_lookup/web"

RSpec.describe DolLookup::Web do
  include Rack::Test::Methods

  let(:app) { described_class }
  let(:tmpdir) { Dir.mktmpdir("dol_web_test") }
  let(:fixture_path) { File.join(FIXTURE_DIR, "lca_sample.xlsx") }

  before do
    allow(DolLookup::Config).to receive(:cache_dir).and_return(tmpdir)
    described_class.set :session_secret, "a" * 64
    described_class.set :environment, :test
    described_class.set :protection, except: [:http_origin, :remote_token, :host_authorization]
  end

  after { FileUtils.rm_rf(tmpdir) }

  def import_fixture(program: "lca", year: 2024, quarter: 3)
    db = DolLookup::Database.new(program: program, year: year, quarter: quarter)
    db.import(fixture_path)
    db
  end

  describe "GET /" do
    it "returns 200 and renders the dashboard" do
      get "/"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("DOL Cases Dashboard")
      expect(last_response.body).to include("program-select")
    end

    it "lists imported datasets" do
      import_fixture
      get "/"
      expect(last_response.body).to include("Imported Datasets")
      expect(last_response.body).to include("LCA")
    end

    it "shows empty state when no datasets imported" do
      get "/"
      expect(last_response.body).to include("No Data Imported Yet")
      expect(last_response.body).to include("Import Data")
    end

    it "sets security headers" do
      get "/"
      expect(last_response.headers["X-Content-Type-Options"]).to eq("nosniff")
      expect(last_response.headers["X-Frame-Options"]).to eq("DENY")
      expect(last_response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    end
  end

  describe "GET /import" do
    it "renders the import page" do
      get "/import"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Import Data")
      expect(last_response.body).to include("Start Import")
    end
  end

  describe "GET /search" do
    before { import_fixture }

    it "returns search results for valid program" do
      get "/search", program: "lca", year: 2024, quarter: 3, employer: "GOOGLE"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("GOOGLE")
    end

    it "returns results with stats" do
      get "/search", program: "lca", year: 2024, quarter: 3
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Total Cases")
      expect(last_response.body).to include("Avg Wage")
      expect(last_response.body).to include("Median Wage")
    end

    it "returns results with top employers chart" do
      get "/search", program: "lca", year: 2024, quarter: 3
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("Top Employers")
      expect(last_response.body).to include("employers-chart")
    end

    it "returns error for non-imported dataset" do
      get "/search", program: "perm", year: 2024, quarter: 3
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("No data imported")
    end

    it "rejects invalid program" do
      get "/search", program: "invalid"
      expect(last_response.status).to eq(400)
      expect(last_response.body).to include("Invalid program")
    end

    it "filters by state" do
      get "/search", program: "lca", year: 2024, quarter: 3, state: "CA"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("GOOGLE")
    end

    it "returns htmx partial for HX-Request" do
      header "HX-Request", "true"
      get "/search", program: "lca", year: 2024, quarter: 3, employer: "GOOGLE"
      expect(last_response.status).to eq(200)
      # Partial should not include full layout
      expect(last_response.body).not_to include("<!DOCTYPE html>")
      expect(last_response.body).to include("GOOGLE")
    end

    it "shows no results message for non-matching search" do
      get "/search", program: "lca", year: 2024, quarter: 3, employer: "ZZZZNONEXISTENT"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("No results found")
    end
  end

  describe "GET /nonexistent" do
    it "returns 404" do
      get "/nonexistent"
      expect(last_response.status).to eq(404)
    end
  end

  describe "CDN resources" do
    it "includes SRI integrity attributes" do
      get "/"
      expect(last_response.body).to include('integrity="sha384-')
      expect(last_response.body).to include('crossorigin="anonymous"')
    end
  end

  describe "CSRF protection" do
    it "includes CSRF meta tag in layout" do
      get "/"
      expect(last_response.body).to include('csrf-token')
    end
  end

  describe "auto-escaping" do
    it "has escape_html enabled" do
      expect(described_class.erb[:escape_html]).to be true
    end
  end
end
