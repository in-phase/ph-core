module Lattice
    class View(S, T)
        include MultiIndexable(T)

        # A proc that transforms one coordinate into another coordinate.
        @src : S
        @transforms : Array(Transform)

        private def initialize(@src : S, @transforms = [] of Transform)
        end

        def initialize(@src : S, region)
            self.of(@src, region)
        end

        def push_transform(t : Transform)
            if t.composes?
                (@transforms.size - 1).downto(0) do |i|
                    if t.class == @transforms[i].class 
                        if new_transform = t.compose?(@transforms[i])
                            @transforms[i] = new_transform
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

    # transform types: region, colex, reverse, reshape
    #                  RegionTransform, ColexTransform, ... 



    abstract struct Transform
        getter composes? : Bool
        
        def compose?(t : self) : self?
            return nil
        end
        
        def commutes_with?(t : Transform) : Bool
            return false
        end

        def composes? : Bool
            return false
        end

        abstract def apply(coord : Array(Int32)) : Array(Int32)
    end


    # struct RegionTransform < Transform
    # end

    # becomes COLEX
    struct Transpose < Transform
        def composes?
            true
        end

        def compose?(t : self) : self?
            
        end
    end
end