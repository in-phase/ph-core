require "./coord_iterator"

module Phase
  class ElemAndCoordIterator(E, I)
    include Iterator(Tuple(E, Array(I)))

    getter coord_iter : CoordIterator(I)

    # discussed on signal: have an overload where iter is a mandatory named param

    def self.of(src, iter : CoordIterator(I))
      new(src, iter)
    end

    def self.of(src, region = nil)
      if region.nil?
        iter = LexIterator.cover(src.shape)
      else
        iter = LexIterator.new(region)
      end
      new(src, iter)
    end

    def initialize(@src : MultiIndexable(E), @coord_iter : CoordIterator(I))
    end

    def reset
      @coord_iter.reset
    end

    protected def get_element(coord)
      @src.unsafe_fetch_element(coord)
    end

    def next
      coord = @coord_iter.next
      return stop if coord.is_a?(Iterator::Stop)
      {get_element(coord), coord}
    end

    def next_value : (E | Iterator::Stop)
      coord = @coord_iter.next
      return stop if coord.is_a?(Iterator::Stop)
      get_element(coord)
    end

    def unsafe_next_value : E
      coord = @coord_iter.next.unsafe_as(Array(I))
      get_element(coord)
    end

    def reverse
      typeof(self).new(@src, @coord_iter.reverse)
    end

    def reverse!
      @coord_iter.reverse!
    end
  end
end
