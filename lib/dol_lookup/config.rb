require "fileutils"

module DolLookup
  module Config
    PROGRAMS = {
      "lca"  => { prefix: "LCA", description: "H-1B / H-1B1 / E-3 (Labor Condition Application)" },
      "perm" => { prefix: "PERM", description: "PERM (Permanent Labor Certification)" },
      "h2a"  => { prefix: "H-2A", description: "H-2A (Temporary Agricultural Workers)" },
      "h2b"  => { prefix: "H-2B", description: "H-2B (Temporary Non-Agricultural Workers)" }
    }.freeze

    BASE_URL = "https://www.dol.gov/sites/dolgov/files/ETA/oflc/pdfs"

    DEFAULT_PROGRAM  = "lca"
    DEFAULT_YEAR     = Time.now.year
    DEFAULT_QUARTER  = ((Time.now.month - 1) / 3).clamp(1, 4)

    CACHE_DIR = ENV.fetch("DOL_LOOKUP_CACHE_DIR", File.join(Dir.home, ".dol_lookup", "cache"))

    def self.disclosure_url(program:, year:, quarter:)
      info = PROGRAMS.fetch(program) { raise ArgumentError, "Unknown program: #{program}. Valid: #{PROGRAMS.keys.join(', ')}" }
      prefix = info[:prefix]
      fy = "FY#{year}"
      q = "Q#{quarter}"
      "#{BASE_URL}/#{prefix}_Disclosure_Data_#{fy}_#{q}.xlsx"
    end

    def self.cache_dir
      ENV.fetch("DOL_LOOKUP_CACHE_DIR", CACHE_DIR)
    end

    def self.cache_path(program:, year:, quarter:)
      dir = cache_dir
      FileUtils.mkdir_p(dir)
      File.join(dir, "#{program}_FY#{year}_Q#{quarter}.xlsx")
    end

    def self.db_path(program:, year:, quarter:)
      dir = cache_dir
      FileUtils.mkdir_p(dir)
      File.join(dir, "#{program}_FY#{year}_Q#{quarter}.db")
    end
  end
end
