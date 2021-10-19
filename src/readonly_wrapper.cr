module Phase
  # Wraps an `Indexable` type, exposing only the methods from `Indexable` and
  # blocking all methods that would mutate the elements.
  #
  # This is used to store coordinates mutably internally, but expose them
  # immutably to a user (without cloning and the performance penalty that causes).
  # The only standard container type that could do the same  is a Slice
  # with read_only set to true, but this would lead to unexpected runtime errors.
  # By using ReadonlyWrapper, the compiler can prevent improper write calls safely.
  private class ReadonlyWrapper(T)
    include Indexable(T)
    
    getter size : Int32
    @buffer : Pointer(T)
    
    def initialize(@buffer : Pointer(T), @size)
    end
    
    def unsafe_fetch(index : Int)
      @buffer[index]
    end
    
    def inspect(io : IO)
      to_a.inspect(io)
    end
    
    def to_s(io : IO)
      inspect(io)
    end

    def ==(other : self)
      self.equals?(other) { |e1, e2| e1 == e2 }
    end
  end
end