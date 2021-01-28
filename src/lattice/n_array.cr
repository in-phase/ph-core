require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"

module Lattice
    class NArray(T) < AbstractNArray(T)
        include Enumerable(T)

        getter buffer : Slice(T)
        @shape : Array(Int32)

        def self.build(shape, &block : Array(Int32), Int32 -> T)
            NArray(T).new(shape) do |packed_index|
                yield unpack_index(packed_index, shape), packed_index
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
            @buffer = Slice(T).new(num_elements) {|i| yield i }
        end

        # protected def recursive_probe_array(data, shape = [])
        #     if data.is_a? Array
        #         if data.empty?
        #             raise DimensionError.new("Could not profile nested array: Found an array with size zero.")
        #         end

        #         shape << data.size
        #         return recursive_probe_array(data[0], shape)
        #     else
        #         return shape
        #     end
        # end

        # protected def recursive_copy_to_buffer(data, shape, current_dim = 0, buffer = )
            
        #     # check that current array matches expected length for this dimension
            
            
            
        # end

        # def initialize(data_array)

        # end
        # TODO  Constructor accepting nested array

        # Convenience initializer for making copies.
        protected def initialize(shape, @buffer)
            @shape = shape.dup
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
            NArrayFormatter.format(self)
        end

        # Override for printing a string output to stream (e.g., puts)
        def to_s(io : IO)
            NArrayFormatter.print(self, io)
        end


        # Creates a deep copy of this NArray; 
        # Allocates a new buffer of the same shape, and calls #clone on every item in the buffer.
        def clone : NArray(T)
            NArray(T).new(@shape, @buffer.clone())
        end

        # Creates a shallow copy of this NArray;
        # Allocates a new buffer of the same shape, and duplicates every item in the buffer.
        def dup : NArray(T)
            NArray(T).new(@shape, @buffer.dup())
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


        # maps an n-dimensional 
        # to a list of buffer indices that 
        def extract_buffer_indices(coord) : Tuple(Array(Int32), Array(Int32))
            shape = [] of Int32

            # The behaviour of this method will change if we are using non-row-major ordering.

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
                # Originally, all other cases handled here. (else)
                # the [] method requires me to pass coord as an Array rather than Tuple,
                # which for some reason broke here if I didn't check it as an Int32.
                # TODO consider changing this back if we use macros for [], and if that allows Tuples
                when Int32
    
                    index = canonicalize_index(rule, axis)
                    if index < 0 || index >= @shape[axis]
                        raise IndexError.new("Could not canonicalize index: #{rule} is not a sensible index in axis #{index}.")
                    end

                    chunk_start_indices.each do |ref|
                        new_indices << ref + index * step
                    end
                    shape << 1
                else 
                   puts "Not a Range or Integer!" # throw error here?
                end
                chunk_start_indices = new_indices
            end

            {shape, chunk_start_indices}
        end

        #Higher-order slicing operations (like slicing in numpy)
        def [](*coord) : NArray(T)
            shape, mapping = extract_buffer_indices(coord)
            NArray(T).new(shape) {|i| @buffer[mapping[i]]}
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


        # replaces an indexed chunk with a given chunk of the same shape.
        def set(coord, value : NArray(T))
            shape, mapping = extract_buffer_indices(coord)

            # check that the replacement slice matches the 
            if value.shape != shape
                raise DimensionError.new("Cannot substitute array: given array does not match shape of specified slice.")
            end

            mapping.each_with_index do |dst_idx, src_idx|
                @buffer[dst_idx] = value.buffer[src_idx]
            end
        end

        # replaces all values in an indexed chunk with the given value.
        def set(coord, value : T)
            shape, mapping = extract_buffer_indices(coord)

            mapping.each do |index|
                @buffer[index] = value
            end
        end


        # TODO macro-ify this
        # Takes a valid slicing operation in [], and sets the obtained values to the value after =. 
        # def []=(*args)
        #     value = args.last?
        #     coord = args.to_a[...-1]

        #     case value
        #     when NArray
        #         set(coord, value.as(NArray))
                
        #     when T 
        #         set(coord, value.as(T))
        #     else
        #         puts "Neither"
        #         # Maybe attempt casting to T?

        #         #raise TypeError.new("Cannot set values: type of input does not match type of NArray.")
        #     end
        # end

        def []=(*args : *U) forall U
            {% begin %}
                set([{% for i in 0...(U.size - 1) %}args[{{i}}] {% if i < U.size - 2 %}, {% end %}{% end %}], args.last)
            {% end %}
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
            NArray(Int32 | String).new([objects.size]) {|i| objects[i]}
        end

        def get_buffer_idx(index) : T
            @buffer[index]
        end

        def flatten : NArray(T)
            NArray.new([@shape.product], @buffer.dup)
        end

        def to_a : Array(T)
            @buffer.to_a
        end

        def each_with_index(&block : T, Int32 -> )
            @buffer.each_with_index do |elem, idx|
                yield elem, idx
            end
        end

        def each(&block : T -> )
            each_with_index do |elem|
                yield elem
            end
        end

        def each_with_indices(&block : T, Array(Int32), Int32 -> )
            each_with_index do |elem, idx|
                yield elem, unpack_index(idx), idx
            end
        end

        def map_with_index(&block : T, Int32 -> U) forall U
            buffer = Slice(U).new(@shape.product) do |idx|
                yield @buffer[idx], idx
            end

            NArray(U).new(@shape, buffer)
        end

        def map(&block : T -> U) forall U
            map_with_index do |elem|
                yield elem
            end
        end
        
        def map_with_indices(&block : T, Array(Int32), Int32 -> U) forall U
            map_with_index do |elem, idx|
                yield elem, unpack_index(idx), idx
            end
        end

        def map_with_index!(&block : T, Int32 -> T) forall T
            @buffer.map_with_index! do |elem, idx|
                yield elem, idx
            end
            
            self
        end

        def map!(&block : T -> U) forall U
            map_with_index! do |elem|
                yield elem
            end
        end

        def map_with_indices!(&block : T, Array(Int32), Int32 -> U) forall U
            map_with_index! do |elem, idx|
                yield elem, unpack_index(idx), idx
            end
        end


        def reshape(new_shape)
            NArray(T).new(new_shape, @buffer)
        end

        # TODO implement these
        
        # deletion
        # constructors
            
    end
end