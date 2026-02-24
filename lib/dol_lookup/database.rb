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

    WAGE_FILTER = "wage_from IS NOT NULL AND wage_from != '' AND CAST(wage_from AS REAL) > 0"

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

    def import_with_progress(xlsx_path, &on_progress)
      tmp_path = "#{@db_path}.tmp"
      File.delete(tmp_path) if File.exist?(tmp_path)

      original_db_path = @db_path
      @db_path = tmp_path
      begin
        open_db
        create_table

        parser = Parser.new(xlsx_path, program: @program)
        placeholders = COLUMNS.map { "?" }.join(", ")
        col_list = COLUMNS.join(", ")
        insert_sql = "INSERT INTO cases (#{col_list}) VALUES (#{placeholders})"

        batch = []
        total_rows = 0
        parser.each_row do |row|
          values = COLUMNS.map { |col| row[@column_map[col]]&.to_s }
          batch << values
          total_rows += 1

          if batch.size >= BATCH_SIZE
            flush_batch(insert_sql, batch)
            batch.clear
            on_progress&.call(total_rows)
          end
        end
        flush_batch(insert_sql, batch) unless batch.empty?
        on_progress&.call(total_rows)

        create_indexes
        close

        # Atomic rename on success
        File.delete(original_db_path) if File.exist?(original_db_path)
        File.rename(tmp_path, original_db_path)
        @db_path = original_db_path
      rescue => e
        close
        File.delete(tmp_path) if File.exist?(tmp_path)
        @db_path = original_db_path
        raise
      end
    end

    def query(filters = nil, limit: nil, offset: nil, **filter_kwargs)
      filters = filters || filter_kwargs
      open_db
      where_clauses, params = build_where(filters)

      sql = "SELECT * FROM cases"
      sql += " WHERE #{where_clauses.join(' AND ')}" unless where_clauses.empty?
      sql += " LIMIT #{limit.to_i}" if limit
      sql += " OFFSET #{offset.to_i}" if offset

      rows = @db.execute(sql, params)
      translate_rows(rows)
    ensure
      close
    end

    def count(filters = nil, **filter_kwargs)
      filters = filters || filter_kwargs
      open_db
      where_clauses, params = build_where(filters)
      sql = "SELECT COUNT(*) FROM cases"
      sql += " WHERE #{where_clauses.join(' AND ')}" unless where_clauses.empty?
      @db.get_first_value(sql, params).to_i
    ensure
      close
    end

    def stats(filters = nil, **filter_kwargs)
      filters = filters || filter_kwargs
      open_db
      where_clauses, params = build_where(filters)
      where_sql = where_clauses.empty? ? "" : " AND #{where_clauses.join(' AND ')}"

      summary = @db.get_first_row(<<~SQL, params)
        SELECT
          COUNT(*) AS total_cases,
          ROUND(MIN(CAST(wage_from AS REAL)), 0) AS min_wage,
          ROUND(MAX(CAST(wage_from AS REAL)), 0) AS max_wage,
          ROUND(AVG(CAST(wage_from AS REAL)), 0) AS avg_wage,
          ROUND(median(CAST(wage_from AS REAL)), 0) AS median_wage
        FROM cases
        WHERE #{WAGE_FILTER}#{where_sql}
      SQL

      histogram = @db.execute(<<~SQL, params)
        SELECT
          CASE
            WHEN CAST(wage_from AS REAL) < 50000 THEN 'Under $50k'
            WHEN CAST(wage_from AS REAL) < 75000 THEN '$50k-$75k'
            WHEN CAST(wage_from AS REAL) < 100000 THEN '$75k-$100k'
            WHEN CAST(wage_from AS REAL) < 125000 THEN '$100k-$125k'
            WHEN CAST(wage_from AS REAL) < 150000 THEN '$125k-$150k'
            WHEN CAST(wage_from AS REAL) < 200000 THEN '$150k-$200k'
            ELSE '$200k+'
          END AS wage_range,
          COUNT(*) AS case_count
        FROM cases
        WHERE #{WAGE_FILTER}#{where_sql}
        GROUP BY wage_range
        ORDER BY MIN(CAST(wage_from AS REAL))
      SQL

      by_status = @db.execute(<<~SQL, params)
        SELECT case_status, COUNT(*) AS count
        FROM cases
        WHERE 1=1#{where_sql}
        GROUP BY case_status
        ORDER BY count DESC
      SQL

      {
        summary: summary,
        histogram: histogram.map { |r| { "wage_range" => r[0], "case_count" => r[1] } },
        by_status: by_status.map { |r| { "case_status" => r[0], "count" => r[1] } }
      }
    ensure
      close
    end

    def top_employers(filters = nil, limit: 25, **filter_kwargs)
      filters = filters || filter_kwargs
      open_db
      where_clauses, params = build_where(filters)
      where_sql = where_clauses.empty? ? "" : " AND #{where_clauses.join(' AND ')}"

      rows = @db.execute(<<~SQL, params + [limit])
        SELECT
          employer_name,
          COUNT(*) AS case_count,
          SUM(CASE WHEN case_status = 'Certified' THEN 1 ELSE 0 END) AS certified,
          ROUND(AVG(CAST(wage_from AS REAL)), 0) AS avg_wage,
          ROUND(median(CAST(wage_from AS REAL)), 0) AS median_wage
        FROM cases
        WHERE #{WAGE_FILTER}#{where_sql}
        GROUP BY employer_name
        ORDER BY case_count DESC
        LIMIT ?
      SQL

      rows.map do |r|
        {
          "employer_name" => r[0], "case_count" => r[1], "certified" => r[2],
          "avg_wage" => r[3], "median_wage" => r[4]
        }
      end
    ensure
      close
    end

    private

    def build_where(filters)
      where_clauses = []
      params = []

      if filters[:case_number]
        where_clauses << "case_number = ? COLLATE NOCASE"
        params << filters[:case_number]
      end

      if filters[:employer]
        where_clauses << "employer_name LIKE ? ESCAPE '\\' COLLATE NOCASE"
        params << "%#{sanitize_like(filters[:employer])}%"
      end

      if filters[:job_title]
        where_clauses << "job_title LIKE ? ESCAPE '\\' COLLATE NOCASE"
        params << "%#{sanitize_like(filters[:job_title])}%"
      end

      if filters[:status]
        where_clauses << "case_status = ? COLLATE NOCASE"
        params << filters[:status]
      end

      if filters[:visa_class]
        where_clauses << "visa_class = ? COLLATE NOCASE"
        params << filters[:visa_class]
      end

      if filters[:state]
        where_clauses << "(worksite_state = ? COLLATE NOCASE OR employer_state = ? COLLATE NOCASE)"
        params << filters[:state]
        params << filters[:state]
      end

      [where_clauses, params]
    end

    def sanitize_like(value)
      value.gsub(/[%_\\]/) { |c| "\\#{c}" }
    end

    def translate_rows(rows)
      col_names = COLUMNS.map(&:to_s)
      rows.map do |row|
        hash = {}
        col_names.each_with_index do |col, idx|
          xlsx_header = @column_map[col.to_sym]
          hash[xlsx_header] = row[idx] if xlsx_header
        end
        hash
      end
    end

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
      @db.execute("CREATE INDEX IF NOT EXISTS idx_wage_from_real ON cases(CAST(wage_from AS REAL)) WHERE wage_from IS NOT NULL AND wage_from != ''")
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
