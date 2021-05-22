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
        @transforms : Array(Transform)

        private def initialize(@src : S, @transforms = [] of Transform)
        end

        def clone : self
            self.new(@src, @transforms)
        end

        def shape : Array(Int32)
            @src.shape
        end

        # def initialize(@src : S, region)
        #     self.of(@src, region)
        # end

        def push_transform(t : Transform) : Nil
            if t.composes?
                (@transforms.size - 1).downto(0) do |i|
                    if t.class == @transforms[i].class 
                        if new_transform = t.compose?(@transforms[i])
                            if new_transform < NoTransform # If composition => annihiliation
                                @transforms.delete_at(i)
                            else
                                @transforms[i] = new_transform
                            end
                            return
                        end
                    elsif !t.commutes_with?(@transforms[i])
                        break
                    end
                end
            end
            @transforms << t
        end

        def self.of(src, region)
        end
    end

end