require_relative "xlsx_reader"

module DolLookup
  class Parser
    def initialize(file_path, program:)
      @file_path = file_path
      @program = program
      @columns = ColumnMap.columns_for(program)
    end

    # Yields one hash per row (only the columns we care about).
    # Keys are the XLSX column headers (e.g. "CASE_NUMBER").
    def each_row(&block)
      return enum_for(:each_row) unless block_given?

      reader = XlsxReader.new(@file_path)

      headers = nil
      wanted_indices = nil # col letter => semantic field

      reader.each_row do |row|
        if headers.nil?
          headers = row.transform_values { |v| v.to_s.strip }
          wanted_indices = build_index(headers)
          next
        end

        record = {}
        wanted_indices.each do |cell_letter, xlsx_header|
          cell_key = row.keys.find { |k| k.start_with?(cell_letter) && k[cell_letter.length..].match?(/\A\d+\z/) }
          value = cell_key ? row[cell_key] : nil
          record[xlsx_header] = value.is_a?(String) ? value.strip : value&.to_s
        end
        yield record
      end
    end

    private

    # Returns { "A" => "CASE_NUMBER", "B" => "CASE_STATUS", ... }
    # only for columns present in ColumnMap for this program.
    def build_index(header_row)
      wanted_headers = @columns.values.to_set
      index = {}
      header_row.each do |cell_ref, header_value|
        col_letter = cell_ref.gsub(/\d+/, "")
        index[col_letter] = header_value if wanted_headers.include?(header_value)
      end
      index
    end
  end
end
