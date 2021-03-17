module Lattice
    module MultiWritable(T)
        abstract def size : Int32
        abstract def shape : Array(Int32)
        abstract def unsafe_set_region(region : Enumerable, value : MultiIndexable(T))
        abstract def unsafe_set_region(region : Enumerable, value : T)

        # Please override me :O
        def unsafe_set_element(coord : Enumerable, value : T)
            unsafe_set_region(coord, value)
        end

        def set_region(region : Enumerable, value : MultiIndexable)
            unsafe_set_region(RegionHelpers.canonicalize_region(region, shape), value)
        end
        
        def set_region(region : Enumerable, value)
            unsafe_set_region(RegionHelpers.canonicalize_region(region, shape), value.as(T))
        end

        def []=(region : Enumerable, value)
            set_region(region, value)
        end


        # These two should go last
        def set_region(*args : *U) forall U
            {% begin %}
                set_region([{% for i in 0...(U.size - 1) %}args[{{i}}] {% if i < U.size - 2 %}, {% end %}{% end %}], args.last)
            {% end %}
        end
        
        def []=(*args)
            set_region(*args)
        end


        # In implementation phase:
        coord = NArray...
        otherthingy[coord] = 5

        def []=(bool_mask : MultiIndexable(Bool), value)

            if bool_mask.shape != shape
              raise DimensionError.new("Cannot perform masking: mask shape does not match array shape.")
            end
      
            # TODO implement this based on how each works
            bool_mask.each_with_coord do |bool_val, coord|
              if bool_val
                unsafe_set_element(coord, value.as(T))
              end
            end
        end

        # TODO: once we figure out map, figure out map!
    end
end