require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"

module Lattice
  # An `{{@type}}` is a multidimensional array for any arbitrary type.
  # It is the most general implementation of Abstract{{@type}}, and as a result
  # only implements primitive data operations (construction, data reading,
  # data writing, and region sampling / slicing).
  #
  # `{{@type}}` is designed to provide the best user experience possible, and
  # that methodology led to the use of the `method_missing` macro for element-wise
  # operations. Please read its documentation, as it provides a large amount
  # of functionality that may otherwise appear missing.
  class NArray(T) < AbstractNArray(T)
    include Enumerable(T)

    # Stores the elements of an `{{@type}}` in lexicographic (row-major) order.
    getter buffer : Slice(T)
    
    # Contains the number of elements in each axis of the `{{@type}}`.
    # More explicitly, axis *k* contains *@shape[k]* elements.
    @shape : Array(Int32)

    # Constructs an `{{@type}}` using a user-provided *shape* (see `shape`) and a callback.
    # The provided callback should map a multidimensional index, *coord*, (and an optional packed
    # index) to the value you wish to store at that position.
    # For example, to create the 2x2 identity matrix:
    # ```
    # Lattice::{{@type}}.build([2, 2]) do |coord|
    #   if coord[0] == coord[1]
    #     1
    #   else
    #     0
    #   end
    # end
    # ```
    # Which will create:
    # ```text
    # [[1, 0, 0],
    #   0, 1, 0],
    #   0, 0, 1]]
    # ```
    # The buffer index allows you to easily index elements in lexicographic order.
    # For example:
    # ```
    # {{@type}}.build([5, 1]) { |coord, index| index }
    # ```
    # Will create:
    # ```text
    # [[0],
    #  [1],
    #  [2],
    #  [3],
    #  [4]]
    # ```
    def self.build(shape, &block : Array(Int32), Int32 -> T)
      {{@type}}.new(shape) do |idx|
        yield index_to_coord(idx, shape), idx
      end
    end

    # Creates an `{{@type}}` using only a shape (see `shape`) and a packed index.
    # This is used internally to make code faster - converting from a packed
    # index to an unpacked index isn't needed for many constructors, and generating
    # them would waste resources.
    # For more information, see `coord_to_index`, `buffer`, and `build`.
    protected def initialize(shape, &block : Int32 -> T)
      if shape.empty?
        raise DimensionError.new("Cannot create {{@type}}: `shape` was empty.")
      end

      @shape = shape.map do |dim|
        if dim < 1
          raise DimensionError.new("Cannot create {{@type}}: One or more of the provided dimensions was less than one.")
        end
        dim
      end

      num_elements = shape.product.to_i32
      @buffer = Slice(T).new(num_elements) { |i| yield i }
    end

    # Creates an `{{@type}}` from a nested array with uniform dimensions.
    # For example:
    # ```
    # {{@type}}.new([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    # ```
    # Would create the 3x3 identity matrix of type `{{@type}}(Int32)`.
    # 
    # This constructor will figure out the types of the scalars at the
    # bottom of the nested array at compile time, which allows mixing
    # datatypes effortlessly.
    # For example, to create a matrix with 0.5 on the diagonals:
    # ```
    # {{@type}}.new([[0.5, 0, 0], [0, 0.5, 0], [0, 0, 0.5]])
    # ```
    # This may seem trivial, but note that the `0.5`s are implicit
    # `Float32` literals, whereas the `0`s are implicit `Int32` literals.
    # So, the type returned by that example will actually be an `{{@type}}(Float32 | Int32)`.
    # This also works for more disorganized examples:
    # ```
    # {{@type}}.new([["We can mix types", 2, :do], ["C", 0.0, "l stuff."]])
    # ```
    # The above line will create an `{{@type}}(String | Int32 | Symbol | Float32)`.
    #
    # When a nested array with non-uniform dimensions is passed, this method will
    # raise a `DimensionError`.
    # For example:
    # ```
    # {{@type}}.new([[1], [1, 2]]) # => DimensionError
    # ```
    def self.new(nested_array)
      shape = recursive_probe_array(nested_array)
      expected_element_count = shape.product

      elements = container_for_base_types(nested_array, expected_element_count)

      recursive_extract_to_array(nested_array, shape, elements)

      # fill elements
      buffer = Slice.new(elements.to_unsafe, expected_element_count)

      # Do the typical `new` stuff
      self.new(shape, buffer)
    end

    # Creates an `{{@type}}` out of a shape and a pre-populated buffer.
    # Frequently used internally (for example, this is used in
    # `reshape` as of Feb 5th 2021).
    # TODO: Should be protected, had to remove for testing
    protected def initialize(shape, @buffer : Slice(T))
      @shape = shape.dup
    end

    # Returns the estimated dimension of a multidimensional array that is provided as a nested array literal.
    # Used internally to determine the buffer size for several constructors. Note that this method
    # does not guarantee that the size reported is accurate.
    # For example, `{{@type}}.recursive_probe_array([[1], [1, 2]])` will return `[2, 1]`. The `2` comes
    # from the fact that the top-level array contains 2 elements, and the `1` comes from the size of
    # the sub-array `[1]`. However, we can clearly see that the size isn't uniform - the second
    # sub-array is `[1, 2]`, which is two elements, not one!
    protected def self.recursive_probe_array(nested_array data, shape = [] of Int32) : Array(Int32)
      if data.is_a? Array
        if data.empty?
          raise DimensionError.new("Could not profile nested array: Found an array with size zero.")
        end

        shape << data.size
        return recursive_probe_array(data[0], shape)
      else
        return shape
      end
    end

    # Populated a pre-initialized buffer of appropriate union type with nested array elements in lexicographic order.
    # See `recursive_probe_array` and `recursive_probe_array` for more information about the union type
    # and shape parameter.
    # Raises a `DimensionError` if the number of dimensions is inconsistent. 
    protected def self.recursive_extract_to_array(nested_array data, shape, buffer, current_dim = 0)
      # check if current array matches expected length for this dimension
      if data.size != shape[current_dim]
        raise DimensionError.new("Error converting nested array to {{@type}}: Dimensions of nested array were not constant. (Expected #{shape[current_dim]}, found #{data.size})")
      end

      # Base case: this is the lowest level in shape (expect elements are scalars)
      if current_dim == shape.size - 1
        data.each do |scalar|
          if scalar.is_a?(Enumerable)
            raise DimensionError.new("Error converting nested array to {{@type}}: Inconsistent number of dimensions depending on path.")
          end

          if scalar.is_a?(typeof(buffer[0]))
            buffer << scalar
          end
        end

        # Case 2: this is not the last dimension in shape (expect elements are arrays)
      else
        data.each do |subarray|
          if !subarray.is_a?(Enumerable) # is not actually a subarray
            raise DimensionError.new("Error converting nested array to {{@type}}: Inconsistent number of dimensions depending on path.")
          end

          recursive_extract_to_array(subarray, shape, buffer, current_dim + 1)
        end
      end
    end


    # Fills an `{{@type}}` of given shape with a specified value.
    # For example, to create a zero vector:
    # ```
    # {{@type}}.fill([3, 1], 0)
    # ```
    # Will produce
    # ```text
    # [[0],
    #  [0],
    #  [0]]
    # ```
    # Note that this method makes no effort to duplicate *value*, so this should only be used
    # for `Struct`s. If you want to populate an {{@type}} with `Object`s, see `new(shape, &block)`.
    def self.fill(shape, value : T) 
      # \{% begin %} \{{ @type.id }}.new(shape) { value } \{% end %}
      {{@type}}.new(shape) { value }
    end


    ### Basic getters and convenience functions

    # TODO: Code below this line isn't neccessarily well documented

    # Checks if a given list of integers represent an index that is in range for this `{{@type}}`.
    # TODO: Rename and document
    def valid_coord?(coord)
      {{@type}}.valid_coord?(coord, @shape)
    end

    # TODO: Rename and document
    def self.valid_coord?(coord, shape)
      if coord.size > shape.size
        return false
      end
      coord.each_with_index do |length, dim|
        if shape[dim] <= length
          return false
        end
      end
      true
    end

    # TODO: Talk about what this should be named
    def self.coord_to_index(coord, shape) : Int32
      if !valid_coord?(coord, shape)
        raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this {{@type}} along at least one dimension.")
      end

      memo = 0
      coord.each_with_index do |array_index, dim|
        step = self.step_size(dim, shape)
        memo += step * coord[dim]
      end
      memo
    end

    # Convert from n-dimensional indexing to a buffer location.
    def coord_to_index(coord) : Int32
      {{@type}}.coord_to_index(coord, @shape)
    end

    def self.index_to_coord(index, shape) : Array(Int32)
      coord = Array(Int32).new(shape.size, 0)
      shape.reverse.each_with_index do |length, dim|
        coord[dim] = index % length
        index //= length
      end
      coord.reverse
    end

    # Convert from a buffer location to an n-dimensional coord
    def index_to_coord(index) : Array(Int32)
      {{@type}}.index_to_coord(index, @shape)
    end


    # TODO docs
    def step_size(axis)
      {{@type}}.step_size(axis, @shape)
    end

    def self.step_size(axis, shape)
      (shape[(axis + 1)..]? || [1]).product
    end

    # Returns the number of elements in each axis of the `{{@type}}`.
    # More explicitly, axis *k* contains `shape[k]` elements.
    def shape : Array(Int32)
      @shape.clone
    end

    # Returns the number of dimensions of this `{{@type}}`.
    # This is equivalent to, but slightly faster than, `shape.size`.
    def dimensions : Int32
      @shape.size
    end

    # Maps a zero-dimensional {{@type}} to the element it contains.
    def to_scalar : T
      if scalar?
        return @buffer[0]
      else
        raise DimensionError.new("Cannot cast to scalar: self has more than one dimension or more than one element.")
      end
    end

    # Checks that the array is a 1-vector (a "zero-dimensional" {{@type}})
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

    # Creates a deep copy of this {{@type}};
    # Allocates a new buffer of the same shape, and calls #clone on every item in the buffer.
    def clone : self
      {{@type}}.new(@shape, @buffer.clone)
    end

    # Creates a shallow copy of this {{@type}};
    # Allocates a new buffer of the same shape, and duplicates every item in the buffer.
    def dup : self
      {{@type}}.new(@shape, @buffer.dup)
    end







    ### Buffer data manipulation: slicing, setting, etc


    # Takes a single index into the {{@type}}, returning a slice of the largest dimension possible.
    # For example, if `a` is a matrix, `a[0]` will be a vector. There is a special case when
    # indexing into a 1D `{{@type}}` - the scalar at the index provided will be wrapped in an
    # `{{@type}}`. This is to preserve type-safety - if you want to extract the scalar as type `T`,
    # invoke `#to_scalar`.
    # TODO: Either make the type restriction here go away (it was getting called when indexing
    # with a single range), or remove this method entirely in favor of read only views
    def [](index : Int32) : self
      index = canonicalize_index(index, axis=0)
      
      if dimensions == 1
        new_shape = [1]
      else
        new_shape = @shape[1..]
      end
      # The "step size" of the top level dimension (row) is the product of the lower dimensions.
      step = new_shape.product

      new_buffer = @buffer[index * step, step]
      {{@type}}.new(new_shape, new_buffer.clone)
    end

    # Given a fully-qualified coordinate, returns the scalar at that position.
    def get(*coord) : T
      @buffer[coord_to_index(coord)]
    end


    # TODO any way to avoid copying these out yet, too? Iterator magic?
    def slices(axis = 0) : Array(self)
      region = [] of (Int32 | Range(Int32, Int32))
      (0...axis).each do |dim|
        region << Range.new(0, @shape[dim] - 1)
      end
      region << 0

      # Version 1: Theoretically faster, as index calculations occur only once
      mapping = buffer_indices(region)
      shape = measure_region(region)
      step = step_size(axis)

      slices = (0...@shape[axis]).map do |slice_number|
        offset = step * slice_number
        {{@type}}.new(shape) {|i| mapping[i] + offset}
      end

      # Version 2: Cleaner, and may be faster if [] does not get indices as an intermediate step

      # Does not currently work; TODO fix
      # slices = (0...@shape[axis]).map do |slice_number|
      #   region[axis] = slice_number
      #   next self[region]
      # end
    end


    def get_region(region) : self

      shape = measure_region(region)

      # TODO optimize this! Any way to avoid double iteration?
      buffer_arr = [] of T
      each_in_region(region) do |elem, idx, src_idx|
        buffer_arr << elem
      end
      {{@type}}.new(shape) { |i| buffer_arr[i] }
    end

    def [](region : Indexable) : self
      get_region(region)
    end

    # Higher-order slicing operations (like slicing in numpy)
    def [](*region) : self
      get_region(region)
    end

    # replaces all values in a boolean mask with a given value
    def []=(bool_mask : AbstractNArray(Bool), value : T)
      if bool_mask.shape != @shape
        raise DimensionError.new("Cannot perform masking: mask shape does not match array shape.")
      end

      bool_mask.buffer.each_with_index do |bool_val, idx|
        if bool_val
          @buffer[idx] = value
        end
      end
    end

    def []=(*args : *U) forall U
      {% begin %}
        set([{% for i in 0...(U.size - 1) %}args[{{i}}] {% if i < U.size - 2 %}, {% end %}{% end %}], args.last)
      {% end %}
    end

    # replaces an indexed chunk with a given chunk of the same shape.
    def set(region, value : self)
      
      # check that the replacement slice matches the destination shape
      if value.shape != measure_region(region)
        raise DimensionError.new("Cannot substitute array: given array does not match shape of specified slice.")
      end

      each_in_region(region) do |elem, other_idx, this_idx|
        @buffer[this_idx] = value.buffer[other_idx]
      end
    end

    # replaces all values in an indexed chunk with the given value.
    def set(region, value) # prev: set(region, value : T)

      # Try to cast the value to T; throws an error if it fails
      # TODO: decide if this is how we want to handle it
      fill_value = value.as(T)

      each_in_region(region) do |elem, idx, buffer_idx|
        @buffer[buffer_idx] = fill_value
      end
    end

    def buffer_indices(region) : Array(Int32)
      indices = [] of Int32
      each_in_region(region) do |elem, idx, src_idx|
        indices << src_idx
      end
      indices
    end


    # Returns the `shape` of a region when sampled from this `{{@type}}`.
    # For example, on a 5x5x5 {{@type}}, `measure_shape(1..3, ..., 5)` => `[3, 5]`.
    def measure_region(region) : Array(Int32)
      measure_canonical_region(canonicalize_region(region))
    end

    def each_in_region(region, &block : T, Int32, Int32 ->)
      region = canonicalize_region(region)
      shape = measure_canonical_region(region)

      each_in_canonical_region(region, compute_buffer_step_sizes, &block)
    end

    # TODO docs
    def canonicalize_index_unchecked(index, axis)
      if index < 0
        return @shape[axis] + index
      else
        return index
      end
    end

    # TODO docs
    # see canonicalize_index_unchecked; but throws an error if index is out of range for axis
    def canonicalize_index(index, axis)
      if index < -@shape[axis] || index >= @shape[axis]
        raise IndexError.new("Could not canonicalize index: #{index} is not a sensible index in axis #{axis}.")
      end
      if index < 0
        return @shape[axis] + index
      else
        return index
      end
    end


    # Given a range in some dimension (typically the domain to slice in), returns a canonical
    # form where both indexes are positive and the range is strictly inclusive of its bounds.
    # This method also returns a direction parameter, which is 1 iff `begin` < `end` and
    # -1 iff `end` < `begin`
    def canonicalize_range(range, axis) : Tuple(Range(Int32, Int32), Int32)
      positive_begin = canonicalize_index(range.begin || 0, axis)
      # definitely not negative, but we're not accounting for exclusivity yet
      positive_end = canonicalize_index_unchecked(range.end || (@shape[axis] - 1), axis)

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

      # Since the validity of the end value has not been verified yet, do so here:
      if positive_end < 0 || positive_end >= @shape[axis]
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range in axis #{axis}.")
      end

      # TODO: This function is supposed to support both Range and StepIterator - in the latter case, direction != step_size
      # Need to measure step size and properly return it
      {Range.new(positive_begin, positive_end), direction}
    end

    

    # TODO combine/revise docs
    # Converts a region specifier to canonical form.
    # A canonical region specifier obeys the following:
    # - No implicit trailing ranges; the dimensions of the RS matches that of the {{@type}}. 
    #     Eg, for a 3x3x3, [.., 2] is non-canonical
    # - All elements are ranges (single-number indexes must be converted to ranges of a single element)
    # - Both the start and end of the range must be positive, and in range for the axis in question
    # - The ranges must be inclusive (eg, 1..2, not 1...3)
    # - In each range, start < end indicates forward direction; start > end indicates backward

    # Applies `#canonicalize_index` and `#canonicalize_range` to each element of a region specification.
    # In order to fully canonicalize the region, it will also add wildcard selectors if the region
    # has implicit wildcards (if `region.size < shape.size`).
    #
    # Returns a tuple containing (in this order):
    # - The input region in canonicalized form
    # - An array of equal size to the region that indicates if that index is a scalar (0),
    #     a range with increasing index (+1), or a range with decreasing index (-1).
    def canonicalize_region(region) : Array(SteppedRange)
      canonical_region = region.clone.to_a + [..] * (@shape.size - region.size)
    
        canonical_region = canonical_region.map_with_index do |rule, axis|
            case rule
            # TODO: Handle StepIterator or whatever
            when Range
                # Ranges are the only implementation we support
                range, step = canonicalize_range(rule, axis)
                next SteppedRange.new(range, step)
            else
                # This branch is supposed to capture numeric objects. We avoid specifying type
                # explicitly so we can have the most interoperability.
                index = canonicalize_index(rule, axis)
                next SteppedRange.new((index..index), 1)
            end
        end
    end


    


        # See `{{@type}}#measure_region`. The only difference is that this method assumes
    # the region is already canonicalized, which can provide speedups.
    # TODO: account for step sizes
    protected def measure_canonical_region(region) : Array(Int32)
      shape = [] of Int32
      if region.size != @shape.size
        raise DimensionError.new("Could not measure canonical range - A region with #{region.size} dimensions cannot be canonical over a #{@shape.size} dimensional {{@type}}.")
      end

      # Measure the effect of applied restrictions (if a rule is a number, a dimension
      # gets dropped. If a rule is a range, a dimension gets resized)
      region.each do |range|
        if range.size > 1
          shape << range.size
        end
      end

      return [1] if shape.empty?
      return shape
    end

    


    # Given an array of step sizes in each coordinate axis, returns the offset in the buffer
    # that a step of that size represents.
    # The buffer index of a multidimensional coordinate, x, is equal to x dotted with buffer_step_sizes
    def compute_buffer_step_sizes
        ret = @shape.clone
        ret[-1] = 1
        ((ret.size - 2)..0).step(-1) do |idx|
          ret[idx] = ret[idx + 1] * @shape[idx + 1]
        end
        ret
    end

    # TODO: Document
    def each_in_canonical_region(region, buffer_step_sizes, axis = 0, read_index = 0, write_index = [0], &block : T, Int32, Int32 -> )
        current_range = region[axis]

        # Base case - yield the scalars in a subspace
        if axis == @shape.size - 1        
            current_range.each do |idx|
                # yield @buffer[read_index + idx], write_index[0], read_index + idx
                # write_index[0] += 1
                yield @buffer.unsafe_fetch(read_index + idx), write_index.unsafe_fetch(0), read_index + idx
                write_index[0] += 1
            end  
            return
        end

        # Otherwise, recurse
        buffer_step_size = buffer_step_sizes[axis]
        initial_read_index = read_index

        current_range.each do |idx|
            # navigate to the correct start index
            read_index = initial_read_index + idx * buffer_step_size
            each_in_canonical_region(region, buffer_step_sizes, axis + 1, read_index, write_index) do |a, b, c|
                block.call(a, b, c)
            end
        end
    end

    
    
    




    # Given a list of `{{@type}}`s, returns the smallest shape array in which any one of those `{{@type}}s` can be contained.
    # TODO: Example
    def self.common_container(*objects)
      shapes = objects.to_a.map { |x| x.shape }
      max_dimension = (shapes.map &.size).max
      container = (0...max_dimension).map do |dim_idx|
        sizes_in_dim = shapes.map { |shape| shape[dim_idx]? }
        sizes_in_dim.compact.max
      end
      container
    end

    # Adds a dimension at highest level, where each "row" is an input {{@type}}.
    # If pad is false, then throw error if shapes of objects do not match;
    # otherwise, pad subarrays along each axis to match whichever is largest in that axis
    def self.wrap(*objects : AbstractNArray(T), pad = false) : NArray
      shapes = objects.to_a.map { |x| x.shape }
      if pad
        container = common_container(*objects)
        # TODO pad all arrays to this size
        raise NotImplementedError.new("As of this time, {{@type}}.wrap() cannot pad arrays for you. Come back after reshaping has been implemented, or get off the couch and go do it yourself.")
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
      # TODO: Figure out how this will work with inheritance & Tensor
      NArray(T).new(container) { |i| combined_buffer[i] }
    end

    # creates an {{@type}}-type vector from a tuple of scalars.
    def self.wrap(*objects)
      # TODO: Figure out how this will work with inheritance & Tensor
      NArray.new(objects.to_a)
    end

    


    def get_buffer_idx(index) : T
      @buffer[index]
    end

    def flatten : self
      {{@type}}.new([@shape.product], @buffer.dup)
    end

    def to_a : Array(T)
      @buffer.to_a
    end

    def each_with_index(&block : T, Int32 ->)
      @buffer.each_with_index do |elem, idx|
        yield elem, idx
      end
    end

    def each(&block : T ->)
      each_with_index do |elem|
        yield elem
      end
    end

    def each_with_coord(&block : T, Array(Int32), Int32 ->)
      each_with_index do |elem, idx|
        yield elem, index_to_coord(idx), idx
      end
    end

    def map_with_index(&block : T, Int32 -> U) forall U
      buffer = Slice(U).new(@shape.product) do |idx|
        yield @buffer[idx], idx
      end

      {% begin %}
        {{@type.id}}(U).new(@shape, buffer)
      {% end %}
    end

    def map(&block : T -> U) forall U
      map_with_index do |elem|
        yield elem
      end
    end

    def map_with_coord(&block : T, Array(Int32), Int32 -> U) forall U
      map_elems_with_index do |elem, idx|
        yield elem, index_to_coord(idx), idx
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

    def map_with_coord!(&block : T, Array(Int32), Int32 -> U) forall U
      map_with_index! do |elem, idx|
        yield elem, index_to_coord(idx), idx
      end
    end

    def reshape(new_shape)
      {{@type}}.new(new_shape, @buffer)
    end

    def to_tensor : Tensor(T)
      Tensor.new(self)
    end
    
    # If a method signature not defined on {{@type}} is called, then `method_missing` will attempt
    # to apply the method to every element contained in the {{@type}}. Any argument to the method call
    # that is also an {{@type}} will be applied element-wise.
    # For example:
    # ```arr = {{@type}}(Int32).new([2,2,2]) { |i| i }
    # arr > 4```
    # will give: [[[false, false], [false, false]], [[false, true], [true true]]]
    # WARNING: fully exhaustive testing is not possible for this method; use at your own risk.
    # If a method is defined on both {{@type}} and the type parameter T, precedence will be
    # given to {{@type}}. Complex overloading may cause problems.
    macro method_missing(call)
      def {{call.name.id}}(*args : *U) forall U
        \{% if !@type.type_vars[0].has_method?({{call.name.id.stringify}}) %}
          \{% raise( <<-ERROR
                      undefined method '{{call.name.id}}' for #{@type.type_vars[0]}.
                      This error is a result of Lattice attempting to apply `{{call.name.id}}`,
                      an unknown method, to each element of an `{{@type}}`. (See the documentation
                      of `{{@type}}#method_missing` for more info). For the source of the error, 
                      use `--error-trace`.
                      ERROR
                      ) %}
        \{% end %}

        \{% for i in 0...(U.size) %}
          \{% if U[i] < {{@type}} %}
            if args[\{{i}}].shape != @shape
              raise DimensionError.new("Could not apply .{{call.name.id}} elementwise - Shape of argument does match dimension of `self`")
            end
          \{% end %}
        \{% end %}

        new_buffer = @buffer.map_with_index do |elem, buf_idx|
          \{% begin %}
            # Note: Be careful with this section. Adding newlines can break this code because it might put commas on their
            # own lines.
            elem.{{call.name.id}}(
              \{% for i in 0...(U.size) %}\
                \{% if U[i] < {{@type}} %} args[\{{i}}].buffer[buf_idx] \{% else %} args[\{{i}}] \{% end %} \{% if i < U.size - 1 %}, \{% end %}
              \{% end %}\
            )
          \{% end %}
          end
          
          {{@type}}.new(shape, new_buffer)
      end
    end

    # TODO implement these

    # deletion
    # constructors

    # TODO: Document properly
    # Given a nested array, returns the union type needed to store any of the leaf-level scalars contained within.
    # For example:
    # union_of_base_types([["a", 1], ['b', false]], 15) # => Array(String | Int32 | Char | Bool)
    private def self.container_for_base_types(nested : T, size) forall T
      {% begin %}
        {%
          scalar_types = [] of TypeNode
          identified = [] of TypeNode
          identified << T
        %}

        {% for type_to_check in identified %}

          # If the object is array-like, mark each type in its type parameter as needing to be checked
          {% if type_to_check.type_vars.size == 1 && type_to_check < Enumerable %} # has one generic type var that extends enumerate
            {% type_var = type_to_check.type_vars[0] %}

            {% for type in type_var.union_types %}
              {% identified << type %}     
            {% end %}
        
          # If the object is a scalar, push the type to the scalar_types list    
          {% else %} 
            {% scalar_types << type_to_check %}
          {% end %}
        {% end %}

        {% ret_types = scalar_types.uniq %}
        
        return Array({% for i in 0...(ret_types.size) %} {% if i > 0 %} | {% end %} {{ ret_types[i] }} {% end %}).new(initial_capacity: size)
      {% end %}
    end
  end


  struct SteppedRange
    getter size : Int32
    getter range : Range(Int32, Int32)
    getter step : Int32

    def initialize(@range : Range(Int32, Int32), @step : Int32)
      @size = ((@range.end - @range.begin) // @step).abs.to_i32 + 1
    end

    # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
    # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
    # going forwards or backwards.
    # TODO: Better docs
    # TODO find out why these 2 implementations are so drastically different in performance! Maybe because the functionality has been recently modified? (0.36)
    def each(&block)
        idx = @range.begin
        if @step > 0
          while idx <= @range.end
            yield idx
            idx += @step
          end
        else
          while idx >= @range.end
            yield idx
            idx += @step
          end
        end
    #   @range.step(@step) do |i|
    #     yield i
    #   end
    end

    def begin
      @range.begin
    end

    def end
      @range.end
    end
  end
end

