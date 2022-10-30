module Phase
  module MultiIndexable::Mutable(T)
    include MultiIndexable(T)
    include MultiWritable(T)

    def mutable_view(region : Indexable? | IndexRegion = nil) : MutableView(self, T)
      MutableView.new(self, region)
    end

    def mutable_view(*region) : MutableView(self, T)
      mutable_view(region)
    end

    # TODO docs
    # DISCUSS is this good behaviour?
    def map_with_coord!(&block : (T -> T))
      each_coord do |coord|
        unsafe_set_element(coord, yield(unsafe_fetch_element(coord), coord))
      end
    end

    def map_with_coord!(&block : (T -> MultiIndexable(T)))
      each_coord do |coord|
        val = yield unsafe_fetch_element(coord), coord
        unsafe_set_element(coord, val.to_scalar)
      end
    end

    # TODO docs, test
    def map!(&block : (T -> T | MultiIndexable(T))) : MultiIndexable(T)
      map_with_coord! do |el, coord|
        yield el
      end
    end

    def apply! : InPlaceApplyProxy
      InPlaceApplyProxy.of(self)
    end

    private class InPlaceApplyProxy(S,T) < ApplyProxy(S,T)
      def self.of(src : S) forall S
        InPlaceApplyProxy(S, typeof(src.first)).new(src)
      end
      
      macro method_missing(call)
        def {{call.name.id}}(*args : *U) forall U
          @src.map_with!(*args) do |elem, *arg_elems|
            elem.{{call.name.id}}(*arg_elems)
          end
        end
      end
    end 

    def map_with!(*args : *U, &block) forall U 
      {% begin %}
      ensure_writable
      each_coord do |coord|
        unsafe_set_element(coord, 
          yield(
            unsafe_fetch_element(coord),
            {% for i in 0...(U.size) %}
              {% if U[i] < MultiIndexable %} args[{{i}}].unsafe_fetch_element(coord) {% else %} args[{{i}}]{% end %},
            {% end %}
          ))
      end
      {% end %}
    end
  end
end
