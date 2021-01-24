require "./n_array_abstract.cr"
require "./exceptions.cr"

module Lattice
    class NArray(T) # < AbstractNArray(T)
        @buffer : Slice(T)
        @shape : Array(UInt32)

        protected def initialize(shape, &block : Int32 -> T)
            @shape = shape.map &.to_u32
            num_elements = shape.product
            @buffer = Slice.new(num_elements) {|i| yield i}
        end

        # Convenience initializer for making copies.
        protected def initialize(@shape, @buffer)
        end
        
        # Fill an array of given size with a given value
        def self.fill(shape, value : T) : NArray(T)
            NArray(T).new(shape) { value }
        end        

        # Fill an array of given dimensions with zeros
        def self.zeros(shape) : NArray(Float64)
            NArray.fill(shape, 0f64)
        end


        # TODO rename or remove this!! Mostly for experimentation
        # Assigns each array element an integer corresponding to its index in the buffer.
        def self.integers(shape) : NArray(Int32)
            NArray(Int32).new(shape) {|i| i}
        end

        # Returns an array where `shape[i]` is the size of the NArray in the `i`th dimension.
        def shape : Array(UInt32)
            @shape.clone()
        end
        
        # Maps a zero-dimensional NArray to the element it contains.
        def to_scalar : T
            if @shape.size == 1 && @shape[0] == 1
                return @buffer[0]
            else
                raise DimensionError.new("Cannot cast to scalar: NArray has more than one dimension or more than one element.")
            end
        end




        def to_s : String
            # TODO
            # Possibly have format options which control behaviour of this eventually
            "Insert beautifully formatted array of size #{@shape} here"
        end

        # Override for printing a string output to stream (e.g., puts)
        def to_s(io : IO)
            io << to_s()
        end


        # Creates a deep copy of this NArray; 
        # Allocates a new buffer of the same shape, and calls #clone on every item in the buffer.
        def clone : NArray(T)
            NArray(T).new(@shape.clone(), @buffer.clone())
        end

        # Creates a shallow copy of this NArray;
        # Allocates a new buffer of the same shape, and duplicates every item in the buffer.
        def dup : NArray(T)
            NArray(T).new(@shape.clone(), @buffer.dup())
        end
        
        # Takes a single index into the NArray, returning a slice of the largest dimension possible.
        # For example, if `a` is a matrix, `a[0]` will be a vector. 
        def [](index) : NArray(T)

            # Check if index is legal (less than @shape[0]) - or see if Slice will throw appropriate error itself if memory bounds are exceeded

            # If a 1-vector, possibly: return the object as is, and warn the user that they can't index any further/suggest they use .get() or .to_scalar()?

            # Otherwise:
            # The "step size" of the top level dimension (row) is the product of the lower dimensions.
            # Note - .product has defined the "product of an empty array" to be 1, which is desireable for us if the array is one-dimensional (@shape has one element)
            new_shape = @shape[1..]
            step = new_shape.product

            new_buffer = @buffer[index * step, step]
            NArray(T).new(new_shape, new_buffer.clone())
        end


        def get(*coord) : T
            # definitely check that all indices are legal (or else may map to an existing, but very wrong, value)
        end


        
        # abstract def [](index) : AbstractNArray(T)

        # Higher-order slicing operations (like slicing in numpy)
        # abstract def [](*coord) : AbstractNArray(T)

        # Given a fully-qualified coordinate, returns the scalar at that position.
        # abstract def get(*coord) : T

        # flatten 
            # 
        # display (to string?)

        # deletion
        # constructors
        # reshaping?
        # to float???
        # slice?
            
    end
end