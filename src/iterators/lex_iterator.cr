require "./coord_iterator"

module Lattice
  class LexIterator < CoordIterator
    def reset : self
      setup_coord(CoordIterator::LEAST_SIG)
      self
    end

    def next_if_nonempty
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
