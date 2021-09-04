require "./coord_iterator"

module Phase
  # A `CoordIterator` that produces every coordinate in an `IndexRegion` in colexicographic
  # (column-major) order. For example:
  #
  # ```crystal
  # ColexIterator.cover([2, 3]).each.to_a # => [[0, 0], [1, 0], [0, 1], [1, 1], [0, 1], [1, 2]]
  # ```
  class ColexIterator(T) < CoordIterator(T)

    def_clone

    def initialize(region : IndexRegion(T))
      super
    end

    def initialize(region_literal)
      super(IndexRegion(T).new(region_literal))
    end

    def advance_coord
      @coord.each_index do |i| # ## least sig .. most sig
        if @coord.unsafe_fetch(i) == @last.unsafe_fetch(i)
          @coord[i] = @first.unsafe_fetch(i)
          return stop if i == @coord.size - 1 # most sig
        else
          @coord[i] += @step.unsafe_fetch(i)
          break
        end
      end
      @coord
    end
  end
end
