require "../n_dim/*"
require "./transforms"



# our framework:
# View(B,T)
#   => coord_transforms: [] of Proc(Array(Int32), Array(Int32))

# ProcView(B,T,R)
#   @view : View(B,T)
#   => elem_transforms @proc : Proc(T,R)
  
#   forward_missing_to @view

module Lattice
    class View(S, T)
        include MultiIndexable(T)

        # A proc that transforms one coordinate into another coordinate.
        @src : S
        @transform : ComposedTransform

        private def initialize(@src : S, @transform = ComposedTransform.new)
        end

        # def initialize(@src : S, region)
        #     self.of(@src, region)
        # end

        def self.of(src, region)
        end

        def clone : self
            self.new(@src, @transform.clone)
        end

        def shape : Array(Int32)
            @src.shape
        end

        def view(region = nil) : self
            return clone unless region
            RegionTransform.new(RegionHelpers.canonicalize_region(region))
            new(@src, @transform.compose())
        end

        # def reshape : self
        # end

        # def transpose : self
        # end

        # def reverse : self
        # end

        
        # def process : ProcView
        # end

        # def to_narr : NArray(T)
        # end

    end

end