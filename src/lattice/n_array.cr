require "./n_array_abstract.cr"
require "./exceptions.cr"

module Lattice
    class NArray(T) # < AbstractNArray(T)
        @buffer : Slice(T)
        @shape : Array(UInt32)

        protected def initialize(shape, &block : Int32 -> T)
            @shape = shape.map &.to_u32
            num_elements = shape.product
            @buffer = Slice(T).new(num_elements)

            @buffer.each_with_index do |_, buffer_index|
                @buffer[buffer_index] = yield buffer_index
            end
        end

        def self.zeros(shape) : NArray(Float64)
            NArray(Float64).new(shape) { 0f64 }
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




        # Takes a single index into the NArray, returning a slice of the largest dimension possible.
        # For example, if `a` is a matrix, `a[0]` will be a vector. 
        # abstract def [](index) : AbstractNArray(T)

        # Higher-order slicing operations (like slicing in numpy)
        # abstract def [](*coord) : AbstractNArray(T)

        # Given a fully-qualified coordinate, returns the scalar at that position.
        # abstract def get(*coord) : T

        # Returns a deep copy of the array.
        # abstract def clone : AbstractNArray(T)

        # Returns a shallow copy of the array.
        # abstract def dup : AbstractNArray(T)

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