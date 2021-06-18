module Lattice
  module MultiWritable(T)
    # TODO: discuss: should mutators explicitly return the object itself, for chaining purposes?

    # For performance gains, we recommend the user to consider overriding the following methods when including MultiWritable(T):
    # - `#unsafe_set_element` - while behaviour is identical to setting a one-element region, there may be optimizations for setting a single element.

    # Returns the number of elements in the `{{@type}}`; equal to `shape.product`.
    abstract def size

    # Returns the length of the `{{@type}}` in each dimension.
    # For a `coord` to specify an element of the `{{@type}}` it must satisfy `coord[i] < shape[i]` for each `i`.
    abstract def shape : Shape

    # Given a coordinate representing some location in the {{@type}} and a value, store the value at that coordinate.
    # Assumes that the coordinate is in-bounds for this {{@type}}.
    abstract def unsafe_set_element(coord : Coord, value : T)

    protected def shape_internal : Shape
      shape
    end

    # Copies the elements from a MultiIndexable `src` into `region`, assuming that `region` is in canonical form and in-bounds for this `{{@type}}`
    # and the shape of `region` matches the shape of `src`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_set_chunk(region : CanonicalRegion, src : MultiIndexable(T))
      LexIterator.new(shape_internal, region).each do |coord|
        unsafe_set_element(coord, unsafe_fetch_element(coord))
      end
    end

    # Sets each element in `region` to `value`, assuming that `region` is in canonical form and in-bounds for this `{{@type}}`
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_set_chunk(region : CanonicalRegion, value : T)
      LexIterator.new(shape_internal, region).each do |coord|
        unsafe_set_element(coord, value)
      end
    end

    # Sets the element specified by `coord` to `value`.
    # Raises an error if `coord` is out-of-bounds for this `{{@type}}`.
    def set_element(coord : Indexable, value)
      unsafe_set_element(CoordUtil.canonicalize_coord(coord, shape_internal), value.as(T))
    end

    # NOTE: changed name from 'value' to 'src' - approve?
    # Copies the elements from a MultiIndexable `src` into `region`.
    # Raises an error if `region` is out-of-bounds for this `{{@type}}` or if the shape of `region` does not match `src.shape`
    def set_chunk(region : Indexable, src : MultiIndexable)
      canonical_region = RegionUtil.canonicalize_region(region, shape_internal)
      if !RegionUtil.compatible_shapes(src.shape_internal, RegionUtil.measure_canonical_region(canonical_region))
        raise DimensionError.new("Cannot substitute #{typeof(src)}: the given #{typeof(src)} has shape #{src.shape_internal}, but region #{region} has shape #{RegionUtil.measure_canonical_region(canonical_region)}.")
      end

      LexIterator.new(shape_internal, canonical_region).each do |coord|
        unsafe_set_element(coord, unsafe_fetch_element(coord).as(T))
      end
    end

    # Sets each element in `region` to `value`.
    # Raises an error if `region` is out-of-bounds for this `{{@type}}`.
    def set_chunk(region : Indexable, value)
      unsafe_set_chunk(RegionUtil.canonicalize_region(region, shape_internal), value.as(T))
    end

    def set_available(region : Indexable, value)
      unsafe_set_chunk(RegionUtil.trim_region(region, shape))
    end

    # See `#set_chunk(region : Enumerable, value)`
    def []=(region : Indexable, value)
      set_chunk(region, value)
    end

    # These two should go last
    def []=(*args)
      set_chunk(args[...-1].to_a, args.last)
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
