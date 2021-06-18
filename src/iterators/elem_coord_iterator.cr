require "./coord_iterator"

module Lattice
  class ElemAndCoordIterator(T)
    include Iterator(Tuple(T, Array(Int32)))

    getter coord_iter : CoordIterator

    def self.of(src, region = nil, reverse = false, iter : CoordIterator.class = LexIterator)
      new(src, iter.new(src.shape, region, reverse))
    end

    def self.new(src, region = nil, reverse = false, colex = false) : self
      if colex
        new(src, ColexIterator.new(src.shape, region, reverse))
      else
        new(src, LexIterator.new(src.shape, region, reverse))
      end
    end

    def self.new(src, region = nil, reverse = false, iter : CoordIterator.class = LexIterator)
      new(src, iter.new(src.shape, region, reverse))
    end

    protected def initialize(@src : MultiIndexable(T), @coord_iter : CoordIterator)
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

    def next_value : (T | Iterator::Stop)
      coord = @coord_iter.next
      return stop if coord.is_a?(Iterator::Stop)
      get_element(coord)
    end

    def unsafe_next_value : T
      coord = @coord_iter.next.unsafe_as(Array(Int32))
      get_element(coord)
    end
  end
end
