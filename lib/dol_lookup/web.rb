require "sinatra/base"
require "erubi"
require "json"
require "securerandom"

module DolLookup
  class Web < Sinatra::Base
    ALLOWED_PROGRAMS = Config::PROGRAMS.keys.freeze

    set :views, File.join(__dir__, "web", "views")
    set :public_folder, File.join(__dir__, "web", "public")
    set :erb, escape_html: true

    enable :sessions
    set :session_secret, ENV.fetch("SESSION_SECRET") { SecureRandom.hex(32) }.then { |s| s.to_s.length >= 64 ? s : SecureRandom.hex(32) }

    # CSRF protection
    use Rack::Protection::AuthenticityToken

    # Optional HTTP Basic Auth (enabled via env var)
    if ENV["DOL_AUTH_USER"].to_s != ""
      use Rack::Auth::Basic, "DOL Dashboard" do |user, pass|
        Rack::Utils.secure_compare(user, ENV["DOL_AUTH_USER"]) &
          Rack::Utils.secure_compare(pass, ENV.fetch("DOL_AUTH_PASS", ""))
      end
    end

    # Import state
    set :import_running, false
    set :import_lock, Mutex.new
    set :import_queues, {}

    # Security headers
    before do
      headers(
        "X-Content-Type-Options" => "nosniff",
        "X-Frame-Options" => "DENY",
        "Referrer-Policy" => "strict-origin-when-cross-origin",
        "Permissions-Policy" => "camera=(), microphone=(), geolocation=()"
      )
    end

    helpers do
      def current_quarter
        ((Time.now.month - 1) / 3).clamp(1, 4)
      end

      def validate_program!(program)
        unless ALLOWED_PROGRAMS.include?(program)
          halt 400, erb(:error, locals: { message: "Invalid program. Allowed: #{ALLOWED_PROGRAMS.join(', ')}" })
        end
      end

      def available_datasets
        dir = Config.cache_dir
        return [] unless Dir.exist?(dir)
        Dir.glob(File.join(dir, "*.db")).map do |path|
          fname = File.basename(path, ".db")
          if fname =~ /\A(\w+)_FY(\d+)_Q(\d)\z/
            prog = $1
            next unless ALLOWED_PROGRAMS.include?(prog)
            { program: prog, year: $2.to_i, quarter: $3.to_i, path: path,
              size: File.size(path), imported_at: File.mtime(path) }
          end
        end.compact
      end

      def format_wage(val)
        return "" if val.nil? || val.to_s.empty?
        num = val.to_f
        return val.to_s if num == 0
        "$#{num.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      end

      def format_number(val)
        return "0" if val.nil?
        val.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end

      def csrf_tag
        token = session[:csrf] ||= SecureRandom.hex(32)
        "<input type=\"hidden\" name=\"authenticity_token\" value=\"#{Rack::Utils.escape_html(token)}\">"
      end

      def csrf_meta_tag
        token = session[:csrf] ||= SecureRandom.hex(32)
        "<meta name=\"csrf-token\" content=\"#{Rack::Utils.escape_html(token)}\">"
      end

      def extract_filters(params)
        filters = {}
        filters[:employer]    = params[:employer].strip    if params[:employer]&.strip.to_s != ""
        filters[:job_title]   = params[:job_title].strip   if params[:job_title]&.strip.to_s != ""
        filters[:state]       = params[:state].strip       if params[:state]&.strip.to_s != ""
        filters[:status]      = params[:status].strip      if params[:status]&.strip.to_s != ""
        filters[:visa_class]  = params[:visa_class].strip  if params[:visa_class]&.strip.to_s != ""
        filters[:case_number] = params[:case_number].strip if params[:case_number]&.strip.to_s != ""
        filters
      end

      def program_label(program)
        Config::PROGRAMS.dig(program, :description) || program.upcase
      end
    end

    # --- Error Handling ---

    not_found do
      @error = "Page not found."
      erb :dashboard
    end

    error do
      $stderr.puts env["sinatra.error"]&.full_message
      @error = "Something went wrong. Please try again."
      erb :dashboard
    end

    # --- Pages ---

    get "/" do
      @datasets = available_datasets
      @programs = Config::PROGRAMS
      erb :dashboard
    end

    get "/import" do
      @programs = Config::PROGRAMS
      erb :import
    end

    # --- Search ---

    get "/search" do
      program = params[:program] || "lca"
      validate_program!(program)
      year    = (params[:year] || Config::DEFAULT_YEAR).to_i
      quarter = (params[:quarter] || current_quarter).to_i

      db = Database.new(program: program, year: year, quarter: quarter)
      unless db.ready?
        @error = "No data imported for #{program.upcase} FY#{year} Q#{quarter}. Import it first."
        @datasets = available_datasets
        @programs = Config::PROGRAMS
        return request.env["HTTP_HX_REQUEST"] ? erb(:_results, layout: false) : erb(:dashboard)
      end

      filters  = extract_filters(params)
      page     = [1, (params[:page] || 1).to_i].max
      per_page = 50
      offset   = (page - 1) * per_page

      @results  = db.query(filters, limit: per_page, offset: offset)
      @total    = db.count(filters)
      @stats    = db.stats(filters)
      @top_employers = @results.any? ? db.top_employers(filters, limit: 10) : []
      @page     = page
      @per_page = per_page
      @program  = program
      @year     = year
      @quarter  = quarter
      @filters  = filters
      @datasets = available_datasets
      @programs = Config::PROGRAMS

      if request.env["HTTP_HX_REQUEST"]
        erb :_results, layout: false
      else
        erb :dashboard
      end
    end

    # --- Import ---

    post "/import/start" do
      program = params[:program] || "lca"
      validate_program!(program)
      year    = (params[:year] || Config::DEFAULT_YEAR).to_i
      quarter = (params[:quarter] || current_quarter).to_i
      key = "#{program}_#{year}_#{quarter}"

      settings.import_lock.synchronize do
        if settings.import_running
          return "<div role='alert'>Import already in progress. Please wait.</div>"
        end
        settings.import_running = true
      end

      progress_queue = Queue.new
      settings.import_queues[key] = progress_queue

      Thread.new do
        begin
          progress_queue << { status: "running", phase: "downloading", percent: 0 }.to_json

          xlsx_path = Downloader.new.download(
            program: program, year: year, quarter: quarter,
            refresh: params[:refresh] == "true"
          )
          progress_queue << { status: "running", phase: "downloading", percent: 100 }.to_json

          progress_queue << { status: "running", phase: "importing", percent: 0, rows: 0 }.to_json
          db = Database.new(program: program, year: year, quarter: quarter)
          db.import_with_progress(xlsx_path) do |rows_done|
            progress_queue << { status: "running", phase: "importing", rows: rows_done }.to_json
          end

          progress_queue << { status: "complete", phase: "done", percent: 100 }.to_json
        rescue => e
          $stderr.puts "Import error: #{e.full_message}"
          progress_queue << { status: "error", error: "Import failed. Check server logs." }.to_json
        ensure
          settings.import_lock.synchronize { settings.import_running = false }
        end
      end

      erb :_progress, layout: false, locals: { key: key, program: program, year: year, quarter: quarter }
    end

    get "/import/progress/:key", provides: "text/event-stream" do
      content_type "text/event-stream"
      headers "Cache-Control" => "no-cache", "X-Accel-Buffering" => "no"
      key = params[:key]

      queue = settings.import_queues[key]
      unless queue
        return "event: error\ndata: {\"error\":\"No import found\"}\n\n"
      end

      stream :keep_open do |out|
        loop do
          data = queue.pop
          out << "event: progress\ndata: #{data}\n\n"
          parsed = JSON.parse(data)
          break if %w[complete error].include?(parsed["status"])
        end
        out << "event: done\ndata: done\n\n"
        settings.import_queues.delete(key)
      end
    end
  end
end
