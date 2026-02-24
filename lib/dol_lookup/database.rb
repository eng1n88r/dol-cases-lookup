require "sqlite3"

module DolLookup
  class Database
    BATCH_SIZE = 1000

    COLUMNS = %i[
      case_number case_status employer_name trade_name
      employer_city employer_state job_title soc_title
      wage_from wage_to wage_unit worksite_city worksite_state
      received_date decision_date visa_class prevailing_wage
    ].freeze

    attr_reader :db_path

    def initialize(program:, year:, quarter:)
      @program = program
      @year = year
      @quarter = quarter
      @db_path = Config.db_path(program: program, year: year, quarter: quarter)
      @column_map = ColumnMap.columns_for(program)
    end

    def ready?
      File.exist?(@db_path) && table_exists?
    end

    def import(xlsx_path)
      File.delete(@db_path) if File.exist?(@db_path)
      open_db
      create_table
      insert_rows(xlsx_path)
      create_indexes
    ensure
      close
    end

    def query(filters = {})
      open_db
      where_clauses = []
      params = []

      if filters[:case_number]
        where_clauses << "case_number = ? COLLATE NOCASE"
        params << filters[:case_number]
      end

      if filters[:employer]
        where_clauses << "employer_name LIKE ? COLLATE NOCASE"
        params << "%#{filters[:employer]}%"
      end

      if filters[:job_title]
        where_clauses << "job_title LIKE ? COLLATE NOCASE"
        params << "%#{filters[:job_title]}%"
      end

      if filters[:state]
        where_clauses << "(worksite_state = ?1 COLLATE NOCASE OR employer_state = ?1 COLLATE NOCASE)"
        # numbered param — need special handling
      end

      if filters[:status]
        where_clauses << "case_status = ? COLLATE NOCASE"
        params << filters[:status]
      end

      if filters[:visa_class]
        where_clauses << "visa_class = ? COLLATE NOCASE"
        params << filters[:visa_class]
      end

      # Re-build for state since it uses a single param in two places
      if filters[:state]
        # Rebuild without numbered params — use OR with same value twice
        where_clauses.delete_if { |c| c.include?("worksite_state") }
        where_clauses << "(worksite_state = ? COLLATE NOCASE OR employer_state = ? COLLATE NOCASE)"
        params << filters[:state]
        params << filters[:state]
      end

      sql = "SELECT * FROM cases"
      sql += " WHERE #{where_clauses.join(' AND ')}" unless where_clauses.empty?

      rows = @db.execute(sql, params)
      col_names = COLUMNS.map(&:to_s)

      rows.map do |row|
        hash = {}
        col_names.each_with_index do |col, idx|
          xlsx_header = @column_map[col.to_sym]
          hash[xlsx_header] = row[idx] if xlsx_header
        end
        hash
      end
    ensure
      close
    end

    private

    def open_db
      @db = SQLite3::Database.new(@db_path)
      @db.execute("PRAGMA journal_mode=WAL")
      @db.execute("PRAGMA synchronous=NORMAL")
    end

    def close
      @db&.close
      @db = nil
    end

    def table_exists?
      open_db
      result = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='cases'")
      result.any?
    ensure
      close
    end

    def create_table
      cols = COLUMNS.map { |c| "#{c} TEXT" }.join(", ")
      @db.execute("CREATE TABLE IF NOT EXISTS cases (#{cols})")
    end

    def create_indexes
      @db.execute("CREATE INDEX IF NOT EXISTS idx_case_number ON cases(case_number)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_employer_name ON cases(employer_name COLLATE NOCASE)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_case_status ON cases(case_status)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_worksite_state ON cases(worksite_state)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_employer_state ON cases(employer_state)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_visa_class ON cases(visa_class)")
      @db.execute("CREATE INDEX IF NOT EXISTS idx_job_title ON cases(job_title COLLATE NOCASE)")
    end

    def insert_rows(xlsx_path)
      parser = Parser.new(xlsx_path, program: @program)
      placeholders = COLUMNS.map { "?" }.join(", ")
      col_list = COLUMNS.join(", ")
      insert_sql = "INSERT INTO cases (#{col_list}) VALUES (#{placeholders})"

      batch = []
      parser.each_row do |row|
        values = COLUMNS.map { |col| row[@column_map[col]]&.to_s }
        batch << values

        if batch.size >= BATCH_SIZE
          flush_batch(insert_sql, batch)
          batch.clear
        end
      end
      flush_batch(insert_sql, batch) unless batch.empty?
    end

    def flush_batch(sql, batch)
      @db.transaction do
        batch.each { |values| @db.execute(sql, values) }
      end
    end
  end
end
