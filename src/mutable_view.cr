module Phase
  class MutableView(S, R) < View(S, R)
    include MultiWritable(R)

    def self.of(src : S, region : Enumerable? = nil) : self
      case src
      when View
        return src.view(region)
      else
        new_view = MutableView(S, typeof(src.sample)).new(src)
        new_view.restrict_to(region) if region
        return new_view
      end
    end

    def unsafe_set_element(coord : Indexable, value : R)
      @src.ensure_writable
      @src.unsafe_set_element(@transform.apply(coord), value)
    end
  end
end
