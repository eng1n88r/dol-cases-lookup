module DolLookup
  class Searcher
    def initialize(database, program:)
      @database = database
      @program = program
    end

    def search(filters = {})
      @database.query(filters)
    end
  end
end
