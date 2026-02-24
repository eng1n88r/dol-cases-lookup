require "net/http"
require "fileutils"

module DolLookup
  class Downloader
    class DownloadError < StandardError; end

    def initialize(cache_dir: Config.cache_dir)
      @cache_dir = cache_dir
    end

    def download(program:, year:, quarter:, refresh: false)
      url = Config.disclosure_url(program: program, year: year, quarter: quarter)
      path = cache_path(program, year, quarter)

      if !refresh && File.exist?(path)
        return path
      end

      fetch_and_save(url, path)
      path
    end

    private

    def cache_path(program, year, quarter)
      FileUtils.mkdir_p(@cache_dir)
      File.join(@cache_dir, "#{program}_FY#{year}_Q#{quarter}.xlsx")
    end

    def fetch_and_save(url, path)
      uri = URI.parse(url)
      response = perform_request(uri)

      case response
      when Net::HTTPSuccess
        tmp_path = "#{path}.tmp"
        File.open(tmp_path, "wb") { |f| f.write(response.body) }
        File.rename(tmp_path, path)
      when Net::HTTPRedirection
        redirect_uri = URI.parse(response["location"])
        redirect_uri = uri + redirect_uri unless redirect_uri.host
        response = perform_request(redirect_uri)
        if response.is_a?(Net::HTTPSuccess)
          tmp_path = "#{path}.tmp"
          File.open(tmp_path, "wb") { |f| f.write(response.body) }
          File.rename(tmp_path, path)
        else
          raise DownloadError, "Download failed after redirect: HTTP #{response.code} from #{redirect_uri}"
        end
      else
        raise DownloadError, "Download failed: HTTP #{response.code} from #{url}"
      end
    end

    def perform_request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 30
      http.read_timeout = 120
      http.get(uri.request_uri)
    end
  end
end
