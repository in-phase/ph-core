require "./n_array_abstract.cr"
require "./exceptions.cr"

module Lattice
    class NArray(T) < AbstractNArray(T)
        protected getter buffer : Slice(T)
        @shape : Array(Int32)

        def self.build(shape, &block : Array(Int32) -> T)
            NArray(T).new(shape) do |packed_index|
                yield unpack_index(packed_index, shape)
            end
        end

        protected def initialize(shape, &block : Int32 -> T)
            @shape = shape.map do |dim|
                if dim < 1
                    raise DimensionError.new("Cannot create NArray: One or more of the provided dimensions was less than one.")
                end
                dim
            end
            
            num_elements = shape.product.to_i32
            @buffer = Slice.new(num_elements) {|i| yield i }
        end

        # TODO  Constructor accepting nested array

        # Convenience initializer for making copies.
        protected def initialize(@shape, @buffer)
        end

        # Fill an array of given size with a given value. Note that if value is an `Object`, only its reference will be copied
        # - all elements would refer to a single object.
        def initialize(shape, value : T)
            initialize(shape) { value }
        end

        # Checks if a given list of integers represent an index that is in range for this `NArray`.
        def valid_index?(indices)
            NArray.valid_index?(indices, @shape)
        end

        def self.valid_index?(indices, shape)
            if indices.size > shape.size
                return false
            end
            indices.each_with_index do |length, dim|
                if shape[dim] <= length
                    return false
                end
            end
            true
        end



        def self.pack_index(indices, shape) : Int32
            if !valid_index?(indices, shape)
                raise IndexError.new("Cannot pack index: the given index is out of bounds for this NArray along at least one dimension.")
            end

            memo = 0
            indices.each_with_index do |array_index, dim|
                step = (shape[(dim+1)..]? || [1]).product
                memo += step * indices[dim]
            end
            memo
        end
        
        # Convert from n-dimensional indexing to a buffer location.
        def pack_index(indices) : Int32
            NArray.pack_index(indices, @shape)
        end

        def self.unpack_index(index, shape) : Array(Int32)
            indices = Array(Int32).new(shape.size, 0)
            shape.reverse.each_with_index do |length, dim|
                indices[dim] = index % length
                index //= length
            end
            indices.reverse
        end

        # Convert from a buffer location to an n-dimensional indexing 
        def unpack_index(index) : Array(Int32)
            NArray.unpack_index(index, @shape)
        end

        # Returns an array where `shape[i]` is the size of the NArray in the `i`th dimension.
        def shape : Array(Int32)
            @shape.clone()
        end

        def dimensions : Int32
            @shape.size
        end

        # Maps a zero-dimensional NArray to the element it contains.
        def to_scalar : T
            if scalar?
                return @buffer[0]
            else
                raise DimensionError.new("Cannot cast to scalar: NArray has more than one dimension or more than one element.")
            end
        end

        # Checks that the array is a 1-vector (a "zero-dimensional" NArray)
        def scalar?
            @shape.size == 1 && @shape[0] == 1
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
        # For example, if `a` is a matrix, `a[0]` will be a vector. There is a special case when 
        # indexing into a 1D `NArray` - the scalar at the index provided will be wrapped in an
        # `NArray`. This is to preserve type-safety - if you want to extract the scalar as type `T`,
        # invoke `#to_scalar`.
        def [](index) : NArray(T)
            if dimensions == 1
                new_shape = [1]
            else
                new_shape = @shape[1..]
            end
            # The "step size" of the top level dimension (row) is the product of the lower dimensions.
            step = new_shape.product

            new_buffer = @buffer[index * step, step]
            NArray(T).new(new_shape, new_buffer.clone())
        end

        # Given a fully-qualified coordinate, returns the scalar at that position.
        def get(*coord) : T
            @buffer[pack_index(coord)]
        end

        # Given a range in some dimension (typically the domain to slice in), returns a canonical
        # form where both indexes are positive and the range is strictly inclusive of its bounds.
        # This method also returns a direction parameter, which is 1 iff `begin` < `end` and
        # -1 iff `end` < `begin`
        def canonicalize_range(range, axis) : Tuple(Range(Int32, Int32), Int32)
            
            positive_begin = canonicalize_index(range.begin || 0, axis)
            # definitely not negative, but we're not accounting for exclusivity yet
            positive_end = canonicalize_index(range.end || (@shape[axis] - 1), axis)

            # The case (positive_end - positive_begin) == 0 will raise an exception below, if the range excludes its end.
            # Otherwise, we may treat it as an "ascending" array of a single element.
            direction = positive_end - positive_begin >= 0 ? 1 : -1

            if range.excludes_end? && range.end
                if positive_begin == positive_end
                    raise IndexError.new("Could not canonicalize range: #{range} does not span any integers.")
                end
                # Convert range to inclusive, by adding or subtracting one to the end depending 
                # on whether it is ascending or descending
                positive_end -= direction
            end

            # It's possible to engineer a set of indices that are meaningless but would break code
            # later on. Detect and raise an exception in that case
            if [positive_begin, positive_end].any? { |idx| idx < 0 || idx >= @shape[axis] }
                raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range in axis #{axis}.")
            end

            {Range.new(positive_begin, positive_end), direction}
        end

        def canonicalize_index(index, axis)
            if index < 0
                return @shape[axis] + index
            else
                return index
            end
        end


        def extract_buffer_indices(*coord) : Tuple(Array(Int32), Array(Int32))
            shape = [] of Int32

            # At each dimension of iteration, chunk_start_indices will expand according to the "rule".
            # For example, if unwrapping (1, 1..2, 1) for an Narray of shape [3,3,3] - in the first iteration,
            # chunk_start_indices is [0], representing the start of the top-level chunk to be searched.
            # At start:           chunk_start_indices = [0]                           (start of buffer)
            # After iteration 1:  chunk_start_indices = [9] = 1 * (3*3)               (start of row 2)
            # After iteration 2:  chunk_start_indices = [12, 15] = [9 + 3, 9 + 6]     (starts of columns 2 and 3 in row 2)
            # After iteration 3:  chunk_start_indices = [13, 16] = [12 + 1, 15 + 1]   (2nd item of columns 2 and 3)
            chunk_start_indices = [0]

            coord.each_with_index do |rule, axis|
                step = (@shape[(axis + 1)..]? || [1]).product
                new_indices = [] of Int32

                case rule
                when Range                    
                    range, dir = canonicalize_range(rule, axis)

                    chunk_start_indices.each do |ref|
                        range.step(dir) do |index|
                            new_indices << ref + index * step * 1
                        end
                    end

                    shape << rule.size
                else
                    index = canonicalize_index(rule, axis)
                    if index < 0 || index >= @shape[axis]
                        raise IndexError.new("Could not canonicalize index: #{rule} is not a sensible index in axis #{index}.")
                    end

                    chunk_start_indices.each do |ref|
                        new_indices << ref + index * step
                    end
                    shape << 1
                end
                chunk_start_indices = new_indices
            end

            {shape, chunk_start_indices}
        end


        #Higher-order slicing operations (like slicing in numpy)
        def [](*coord) : NArray(T)

            # create output NArray
            # for each parameter in coord:
            #   check if it's a range or integer
            #   if range:
            #        iterate through and copy selected elements to output NArray
            #   if integer:
            #        

            shape, mapping = extract_buffer_indices(*coord)

            NArray(T).new(shape) {|i| @buffer[mapping[i]]}

            # extract_buffer_indices to get shape and 

            # matrix[2, ..]
            # mapping = [1]
            # mapping[sliced_array_axis] == where in matrix you must put that index

            # output_arr = new(shape) do |indices|
                # goes from output array index to full array index

            # end
            
            # begin >= -shape, < shape 
            # end >= -shape, < shape
            # 1...1 raises indexerror? (range of no elements)
            # 3..1 flips horizontally
            # ... -> all
            # 2.. -> index 2 (inclusive) to end
            # ..-1 -> up to that
            # .. -> all

            
            # img : 128 x 64 x 3, we want a 32 x 32 square from the top left corner
            # img[0...32, 0...32] <- type: Range (not full depth)

            # just the top row:
            # img[..., 6] <- Range and Integer (not full depth)

            # just red:
            # img[..,..,0] <- Range/Integer, at full depth

            # img[.., -32..32] <- puts the beach above the sky

            # img[0..-10] <- everything but the last ten rows
            
            # img[-10..-5] <- Only the five rows five before the end

            # img[-1..0] <- horizontal flip of the image
            # img[0..-1] <- identity

            # boolean mask: find all elems that are 0 and make them 1
            # mask = img[..,..] == 0 
            # img[mask] = 1
        end


        # TODO fix! Compiler cannot differentiate *coord and value
        # replaces all values in a given slice with the given value.
        def []=(*coord, value : T)
            shape, mapping = extract_buffer_indices(*coord)

            mapping.each do |index|
                @buffer[index] = value
            end
        end

        # replaces all values in a boolean mask with a given value
        def []=(bool_mask : NArray(Bool), value : T)
            if bool_mask.shape != @shape
                raise DimensionError.new("Cannot perform masking: mask shape does not match array shape.")
            end

            bool_mask.buffer.each_with_index do |bool_val, idx|
                if bool_val
                    @buffer[idx] = value
                end
            end
        end

        # TODO also won't work :(
        # replaces a provided slice with a given slice of the same shape.
        def []=(*coord, value : NArray(T))
            shape, mapping = extract_buffer_indices(*coord)

            # check that the replacement slice matches the 
            if value.shape != shape
                raise DimensionError.new("Cannot substitute array: given array does not match shape of specified slice.")
            end

            mapping.each_with_index do |dst_idx, src_idx|
                @buffer[dst_idx] = value.buffer[src_idx]
            end
        end

        # Given a list of `NArray`s, returns the smallest shape array in which any one of those `NArrays` can be contained.
        # TODO: Example
        def self.common_container(*objects)
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
                container = common_container(*objects)
                # pad all arrays to this size
                raise NotImplementedError.new("As of this time, NArray.wrap() cannot pad arrays for you. Come back after reshaping has been implemented, or get off the couch and go do it yourself.")
            else
                container = shapes[0]
                # check that all arrays are same size
                if shapes.any? { |shape| shape != container }
                    raise DimensionError.new("Cannot wrap these arrays: shapes do not match. Pass argument pad:true if you want to reshape arrays as necessary.")
                end
            end
            container.insert(0, objects.size)
            # This currently creates an array, then reconverts into a slice. possibly use a more direct method, copying buffers directly?
            # Although if we generalize to concatenating arrays of different types this may be superior?
            combined_buffer = objects.reduce([] of T) { |memo, i| memo.concat(i.buffer.to_a) }
            NArray(T).new(container) { |i| combined_buffer[i] }
        end

        # creates an NArray-type vector from a tuple of scalars.
        # Currently can't mix types
        def self.wrap(*objects : T) : NArray(T)        
            NArray(T).new([objects.size]) {|i| objects[i]}
        end

        
        # TODO implement these

        # flatten 
            # 

        # deletion
        # constructors
        # reshaping?
        # to float???



        # A function to help with testing during development,
        # probably not too useful otherwise
        # TODO remove
        def get_by_buffer_index(index) : T
            return @buffer[index]
        end

            
    end
end