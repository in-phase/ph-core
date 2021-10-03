module Phase
  module MultiIndexable(T)
    private class ElemAndCoordIterator(S, E, I)
      include Iterator(Tuple(E, Indexable(I)))

      getter coord_iter : Iterator(Indexable(I))
      @src : S

      delegate :reset, :reverse!, to: @coord_iter

      # TODO: doc
      # this is here rather than just an initialize because it'll pull type params out for you
      def self.new(src, iter : Iterator(Indexable(I)))
        # Careful, this looks recursive but isn't due to the named param
        ElemAndCoordIterator(typeof(src), typeof(src.first), typeof(src.shape[0])).new(src, coord_iter: iter)
      end

      def self.of(src, region = nil)
        if region.nil?
          iter = LexIterator.cover(src.shape)
        else
          iter = LexIterator(typeof(src.shape[0])).new(region)
        end
        new(src, iter)
      end

      protected def initialize(@src : S, *, @coord_iter : Iterator(Indexable(I)))
      end

      # Clone the iterator (while maintaining reference to the same source array)
      def clone 
        {{@type}}.new(@src, @coord_iter.clone)
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
        coord = @coord_iter.next.as(Array(I))
        get_element(coord)
      end

      def reverse
        clone.reverse!
      end
    end
  end
end