require "./region_helpers.cr"

module Lattice

    module MultiIndexable(T)


        # For performance gains, we recommend the user to consider overriding the following methods when including MultiIndexable(T):
        # - a pretty list
        # - more list

        # Returns the number of elements in the `{{type}}`; equal to `shape.product`.
        abstract def size : Int32

        # Returns the length of the `{{type}}` in each dimension. 
        # For a `coord` to specify an element of the `{{type}}` it must satisfy `coord[i] < shape[i]` for each `i`.
        abstract def shape : Array(Int32)

        # Copies the elements in `region` to a new `{{type}}`, assuming that `region` is in canonical form and in-bounds for this `{{type}}`.
        # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
        abstract def unsafe_fetch_region(region) 

        # Retrieves the element specified by `coord`, assuming that `coord` is in canonical form and in-bounds for this `{{type}}`.
        # For full specification of canonical form see `RegionHelpers` documentation. TODO: make this actually happen
        abstract def unsafe_fetch_element(coord) : T


        # Stuff that we can implement without knowledge of internals

        # Checks that the `{{type}}` contains no elements.
        def empty? : Bool
            size == 0 
        end

        # Checks that this `{{type}}` is one-dimensional, and contains a single element.
        def scalar? : Bool
            shape.size == 1 && size == 1
        end

        # Maps a single-element 1D `{{type}}` to the element it contains.
        def to_scalar : T
            if scalar?
                return first
            else
                if shape.size != 1
                    raise DimensionError.new("Cannot cast to scalar: {{type}} must have 1 dimension, but has #{dimensions}.")
                else
                    raise DimensionError.new("Cannot cast to scalar: {{type}} must have 1 element, but has #{size}.")
                end
            end
        end

        # Returns the element at position `0` along every axis.
        def first : T
            return get_element([0] * shape.size)
        end

        # Returns a random element from the `{{type}}`.
        def sample(random : Random::Default)
            raise IndexError.new("Can't sample empty collection") if empty?
            unsafe_fetch_element(shape.map { |dim| random.rand(dim) })
        end
        
        # Returns the number of indices required to specify an element in `{{type}}`.
        def dimensions : Int32
            @shape.size
        end

        # FIXME: NArrayFormatter depends on buffer indices.
        def to_s : String
            NArrayFormatter.format(self)
        end
        
        # FIXME: NArrayFormatter depends on buffer indices.
        def to_s(io : IO) : Nil
            NArrayFormatter.print(self, io)
        end

        # Checks that `coord` is in-bounds for this `{{type}}`.
        def has_coord?(coord : Enumerable) : Bool
            RegionHelpers.has_coord?(coord, shape)
        end
      
        # Checks that `region` is in-bounds for this `{{type}}`.
        def has_region?(region : Enumerable) : Bool
            RegionHelpers.has_region?(region, shape)
        end

        # Copies the elements in `region` to a new `{{type}}`, and throws an error if `region` is out-of-bounds for this `{{type}}`.
        def get_region(region : Enumerable) 
            unsafe_fetch_region RegionHelpers.canonicalize_region(region, shape)
        end

        # Retrieves the element specified by `coord`, and throws an error if `coord` is out-of-bounds for this `{{type}}`.
        def get_element(coord : Enumerable) : T
            unsafe_fetch_element RegionHelpers.canonicalize_coord(coord, shape)
        end

        def get(coord) : T
            get_element(coord)
        end

        # Copies the elements in `region` to a new `{{type}}`, and throws an error if `region` is out-of-bounds for this `{{type}}`.
        def [](region : Enumerable) 
            get_region(region)
        end

        # Tuple-accepting overload of `#{{name}}`.
        # NOTE: cannot be (easily) generated in the macro since it requires syntax `[tuple]` rather than `[](tuple)`
        def [](*region) 
            get_region(region)
        end
        
        {% begin %}
            {% enumerable_functions = %w(get get_element get_region has_coord? has_region?) %}

            {% for name in enumerable_functions %}
                # Tuple-accepting overload of `#{{name}}`.
                def {{name.id}}(*tuple)
                    {{name.id}}(tuple)
                end
            {% end %}
        {% end %}

        # TODO: Each methods should exist that allow:
        # - by default, generic lexicographic iteration
        # - providing custom `MultiIterators` to iterate in different orders
        # - Some way to handle slice iteration? (how do we pass in the axis? etc)
        # - Implement map based off the each function
        # - region iterator? each_in_canonical_region?
        
        def each_coord
            LexicographicCoordIterator(self).new(self)
        end

        def each
            ItemIterator(self, T).new(self)
        end

        # Version that accepts a block
        def each
            each {|elem| yield elem}
        end
        {% begin %}
            {% for name in %w(each) %}
                def {{name.id}}
                    {{name.id}} do |args| 
                        yield args
                    end # This may not work at all...
                end
            {% end %}
        {% end %}
       

        # To implement:

        # to_a maybe?

        abstract class MultiIterator
            def initialize(multiindexable, &block)
                # based on multiindexable, run iterating code
                
            end
        end

        
        # may be used to iterate over all coordinates in a MultiIndexable
        abstract class CoordIterator(A)
            include Iterator(Array(Int32))
        end

        abstract class RegionIterator(A)
            include RegionHelpers
            include Iterator(Array(SteppedRange))
        end

        private class ItemIterator(A,T)
            include Iterator(T)

            def initialize(@narray : A, @coord_iter : CoordIterator = LexicographicCoordIterator.new(@narray))
            end


            def next
                coord = @coord_iter.next # will throw stop if coord_iter does?
                @narray.unsafe_fetch_element(coord)
            end
        end

        private class SubarrayIterator(A,T)
            include Iterator(MultiIndexable(T))

            def initialize(@narray : A, @region_iter : RegionIterator = SliceIterator.new(@narray, 0))
            end

            def next
                region = @region_iter.next # will throw stop if coord_iter does?
                @narray.unsafe_fetch_region(region)
            end
        end

        # Iterates through all possible coordinates for `@narray` in lexicographic order.
        private class LexicographicCoordIterator(A) < CoordIterator(A)

            def initialize(@narray : A)
                @coord = [0] * @narray.dimensions
            end

            def next
                value = @coord
                @coord[-1] += 1
                
                (@coord.size - 1).downto(1) do |i|
                    if @coord[i] == @narray.shape[i]
                        @coord[i] = 0
                        @coord[i - 1] += 1
                    else 
                        break
                    end
                end

                if @coord[0] == @narray.shape[0]
                    stop
                else
                    value
                end
            end
        end


        private class SliceIterator(A) < RegionIterator(A)

            def initialize(@narray : A, @axis = 0)
                @region = @narray.shape.map do |dim|
                    SteppedRange.new(0..(dim - 1), 1)
                end

                @index = 0
                @region[@axis] = SteppedRange.new(@index)
            end

            def next
                @region
                if @region[@axis] < @narray.shape[@axis] - 1
                    @index += 1
                    @region[@axis] = SteppedRange.new(@index)
                    value
                else
                    stop 
                end               
            end
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