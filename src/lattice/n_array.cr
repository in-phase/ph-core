require "./exceptions.cr"
require "./n_array_formatter.cr"
require "./region_helpers.cr"

module Lattice
  # An `{{@type}}` is a multidimensional array for any arbitrary type.
  # It is the most general implementation of Abstract{{@type}}, and as a result
  # only implements primitive data operations (construction, data reading,
  # data writing, and region sampling / slicing).
  #
  class NArray(T)
    include MultiIndexable(T)
    include MultiWritable(T)

    # Stores the elements of an `{{@type}}` in lexicographic (row-major) order.
    getter buffer : Slice(T)

    # Contains the number of elements in each axis of the `{{@type}}`.
    # More explicitly, axis *k* contains *@shape[k]* elements.
    @shape : Array(Int32)

    # Cached version of `.buffer_step_sizes`.
    protected getter buffer_step_sizes : Array(Int32)

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

      @buffer_step_sizes = NArray.buffer_step_sizes(@shape)

      num_elements = shape.product.to_i32
      @buffer = Slice(T).new(num_elements) { |i| yield i }
    end

    # Creates an `{{@type}}` out of a shape and a pre-populated buffer.
    # Frequently used internally (for example, this is used in
    # `reshape` as of Feb 5th 2021).
    # TODO: Should be protected, had to remove for testing
    def initialize(shape, @buffer : Slice(T))
      if shape.product != @buffer.size
        raise ArgumentError.new("Cannot create {{@type}}: Given shape does not match number of elements in buffer.")
      end

      @shape = shape.dup
      @buffer_step_sizes = NArray.buffer_step_sizes(@shape)
    end

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
      shape = measure_nested_array(nested_array)
      flattened = nested_array.flatten

      # fill elements
      buffer = Slice.new(flattened.to_unsafe, flattened.size)

      # Do the typical `new` stuff
      self.new(shape, buffer)
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

    # Returns the number of elements in each axis of the `{{@type}}`.
    # More explicitly, axis *k* contains `shape[k]` elements.
    def shape : Array(Int32)
      @shape.clone
    end

    def size : Int32
      return @shape.product
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

    # TODO any way to avoid copying these out yet, too? Iterator magic?
    def slices(axis = 0) : Array(self)
      region = [] of (Int32 | Range(Int32, Int32))
      (0...axis).each do |dim|
        region << Range.new(0, @shape[dim] - 1)
      end
      region << 0

      # Version 1: Theoretically faster, as index calculations occur only once
      mapping = [] of Int32
      each_in_region(region) do |elem, idx, buffer_idx|
        mapping << buffer_idx
      end
      shape = RegionHelpers.measure_region(region, @shape)
      step = @buffer_step_sizes[axis]

      slices = (0...@shape[axis]).map do |slice_number|
        offset = step * slice_number
        {{@type}}.new(shape) { |i| mapping[i] + offset }
      end
    end

    def flatten : self
      reshape(@buffer.size)
    end

    def reshape(new_shape : Enumerable)
      {{@type}}.new(new_shape.to_a, @buffer)
    end

    def reshape(*splat)
      reshape(splat)
    end

    # Checks that the array is a 1-vector (a "zero-dimensional" {{@type}})
    def scalar? : Bool
      @shape.size == 1 && @shape[0] == 1
    end

    # Checks for elementwise equality between `self` and *other*.
    def ==(other : MultiIndexable) : Bool
      equals?(other) { |x, y| x == y }
    end

    # Convert from n-dimensional indexing to a buffer location.
    def coord_to_index(coord) : Int32
      coord = RegionHelpers.canonicalize_coord(coord, @shape)
      {{@type}}.coord_to_index_fast(coord, @shape, @buffer_step_sizes)
    end

    # TODO: Talk about what this should be named
    def self.coord_to_index(coord, shape) : Int32
      coord = RegionHelpers.canonicalize_coord(coord, shape)
      steps = buffer_step_sizes(shape)
      {{@type}}.coord_to_index_fast(coord, shape, steps)
    end

    # Assumes coord is canonical
    protected def self.coord_to_index_fast(coord, shape, buffer_step_sizes) : Int32
      begin
        index = 0
        coord.each_with_index do |elem, idx|
          index += elem * buffer_step_sizes[idx]
        end
        index
      rescue exception
        raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this {{@type}} along at least one dimension.")
      end
    end

    # Convert from a buffer location to an n-dimensional coord
    def index_to_coord(index) : Array(Int32)
      {{@type}}.index_to_coord(index, @shape)
    end

    # OPTIMIZE: This could (maybe) be improved with use of `buffer_step_sizes`
    def self.index_to_coord(index, shape) : Array(Int32)
      if index > shape.product
        raise IndexError.new("Cannot convert index to coordinate: the given index is out of bounds for this {{@type}} along at least one dimension.")
      end
      coord = Array(Int32).new(shape.size, 0)
      shape.reverse.each_with_index do |length, dim|
        coord[dim] = index % length
        index //= length
      end
      coord.reverse
    end

    # Copies the elements in `region` to a new `{{type}}`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_fetch_region(region)
      shape = RegionHelpers.measure_canonical_region(region)

      # TODO optimize this! Any way to avoid double iteration?
      buffer_arr = [] of T
      narray_each_in_canonical_region(region) do |elem, idx, src_idx|
        buffer_arr << elem
      end

      {{@type}}.new(shape) { |i| buffer_arr[i] }
    end

    # Retrieves the element specified by `coord`, assuming that `coord` is in canonical form and in-bounds for this `{{type}}`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_fetch_element(coord) : T
      @buffer.unsafe_fetch(coord_to_index(coord))
    end

    # Takes a single index into the {{@type}}, returning a slice of the largest dimension possible.
    # For example, if `a` is a matrix, `a[0]` will be a vector. There is a special case when
    # indexing into a 1D `{{@type}}` - the scalar at the index provided will be wrapped in an
    # `{{@type}}`. This is to preserve type-safety - if you want to extract the scalar as type `T`,
    # invoke `#to_scalar`.
    # TODO: Either make the type restriction here go away (it was getting called when indexing
    # with a single range), or remove this method entirely in favor of read only views
    def [](index : Int32) : self
      index = RegionHelpers.canonicalize_index(index, @shape, axis = 0)

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

    # Copies the elements from a MultiIndexable `src` into `region`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`
    # and the shape of `region` matches the shape of `src`.
    def unsafe_set_region(region : Enumerable, src : MultiIndexable(T))
      narray_each_in_canonical_region(region) do |elem, other_idx, this_idx|
        # @buffer[this_idx] = src.buffer[other_idx]
        # TODO: see if this is the best way! (Want it to be generalizable to MultiIndexable...)
        @buffer[this_idx] = src.unsafe_fetch_element(src.index_to_coord(other_idx))
      end
    end

    # Sets each element in `region` to `value`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`
    def unsafe_set_region(region : Enumerable, value : T)
      narray_each_in_canonical_region(region) do |elem, idx, buffer_idx|
        @buffer[buffer_idx] = value
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

    # def each(&block : T ->)
    #   each_with_index do |elem|
    #     yield elem
    #   end
    # end

    def each_with_index(&block : T, Int32 ->)
      @buffer.each_with_index do |elem, idx|
        yield elem, idx
      end
    end

    # def each_with_coord(&block : T, Array(Int32), Int32 ->)
    #   each_with_index do |elem, idx|
    #     yield elem, index_to_coord(idx), idx
    #   end
    # end

    # def map(&block : T -> U) forall U
    #   map_with_index do |elem|
    #     yield elem
    #   end
    # end

    # def map_with_index(&block : T, Int32 -> U) forall U
    #   buffer = Slice(U).new(@shape.product) do |idx|
    #     yield @buffer[idx], idx
    #   end

    #   NArray(U).new(@shape, buffer)
    # end

    # def map_with_coord(&block : T, Array(Int32), Int32 -> U) forall U
    #   map_with_index do |elem, idx|
    #     yield elem, index_to_coord(idx), idx
    #   end
    # end

    # def map!(&block : T -> U) forall U
    #   map_with_index! do |elem|
    #     yield elem
    #   end
    # end

    # def map_with_index!(&block : T, Int32 -> T) forall T
    #   @buffer.map_with_index! do |elem, idx|
    #     yield elem, idx
    #   end
    #   self
    # end

    # def map_with_coord!(&block : T, Array(Int32), Int32 -> U) forall U
    #   map_with_index! do |elem, idx|
    #     yield elem, index_to_coord(idx), idx
    #   end
    # end

    def each_in_region(region, &block : T, Int32, Int32 ->)
      region = RegionHelpers.canonicalize_region(region, @shape)

      narray_each_in_canonical_region(region, &block)
    end

    # TODO: Document
    def narray_each_in_canonical_region(region, axis = 0, read_index = 0, write_index = [0], &block : T, Int32, Int32 ->)

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
      buffer_step_size = @buffer_step_sizes[axis]
      initial_read_index = read_index

      current_range.each do |idx|
        # navigate to the correct start index
        read_index = initial_read_index + idx * buffer_step_size
        narray_each_in_canonical_region(region, axis + 1, read_index, write_index) do |a, b, c|
          block.call(a, b, c)
        end
      end
    end

    # Given an array of step sizes in each coordinate axis, returns the offset in the buffer
    # that a step of that size represents.
    # The buffer index of a multidimensional coordinate, x, is equal to x dotted with buffer_step_sizes
    def self.buffer_step_sizes(shape)
      ret = shape.clone
      ret[-1] = 1

      ((ret.size - 2)..0).step(-1) do |idx|
        ret[idx] = ret[idx + 1] * shape[idx + 1]
      end

      ret
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

    # Checks that the shape of this and other match in every dimension
    # (except `axis`, if it is specified)
    def compatible?(*others : MultiIndexable, axis = -1) : Bool
      shape.each_with_index do |dim, idx|
        others.each do |narr|
          return false if dim != narr.shape[idx] && idx != axis
        end
      end
      return true
    end

    # Checks that the shape of this and other match in every dimension
    # (except `axis`, if it is specified)
    def self.compatible?(*narrs : MultiIndexable, axis = -1) : Bool
      first = narrs.to_a.pop
      first.compatible?(narrs, axis: axis)
    end
    

    def <<(other : self) : self
      push(other)
    end

    # optimization for pushing other NArrays on axis 0, in-place
    def push(*others : self) : self
      raise DimensionError.new("Cannot concatenate these arrays along axis #{axis}: shapes do not match") if !compatible?(*others, axis: axis)

      concat_size = size + others.sum {|narr| narr.size}
      
      full_ptr = Pointer(T).malloc(concat_size)
      full_ptr.move_from(@buffer.to_unsafe, size)
      ptr = full_ptr + size

      # more in-place - but feels much less thread-safe?
      # full_ptr = @buffer.to_unsafe.realloc(concat_size)
      # @buffer = Slice.new(full_ptr, concat_size)
      # ptr = full_ptr + size

      others.each do |narr|
        ptr.move_from(narr.buffer.to_unsafe, narr.size)
        ptr += narr.size
      end

      @shape[0] += others.sum{|narr| narr.shape[0]}
      @buffer = Slice.new(full_ptr, concat_size)
      self
    end


    def concatenate(*others, axis = 0) : self
      self.new *(narrs[0].concatenate_to_slice(*narrs, axis: axis))
    end

    def concatenate!(*others, axis = 0) : self
      @shape, @buffer = concatenate_to_slice(self, *others, axis: axis)
      self
    end

    def self.concatenate(*narrs : MultiIndexable(T), axis = 0) : NArray(T)
      self.new *(narrs[0].concatenate_to_slice(*narrs, axis: axis))
    end

    # Cycle between the iterators of each narr maybe?
    # OPTIMIZE: this is really dumb right now; double-iterates
    # NOTE: narrs should include self.
    protected def concatenate_to_slice(*narrs, axis = 0) : Tuple(Array(Int32), Slice(T))
      raise DimensionError.new("Cannot concatenate these arrays along axis #{axis}: shapes do not match") if !self.compatible?(*narrs, axis: axis)

      concat_size = narrs.sum {|narr| narr.size}
      concat_shape = @shape.dup
      concat_shape[axis] = narrs.sum { |narr| narr.shape[axis]}

      partial_chunk_size = @buffer_step_sizes[axis]
      chunk_sizes = narrs.map {|narr| narr.shape[axis] * partial_chunk_size }
      num_chunks = concat_shape[...axis].product

      values = Array(T).new(initial_capacity: concat_size)
      iters = narrs.map {|narr| narr.each }

      num_chunks.times do
        iters.each_with_index do |narr_iter, i|
          chunk_sizes[i].times do
            values << narr_iter.next.as(Tuple(T, Array(Int32)))[0]
          end
        end
      end
      {concat_shape, Slice.new(values.to_unsafe, values.size)}
    end

    # TODO: Update documentation. I (seth) rewrote this function to make it validate the shape fully.
    # documentation doesn't currently reflect that
    # Returns the estimated dimension of a multidimensional array that is provided as a nested array literal.
    # Used internally to determine the buffer size for several constructors. Note that this method
    # does not guarantee that the size reported is accurate.
    # For example, `{{@type}}.recursive_probe_array([[1], [1, 2]])` will return `[2, 1]`. The `2` comes
    # from the fact that the top-level array contains 2 elements, and the `1` comes from the size of
    # the sub-array `[1]`. However, we can clearly see that the size isn't uniform - the second
    # sub-array is `[1, 2]`, which is two elements, not one!
    protected def self.measure_nested_array(nested_array current, depth = 0, max_depth = StaticArray[0i32], shape = [] of Int32) : Array(Int32)
      # There are three main goals here:
      # 1. Measure the array shape
      # 2. Ensure that the number of elements in each dimension is consistent
      # 3. Ensure that the depth is identical regardless of path
      #
      # [[1, 2], [1, 2, 3]] would violate goal 2 (right depth, wrong number of elements)
      # [[1, 2, 3], [[1], [1], [1]]] would violate goal 3 (right number of elements, wrong depth)

      if current.is_a? Array
        # If this is the first time we've gotten this deep
        if depth == shape.size
          if current.size == 0
            raise DimensionError.new("Could not profile nested array: Found an array with size zero.")
          end

          shape << current.size
        end

        current.each do |sub_element|
          # TODO: Possible optimization here
          # It's computationally wasteful to iterate over scalars when you're
          # just above max depth, but it's also possible that the scalars have type
          # Whatever | Array, in which case we want to iterate. E.g
          # [[1, [2, 3]]] - this should crash, but hard to detect without iterating
          measure_nested_array(sub_element, depth + 1, max_depth, shape)
        end
      else
        # This will only be -1 if the depth had not yet been determined
        if max_depth[0] = -1
          max_depth[0] = depth
        else
          # Ensure the depth recorded last time is consistent
          # Using max_depth rather than shape.size is important.
          # [0, [0], [[0]]] would always satisfy shape.size == depth,
          # but is clearly inconsistent.
          if max_depth[0] != depth
            raise DimensionError.new("Could not profile nested array: Array depth was inconsistent.")
          end
        end
      end

      shape
    end


    # TODO: compare this iterator, generic MultiIndexable iterator, and old direct each
    class BufferedLexRegionIterator(A,T) < RegionIterator(A,T)

      @buffer_index : Int32
      @buffer_step : Array(Int32)

      def initialize(@narr : A, region = nil, reverse = false)
        super
        @buffer_step = @narr.buffer_step_sizes
        @buffer_index = @buffer_step.map_with_index {|e, i| e * @first[i]}.sum
        @buffer_index = setup_buffer_index(@buffer_index, @buffer_step, @step)
      end

      def setup_coord(coord, step)
        coord[-1] -= step[-1]
      end

      def setup_buffer_index(buffer_index, buffer_step, step)
        buffer_index -= buffer_step[-1] * step[-1]
        buffer_index
      end

      def next
        (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @buffer_index -= (@coord[i] - @first[i]) * @buffer_step[i]
            @coord[i] = @first[i]
            return stop if i == 0 # most sig
          else
            @coord[i] += @step[i]
            @buffer_index += @buffer_step[i] * @step[i]
            break
          end
        end
        {@narr.buffer.unsafe_fetch(@buffer_index), @coord}
      end
    end


    class BufferedColexRegionIterator(A,T) < BufferedLexRegionIterator(A,T)

      def setup_coord(coord, step)
        coord[0] -= step[0]
      end

      def setup_buffer_index(buffer_index, buffer_step, step)
        buffer_index -= buffer_step[0] * step[0]
        buffer_index
      end

      def next
        0.upto(@coord.size - 1) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @buffer_index -= (@coord[i] - @first[i]) * @buffer_step[i]
            @coord[i] = @first[i]
            return stop if i == @coord.size - 1 # most sig
          else
            @coord[i] += @step[i]
            @buffer_index += @buffer_step[i] * @step[i]
            break
          end
        end
        {@narr.buffer.unsafe_fetch(@buffer_index), @coord}
      end

    end
  end
end
