require "./region_helpers"
require "./order"
require "./iterators/*"

module Lattice
  module MultiWritable(T)
    # TODO: discuss: should mutators explicitly return the object itself, for chaining purposes?

    # For performance gains, we recommend the user to consider overriding the following methods when including MultiWritable(T):
    # - `#unsafe_set_element` - while behaviour is identical to setting a one-element region, there may be optimizations for setting a single element.

    # Returns the number of elements in the `{{type}}`; equal to `shape.product`.
    abstract def size

    # Returns the length of the `{{type}}` in each dimension.
    # For a `coord` to specify an element of the `{{type}}` it must satisfy `coord[i] < shape[i]` for each `i`.
    abstract def shape : Array(Int32)

    # Copies the elements from a MultiIndexable `src` into `region`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`
    # and the shape of `region` matches the shape of `src`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    abstract def unsafe_set_region(region : Enumerable, src : MultiIndexable(T))

    # Sets each element in `region` to `value`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    abstract def unsafe_set_region(region : Enumerable, value : T)

    protected def shape_internal : Array(Int32)
      shape
    end

    # Sets the element specified by `coord` to `value`, assuming that `coord` is in canonical form and in-bounds for this `{{type}}`
    def unsafe_set_element(coord : Enumerable, value : T)
      unsafe_set_region(RegionHelpers.region_from_coord(coord), value)
    end

    # Sets the element specified by `coord` to `value`.
    # Raises an error if `coord` is out-of-bounds for this `{{type}}`.
    def set_element(coord : Enumerable, value)
      unsafe_set_element(RegionHelpers.canonicalize_coord(coord, shape_internal), value.as(T))
    end

    # NOTE: changed name from 'value' to 'src' - approve?
    # Copies the elements from a MultiIndexable `src` into `region`.
    # Raises an error if `region` is out-of-bounds for this `{{type}}` or if the shape of `region` does not match `src.shape`
    def set_region(region : Enumerable, src : MultiIndexable)
      canonical_region = RegionHelpers.canonicalize_region(region, shape_internal)
      if !RegionHelpers.compatible_shapes(src.shape_internal, RegionHelpers.measure_canonical_region(canonical_region))
        raise DimensionError.new("Cannot substitute #{typeof(src)}: the given #{typeof(src)} has shape #{src.shape_internal}, but region #{region} has shape #{RegionHelpers.measure_canonical_region(canonical_region)}.")
      end
      # [1, 5]    [1, 5, 1, 1]
      # [1, 5]    [1, 5]

      # region [1, 5, 1, 1]
      # src [1, 5]
      unsafe_set_region(canonical_region, src) # ReshapeView.of(src, shape: RegionHelpers.measure_canonical_region(canonical_region)))
    end

    # Sets each element in `region` to `value`.
    # Raises an error if `region` is out-of-bounds for this `{{type}}`.
    def set_region(region : Enumerable, value)
      unsafe_set_region(RegionHelpers.canonicalize_region(region, shape_internal), value.as(T))
    end

    # See `#set_region(region : Enumerable, value)`
    def []=(region : Enumerable, value)
      set_region(region, value)
    end

    # These two should go last
    def []=(*args : *U) forall U
      {% begin %}
          set_region([{% for i in 0...(U.size - 1) %}args[{{i}}] {% if i < U.size - 2 %}, {% end %}{% end %}], args.last)
      {% end %}
    end

    # In implementation phase:

    def []=(bool_mask : MultiIndexable(Bool), value)
      # We can't use `bool_mask.shape_internal` here, because it is protected
      if bool_mask.shape != shape_internal
        raise DimensionError.new("Cannot perform masking: mask shape #{bool_mask.shape} does not match array shape #{shape_internal}.")
      end

      # TODO implement this based on how each works
      bool_mask.each_with_coord do |bool_val, coord|
        if bool_val
          unsafe_set_element(coord, value.as(T))
        end
      end
    end

    # TODO: once we figure out map, figure out map!
    # Will throw compile error if not both read and writeable
  end
end
