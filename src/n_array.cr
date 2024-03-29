require "json"
require "yaml"

# alias IndexType = Int32
# alias Shape = Array(IndexType)

module Phase
  # `NArray` is Phase's general-use n-dimensional array implementation. It stores
  # its values in a memory buffer, allowing efficient reading, writing, and in-place manipulations
  # of data. Most of the functionality of `NArray` is provided by `MultiIndexable` and `MultiWritable`,
  # which are the most general container types in Phase (although NArray overloads many of these
  # functions for performance).
  #
  # TLDR: `NArray` is to Phase as `Array` is to Crystal.
  class NArray(T)
    include MultiIndexable::Mutable(T)
    include Buffered(T)

    # Stores the elements of an `NArray` in lexicographic (row-major) order.
    getter buffer : Slice(T)

    # Contains the number of elements in each axis of the `NArray`.
    # More explicitly, axis `k` has valid ordinates `0...@shape[k]`
    @shape : Array(Int32)

    # Cached version of `.axis_strides`.
    protected getter axis_strides : Array(Int32)

    # Raises a `ShapeError` if the provided *shape* has a computed element count which differs from the *buffer* size.
    protected def self.ensure_valid!(shape : Array(Int32), buffer : Slice)
      if ShapeUtil.shape_to_size(shape) != buffer.size
        raise ShapeError.new("Cannot create NArray: Given shape does not match number of elements in buffer.")
      end
    end

    # Creates an `NArray` using only a shape (see `shape`) and a lexicographic buffer index.
    # This is used internally to make code faster - converting from an index to
    # a coordinate isn't needed for many constructors, and generating them
    # would waste resources.
    # For more information, see `coord_to_index`, `buffer`, and `build`.
    #
    # ```crystal
    # new([2, 3]) { |idx| idx } # => NArray[[0, 1, 2], [3, 4, 5]]
    # new([] of Int32) { |idx| idx } # => NArray[]
    # new([-1]) { |idx| idx } # => DimensionError
    # ```
    protected def initialize(shape : Enumerable, &block : Int32 -> T)
      @shape = shape.map do |dim|
        if dim < 0
          raise DimensionError.new("Cannot create NArray: One or more of the provided dimensions was negative.")
        end
        dim
      end.to_a

      num_elements = ShapeUtil.shape_to_size(shape).to_i32
      @axis_strides = Buffered.axis_strides(@shape)

      @buffer = Slice(T).new(num_elements) { |i| yield i }
    end

    # Creates an `NArray` out of a shape and a pre-populated buffer.
    # This method does not do any validation on the data provided to it,
    # so ensure that *shape* and *buffer* are compatible.
    protected def initialize(shape : Array(Int32), @buffer : Slice(T))
      @shape = shape.dup
      @axis_strides = Buffered.axis_strides(@shape)
    end

    # Creates an `NArray` out of a shape and a pre-populated lexicographic (row-major) buffer.
    # This constructor will raise a `ShapeError` if the shape and buffer
    # have incompatible sizes (see `ShapeUtil#shape_to_size`).
    # ```crystal
    # NArray.of_buffer([3, 1], Slice['a', 'b', 'c']) # => NArray[['a'], ['b'], ['c']]
    # NArray.of_buffer([3, 1], Slice['a']) # => ShapeError
    # ```
    def self.of_buffer(shape : Array(Int32), buffer : Slice(T))
      NArray.ensure_valid!(shape, buffer)
      new(shape.dup, buffer)
    end

    # Constructs an `NArray` using a user-provided *shape* (see `shape`) and a callback.
    # The provided callback should map a multidimensional index, *coord*, (and an optional packed
    # index) to the value you wish to store at that position.
    # For example, to create the 2x2 identity matrix:
    # ```
    # Phase::NArray.build([2, 2]) do |coord|
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
    # NArray.build([3, 2]) { |coord, index| index }
    # ```
    # Will create:
    # ```text
    # [[0, 1],
    #  [2, 3],
    #  [4, 5]]
    # ```
    def self.build(shape : Enumerable, &block : ReadonlyWrapper(Array(Int32), Int32), Int32 -> T)
      coord_iter = Indexed::LexIterator.cover(shape.to_a)
      NArray(T).new(shape) do
        yield *(coord_iter.unsafe_next_with_index)
      end
    end

    # Tuple-accepting variant of `NArray.build(shape : Enumerable, &block).
    # ```crystal
    # NArray.build(3, 2) { |coord, index| index } # => NArray[[0, 1], [2, 3], [4, 5]]
    # ```
    def self.build(*shape : Int, &block : ReadonlyWrapper(Array(Int32), Int32), Int32 -> T)
      build(shape, &block)
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
    def self.new(data : Enumerable)
      nested_array = data.to_a
      shape = measure_nested_array(nested_array)
      flattened = nested_array.flatten

      # fill elements
      buffer = Slice.new(flattened.to_unsafe, flattened.size)

      NArray.ensure_valid!(shape, buffer)
      new(shape, buffer)
    end

    # NArray[1, 2, 3] == NArray.new([1, 2, 3])
    # NArray[[1, 2, 3]] == NArray.new([[1, 2, 3]])
    # Convenience constructor for typing out an `NArray` as a literal.
    #
    # For example:
    # ```crystal
    # NArray[1, 2, 3] == NArray.new([1, 2, 3])
    # NArray[1, 2, 3].shape # => [3]
    # 
    # NArray[[1, 2, 3]] == NArray.new([[1, 2, 3]])
    # NArray[[1, 2, 3]].shape # => [1, 3]
    #
    # NArray[['a', 'b'], ['c', 'd']].shape # => [2, 2]
    # ```
    def self.[](*contents)
      new(contents)
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
    #
    # Note that this method makes no effort to duplicate *value*, so this
    # should only be used for `Value`s. If you want to populate an NArray with
    # `Reference`s, see `new(shape, &block)`.
    # For an example of this:
    # ```crystal
    # class ImAReference
    # 	getter foo = 0
    # 
    # 	def mutate!
    # 		@foo += 1
    # 	end
    # 
    # 	def inspect(io : IO)
    # 		io << "Foo #{@foo}"
    # 	end
    # end
    # 
    # # This is probably not what you want!
    # # Fill won't duplicate the `ImAReference` object:
    # narr = NArray.fill([2], ImAReference.new)
    # puts narr # => NArray[Foo 0, Foo 0]
    # narr.get(0).mutate!
    # # So mutating one element will mutate both!
    # puts narr # => NArray[Foo 1, Foo 1]
    # 
    # # You probably wanted to do this:
    # # Using the block in NArray.build ensures that each element is distinct
    # narr = NArray.build([2]) { ImAReference.new }
    # puts narr # => NArray[Foo 0, Foo 0]
    # narr.get(0).mutate!
    # # Now, things behave as expected
    # puts narr # => NArray[Foo 1, Foo 0]
    # ```
    def self.fill(shape, value : T)
      NArray(T).new(shape) { value }
    end

    # Repeats a *source* `MultiIndexable` along its axes, *counts[i]* times along axis *i*.
    #
    # For example:
    # ```crystal
    # src = NArray[[1, 2], [3, 4]]
    # NArray.tile(src, [2, 1])
    # # => NArray[[1, 2, 1, 2],
    # #           [3, 4, 3, 4]]
    # ```
    def self.tile(source : MultiIndexable(T), counts : Enumerable)
      shape = source.shape.map_with_index { |axis, idx| axis * counts[idx] }

      iter = TilingLexIterator.new(IndexRegion.cover(shape), source.shape).each

      build(shape) do
        iter.next
        source.get(iter.smaller_coord)
      end
    end

    # shorthand
    # pad(0, {0, 3, 5}, {1, 0, 6}, "hi")
    # def pad(value, *amounts : Tuple(Int32, Int32, Int32) | String)

    # core
    # pad(0, {0 => {2, 2}, 1 => {3, 4}, -1 => {0, 5}})
    def pad(value, amounts : Hash(Int32, Tuple(Int32, Int32)))
      # figure out the resulting shape and alignment
      # pad(0, {0 => {2, 2}, 1 => {3, 4}, -1 => {0, 5}})
      # [5, 5, 5] -> [4 + 5, 7 + 5, 5 + 5]
      # amounts.transform_values { |value| value[0] }
      fit()
    end

    # This version requires you are only <= on each axis; cannot pad
    def fit(new_shape, *, align : Hash(Int32, NArray::Alignment | Int32))
      # If the new shape is larger (at all), you need to have provided a pad_with value
      @shape.each_with_index do |size, idx|
        if size > new_shape[idx]
        end
      end

      # move this to where applicable
      raise "Can't fit array: provided shape is larger that shape of self. Provide a `pad_with` argument if padding is desired."

      # if only shrinking: value is not needed, can just take a region
      # compute region based on align
      return self.unsafe_fetch_chunk(region)
    end

    # fit([1, 2, 3], align: {1 => 5}, pad_with: nil)

    def fit(new_shape, *, align : Hash(Int32, NArray::Alignment | Int32)? = nil, pad_with value = nil)
      if new_shape.size != @shape.size
        raise "Cannot fit a #{@shape.size} dimensional NArray into a #{new_shape.size} dimensional shape. Consider calling `reshape` if you wish to change dimensionality."
      end
      # otherwise:
    end

    def pad!
    end

    def fit!
      # implement for real
    end

    # def fit
    #   clone_but_cast_to().fit!
    # end

    # protected fit_buffer()
    # end

    # def self.fit(narr : NArray(T), ..., value : U) : NArray(T | U) forall U

    # Requires that shape is equal to coord + self.shape in each dimension
    protected def unsafe_pad(new_shape, value, coord)
      padded = NArray.fill(new_shape, value.as(T))
      padded.unsafe_set_chunk(IndexRegion.cover(@shape).translate!(coord), self)
      padded
    end


    # Adds a dimension at highest level, where each "row" is an input NArray.
    # If pad is false, then throw error if shapes of objects do not match;
    # otherwise, pad subarrays along each axis to match whichever is largest in that axis
    # TODO: Fix
    def self.wrap(*objects : AbstractNArray(T), pad = false) : NArray
      shapes = objects.to_a.map { |x| x.shape }
      if pad
        container = common_container(*objects)
        # TODO pad all arrays to this size
        raise NotImplementedError.new("As of this time, NArray.wrap() cannot pad arrays for you.")
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

    # creates an NArray-type vector from a tuple of scalars.
    def self.wrap(*objects)
      NArray.new(objects.to_a)
    end

    protected def shape_internal : Array(Int32)
      @shape
    end

    # :ditto:
    def size : Int32
      @buffer.size
    end

    # Creates a deep copy of this NArray.
    # More specifically, this allocates a new buffer of the same shape, and
    # calls #clone on every item in the buffer. Then, a new `NArray` is constructed
    # with that copied buffer.
    # ```crystal
    # elem = Set{'a'}
    # narr = NArray[elem]
    # 
    # # Calling clone will clone the element, too:
    # copy = narr.clone
    # narr.get(0) << 'b'
    # 
    # # So the data inside the narr and the copy are distinct
    # puts narr # => NArray[Set{'a', 'b'}]
    # puts copy # => NArray[Set{'a'}]
    # ```
    def clone : self
      NArray.new(@shape, @buffer.clone)
    end

    # Creates a shallow copy of this NArray.
    # More specifically, this allocates a new buffer of the same shape, and
    # calls #dup on every item in the buffer. Then, a new `NArray` is constructed
    # with that copied buffer.
    #
    # ```crystal
    # elem = Set{'a'}
    # narr = NArray[elem]
    # 
    # # Calling clone will dup the element, too:
    # copy = narr.dup
    # narr.get(0) << 'b'
    # 
    # # So the data inside the narr and the copy aren't distinct:
    # puts narr # => NArray[Set{'a', 'b'}]
    # puts copy # => NArray[Set{'a', 'b'}]
    # ```
    def dup : self
      NArray.new(@shape, @buffer.dup)
    end

    # TODO any way to avoid copying these out yet, too? Iterator magic?
    # def slices(axis = 0) : Array(self)
    #   region = [] of (Int32 | Range(Int32, Int32))
    #   (0...axis).each do |dim|
    #     region << Range.new(0, @shape[dim] - 1)
    #   end
    #   region << 0

    #   # Version 1: Theoretically faster, as index calculations occur only once
    #   mapping = [] of Int32
    #   each_in_region(region) do |elem, _, buffer_idx|
    #     mapping << buffer_idx
    #   end
    #   shape = RegionUtil.measure_region(region, @shape)
    #   step = @axis_strides[axis]

    #   (0...@shape[axis]).map do |slice_number|
    #     offset = step * slice_number
    #     NArray.new(shape) { |i| mapping[i] + offset }
    #   end
    # end

    # Converts a potentially multidimensional array into a flat, 1-dimensional NArray.
    # The elements will be raveled into lexicographic order inside of the new array.
    # For example:
    # ```crystal
    # ```
    def flatten : self
      reshape(@buffer.size)
    end

    # TODO: reshape should return a clone by default
    def reshape(new_shape : Enumerable)
      shape_arr = new_shape.to_a
      NArray.ensure_valid!(shape_arr, @buffer)
      NArray.new(shape_arr, @buffer)
    end

    def reshape(*new_shape)
      reshape(new_shape)
    end

    # Checks for elementwise equality between `self` and *other*.
    def ==(other : NArray) : Bool
      equals?(other) { |x, y| x == y }
    end

    # :nodoc:
    def ==(other : MultiIndexable) : Bool
      false
    end

    # :ditto:
    def unsafe_fetch_chunk(region : IndexRegion)
      iter = Indexed::ElemAndCoordIterator.new(self, Indexed::LexIterator.new(region, @shape))
      typeof(self).new(region.shape) { iter.unsafe_next[0] }
    end

    # :ditto:
    def unsafe_fetch_element(coord) : T
      @buffer.unsafe_fetch(Buffered.coord_to_index_fast(coord, @shape, @axis_strides))
    end

    # Takes a single index into the NArray, returning a slice of the largest dimension possible.
    # For example, if `a` is a matrix, `a[0]` will be a vector. There is a special case when
    # indexing into a 1D `NArray` - the scalar at the index provided will be wrapped in an
    # `NArray`. This is to preserve type-safety - if you want to extract the scalar as type `T`,
    # invoke `#to_scalar`.
    # TODO: Either make the type restriction here go away (it was getting called when indexing
    # with a single range), or remove this method entirely in favor of read only views
    # TODO: benchmark against normal implementation
    # def [](index : Int) : self
    #   index = CoordUtil.canonicalize_index(index, @shape, axis = 0)

    #   if dimensions == 1
    #     new_shape = [1]
    #   else
    #     new_shape = @shape[1..]
    #   end
    #   # The "step size" of the top level dimension (row) is the product of the lower dimensions.
    #   step = new_shape.product

    #   new_buffer = @buffer[index * step, step]
    #   typeof(self).new(new_shape, new_buffer.clone)
    # end

    # :ditto:
    def unsafe_set_chunk(region : IndexRegion, src : MultiIndexable(T))
      absolute_iter = Indexed::LexIterator.new(region, @shape)
      src_iter = src.each

      src_iter.each do |src_el|
        absolute_iter.next
        @buffer[absolute_iter.current_index] = src_el
      end
    end

    # :ditto:
    def unsafe_set_chunk(region : IndexRegion, value : T)
      iter = Indexed::LexIterator.new(region, @shape)
      iter.each do
        @buffer[iter.current_index] = value
      end
    end

    # :ditto:
    def unsafe_set_element(coord : Enumerable, value : T)
      @buffer[Buffered.coord_to_index_fast(coord, @shape, @axis_strides)] = value
    end

    # :nodoc:
    # This is a faster implementation of #[]= for the case where
    # the mask is an NArray.
    def []=(mask : NArray(Bool), value : T)
      if mask.shape != @shape
        raise DimensionError.new("Cannot perform masking: mask shape does not match array shape.")
      end

      mask.buffer.each_with_index do |should_copy, idx|
        if should_copy
          @buffer[idx] = value
        end
      end
    end

    # :nodoc:
    # Overloaded for performance on NArrays by using the buffer directly
    def []=(mask : MultiIndexable(Bool), value : MultiIndexable(T))
      if mask.shape != @shape
        raise DimensionError.new("Cannot perform masking: mask shape does not match array shape.")
      end

      iter = Indexed::LexIterator.cover(@shape)
      iter.each do |coord|
        if mask.get(coord)
          @buffer[iter.current_index] = value.get(coord)
        end
      end
    end

    # :nodoc:
    # Overloaded for performance on NArrays by using the buffer directly
    def []=(mask : MultiIndexable(Bool), value : T)
      # Overloaded for performance
      if mask.shape != @shape
        raise DimensionError.new("Cannot perform masking: mask shape does not match array shape.")
      end

      iter = Indexed::LexIterator.cover(@shape)
      iter.each do |coord|
        if mask.get(coord)
          @buffer[iter.current_index] = value
        end
      end
    end

    # Iterator overrides for buffer-based speedups

    # :inherit:
    def each
      @buffer.each
    end

    # See `MultiIndexable#fast_each`.
    # For an `NArray`, the iteration order of `#each` is already as fast as possible.
    def fast_each
      @buffer.each
    end

    # :inherit:
    def each_coord
      Indexed::LexIterator.cover(shape_internal)
    end

    # Iterates over elements in lexicographic order, providing their lexicographic buffer index.
    # ```crystal
    # NArray[['a', 'b'],
    #        ['c', 'd']].each_with_index do |el, idx|
    #   puts "#{el} at #{idx}"
    # end
    # # => 'a' at 0
    # # => 'b' at 1
    # # => 'c' at 2
    # # => 'd' at 3
    # ```
    def each_with_index(&block : T, Int32 ->)
      @buffer.each_with_index do |elem, idx|
        yield elem, idx
      end
    end

    # :inherit:
    def map(&block : T -> U) forall U
      new_buffer = @buffer.map do |elem|
        yield elem
      end

      NArray.new(@shape.clone, new_buffer)
    end

    # Creates a new `NArray` by mapping elements by their lexicographic buffer index and value.
    # ```crystal
    # narr = NArray["a", "b", "c"]
    # narr.map_with_index { |el, idx| el * idx} # => NArray["", "b", "cc"]
    #
    # # Note that the source is not changed:
    # narr # => NArray["a", "b", "c"]
    # ```
    def map_with_index(&block : T, Int32 -> U) : NArray(U) forall U
      new_buffer = @buffer.map_with_index do |elem, idx|
        yield elem, idx
      end

      NArray.new(@shape.clone, new_buffer)
    end

    # :inherit:
    def map_with_coord(&block : T, ReadonlyWrapper(Array(Int32), Int32) -> U) forall U
      NArray(U).build(@shape) do |coord, idx|
        yield @buffer[idx], coord, idx
      end
    end

    # In-place version of `#map`.
    # The element type of this NArray cannot be changed via this method.
    def map!(&block : T -> T) : self
      map_with_index! do |elem|
        yield elem
      end

      self
    end

    # In-place version of `#map_with_index`.
    # The element type of this NArray cannot be changed via this method.
    def map_with_index!(&block : T, Int32 -> T) : self
      @buffer.map_with_index! do |elem, idx|
        yield elem, idx
      end

      self
    end

    # In-place version of `#map_with_coord`.
    # The element type of this NArray cannot be changed via this method.
    def map_with_coord!(&block : T, ReadonlyWrapper(Array(Int32), Int32) -> U) forall U
      iter = LexIterator.cover(shape_internal)

      @buffer.map_with_index! do |el, idx|
        yield el, iter.unsafe_next, idx
      end

      self
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

    # Checks that the shape of this and other match in every dimension
    # (except `axis`, if it is specified)
    def compatible?(*others : MultiIndexable, axis = -1) : Bool
      shape.each_with_index do |dim, idx|
        others.each do |narr|
          return false if dim != narr.shape[idx] && idx != axis
        end
      end
      true
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
    # TODO: axis = 0 should not be a user modifiable parameter and never should have been
    def push(*others : self, axis = 0) : self
      raise DimensionError.new("Cannot concatenate these arrays along axis #{axis}: shapes do not match") if !compatible?(*others, axis: axis)

      concat_size = size + others.sum &.size

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

      @shape[0] += others.sum { |narr| narr.shape[0] }
      @buffer = Slice.new(full_ptr, concat_size)
      self
    end

    def concatenate(*others, axis = 0) : self
      NArray.new *(NArray(T).concatenate_to_slice(self, *others, axis: axis))
    end

    def concatenate!(*others, axis = 0) : self
      @shape, @buffer = NArray(T).concatenate_to_slice(self, *others, axis: axis)
      @axis_strides = Buffered.axis_strides(@shape)
      self
    end

    def self.concatenate(*narrs : MultiIndexable(T), axis = 0) : NArray(T)
      self.new *(self.concatenate_to_slice(*narrs, axis: axis))
    end

    # Cycle between the iterators of each narr maybe?
    # NOTE: narrs should include self.
    protected def self.concatenate_to_slice(*narrs : MultiIndexable(T), axis = 0) : Tuple(Array(Int32), Slice(T)) forall T
      raise DimensionError.new("Cannot concatenate these arrays along axis #{axis}: shapes do not match") if !narrs[0].compatible?(*narrs, axis: axis)

      concat_size = narrs.sum &.size
      concat_shape = narrs[0].shape
      concat_shape[axis] = narrs.sum { |narr| narr.shape[axis] }

      partial_chunk_size = narrs[0].axis_strides[axis]
      chunk_sizes = narrs.map { |narr| narr.shape[axis] * partial_chunk_size }
      num_chunks = ShapeUtil.shape_to_size(concat_shape[...axis])

      values = Array(T).new(initial_capacity: concat_size)
      iters = narrs.map { |narr| BufferedECIterator.of(narr) }

      num_chunks.times do
        iters.each_with_index do |narr_iter, i|
          chunk_sizes[i].times do
            values << narr_iter.unsafe_next_value
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
    # For example, `NArray.recursive_probe_array([[1], [1, 2]])` will return `[2, 1]`. The `2` comes
    # from the fact that the top-level array contains 2 elements, and the `1` comes from the size of
    # the sub-array `[1]`. However, we can clearly see that the size isn't uniform - the second
    # sub-array is `[1, 2]`, which is two elements, not one!
    protected def self.measure_nested_array(nested_array current, depth = 0, max_depth = Slice[-1i32], shape = [] of Int32) : Array(Int32)
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
          shape << current.size
        else
          if shape[depth] != current.size
            # We've been at this before, but the shape was different then.
            raise ShapeError.new("Could not profile nested array: Array shape was inconsistent.")
          end
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
        if max_depth[0] == -1
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

    def to_json(json : JSON::Builder)
      json.object do
        json.scalar("shape")
        @shape.to_json(json)

        json.scalar("elements")
        json.array do
          @buffer.each &.to_json(json)
        end
      end
    end

    def self.new(pull : JSON::PullParser)
      shape = [] of Int32
      elements = [] of T

      found_shape = false
      found_elements = false

      pull.read_object do |key, key_loc|
        case key
        when "shape"
          found_shape = true
          pull.read_array do
            shape << pull.read?(Int32).not_nil!
          end
        when "elements"
          found_elements = true
          pull.read_array do
            elements << T.new(pull)
          end
        end
      end

      if found_shape && found_elements
        if ShapeUtil.shape_to_size(shape) == elements.size
          buffer = Slice.new(elements.to_unsafe, elements.size)
          return new(shape, buffer)
        else
          raise JSON::Error.new("Could not read NArray from JSON: wrong number of elements for shape #{shape}")
        end
      else
        raise JSON::Error.new("Could not read NArray from JSON: 'shape' and/or 'elements' were missing.")
      end
    end

    def to_yaml(yaml : YAML::Nodes::Builder)
      yaml.mapping do
        yaml.scalar("shape")
        yaml.sequence(style: YAML::SequenceStyle::FLOW) do
          @shape.each &.to_yaml(yaml)
        end

        yaml.scalar("elements")
        style = T < Number::Primitive ? YAML::SequenceStyle::FLOW : YAML::SequenceStyle::BLOCK
        yaml.sequence(style: style) do
          @buffer.each &.to_yaml(yaml)
        end
      end
    end

    def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      if node.is_a?(YAML::Nodes::Mapping)
        ctx.read_alias(node, self) do |obj|
          return obj
        end

        shape = nil
        elements = nil

        node.nodes.each_with_index.step(2).each do |child, idx|
          if child.is_a?(YAML::Nodes::Scalar)
            case child.value
            when "shape"
              shape = Array(Int32).new(ctx, node.nodes[idx + 1])
            when "elements"
              elements_node = node.nodes[idx + 1]
              if elements_node.is_a? YAML::Nodes::Sequence
                {% begin %}
                elements = Array({{ @type.type_vars[0] }}).new(ctx, elements_node)
                {% end %}
              else
                raise YAML::Error.new("Could not read NArray from YAML: Expected sequence, found #{elements_node.class}")
              end
            end
          else
            raise YAML::Error.new("Could not read NArray from YAML: Did not expect nested elements")
          end
        end

        unless shape.nil? || elements.nil?
          if elements.size == ShapeUtil.shape_to_size(shape)
            elements = Slice.new(elements.to_unsafe, elements.size)
            ret = new(shape, elements)
            ctx.record_anchor(node, ret)
            return ret
          else
            raise YAML::Error.new("Could not read NArray from YAML: wrong number of elements for shape #{shape}")
          end
        end

        raise YAML::Error.new("Could not read NArray from YAML: 'shape' and/or 'elements' were missing.")
      else
        raise YAML::Error.new("Could not read NArray from YAML: Expected mapping, found #{node.class}")
      end
    end
  end
end
