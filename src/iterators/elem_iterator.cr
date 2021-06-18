require "./elem_coord_iterator"

module Lattice
  class ElemIterator(T)
    include Iterator(T)

    getter region_iter : ElemAndCoordIterator(T)

    def self.of(src, region = nil, reverse = false, iter : CoordIterator.class = LexIterator) : self
      new(src, region, reverse, iter)
    end

    def self.new(src, region = nil, reverse = false, colex = false) : self
      if colex
        iter = ColexIterator.new(src.shape, region, reverse)
      else
        iter = LexIterator.new(src.shape, region, reverse)
      end
      new(ElemAndCoordIterator.new(src, iter))
    end

    def self.new(src, region = nil, reverse = false, iter : CoordIterator.class = LexIterator) : self
      new(ElemAndCoordIterator.new(src, region, reverse, iter))
    end

    protected def initialize(@region_iter : ElemAndCoordIterator(T))
    end

    def next
      @region_iter.next_value
    end

    def unsafe_next
      @region_iter.unsafe_next_value
    end

    def reset
      @region_iter.reset
    end

    def coord_iter
      @region_iter.coord_iter
    end
  end
end
