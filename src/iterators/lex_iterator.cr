require "./coord_iterator"

module Phase
  # A `CoordIterator` that produces every coordinate in an `IndexRegion` in lexicographic
  # (row-major) order. For example:
  #
  # ```crystal
  # LexIterator.cover([2, 3]).each.to_a # => [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]]
  # ```
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
