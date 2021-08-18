require "./coord_iterator"

module Phase
  class LexIterator(T) < CoordIterator(T)

    def_clone

    def initialize(region : IndexRegion(T))
      super
    end

    def initialize(region_literal)
      super(IndexRegion(T).new(region_literal))
      # make coord
      # make step
      # @coord_ptr = @coord.to_unsafe
    end

    def advance_coord
      (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
        if @coord.unsafe_fetch(i) == @last.unsafe_fetch(i)
          @coord[i] = @first.unsafe_fetch(i)
          return stop if i == 0 # most sig
        else
          @coord[i] = @coord.unsafe_fetch(i) + @step.unsafe_fetch(i)
          break
        end
      end
      @coord
    end
  end
end
