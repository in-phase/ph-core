require "./stride_iterator"

module Phase
  # An `iterator` that produces every coordinate in an `IndexRegion` in lexicographic
  # (row-major) order. For example:
  #
  # ```crystal
  # LexIterator.cover([2, 3]).each.to_a # => [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]]
  # ```
  class LexIterator(I) < StrideIterator(I)
    def_clone

    def initialize(first : Array(I), step : Array(Int), last : Array(I))
      super(first, step, last)
    end

    def advance! : Array(I) | Stop
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
