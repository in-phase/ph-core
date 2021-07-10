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
    def unsafe_set_chunk(region : IndexRegion, src : MultiIndexable(T))
      region.each do |coord|
        unsafe_set_element(coord, unsafe_fetch_element(coord))
      end
    end

    # Sets each element in `region` to `value`, assuming that `region` is in canonical form and in-bounds for this `{{@type}}`
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_set_chunk(region : IndexRegion, value : T)
      region.each do |coord|
        unsafe_set_element(coord, value)
      end
    end

    # Sets the element specified by `coord` to `value`.
    # Raises an error if `coord` is out-of-bounds for this `{{@type}}`.
    def set_element(coord : Indexable, value : T)
      unsafe_set_element(CoordUtil.canonicalize_coord(coord, shape_internal), value)
    end

    # NOTE: changed name from 'value' to 'src' - approve?
    # Copies the elements from a MultiIndexable `src` into `region`.
    # Raises an error if `region` is out-of-bounds for this `{{@type}}` or if the shape of `region` does not match `src.shape`
    def set_chunk(region_literal : Indexable, src : MultiIndexable(T))
      idx_region = IndexRegion.new(region_literal, shape_internal)

      if !ShapeUtil.compatible_shapes?(src.shape_internal, idx_region.shape)
        raise DimensionError.new("Cannot substitute #{typeof(src)}: the given #{typeof(src)} has shape #{src.shape_internal}, but region #{idx_region} has shape #{idx_region.shape}.")
      end

      idx_region.each do |coord|
        unsafe_set_element(coord, src.unsafe_fetch_element(coord))
      end
    end

    # Sets each element in `region` to `value`.
    # Raises an error if `region` is out-of-bounds for this `{{@type}}`.
    def set_chunk(region : Indexable | IndexRegion, value : T)
      unsafe_set_chunk(IndexRegion.new(region, shape_internal), value)
    end

    def set_available(region : Indexable, value : T)
      unsafe_set_chunk(IndexRegion.new(region, trim_to: shape))
    end

    # See `#set_chunk(region : Enumerable, value)`
    def []=(region : Indexable | IndexRegion, value)
      set_chunk(region, value)
    end

    # These two should go last
    def []=(*args)
      set_chunk(args[...-1].to_a, args.last)
    end
  
    # The general form is a <op>= b and the compiler transform that into a = a <op> b.
    # a[i] ||= b transforms to a[i] = (a[i]? || b)
    # a[pred] *= -1
    # a[pred] = a[pred]? * -1
    # def []?(narr : MultiIndexable(Bool), value) # = this returns
    # def []=(pred : MultiIndexable(Bool), src : MultiIndexable(T?))
  
    # TODO: consider overriding these in NArray, may benefit from speedup?
    def []=(bool_mask : MultiIndexable(Bool), value : T)
      # We can't use `bool_mask.shape_internal` here, because it is protected
      if bool_mask.shape != shape_internal
        raise ShapeError.new("Cannot perform masking: mask shape #{bool_mask.shape} does not match array shape #{shape_internal}.")
      end

      bool_mask.each_with_coord do |bool_val, coord|
        if bool_val
          unsafe_set_element(coord, value)
        end
      end
    end

    def set_mask(bool_mask, src : MultiIndexable(T))
      if src.shape != shape_internal
        raise ShapeError.new("Cannot perform masking: source shape #{src.shape} does not match array shape #{shape_internal}.")
      end
      set_mask(bool_mask) {|coord| src.unsafe_fetch_element(coord)}
    end

    def set_mask(bool_mask, value)
      set_mask(bool_mask) {value}
    end

    def set_mask(bool_mask : MultiIndexable(Bool), &block)
      if bool_mask.shape != shape_internal
        raise ShapeError.new("Cannot perform masking: mask shape #{bool_mask.shape} does not match array shape #{shape_internal}.")
      end
      bool_mask.each_with_coord do |bool_val, coord|
        if bool_val
          unsafe_set_element(coord, yield coord)
        end
      end
    end

    def []=(bool_mask : MultiIndexable(Bool), src : MultiIndexable(T?))
      # We can't use `bool_mask.shape_internal` here, because it is protected
      if bool_mask.shape != shape_internal
        raise DimensionError.new("Cannot perform masking: mask shape #{bool_mask.shape} does not match array shape #{shape_internal}.")
      end

      # TODO: for now we are checking for an exact shape match. modify later if needed
      if src.shape != shape_internal
        raise ShapeError.new("Cannot perform masking: source shape #{src.shape} does not match array shape #{shape_internal}.")
      end

      bool_mask.each_with_coord do |bool_val, coord|
        if bool_val
          if src_el = src.unsafe_fetch_element(coord)
            unsafe_set_element(coord, src_el)
          else
            raise "TODO"
          end
        end
      end
    end
  end
end
