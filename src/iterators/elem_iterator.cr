require "./elem_coord_iterator"

module Phase
  class ElemIterator(E, I)
    include Iterator(E)

    getter ec_iter : ElemAndCoordIterator(E, I)

    def self.of(src, iter : CoordIterator)
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

    def self.new(src, iter : CoordIterator)
      new(ElemAndCoordIterator.new(src, iter))
    end

    protected def initialize(@ec_iter : ElemAndCoordIterator(E, I))
    end

    def next
      @ec_iter.next_value
    end

    def unsafe_next
      @ec_iter.unsafe_next_value
    end

    def reset
      @ec_iter.reset
    end

    def coord_iter
      @ec_iter.coord_iter
    end

    def reverse
      new(@src, @ec_iter.reverse)
    end

    def reverse!
      @ec_iter.reverse!
    end
  end
end
