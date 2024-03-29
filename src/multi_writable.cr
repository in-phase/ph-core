module Phase
  module MultiWritable(T)
    # DISCUSS: should mutators explicitly return the object itself, for chaining purposes?

    # For performance gains, we recommend the user to consider overriding the following methods when including MultiWritable(T):
    # - `#unsafe_set_element` - while behaviour is identical to setting a one-element region, there may be optimizations for setting a single element.

    # Implementors must use this to expose the shape of a `MultiIndexable`.
    # The returned `Shape` is allowed to be mutable, as callers of this method
    # are trusted to never mutate the result. This allows for performance
    # optimizations where cloning and wrapping are too costly.
    protected abstract def shape_internal : Shape

    # Given a coordinate and a value, store the value at that coordinate.
    # Assumes that the coordinate is in-bounds for this `MultiWritable`.
    abstract def unsafe_set_element(coord : Coord, value : T)

    def size
      ShapeUtil.shape_to_size(shape_internal)
    end

    def shape : Shape
      shape_internal.clone
    end

    # Copies the elements from a MultiIndexable `src` into `region`, assuming that `region` is in canonical form and in-bounds for this `MultiWritable`
    # and the shape of `region` matches the shape of `src`.
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_set_chunk(region : IndexRegion, src : MultiIndexable(T))
      absolute_iter = region.each
      src_iter = src.each

      src_iter.each do |src_el|
        unsafe_set_element(absolute_iter.unsafe_next, src_el)
      end
    end

    # Sets each element in `region` to `value`, assuming that `region` is in canonical form and in-bounds for this `MultiWritable`
    # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
    def unsafe_set_chunk(region : IndexRegion, value : T)
      region.each do |coord|
        unsafe_set_element(coord, value)
      end
    end

    # Sets the element specified by `coord` to `value`.
    # Raises an error if `coord` is out-of-bounds for this `MultiWritable`.
    def set_element(coord : Indexable, value : T)
      unsafe_set_element(CoordUtil.canonicalize_coord(coord, shape_internal), value)
    end

    # NOTE: changed name from 'value' to 'src' - approve?
    # Copies the elements from a MultiIndexable `src` into `region`.
    # Raises an error if `region` is out-of-bounds for this `MultiWritable` or if the shape of `region` does not match `src.shape`
    def set_chunk(region_literal : Indexable, src : MultiIndexable(T))
      idx_region = IndexRegion.new(region_literal, shape_internal)

      if !ShapeUtil.compatible_shapes?(src.shape_internal, idx_region.shape)
        raise ShapeError.new("Cannot substitute #{typeof(src)}: the given #{typeof(src)} has shape #{src.shape_internal}, but region #{idx_region} has shape #{idx_region.shape}.")
      end

      unsafe_set_chunk(idx_region, src)
    end

    # Sets each element in `region` to `value`.
    # Raises an error if `region` is out-of-bounds for this `MultiWritable`.
    def set_chunk(region : Indexable | IndexRegion, value : T)
      idx_r = IndexRegion.new(region, shape_internal)
      unsafe_set_chunk(idx_r, value)
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

    # Overwrites elements using a boolean *mask* to select which elements are rewritten.
    # For example:
    # ```crystal
    # # 2x2 matrix of zeros
    # narr = NArray.fill([2, 2], 0) # => NArray[[0, 0], [0, 0]]
    # 
    # # Diagonal mask
    # mask = NArray.build([2, 2]) { |coord| coord[0] == coord[1] }
    # # => NArray[[true, false],
    # #           [false, true]]
    # 
    # # Create an identity matrix:
    # narr[mask] = 1
    # 
    # puts narr
    # # => NArray[[1, 0],
    # #           [0, 1]]
    # 
    # # The source elements can come from another MultiIndexable, too:
    # source = NArray.build(2, 2) { |_, idx| idx + 10 }
    # # => NArray[[10, 11],
    # #           [12, 13]]
    # 
    # narr[mask] = source
    # 
    # puts narr
    # # => NArray[[10, 0],
    # #           [0, 13]]
    # ```
    # Note that the elements from *value* (wether value is constant or a
    # *MultiIndexable* are not duplicated or cloned. If you have a
    # `MultiWritable` full of objects, this may be an issue. In this case, the
    # block accepting version might be more desirable for you
    # (`MultiWritable#set_mask(mask, &block`)
    def []=(mask : MultiIndexable(Bool), value)
      set_mask(mask, value)
    end

    # Copies elements from *src* into this `MultiWritable` at coordinates where *mask* is true.
    # The copied elements are not duplicated or cloned - be aware of this if you
    # have a `MultiIndexable` of Objects.
    #
    # ```crystal
    # # 2x2 matrix of zeros
    # narr = NArray.fill([2, 2], 0) # => NArray[[0, 0], [0, 0]]
    # 
    # # Diagonal mask
    # mask = NArray.build([2, 2]) { |coord| coord[0] == coord[1] }
    # # => NArray[[true, false],
    # #           [false, true]]
    # 
    # source = NArray.build(2, 2) { |_, idx| idx + 10 }
    # # => NArray[[10, 11],
    # #           [12, 13]]
    # 
    # narr[mask] = source
    # 
    # puts narr
    # # => NArray[[10, 0],
    # #           [0, 13]]
    # ```
    def set_mask(mask : MultiIndexable(Bool), src : MultiIndexable(T))
      if src.shape != shape_internal
        raise ShapeError.new("Cannot perform masking: source shape #{src.shape} does not match array shape #{shape_internal}.")
      end

      set_mask(mask) { |coord| src.unsafe_fetch_element(coord).as(T) }
    end

    def set_mask(mask : MultiIndexable(Bool), &block)
      if mask.shape != shape_internal
        raise ShapeError.new("Cannot perform masking: mask shape #{mask.shape} does not match array shape #{shape_internal}.")
      end

      mask.each_with_coord do |bool_val, coord|
        if bool_val
          unsafe_set_element(coord, yield coord)
        end
      end
    end
  end
end
