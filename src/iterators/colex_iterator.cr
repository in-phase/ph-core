require "./coord_iterator"

module Phase
  # An `Iterator` that produces every coordinate in an `IndexRegion` in colexicographic
  # (column-major) order. For example:
  #
  # ```crystal
  # ColexIterator.cover([2, 3]).each.to_a # => [[0, 0], [1, 0], [0, 1], [1, 1], [0, 1], [1, 2]]
  # ```
  class ColexIterator(I) < StrideIterator(I)
    def_clone

    def initialize(first : Array(I), step : Array(Int), last : Array(I))
      super(first, step, last)
    end

    def advance! : Array(I) | Stop
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
