module Phase
  class View(S, R)
    include MultiIndexable(R)

    # A proc that transforms one coordinate into another coordinate.
    @src : S
    @transform : ComposedTransform
    @shape : Array(Int32)

    def self.of(src : S, region = nil) : self
      case src
      when View
        return src.view(region)
      else
        new_view = View(S, typeof(src.sample)).new(src)
        new_view.restrict_to(region) if region
        return new_view
      end
    end

    protected def initialize(@src : S, @transform : ComposedTransform = ComposedTransform.new)
      @shape = @src.shape
    end

    protected def initialize(@src : S, @shape : Array(Int32), @transform = ComposedTransform.new)
    end

    def clone : self
      typeof(self).new(@src, @shape.clone, @transform.clone)
    end

    def shape_internal : Array(Int32)
      @shape
    end

    def view(region = nil) : self
      new_view = clone
      new_view.restrict_to(region) if region
      new_view
    end

    # an in-place version of view(region), because view! didn't make much sense
    protected def restrict_to(region) : self
      canonical = IndexRegion.new(region, @shape)
      @shape = canonical.shape
      @transform.compose!(RegionTransform.new(canonical))
      self
    end

    def reshape!(new_shape) : self
      if ShapeUtil.shape_to_size(new_shape) != size
        raise ShapeError.new("Cannot change shape from #{@shape.join('x')} (#{size} elements) to #{new_shape.join('x')} (#{ShapeUtil.shape_to_size(new_shape)} elements) because reshape cannot add or remove elements.")
      end

      @transform.compose!(ReshapeTransform.new(@shape, new_shape))
      @shape = new_shape
      self
    end

    def reshape(new_shape) : self
      clone.reshape!(new_shape)
    end

    def permute!(order : Enumerable? = nil) : self
      if order && (bad_axis = order.find { |axis| axis < 0 || axis >= @shape.size })
        raise IndexError.new("Could not use pattern #{order} to permute: Axis #{bad_axis} is not present in a #{dimensions}-dimensional MultiIndexable")
      end

      pt = PermuteTransform.new(order || self.dimensions)
      @shape = pt.permute(@shape)
      @transform.compose!(pt)
      self
    end

    def permute(order : Enumerable? = nil) : self
      clone.permute!(order)
    end

    {% begin %}
      {% for name in {"permute", "permute!", "reshape", "reshape!"} %}
        # Tuple-accepting overload of `#{{name}}`.
        def {{name.id}}(*args)
          {{name.id}}(args)
        end
      {% end %}
    {% end %}

    def reverse! : self
      @transform.compose!(ReverseTransform.new(@shape))
      self
    end

    def reverse : self
      clone.reverse!
    end

    def unsafe_fetch_chunk(region : IndexRegion) : self
      view(region)
    end

    def unsafe_fetch_element(coord : Indexable) : R
      # TODO OPTIMIZE
      # The transform chain only accept `Array` because it needs mutability.
      # ideally we should have an Array stored in each View that
      # can be used as a temp buffer for coordinates that aren't writable.
      # When coord is Array, no allocation is done. But when Coord is
      # ReadonlyWrapper, an allocation is done on every single fetch!
      @src.unsafe_fetch_element(@transform.apply(coord.to_a)).as(R)
    end

    def process(new_proc : (R -> U)) : ProcView(S, R, U) forall U
      ProcView(S, R, U).new(@src, @shape.clone, new_proc, @transform.clone)
    end

    def process(&block : (R -> U)) : ProcView(S, R, U) forall U
      process(block)
    end

    def to_narr : NArray
      iter = self.each
      NArray.build(@shape) { |coord, i| unsafe_fetch_element(coord) }
    end
  end
end
