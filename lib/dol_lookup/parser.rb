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
      wanted_letters = nil # col letter => xlsx header

      reader.each_row do |row|
        if headers.nil?
          headers = row.transform_values { |v| v.to_s.strip }
          wanted_letters = build_index(headers)
          next
        end

        record = {}
        row.each do |cell_ref, value|
          col_letter = cell_ref.delete("0-9")
          xlsx_header = wanted_letters[col_letter]
          next unless xlsx_header
          record[xlsx_header] = value.is_a?(String) ? value.strip : value&.to_s
        end
        yield record unless record.empty?
      end
    end

    private

    # Returns { "A" => "CASE_NUMBER", "B" => "CASE_STATUS", ... }
    # only for columns present in ColumnMap for this program.
    def build_index(header_row)
      wanted_headers = @columns.values.to_set
      index = {}
      header_row.each do |cell_ref, header_value|
        col_letter = cell_ref.delete("0-9")
        index[col_letter] = header_value if wanted_headers.include?(header_value)
      end
      index
    end
  end
end
