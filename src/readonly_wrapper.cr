module Phase
  # Wraps an `Indexable` type, exposing only the methods from `Indexable` and
  # blocking all methods that would mutate the elements.
  #
  # This is used to store coordinates mutably internally, but expose them
  # immutably to a user (without cloning and the performance penalty that causes).
  # The only standard container type that could do the same  is a Slice
  # with read_only set to true, but this would lead to unexpected runtime errors.
  # By using ReadonlyWrapper, the compiler can prevent improper write calls safely.
  private class ReadonlyWrapper(S, T)
    include Indexable(T)
    
    @src : S
    delegate size, inspect, to_s, to: @src
    
    protected def initialize(*, internal_name @src : S)
    end
    
    def self.new(src : Indexable(T)) forall T
      instance = ReadonlyWrapper(typeof(src), T).new(internal_name: src)
    end

    def unsafe_fetch(index : Int)
      @src.unsafe_fetch(index)
    end
    
    def ==(other : self)
      self.equals?(other) { |e1, e2| e1 == e2 }
    end

    def ==(other)
      false
    end
  end
end
