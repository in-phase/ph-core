require "./coord_iterator"

module Lattice
  class LexIterator(T) < CoordIterator(T)
    def_clone
    def initialize(region : IndexRegion(T))
      super
    end

    def initialize(region_literal)
      super(IndexRegion(T).new(region_literal))
    end

    def advance_coord
      (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
        if @coord[i] == @last[i]
          @coord[i] = @first[i]
          return stop if i == 0 # most sig
        else
          @coord[i] += @step[i]
          break
        end
      end
      @coord
    end
  end
end
