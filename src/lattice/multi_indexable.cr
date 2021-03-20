require "./region_helpers.cr"
require "../iterators/region_iterators.cr"
require "./order.cr"

module Lattice
  module MultiIndexable(T)
    include MultiEnumerable(T)

    # For performance gains, we recommend the user to consider overriding the following methods when including MultiIndexable(T):
    # - #each_fastest
    # - more list

    # Returns the number of elements in the `{{type}}`; equal to `shape.product`.
    # abstract def size : Int32

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

    # Checks that the `{{type}}` contains no elements.
    def empty? : Bool
      size == 0
    end

    # Checks that this `{{type}}` is one-dimensional, and contains a single element.
    def scalar? : Bool
      shape.size == 1 && size == 1
    end

    # Maps a single-element 1D `{{type}}` to the element it contains.
    def to_scalar : T
      if scalar?
        return first
      else
        if shape.size != 1
          raise DimensionError.new("Cannot cast to scalar: {{type}} must have 1 dimension, but has #{dimensions}.")
        else
          raise DimensionError.new("Cannot cast to scalar: {{type}} must have 1 element, but has #{size}.")
        end
      end
    end

    # Returns the element at position `0` along every axis.
    def first : T
      return get_element([0] * shape.size)
    end

    # Returns a random element from the `{{type}}`.
    def sample(random : Random::Default)
      raise IndexError.new("Can't sample empty collection") if empty?
      unsafe_fetch_element(shape.map { |dim| random.rand(dim) })
    end

    # Returns the number of indices required to specify an element in `{{type}}`.
    def dimensions : Int32
      @shape.size
    end

    # FIXME: NArrayFormatter depends on buffer indices.
    def to_s : String
      NArrayFormatter.format(self)
    end

    # FIXME: NArrayFormatter depends on buffer indices.
    def to_s(io : IO) : Nil
      NArrayFormatter.print(self, io)
    end

    # Checks that `coord` is in-bounds for this `{{type}}`.
    def has_coord?(coord : Enumerable) : Bool
      RegionHelpers.has_coord?(coord, shape)
    end

    # Checks that `region` is in-bounds for this `{{type}}`.
    def has_region?(region : Enumerable) : Bool
      RegionHelpers.has_region?(region, shape)
    end

    # Copies the elements in `region` to a new `{{type}}`, and throws an error if `region` is out-of-bounds for this `{{type}}`.
    def get_region(region : Enumerable)
      unsafe_fetch_region RegionHelpers.canonicalize_region(region, shape)
    end

    # Retrieves the element specified by `coord`, and throws an error if `coord` is out-of-bounds for this `{{type}}`.
    def get_element(coord : Enumerable) : T
      unsafe_fetch_element RegionHelpers.canonicalize_coord(coord, shape)
    end

    def get(coord) : T
      get_element(coord)
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

    def each(order : Order = Order::LEX)
      puts "MultiIndexable each got called"
      case order
      when Order::LEX
        LexRegionIterator(self, T).new(self)
      when Order::COLEX
        ColexRegionIterator(self, T).new(self)
      when Order::REV_LEX
        LexRegionIterator(self, T).new(self, reverse: true)
      when Order::REV_COLEX
        ColexRegionIterator(self, T).new(self, reverse: true)
      when Order::FASTEST
        each_fastest
      else
        raise ArgumentError.new("Could not iterate over MultiIndexable: Unrecognized order #{order}.")
      end
    end

    def each(order : Order = Order::LEX, &block)
      each(order).each do |elem|
        yield elem
      end
    end

    def each_with_coord(order : Order = Order::LEX, &block)
      each.each(order) do |elem, coord|
        yield elem, coord
      end
    end

    # A method to get all elements in this `{{@type}}` when order is irrelevant.
    # Recommended that implementers override this method to take advantage of
    # the storage scheme the implementation uses
    def each_fastest
      each(Order::LEX)
    end

    # # TODO: Each methods should exist that allow:
    # # - Some way to handle slice iteration? (how do we pass in the axis? etc)
    # # - Implement map based off the each function

    # # Version that accepts a block
    # def each
    #     each.each {|elem| yield elem}
    # end

    # {% begin %}
    #     {% for name in %w(each) %}
    #         def {{name.id}}
    #             {{name.id}} do |*args|
    #                 yield *args
    #             end # This may not work at all...
    #         end
    #     {% end %}
    # {% end %}

    # To implement:

    # to_a maybe?
    # ^ TOOD make to_a

    # def each_with_coord(type : MultiIterator.class = LexicographicIterator, &block : )

    # def each(type : MultiIterator.class = NArrayIterator, &block)

    # def each(type)
    #     type.new(self)
    # end

    # stolen from Enumerable:
    # def map(&block : T -> U) forall U
    #     ary = [] of U
    #     each { |e| ary << yield e }
    #     ary
    # end

    # def slices(axis = 0) : Array(self)

    def equals?(other : MultiIndexable) : Bool
      each_with_coord do |elem, coord|
        return false if elem != other[coord].to_scalar
      end
    end

    def equals?(other : MultiIndexable, &block) : Bool
      return false if shape != other.shape
      each_with_coord do |elem, coord|
        return false unless yield(elem, other[coord].to_scalar)
      end
    end

    {% begin %}
      # Implements most binary operations
      {% for name in %w(+ - * / // > < >= <= &+ &- &- ** &** % & | ^ <=>) %}
        # Invokes `#{{name.id}}` element-wise between `self` and *other*, returning
        # an `NArray` that contains the results.
        def {{name.id}}(other : MultiIndexable(U)) forall U
          map_with_coord do |elem, coord|
            elem.{{name.id}} other[coord].to_scalar
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
