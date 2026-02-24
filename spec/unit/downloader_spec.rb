require "spec_helper"
require "tmpdir"

RSpec.describe DolLookup::Downloader do
  let(:tmpdir) { Dir.mktmpdir("dol_test") }
  let(:downloader) { described_class.new(cache_dir: tmpdir) }
  let(:url) { DolLookup::Config.disclosure_url(program: "lca", year: 2024, quarter: 3) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#download" do
    it "downloads and caches the file" do
      stub_request(:get, url).to_return(status: 200, body: "fake xlsx content")

      path = downloader.download(program: "lca", year: 2024, quarter: 3)

      expect(File.exist?(path)).to be true
      expect(File.read(path)).to eq("fake xlsx content")
    end

    it "uses cached copy when available" do
      cached_path = File.join(tmpdir, "lca_FY2024_Q3.xlsx")
      File.write(cached_path, "cached content")

      path = downloader.download(program: "lca", year: 2024, quarter: 3)

      expect(path).to eq(cached_path)
      expect(File.read(path)).to eq("cached content")
      expect(WebMock).not_to have_requested(:get, url)
    end

    it "re-downloads when refresh is true" do
      cached_path = File.join(tmpdir, "lca_FY2024_Q3.xlsx")
      File.write(cached_path, "old content")

      stub_request(:get, url).to_return(status: 200, body: "new content")

      path = downloader.download(program: "lca", year: 2024, quarter: 3, refresh: true)

      expect(File.read(path)).to eq("new content")
    end

    it "follows redirects" do
      redirect_url = "https://example.com/redirected.xlsx"
      stub_request(:get, url).to_return(status: 302, headers: { "Location" => redirect_url })
      stub_request(:get, redirect_url).to_return(status: 200, body: "redirected content")

      path = downloader.download(program: "lca", year: 2024, quarter: 3)

      expect(File.read(path)).to eq("redirected content")
    end

    it "raises DownloadError on HTTP error" do
      stub_request(:get, url).to_return(status: 404)

      expect { downloader.download(program: "lca", year: 2024, quarter: 3) }
        .to raise_error(DolLookup::Downloader::DownloadError, /404/)
    end

    it "does not leave .tmp files on success" do
      stub_request(:get, url).to_return(status: 200, body: "content")

      downloader.download(program: "lca", year: 2024, quarter: 3)

      tmp_files = Dir.glob(File.join(tmpdir, "*.tmp"))
      expect(tmp_files).to be_empty
    end
  end
end
