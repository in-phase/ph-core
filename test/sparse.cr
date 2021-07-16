require "../src/ph-core"


module Phase 

    class SparseArray(T)
        include MultiIndexable(T)
        include MultiWritable(T)

        @shape : Array(Int32)
        @default : T
        @values : Hash(Array(Int32), T)

        def self.fill(shape, default : T) forall T
            new(shape, default, Hash(Array(Int32), T).new(default))
        end

        def self.new(shape, default)
            fill(shape, default)
        end

        def initialize(@shape, @default : T, @values)
        end


        def shape : Array
            @shape.dup 
        end

        def unsafe_fetch_element(coord : Coord) : T
            @values[coord]
        end

        def unsafe_set_element(coord : Coord, value)
            if value == @default
                @values.reject!(coord)
            else 
                @values[coord] = value
            end
        end


        def unsafe_fetch_chunk(region : IndexRegion) : self
            # assumes that the default for self is also the default of the region
            new_hash = Hash(Array(Int32), T).new(@default)
            # region.each {}
            @values.each_key do |key|
                if region.includes?(key)
                    new_hash[region.absolute_to_local(key)] = @values[key]
                end
            end

            SparseArray.new(region.shape, @default, new_hash)
        end
        
    end


    sp = SparseArray.new([2,2,2], 5)
    sp[0,1,0] = 8


    puts sp

    puts sp[..,1]

end