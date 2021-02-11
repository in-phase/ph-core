require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"

module Lattice
  # An `NArray` is a multidimensional array for any arbitrary type.
  # It is the most general implementation of AbstractNArray, and as a result
  # only implements primitive data operations (construction, data reading,
  # data writing, and region sampling / slicing).
  #
  # `NArray` is designed to provide the best user experience possible, and
  # that methodology led to the use of the `method_missing` macro for element-wise
  # operations. Please read its documentation, as it provides a large amount
  # of functionality that may otherwise appear missing.
  class NArray(T) < AbstractNArray(T)
    include Enumerable(T)

    # Stores the elements of an `NArray` in lexicographic (row-major) order.
    getter buffer : Slice(T)
    
    # Contains the number of elements in each axis of the `NArray`.
    # More explicitly, axis *k* contains *@shape[k]* elements.
    @shape : Array(Int32)

    # Constructs an `NArray` using a user-provided *shape* (see `shape`) and a callback.
    # The provided callback should map a multidimensional index, *coord*, (and an optional packed
    # index) to the value you wish to store at that position.
    # For example, to create the 2x2 identity matrix:
    # ```
    # Lattice::NArray.build([2, 2]) do |coord|
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
    # NArray.build([5, 1]) { |coord, index| index }
    # ```
    # Will create:
    # ```text
    # [[0],
    #  [1],
    #  [2],
    #  [3],
    #  [4]]
    # ```
    def self.build(shape, &block : Array(Int32), Int32 -> T) : NArray(T)
      NArray(T).new(shape) do |idx|
        yield index_to_coord(idx, shape), idx
      end
    end

    # Creates an `NArray` using only a shape (see `shape`) and a packed index.
    # This is used internally to make code faster - converting from a packed
    # index to an unpacked index isn't needed for many constructors, and generating
    # them would waste resources.
    # For more information, see `coord_to_index`, `buffer`, and `build`.
    protected def initialize(shape, &block : Int32 -> T)
      @shape = shape.map do |dim|
        if dim < 1
          raise DimensionError.new("Cannot create NArray: One or more of the provided dimensions was less than one.")
        end
        dim
      end

      num_elements = shape.product.to_i32
      @buffer = Slice(T).new(num_elements) { |i| yield i }
    end

    # Creates an `NArray` from a nested array with uniform dimensions.
    # For example:
    # ```
    # NArray.new([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    # ```
    # Would create the 3x3 identity matrix of type `NArray(Int32)`.
    # 
    # This constructor will figure out the types of the scalars at the
    # bottom of the nested array at compile time, which allows mixing
    # datatypes effortlessly.
    # For example, to create a matrix with 0.5 on the diagonals:
    # ```
    # NArray.new([[0.5, 0, 0], [0, 0.5, 0], [0, 0, 0.5]])
    # ```
    # This may seem trivial, but note that the `0.5`s are implicit
    # `Float32` literals, whereas the `0`s are implicit `Int32` literals.
    # So, the type returned by that example will actually be an `NArray(Float32 | Int32)`.
    # This also works for more disorganized examples:
    # ```
    # NArray.new([["We can mix types", 2, :do], ["C", 0.0, "l stuff."]])
    # ```
    # The above line will create an `NArray(String | Int32 | Symbol | Float32)`.
    #
    # When a nested array with non-uniform dimensions is passed, this method will
    # raise a `DimensionError`.
    # For example:
    # ```
    # NArray.new([[1], [1, 2]]) # => DimensionError
    # ```
    def self.new(nested_array)
      shape = recursive_probe_array(nested_array)
      expected_element_count = shape.product

      elements = container_for_base_types(nested_array, expected_element_count)

      recursive_extract_to_array(nested_array, shape, elements)

      # fill elements
      buffer = Slice.new(elements.to_unsafe, expected_element_count)

      # Do the typical `new` stuff
      instance = NArray(typeof(elements[0])).allocate
      instance.initialize(shape, buffer)
      instance
    end

    # Creates an `NArray` out of a shape and a pre-populated buffer.
    # Frequently used internally (for example, this is used in
    # `reshape` as of Feb 5th 2021).
    protected def initialize(shape, @buffer : Slice(T))
      @shape = shape.dup
    end

    # Returns the estimated dimension of a multidimensional array that is provided as a nested array literal.
    # Used internally to determine the buffer size for several constructors. Note that this method
    # does not guarantee that the size reported is accurate.
    # For example, `NArray.recursive_probe_array([[1], [1, 2]])` will return `[2, 1]`. The `2` comes
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
        raise DimensionError.new("Error converting nested array to NArray: Dimensions of nested array were not constant. (Expected #{shape[current_dim]}, found #{data.size})")
      end

      # Base case: this is the lowest level in shape (expect elements are scalars)
      if current_dim == shape.size - 1
        data.each do |scalar|
          if scalar.is_a?(Enumerable)
            raise DimensionError.new("Error converting nested array to NArray: Inconsistent number of dimensions depending on path.")
          end

          if scalar.is_a?(typeof(buffer[0]))
            buffer << scalar
          end
        end

        # Case 2: this is not the last dimension in shape (expect elements are arrays)
      else
        data.each do |subarray|
          if !subarray.is_a?(Enumerable) # is not actually a subarray
            raise DimensionError.new("Error converting nested array to NArray: Inconsistent number of dimensions depending on path.")
          end

          recursive_extract_to_array(subarray, shape, buffer, current_dim + 1)
        end
      end
    end


    # Fills an `NArray` of given shape with a specified value.
    # For example, to create a zero vector:
    # ```
    # NArray.fill([3, 1], 0)
    # ```
    # Will produce
    # ```text
    # [[0],
    #  [0],
    #  [0]]
    # ```
    # Note that this method makes no effort to duplicate *value*, so this should only be used
    # for `Struct`s. If you want to populate an NArray with `Object`s, see `new(shape, &block)`.
    def self.fill(shape, value : T)
      NArray(T).new(shape) { value }
    end

    # TODO: Code below this line isn't neccessarily well documented

    # Checks if a given list of integers represent an index that is in range for this `NArray`.
    # TODO: Rename and document
    def valid_coord?(coord)
      NArray.valid_coord?(coord, @shape)
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
        raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this NArray along at least one dimension.")
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
      NArray.coord_to_index(coord, @shape)
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
      NArray.index_to_coord(index, @shape)
    end


    # TODO docs
    def step_size(axis)
      NArray.step_size(axis, @shape)
    end

    def self.step_size(axis, shape)
      (shape[(axis + 1)..]? || [1]).product
    end

    # Returns the number of elements in each axis of the `NArray`.
    # More explicitly, axis *k* contains `shape[k]` elements.
    def shape : Array(Int32)
      @shape.clone
    end

    # Returns the number of dimensions of this `NArray`.
    # This is equivalent to, but slightly faster than, `shape.size`.
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
      NArray(T).new(@shape, @buffer.clone)
    end

    # Creates a shallow copy of this NArray;
    # Allocates a new buffer of the same shape, and duplicates every item in the buffer.
    def dup : NArray(T)
      NArray(T).new(@shape, @buffer.dup)
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
      NArray(T).new(new_shape, new_buffer.clone)
    end

    # Given a fully-qualified coordinate, returns the scalar at that position.
    def get(*coord) : T
      @buffer[coord_to_index(coord)]
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

      # It's possible to engineer a range with bounds that are meaningless but would break code
      # later on. Detect and raise an exception in that case
      if [positive_begin, positive_end].any? { |idx| idx < 0 || idx >= @shape[axis] }
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range in axis #{axis}.")
      end

      {Range.new(positive_begin, positive_end), direction}
    end

    # TODO docs
    def canonicalize_index(index, axis)
      if index < 0
        return @shape[axis] + index
      else
        return index
      end
    end

    # TODO docs
    # Converts a region specifier to canonical form.
    # A canonical region specifier obeys the following:
    # - No implicit trailing ranges; the dimensions of the RS matches that of the NArray. 
    #     Eg, for a 3x3x3, [.., 2] is non-canonical
    # - All elements are ranges (single-number indexes must be converted to ranges of a single element)
    # - Both the start and end of the range must be positive, and in range for the axis in question
    # - The ranges must be inclusive (eg, 1..2, not 1...3)
    # - In each range, start < end indicates forward direction; start > end indicates backward
    def canonicalize_region(coord) : Tuple(Array(Range(Int32, Int32)), Array(Int32), Array(Int32) )

      full_coord = [] of Range(Int32, Int32)
      shape = [] of Int32
      directions = [] of Int32

      coord.each_with_index do |rule, axis|
        case rule
        when Range
          range, dir = canonicalize_range(rule, axis)
          full_coord << range
          shape << (range.end - range.begin + dir).abs
          directions << dir
        when Int32
          index = canonicalize_index(rule, axis)
          if index < 0 || index >= @shape[axis]
            raise IndexError.new("Could not canonicalize index: #{rule} is not a sensible index in axis #{index}.")
          end
          full_coord << (index..index)
          shape << 1
          directions << 1
        else 
          # TODO raise error here
          puts "Not a Range or Integer"
        end
      end
      # fill in implicit ranges
      (coord.size...@shape.size).each do |axis|
        full_coord << (0..(@shape[axis] - 1))
        shape << @shape[axis]
        directions << 1
      end

      {full_coord, shape, directions}
    end



    def extract_buffer_indices(coord) : Tuple(Array(Int32), Array(Int32))

      # The behaviour of this method will change if we are using non-row-major ordering.

      # At each dimension of iteration, chunk_start_indices will expand according to the "rule".
      # For example, if unwrapping (1, 1..2, 1) for an Narray of shape [3,3,3] - in the first iteration,
      # chunk_start_indices is [0], representing the start of the top-level chunk to be searched.
      # At start:           chunk_start_indices = [0]                           (start of buffer)
      # After iteration 1:  chunk_start_indices = [9] = 1 * (3*3)               (start of row 2)
      # After iteration 2:  chunk_start_indices = [12, 15] = [9 + 3, 9 + 6]     (starts of columns 2 and 3 in row 2)
      # After iteration 3:  chunk_start_indices = [13, 16] = [12 + 1, 15 + 1]   (2nd item of columns 2 and 3)
      full_coord, shape, dirs = canonicalize_region(coord)
      chunk_start_indices = [0]

      full_coord.each_with_index do |range, axis|
        step = step_size(axis)
        new_indices = [] of Int32

        chunk_start_indices.each do |ref|
          range.step(dirs[axis]) do |index|
            new_indices << ref + index * step * 1
          end
        end
        
        chunk_start_indices = new_indices
      end

      {shape, chunk_start_indices}
    end
    

    # Higher-order slicing operations (like slicing in numpy)
    def [](*coord) : NArray(T)
      shape, mapping = extract_buffer_indices(coord)
      NArray(T).new(shape) { |i| @buffer[mapping[i]] }
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

    def []=(*args : *U) forall U
      {% begin %}
                set([{% for i in 0...(U.size - 1) %}args[{{i}}] {% if i < U.size - 2 %}, {% end %}{% end %}], args.last)
            {% end %}
    end

    # Given a list of `NArray`s, returns the smallest shape array in which any one of those `NArrays` can be contained.
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

    # Adds a dimension at highest level, where each "row" is an input NArray.
    # If pad is false, then throw error if shapes of objects do not match;
    # otherwise, pad subarrays along each axis to match whichever is largest in that axis
    def self.wrap(*objects : NArray(T), pad = false) : NArray(T)
      shapes = objects.to_a.map { |x| x.shape }
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
    def self.wrap(*objects)
      NArray.new(objects.to_a)
    end

    def slices(axis = 0) : Array(NArray(T))

      step = 1

      # TODO generalize to give slices along any axis
      #new_buffer = @buffer.each(step: step).to_a
      (0...@shape[axis]).map do |idx|
        self[idx]
      end
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

      NArray(U).new(@shape, buffer)
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
      NArray(T).new(new_shape, @buffer)
    end

    def to_tensor : Tensor(T)
      Tensor.new(self)
    end
    
    macro method_missing(call)
      def {{call.name.id}}(*args : *U) forall U
        \{% if !@type.type_vars[0].has_method?({{call.name.id.stringify}}) %}
          \{% raise( <<-ERROR
                      undefined method '{{call.name.id}}' for #{@type.type_vars[0]}.
                      This error is a result of Lattice attempting to apply `{{call.name.id}}`,
                      an unknown method, to each element of an `NArray`. (See the documentation
                      of `NArray#method_missing` for more info). For the source of the error, 
                      use `--error-trace`.
                      ERROR
                      ) %}
        \{% end %}

        \{% for i in 0...(U.size) %}
          \{% if U[i] < NArray %}
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
                \{% if U[i] < NArray %} args[\{{i}}].buffer[buf_idx] \{% else %} args[\{{i}}] \{% end %} \{% if i < U.size - 1 %}, \{% end %}
              \{% end %}\
            )
          \{% end %}
          end
          
          NArray.new(shape, new_buffer)
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
end
