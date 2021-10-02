require "./elem_coord_iterator"

module Phase
  class ElemIterator(S, E, I)
    include Iterator(E)

    getter ec_iter : ElemAndCoordIterator(S, E, I)

    def_clone
    delegate :reset, :reverse!, :coord_iter, to: @ec_iter

    def self.of(src, region = nil)
      if region.nil?
        iter = LexIterator.cover(src.shape)
      else
        iter = LexIterator(typeof(src.shape[0])).new(region)
      end

      new(src, iter)
    end

    def self.new(src, iter : Iterator(Indexable(I))) forall I
      new(ElemAndCoordIterator.new(src, iter))
    end

    def initialize(@ec_iter : ElemAndCoordIterator(S, E, I))
    end

    def next
      @ec_iter.next_value
    end

    def unsafe_next
      @ec_iter.unsafe_next_value
    end

    def reverse
      clone.reverse!
    end
  end
end
