require "./lattice"

include Lattice


abstract class CoordIterator(A)
    include Iterator(Array(Int32))
end

abstract class RegionIterator(A)
    include RegionHelpers
    include Iterator(Array(SteppedRange))
end


private class ItemIterator(A,T)
    include Iterator(T)

    @coord_iter : CoordIterator(A)

    # def initialize(@narray : A, order : CoordIterator.class = LexCoordIterator)
    #     @coord_iter = order.new(@narray)
    # end

    def initialize(@narray : A, coord_iter : (CoordIterator | Nil) = nil)
        @coord_iter = coord_iter ? coord_iter : LexCoordIterator.new(@narray)
    end

    def next
        coord = @coord_iter.next # will throw stop if coord_iter does?
        return stop if coord == stop
        @narray.unsafe_fetch_element(coord.as(Array(Int32)))
    end
end

private class SubarrayIterator(A,T)
    include Iterator(MultiIndexable(T))

    @region_iter : RegionIterator(A)

    # def initialize(@narray : A, order : RegionIterator.class = SliceIterator)
    #    @region_iter = order.new()
    # end

    def initialize(@narray : A, region_iter : (RegionIterator | Nil) = nil)
        @region_iter = region_iter ? region_iter : SliceIterator.new(@narray, axis = 0)
    end

    def next
        region = @region_iter.next
        return stop if region == stop
        @narray.unsafe_fetch_region(region.as(Array(SteppedRange)))
    end
end

# https://en.wikiversity.org/wiki/Lexicographic_and_colexicographic_order

# Iterates through all possible coordinates for `@narray` in lexicographic order.
private class LexCoordIterator(A) < CoordIterator(A)

    @coord : Array(Int32)

    def initialize(@narray : A)
        @coord = [0] * @narray.dimensions.to_i32
        @coord[-1] -= 1 # initialize so that first call to 'next' will yield all zeros
    end

    # Implementation of a synchronous counter with variable-max digits
    def next
        (@coord.size - 1).downto(0) do |i|
            if @coord[i] == @narray.shape[i] - 1
                @coord[i] = 0
                return stop if i == 0
            else 
                @coord[i] += 1
                break
            end
        end
        @coord
    end
end

# returns coordinates in colexicographic order
private class ColexCoordIterator(A) < CoordIterator(A)
    @coord : Array(Int32)

    def initialize(@narray : A)
        @coord = [0] * @narray.dimensions.to_i32
        @coord[0] -= 1 # initialize so that first call to 'next' will yield all zeros
    end

    # Implementation of a synchronous counter with variable-max digits
    def next
        @coord.each_index do |i|
            if @coord[i] == @narray.shape[i] - 1
                @coord[i] = 0
                return stop if i == @coord.size - 1
            else 
                @coord[i] += 1
                break
            end
        end
        @coord
    end
end

private class RevColexCoordIterator(A) < CoordIterator(A)
    @coord : Array(Int32)

    def initialize(@narray : A)
        @coord = @narray.shape.map {|size| size - 1}
        @coord[0] += 1 # initialize so that first call to 'next' will yield all zeros
    end

    # Implementation of a synchronous counter with variable-max digits
    def next
        @coord.each_index do |i|
            if @coord[i] == 0
                @coord[i] = @narray.shape[i] - 1
                return stop if i == @coord.size - 1
            else 
                @coord[i] -= 1
                break
            end
        end
        @coord
    end
end

private class RevLexCoordIterator(A) < CoordIterator(A)
    @coord : Array(Int32)

    def initialize(@narray : A)
        @coord = @narray.shape.map {|size| size - 1}
        @coord[-1] += 1 # initialize so that first call to 'next' will yield all zeros
    end

    # Implementation of a synchronous counter with variable-max digits
    def next
        (@coord.size - 1).downto(0) do |i|
            if @coord[i] == 0
                @coord[i] = @narray.shape[i] - 1
                return stop if i == 0
            else 
                @coord[i] -= 1
                break
            end
        end
        @coord
    end
end


private class SliceIterator(A) < RegionIterator(A)

    @region : Array(SteppedRange)

    def initialize(@narray : A, @axis = 0)
        @region = @narray.shape.map do |dim|
            SteppedRange.new(0..(dim - 1), 1)
        end

        @index = -1
        @region[@axis] = SteppedRange.new(@index)
    end

    def next
        if @region[@axis].begin < @narray.shape[@axis] - 1
            @index += 1
            @region[@axis] = SteppedRange.new(@index)
            @region
        else
            stop 
        end               
    end
end




arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }

small_arr = NArray.build([3,3]) {|coord, index| index}

puts "Lexicographic:"
LexCoordIterator.new(small_arr).each {|elem| puts elem}

puts "Colexicographic:"
ColexCoordIterator.new(small_arr).each {|elem| puts elem}

puts "Reverse Lexicographic:"
RevLexCoordIterator.new(small_arr).each {|elem| puts elem}

puts "Reverse Colexicographic:"
RevColexCoordIterator.new(small_arr).each {|elem| puts elem}


puts "Slices, axis 0:"
SliceIterator.new(small_arr).each {|elem| puts elem}

puts "Slices, axis 1:"
SliceIterator.new(small_arr, axis=1).each {|elem| puts elem}

# iter.each {|elem| puts elem}

# item_iter = ItemIterator(NArray(Int32), Int32).new(arr)
# item_iter.each {|elem| puts elem}
    
