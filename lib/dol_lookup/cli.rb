require "optparse"

module DolLookup
  class CLI
    def initialize(argv = ARGV)
      @argv = argv
      @options = {
        program: Config::DEFAULT_PROGRAM,
        year:    Config::DEFAULT_YEAR,
        quarter: Config::DEFAULT_QUARTER,
        format:  :table,
        refresh: false,
        filters: {}
      }
    end

    def run
      parse_options
      validate_options

      db = Database.new(
        program: @options[:program],
        year:    @options[:year],
        quarter: @options[:quarter]
      )

      if @options[:refresh] || !db.ready?
        xlsx_path = Downloader.new.download(
          program: @options[:program],
          year:    @options[:year],
          quarter: @options[:quarter],
          refresh: @options[:refresh]
        )
        $stderr.puts "Importing #{xlsx_path} into SQLite..."
        db.import(xlsx_path)
        $stderr.puts "Import complete."
      end

      results = Searcher.new(db, program: @options[:program]).search(@options[:filters])
      output = Formatter.new(results, program: @options[:program]).format(@options[:format])
      puts output
    rescue Downloader::DownloadError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    rescue ArgumentError => e
      $stderr.puts "Error: #{e.message}"
      exit 1
    end

    private

    def parse_options
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: dol-lookup [options]"
        opts.separator ""
        opts.separator "Data source options:"

        opts.on("-p", "--program PROGRAM", Config::PROGRAMS.keys, "Program: #{Config::PROGRAMS.keys.join(', ')} (default: lca)") do |v|
          @options[:program] = v
        end
        opts.on("-y", "--year YEAR", Integer, "Fiscal year (default: #{Config::DEFAULT_YEAR})") do |v|
          @options[:year] = v
        end
        opts.on("-q", "--quarter QUARTER", Integer, "Quarter 1-4 (default: #{Config::DEFAULT_QUARTER})") do |v|
          @options[:quarter] = v
        end
        opts.on("--refresh", "Force re-download and re-import of data") do
          @options[:refresh] = true
        end

        opts.separator ""
        opts.separator "Search filters:"

        opts.on("-e", "--employer NAME", "Employer name (substring match)") do |v|
          @options[:filters][:employer] = v
        end
        opts.on("-c", "--case-number NUMBER", "Case number (exact match)") do |v|
          @options[:filters][:case_number] = v
        end
        opts.on("-s", "--state STATE", "Worksite state abbreviation, e.g. CA") do |v|
          @options[:filters][:state] = v
        end
        opts.on("-j", "--job-title TITLE", "Job title (substring match)") do |v|
          @options[:filters][:job_title] = v
        end
        opts.on("--status STATUS", "Case status (exact match, e.g. Certified)") do |v|
          @options[:filters][:status] = v
        end
        opts.on("--visa-class CLASS", "Visa class (exact match, e.g. H-1B)") do |v|
          @options[:filters][:visa_class] = v
        end

        opts.separator ""
        opts.separator "Output options:"

        opts.on("-f", "--format FORMAT", [:table, :csv, :json], "Output format: table, csv, json (default: table)") do |v|
          @options[:format] = v
        end

        opts.separator ""
        opts.on("-v", "--version", "Show version") do
          puts "dol-lookup #{VERSION}"
          exit 0
        end
        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit 0
        end
      end

      parser.parse!(@argv)
    end

    def validate_options
      unless (1..4).include?(@options[:quarter])
        raise ArgumentError, "Quarter must be between 1 and 4"
      end

      unless @options[:year].between?(2020, Time.now.year + 1)
        raise ArgumentError, "Year must be between 2020 and #{Time.now.year + 1}"
      end
    end
  end
end
