module Phase
  module MultiIndexable(T)
    class ElemAndCoordIterator(S, E, I)
      include Iterator(Tuple(E, Indexable(I)))

      @coord_iter : StrideIterator(I)
      @src : S

      delegate :reset, :reverse!, to: @coord_iter

      private def initialize(@src : S, el_type : E.class, @coord_iter : StrideIterator(I))
        shape = @src.shape
        largest_coord = @coord_iter.largest_coord

        if shape.size != largest_coord.size
          raise ShapeError.new("The coordinate iterator's dimensionality (#{largest_coord.size}D) does not match the dimensionality of the MultiIndexable (#{shape.size}D).")
        end

        largest_coord.each_with_index do |ord, axis|
          if ord >= shape[axis]
            raise IndexError.new("The largest coord in the provided coordinate iterator, #{largest_coord}, overflows the MultiIndexable shape (#{shape}) on axis #{axis}")
          end
        end
      end

      def self.new(src : MultiIndexable, coord_iter : StrideIterator(I)) forall I
        new(src, typeof(src.sample), coord_iter)
      end

      def self.new(src : MultiIndexable, idx_region : IndexRegion)
        if src.dimensions != idx_region.proper_dimensions
        end

        new(@src, idx_region.each)
      end

      def next : Tuple(E, Indexable(I)) | Stop
        coord = @coord_iter.next

        if coord.is_a? Stop
          stop
        else
          {@src.unsafe_fetch_element(coord), coord}
        end
      end

      def to_a
        arr = [] of Tuple(E, Array(I))
        each { |el| arr << {el[0], el[1].to_a} }
        arr
      end

      def unsafe_next : Tuple(E, Indexable(I))
        self.next.as(Tuple(E, Indexable(I)))
      end

      def reverse_each
        inst = clone
        inst.@coord_iter.reverse!
        inst
      end

      def reverse_each(&block)
        reverse_each.each do |tuple|
          yield tuple
        end
      end

      def clone : self
        ElemAndCoordIterator.new(@src, @coord_iter.clone)
      end
    end
  end
end