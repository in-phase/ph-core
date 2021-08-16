require "./coord_iterator"

module Phase
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
