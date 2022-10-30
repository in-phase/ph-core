module Phase
  class MutableView(S, R) < View(S, R)
    include MultiIndexable::Mutable(R)

    def self.new(src : MultiIndexable::Mutable, region = nil) : self
      case src
      when MutableView
        return src.mutable_view(region)
      else
        new_view = MutableView(typeof(src), typeof(src.sample)).new(validated: src)
        new_view.restrict_to(region) if region
        return new_view
      end
    end

    def unsafe_set_element(coord : Indexable, value : R)
      @src.unsafe_set_element(@transform.apply(coord), value)
    end

    def view(region = nil) : View(S, R)
      new_view = View(S, R).new(validated: @src, transform: @transform.clone, shape: @shape.clone)
      new_view.restrict_to(region) if region
      new_view
    end

    def mutable_view(region = nil) : self
      new_view = clone
      new_view.restrict_to(region) if region
      new_view
    end

    def process(new_proc : (R -> U)) : ProcView(S, R, U) forall U
      ProcView(S, R, U).new(@src, @shape.clone, new_proc, @transform.clone)
    end
  end
end
