require "zip"
require "nokogiri"

module DolLookup
  # Lightweight streaming XLSX reader using Nokogiri SAX + rubyzip.
  # Streams rows directly from the zip with minimal memory — replaces Creek.
  class XlsxReader
    def initialize(file_path)
      @file_path = file_path
    end

    # Yields one Hash per row. Keys are cell references ("A1", "B2").
    # Values are strings.
    def each_row(&block)
      return enum_for(:each_row) unless block_given?

      Zip::File.open(@file_path) do |zip|
        shared_strings = load_shared_strings(zip)
        parse_sheet(zip, shared_strings, &block)
      end
    end

    private

    def load_shared_strings(zip)
      entry = zip.find_entry("xl/sharedStrings.xml")
      return [] unless entry

      handler = SharedStringsHandler.new
      entry.get_input_stream do |io|
        Nokogiri::XML::SAX::Parser.new(handler).parse(io)
      end
      handler.strings
    end

    def parse_sheet(zip, shared_strings, &block)
      entry = zip.find_entry("xl/worksheets/sheet1.xml")
      raise "No worksheet found in XLSX" unless entry

      handler = SheetHandler.new(shared_strings, &block)
      entry.get_input_stream do |io|
        Nokogiri::XML::SAX::Parser.new(handler).parse(io)
      end
    end

    # Collects shared strings into a flat Array.
    class SharedStringsHandler < Nokogiri::XML::SAX::Document
      attr_reader :strings

      def initialize
        @strings = []
        @in_si = false
        @in_t = false
        @buf = nil
      end

      def start_element(name, attrs = [])
        case name
        when "si"
          @in_si = true
          @buf = +""
        when "t"
          @in_t = true if @in_si
        end
      end

      def characters(str)
        @buf << str if @in_t && @buf
      end

      def end_element(name)
        case name
        when "t"
          @in_t = false
        when "si"
          @strings << (@buf ? @buf.freeze : "".freeze)
          @buf = nil
          @in_si = false
        end
      end
    end

    # SAX handler that yields one Hash per worksheet row.
    class SheetHandler < Nokogiri::XML::SAX::Document
      def initialize(shared_strings, &block)
        @ss = shared_strings
        @block = block
        @row = nil
        @ref = nil
        @type = nil
        @val = +""
        @inline = +""
        @in_v = false
        @in_is = false
        @in_t = false
      end

      def start_element(name, attrs = [])
        case name
        when "row"
          @row = {}
        when "c"
          h = attrs.to_h
          @ref = h["r"]
          @type = h["t"]
          @val = +""
          @inline = +""
        when "v"
          @in_v = true
        when "is"
          @in_is = true
        when "t"
          @in_t = true if @in_is
        end
      end

      def characters(str)
        if @in_v
          @val << str
        elsif @in_t
          @inline << str
        end
      end

      def end_element(name)
        case name
        when "v"
          @in_v = false
        when "t"
          @in_t = false
        when "is"
          @in_is = false
        when "c"
          if @ref && @row
            resolved = resolve
            @row[@ref] = resolved unless resolved.nil?
          end
          @ref = nil
          @type = nil
        when "row"
          @block.call(@row) if @row && !@row.empty?
          @row = nil
        end
      end

      private

      def resolve
        case @type
        when "s"
          @ss[@val.to_i]
        when "inlineStr"
          @inline.empty? ? nil : @inline
        else
          @val.empty? ? nil : @val
        end
      end
    end
  end
end
