module Phase
  class ProcView(S, T, R) < View(S, R)
    @proc : Proc(T, R)

    # DOCUMENT
    def self.new(src : MultiIndexable(T), proc : (T -> R), *, region = nil) : self forall T, R
      case src
      when View
        return src.process(proc)
      else
        new_view = ProcView(typeof(src), T, R).new(validated: src, shape: src.shape, proc: proc)
        new_view.restrict_to(region) if region
        return new_view
      end
    end

    def self.new(src : B, region = nil, &block : (T -> R)) : self forall T, R
      new(src, region, block)
    end

    protected def initialize(*, validated @src : S, @shape : Array(Int32), @proc : Proc(T, R), @transform = ComposedTransform.new)
    end

    def clone : self
      new(@src, @shape.clone, @proc.clone, @transform.clone)
    end

    def unsafe_fetch_element(coord) : R
      @proc.call(@src.unsafe_fetch_element(@transform.apply(coord)))
    end

    def process(new_proc : (R -> U)) : ProcView(S, T, U) forall U
      composition = Proc(T, U).new { |x| new_proc.call(@proc.clone.call(x)) }
      ProcView(S, T, U).new(@src, @shape.clone, composition, @transform.clone)
    end
  end
end
