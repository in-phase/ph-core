require "./n_array_abstract.cr"
require "./exceptions.cr"

module Lattice
    class NArray(T) < AbstractNArray(T)
        @buffer : Slice(T)
        @shape : Array(UInt32)

        # TODO Int cannot be used as a Proc argument type yet. See if this is possible later.
        protected def initialize(shape, &block : Int32 -> T)
            @shape = shape.map &.to_u32
            num_elements = shape.product.to_i32
            # TODO should we check that shape has only > 0?
            #if num_elements == 0
            #    raise SomeError.new()
            #end
            @buffer = Slice.new(num_elements) {|i| yield i }
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

        # Returns an array where `shape[i]` is the size of the NArray in the `i`th dimension.
        def shape : Array(UInt32)
            # TODO note: made this Int32 here because for initialize #1 to work, shape must be 
            # 
            @shape.clone()
        end
        
        # Maps a zero-dimensional NArray to the element it contains.
        def to_scalar : T
            if scalar?
                return @buffer[0]
            else
                raise DimensionError.new("Cannot cast to scalar: NArray has more than one dimension or more than one element.")
            end
        end




        # TODO check/implement these

        # Checks that the array is a 1-vector (a "zero-dimensional" NArray)
        def scalar?
            @shape.size == 1 && @shape[0] == 1
        end

        # Checks that the shape is greater than 1 in at most one dimension.
        # (eg, may be a row or column vector; may be flattened without loss of order information)
        def vector?
            @shape.count { |i| i != 1 } <= 1
        end

        # Checks that the array is defined in exactly 2 dimensions.
        def matrix?
            @shape.size == 2
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

        # Given a fully-qualified coordinate, returns the scalar at that position.
        def get(*coord) : T
            # definitely check that all indices are legal (or else may map to an existing, but very wrong, value)
            raise NotImplementedError.new("not implemented")
        end


        # Higher-order slicing operations (like slicing in numpy)
        def [](*coord) : NArray(T)
            raise NotImplementedError.new("not implemented")
        end




        # TODO decide if we want these

        protected def get_buffer : Slice(T)
            @buffer
        end

        # A function to help with testing during development,
        # probably not too useful otherwise
        def get_by_buffer_index(index) : T
            return @buffer[index]
        end


        # Get the smallest shape that each object may be contained in
        def self.least_common_shape(objects)
            shapes = objects.to_a.map { |x| x.shape() }
            max_dimension = (shapes.map &.size).max
            container = (0...max_dimension).map do |dim_idx|
                sizes_in_dim = shapes.map { |shape| shape[dim_idx]? }
                sizes_in_dim.compact.max
            end
            container
        end


        # Adds a dimension at highest level, where each "row" is an input NArray.
        # If pad is false, then throw error if shapes of objects do not match;
        # otherwise, pad subarrays along each axis to match whichever is largest in that axis
        def self.wrap(*objects : NArray(T), pad = false) : NArray(T)
            shapes = objects.to_a.map { |x| x.shape() }
            if pad
                container = least_common_shape(objects)
                # pad all arrays to this size
                raise NotImplementedError.new("As of this time, NArray.wrap() cannot pad arrays for you. Come back after reshaping has been implemented, or get off the couch and go do it yourself.")
            else
                container = shapes[0]
                # check that all arrays are same size
                if shapes.any? { |shape| shape != container }
                    raise DimensionError.new("Cannot wrap these arrays: shapes do not match. Pass argument pad:true if you want to reshape arrays as necessary.")
                end
            end
            container.insert(0, objects.size.to_u32)
            # This currently creates an array, then reconverts into a slice. possibly use a more direct method, copying buffers directly?
            # Although if we generalize to concatenating arrays of different types this may be superior?
            combined_buffer = objects.reduce([] of T) { |memo, i| memo.concat(i.get_buffer.to_a) }
            NArray(T).new(container) { |i| combined_buffer[i] }
        end

        # creates an NArray-type vector from a tuple of scalars.
        # Currently can't mix types
        def self.wrap(*objects : T) : NArray(T)        
            NArray(T).new([objects.size]) {|i| objects[i]}
        end

        
        

        # TODO rename or remove this!! Mostly for experimentation
        # Assigns each array element an integer corresponding to its index in the buffer.
        def self.integers(shape) : NArray(Int32)
            NArray(Int32).new(shape) {|i| i}
        end
        



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