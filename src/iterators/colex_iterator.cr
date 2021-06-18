require "./coord_iterator"

module Lattice
  class ColexIterator < CoordIterator
    def reset : self
      setup_coord(CoordIterator::MOST_SIG)
      self
    end

    def next_if_nonempty
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
