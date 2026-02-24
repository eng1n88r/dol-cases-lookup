require "json"
require "terminal-table"

module DolLookup
  class Formatter
    def initialize(rows, program:)
      @rows = rows
      @program = program
      @columns = ColumnMap.columns_for(program)
    end

    def format(style = :table)
      case style.to_sym
      when :table then format_table
      when :csv   then format_csv
      when :json  then format_json
      else raise ArgumentError, "Unknown format: #{style}. Valid: table, csv, json"
      end
    end

    private

    def display_rows
      @rows.map do |row|
        ColumnMap::DISPLAY_COLUMNS.each_with_object({}) do |(field, label), out|
          col = @columns[field]
          out[label] = format_value(row[col]) if col
        end
      end
    end

    def format_value(value)
      case value
      when Date, Time
        value.strftime("%Y-%m-%d")
      when Float
        value == value.to_i ? value.to_i.to_s : sprintf("%.2f", value)
      when nil
        ""
      else
        value.to_s
      end
    end

    def format_table
      display = display_rows
      return "No results found." if display.empty?

      headers = display.first.keys
      table = Terminal::Table.new(
        headings: headers,
        rows: display.map(&:values)
      )
      "#{table}\n#{display.length} result(s) found."
    end

    def format_csv
      display = display_rows
      return "" if display.empty?

      headers = display.first.keys
      lines = [headers.join(",")]
      display.each do |row|
        lines << headers.map { |h| csv_escape(row[h].to_s) }.join(",")
      end
      lines.join("\n")
    end

    def format_json
      display = display_rows
      JSON.pretty_generate(display)
    end

    def csv_escape(value)
      if value.include?(",") || value.include?('"') || value.include?("\n")
        '"' + value.gsub('"', '""') + '"'
      else
        value
      end
    end
  end
end
