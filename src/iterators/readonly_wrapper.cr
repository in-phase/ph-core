module Phase
    # Wraps an `Indexable` type, exposing only the methods from `Indexable` and
    # blocking all methods that would mutate the elements.
    # 
    # This exists because coordinate iterators are in a bit of an awkward niche - they must store a
    # coordinate mutably (because the iterator alters it), prevent the user from mutating it,
    # and yet be very fast. The only standard container type that would work is a Slice
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

        def to_s(io : IO)
            to_a.to_s(io)
        end
    end
end