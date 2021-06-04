require "./region_helpers"
require "./order"
require "./iterators/*"

module Lattice
  # Assumptions:
  # - length along every axis is finite and positive, and each element is positively indexed
  # - size is stored as an Int32, i.e. there are no more than Int32::MAX elements.
  module MultiIndexable(T)
    # add search, traversal methods
    include Enumerable(T)

    # Please consider overriding:
    # -fast: for performance
    # -transform functions: reshape, permute, reverse; for performance

    # Returns the number of elements in the `{{type}}`; equal to `shape.product`.
    abstract def size

    # Returns the length of the `{{type}}` in each dimension.
    # For a `coord` to specify an element of the `{{type}}` it must satisfy `coord[i] < shape[i]` for each `i`.
    abstract def shape : Array(Int32)

    # Copies the elements in `region` to a new `{{type}}`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    abstract def unsafe_fetch_region(region)

    # Retrieves the element specified by `coord`, assuming that `coord` is in canonical form and in-bounds for this `{{type}}`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    abstract def unsafe_fetch_element(coord) : T

    # Stuff that we can implement without knowledge of internals

    protected def shape_internal : Array(Int32)
      # NOTE: Some implementations might not have a well defined @shape, but
      # instead generate it with a function. We leave shape_internal to be
      # overridden with @shape for a small performance boost if the implementer
      # offers that.
      shape
    end

    # Checks that the `{{type}}` contains no elements.
    def empty? : Bool
      size == 0
    end

    # Checks that this `{{type}}` is one-dimensional, and contains a single element.
    def scalar? : Bool
      shape_internal.size == 1 && size == 1
    end

    # Maps a single-element 1D `{{type}}` to the element it contains.
    def to_scalar : T
      if scalar?
        return first
      else
        if shape_internal.size != 1
          raise DimensionError.new("Cannot cast to scalar: {{type}} must have 1 dimension, but has #{dimensions}.")
        else
          raise DimensionError.new("Cannot cast to scalar: {{type}} must have 1 element, but has #{size}.")
        end
      end
    end

    # Returns the element at position `0` along every axis.
    def first : T
      # TODO: what happens when empty?
      return get_element([0] * shape_internal.size)
    end

    # Returns a random element from the `{{type}}`. Note that this might not return
    # distinct elements if the random number generator returns the same coordinate twice.
    def sample(n, random = Random::DEFAULT)
      raise ArgumentError.new("Can't sample negative number of elements") if n < 0

      Array(T).new(n) { sample(random) }
    end

    # Returns a random element from the `{{type}}`.
    def sample(random = Random::DEFAULT)
      raise IndexError.new("Can't sample empty collection") if empty?
      unsafe_fetch_element(shape_internal.map { |dim| random.rand(dim) })
    end

    # Returns the number of indices required to specify an element in `{{type}}`.
    def dimensions : Int32
      shape_internal.size
    end

    # Checks that `coord` is in-bounds for this `{{type}}`.
    def has_coord?(coord : Enumerable) : Bool
      RegionHelpers.has_coord?(coord, shape_internal)
    end

    # Checks that `region` is in-bounds for this `{{type}}`.
    def has_region?(region : Enumerable) : Bool
      RegionHelpers.has_region?(region, shape_internal)
    end

    # Copies the elements in `region` to a new `{{type}}`, and throws an error if `region` is out-of-bounds for this `{{type}}`.
    def get_region(region : Enumerable)
      unsafe_fetch_region RegionHelpers.canonicalize_region(region, shape_internal)
    end

    # Retrieves the element specified by `coord`, and throws an error if `coord` is out-of-bounds for this `{{type}}`.
    def get_element(coord : Enumerable) : T
      unsafe_fetch_element RegionHelpers.canonicalize_coord(coord, shape_internal)
    end

    def get(coord) : T
      get_element(coord)
    end

    def get_region(coord : Enumerable, region_shape : Enumerable)
      get_region(RegionHelpers.translate_shape(region_shape, coord))
    end

    def get_available(region : Enumerable)
      get_region(RegionHelpers.trim_region(region, shape))
    end

    def [](region : Range)
      get_region([region])
    end

    # Copies the elements in `region` to a new `{{type}}`, and throws an error if `region` is out-of-bounds for this `{{type}}`.
    def [](region : Enumerable)
      get_region(region)
    end

    # Tuple-accepting overload of `#{{name}}`.
    # NOTE: cannot be (easily) generated in the macro since it requires syntax `[tuple]` rather than `[](tuple)`
    def [](*region)
      get_region(region)
    end

    {% begin %}
      {% enumerable_functions = %w(get get_element get_region has_coord? has_region?) %}
      {% for name in enumerable_functions %}
          # Tuple-accepting overload of `#{{name}}`.
          def {{name.id}}(*tuple)
            {{name.id}}(tuple)
          end
      {% end %}
    {% end %}

    # Iterators ====================================================================
    def each_coord : CoordIterator
      LexIterator.of(shape)
    end

    def each(iter = LexIterator)
      ElemIterator.of(self, iter: iter)
    end

    def each_with_coord(iter = LexIterator)
      RegionIterator.of(self, iter: iter)
    end

    # A method to get all elements in this `{{@type}}` when order is irrelevant.
    # Recommended that implementers override this method to take advantage of
    # the storage scheme the implementation uses
    def fast : Iterator(T)
      ElemIterator.new(self)
    end

    # # TODO: Each methods should exist that allow:
    # # - Some way to handle slice iteration? (how do we pass in the axis? etc)

    def each_slice
      chunk_shape = shape
    end

    def slices(axis = 0)
      each_slice.to_a
    end

    {% for name in %w(each each_coord each_with_coord each_slice fast) %}
      def {{name.id}}(&block)
        {{name.id}}.each {|arg| yield arg}
      end
    {% end %}

    {% for transform in %w(reshape permute reverse) %}
      def {{transform.id}}(*args)
        view.{{transform.id}}(*args).to_narr
      end
    {% end %}

    def to_narr : NArray(T)
      NArray.build(@shape.dup) do |coord, idx|
        unsafe_fetch_element(coord)
      end
    end

    def equals?(other : MultiIndexable) : Bool
      equals?(other) do |this_elem, other_elem|
        this_elem == other_elem
      end
    end

    def equals?(other : MultiIndexable, &block) : Bool
      return false if shape_internal != other.shape_internal
      each_with_coord do |elem, coord|
        return false unless yield(elem, other.unsafe_fetch_element(coord))
      end
      return true
    end

    def view(region : Enumerable? = nil)
      # TODO: Try to infer T from B?
      View.of(self, region)
    end

    def view(*region)
      view(region)
    end

    def process(&block : (T -> R)) forall R
      process(block)
    end

    def process(proc)
      ProcView.of(self, proc)
    end

    # TODO: rename!
    # Produces an NArray(Bool) (by default) describing which elements of self and other are equal.
    def eq_elem(other : MultiIndexable(U)) : MultiIndexable(Bool) forall U
      if shape_internal != other.shape_internal
        raise DimensionError.new("Cannot perform elementwise operation {{name.id}}: shapes #{other.shape_internal} of other and #{shape_internal} of self do not match")
      end
      map_with_coord do |elem, coord|
        elem == other.unsafe_fetch_element(coord)
      end
    end

    {% begin %}
      # Implements most binary operations
      {% for name in %w(+ - * / // > < >= <= &+ &- &- ** &** % & | ^ <=>) %}

        # Invokes `#{{name.id}}` element-wise between `self` and *other*, returning
        # an `NArray` that contains the results.
        def {{name.id}}(other : MultiIndexable(U)) forall U
          if shape_internal != other.shape_internal
            raise DimensionError.new("Cannot perform elementwise operation {{name.id}}: shapes #{other.shape_internal} of other and #{shape_internal} of self do not match") 
          end
          map_with_coord do |elem, coord|
            elem.{{name.id}} other.unsafe_fetch_element(coord).as(U)
          end
        end

        # Invokes `#{{name.id}}(other)` on each element in `self`, returning an
        # `NArray` that contains the results.
        def {{name.id}}(other)
          map &.{{name.id}} other
        end
      {% end %} 

      {% for name in %w(- + ~) %}
        def {{name.id}}
          map &.{{name.id}}
        end
      {% end %}
    {% end %}
  end
end
