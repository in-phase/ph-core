require "./coord_iterator"

module Lattice
  class ColexIterator(T) < CoordIterator(T)

    def initialize(region : IndexRegion, reverse : Bool = false)
      super
    end

    def advance_coord
      @coord.each_index do |i| # ## least sig .. most sig
        if @coord[i] == @last[i]
          @coord[i] = @first[i]
          return stop if i == @coord.size - 1 # most sig
        else
          @coord[i] += @step[i]
          break
        end
      end
      @coord
    end
  end
end
