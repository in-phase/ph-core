module Lattice
  class View(S, R) < ReadonlyView(S, R)
    include MultiWritable(R)

    def self.of(src : S, region : Enumerable? = nil) : self
      case src
      when ReadonlyView
        return src.view(region)
      else
        new_view = View(S, typeof(src.sample)).new(src)
        new_view.restrict_to(region) if region
        return new_view
      end
    end

    macro ensure_writable
            {% unless S < MultiWritable %}
                {% raise "Could not write to #{@type}: #{S} is not a MultiWritable." %}
            {% end %}
        end

    def unsafe_set_element(coord : Indexable, value : T)
      ensure_writeable
      @src.unsafe_set_element(@transform.apply(coord), src[coord])
    end
  end
end
