module Phase::Buffered::Indexed
  abstract class Indexed::StrideIterator(I) < Phase::StrideIterator(I)
    @buffer_index : I
    @buffer_step : Array(I)
    
    def self.cover(shape)
      new(IndexRegion.cover(shape), shape)
    end

    private def initialize(@first : Indexable(I), @last, @step, @buffer_step)
      @buffer_index = @buffer_step.map_with_index { |e, i| e * @first[i] }.sum
      super(@first, @step, @last)
    end

    protected def self.new(region : IndexRegion, shape : Shape)
      if region.dimensions == 0
        raise DimensionError.new("Failed to create {{@type.id}}: cannot iterate over empty shape \"[]\"")
      end
      
      buffer_step = Buffered.axis_strides(shape)
      new(region.@first, region.@last, region.@step, buffer_step)
    end
    
    def unsafe_next_with_index
      {self.next.unsafe_as(ReadonlyWrapper(Array(I), I)), @buffer_index}
    end
    
    def current_index : I
      @buffer_index
    end
    
    def unsafe_next_index : I
      self.next
      @buffer_index
    end
    
    macro def_standard_clone
      protected def copy_from(other : self)
        @first = other.@first.clone
        @step = other.@step.clone
        @last = other.@last.clone
        @coord = other.@coord.clone
        @buffer_index = other.@buffer_index
        @buffer_step = other.@buffer_step.clone
        @wrapper = ReadonlyWrapper.new(@coord)
        self
      end
      
      def clone : self
        inst = {{@type}}.allocate
        inst.copy_from(self)
      end
    end
  end
end
