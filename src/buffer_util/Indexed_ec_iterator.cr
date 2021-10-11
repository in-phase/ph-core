require "./*"

module Phase
  module BufferUtil
    class IndexedElemCoordIterator(S, E, I)
      include Iterator(Tuple(E, Indexable(I)))
      
      @coord_iter : IndexedStrideIterator(I)
      @src : S
      
      delegate :reset, :reverse!, to: @coord_iter
      
      private def initialize(@src : S, el_type : E.class, @coord_iter : IndexedStrideIterator(I))
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
      
      # Constructs an `ElemAndCoordIterator` that draws coordinates from *coord_iter* and takes the matching elements from *source*.
      def self.new(src : MultiIndexable, coord_iter : IndexedStrideIterator(I)) forall I
        new(src, typeof(src.sample), coord_iter)
      end
      
      def self.new(src : MultiIndexable, idx_region : IndexRegion)
        if src.dimensions != idx_region.proper_dimensions
          raise ShapeError.new("The provided IndexRegion has a proper dimension of #{idx_region.proper_dimensions}, which does not match the dimensionality of the MultiIndexable (#{src.dimensions}D).")
        end
        
        new(src, idx_region.each)
      end
      
      def self.new(src : MultiIndexable)
        iter = IndexedLexIterator.cover(src.shape)
        new(src, iter)
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
        inst.reverse!
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
    # class BufferedECIterator(S, E, I) < MultiIndexable::ElemAndCoordIterator(S, E, I)
    #   # include Iterator(Tuple(E, Indexable(I)))
    
    #   @coord_iter : IndexedStrideIterator(I)
    #   # @src : S
    
    #   # delegate :reset, :reverse!, to: @coord_iter
    
    #   # def self.new(src, iter : Iterator(Indexable(I)))
    #     # BufferedECIterator(typeof(src), typeof(src.first), typeof(src.shape[0])).new(src, coord_iter: iter)
    #   # end
    
    #   # Overridden to replace default iterator type
    #   # def self.of(src, region = nil)
    #   #   if region.nil?
    #   #     iter = IndexedLexIterator.cover(src.shape)
    #   #   else
    #   #     iter = IndexedLexIterator.new(region, src.shape)
    #   #   end
    #   #   new(src, iter)
    #   # end
    
    #   # protected def initialize(@src : MultiIndexable(E), @coord_iter : IndexedStrideIterator)
    #   # end
    
    #   # Clone the iterator (while maintaining reference to the same source array)
    #   # def clone 
    #   #   {{@type}}.new(@src, @coord_iter.clone)
    #   # end
    
    #   private def initialize(@src : S, el_type : E.class, @coord_iter : IndexedStrideIterator(I))
    #     shape = @src.shape
    #     largest_coord = @coord_iter.largest_coord
    
    #     if shape.size != largest_coord.size
    #       raise ShapeError.new("The coordinate iterator's dimensionality (#{largest_coord.size}D) does not match the dimensionality of the MultiIndexable (#{shape.size}D).")
    #     end
    
    #     largest_coord.each_with_index do |ord, axis|
    #       if ord >= shape[axis]
    #         raise IndexError.new("The largest coord in the provided coordinate iterator, #{largest_coord}, overflows the MultiIndexable shape (#{shape}) on axis #{axis}")
    #       end
    #     end
    #   end
    
    #   # Constructs an `ElemAndCoordIterator` that draws coordinates from *coord_iter* and takes the matching elements from *source*.
    #   def self.new(src : MultiIndexable, coord_iter : IndexedStrideIterator(I)) forall I
    #     new(src, typeof(src.sample), coord_iter)
    #   end
    
    #   protected def get_element(coord = nil)
    #     if (src = @src).responds_to?(:buffer)
    #       src.buffer.unsafe_fetch(@coord_iter.current_index)
    #     else
    #       raise "@src was a MultiIndexable that did not define #buffer. This is likely an issue with Phase or a Phase-compatible library."
    #     end
    #   end
    
    #   def next : Tuple(E, Indexable(I)) | Stop
    #     coord = @coord_iter.next
    
    #     if coord.is_a? Stop
    #       stop
    #     else
    #       {get_element(coord), coord}
    #     end
    #   end
    
    #   # def next
    #   #   coord = @coord_iter.next
    #   #   return stop if coord.is_a?(Iterator::Stop)
    #   #   {get_element(coord), coord}
    #   # end
    
    #   # def next_value : (E | Stop)
    #   #   return stop if @coord_iter.next.is_a?(Stop)
    #   #   get_element
    #   # end
    
    #   # def unsafe_next : Tuple(E, Indexable(I))
    #   #   self.next.as(Tuple(E, Indexable(I)))
    #   # end
    
    #   # def unsafe_next_value : E
    #   #   @coord_iter.next
    #   #   get_element
    #   # end
    
    #   # def reverse
    #   #   clone.reverse!
    #   # end
    # end
  end
end