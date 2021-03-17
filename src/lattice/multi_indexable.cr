require "./region_helpers.cr"

module Lattice

    module MultiIndexable(T)

        # Things that NArray has to give us at minimum
        abstract def size : Int32
        abstract def shape : Array(Int32)
        abstract def unsafe_fetch_region(region) : self
        abstract def unsafe_fetch_element(coord) : T


        # Stuff that we can implement without knowledge of internals

        # Maps a zero-dimensional NArray to the element it contains.
        def empty? : Bool
            shape.any?(0)
        end

        def scalar? : Bool
            shape.size == 1 && shape[0] == 1
        end

        def to_scalar : T
            if scalar?
                return first
            else
                raise DimensionError.new("Cannot cast to scalar: self has more than one dimension or more than one element.")
            end
        end

        def first : T
            return get_element([0] * shape.size)
        end

        def sample(random : Random::Default)
            raise IndexError.new("Can't sample empty collection") if empty?
            get_element(shape.map { |dim| random.rand(dim) })
        end
        
        def dimensions : Int32
            @shape.size
        end

        def to_s : String
            NArrayFormatter.format(self)
        end
        
        def to_s(io : IO) : Nil
            NArrayFormatter.print(self, io)
        end

        def has_coord?(coord : Enumerable) : Bool
            RegionHelpers.has_coord?(coord, shape)
        end
      
        def has_region?(region : Enumerable) : Bool
            RegionHelpers.has_region?(region, shape)
        end

        def get_region(region : Enumerable) : self
            unsafe_fetch_region RegionHelper.canonicalize_region(region, shape)
        end

        def get_element(coord : Enumerable) : self
            unsafe_fetch_element RegionHelper.canonicalize_coord(coord, shape)
        end

        def [](region : Enumerable) : self
            get_region(region)
        end
        
        {% enumerable_functions = %w([], get_element get_region has_coord? has_region?) %}

        {% for name in enumerable_functions %}
            # Tuple-accepting overload of `{{name}}`.
            def {{name}}(*tuple)
                {{name}}(tuple)
            end
        {% end %}
        
        # TODO: Each methods should exist that allow:
        # - by default, generic lexicographic iteration
        # - providing custom `MultiIterators` to iterate in different orders
        # - Some way to handle slice iteration? (how do we pass in the axis? etc)
        # - Implement map based off the each function
        # - region iterator? each_in_canonical_region?
        
        
        # To implement:

        abstract class MultiIterator
            def initialize(multiindexable, &block)
                # based on multiindexable, run iterating code
                
            end
        end

        # analog to IndexIterator?
        private class CoordIterator
        end
    
        # def each_with_coord(type : MultiIterator.class = LexicographicIterator, &block : )

        
        # def each(type : MultiIterator.class = NArrayIterator, &block)

        # def each(type)
        #     type.new(self)
        # end
        
        # stolen from Enumerable:
        # def map(&block : T -> U) forall U
        #     ary = [] of U
        #     each { |e| ary << yield e }
        #     ary
        # end



        # def slices(axis = 0) : Array(self)
    end
end