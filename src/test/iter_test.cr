require "../lattice"

include Lattice

# def initialize(@narray : A, coord_iter : (CoordIterator | Nil) = nil)
#     @coord_iter = coord_iter ? coord_iter : LexCoordIterator.new(@narray)
# end

# def each_in_region(*args, reverse = false)
# each_in_region(1..0, 5, 2..0, reverse: true)

# abstract class RegionIterator(A)
#     include RegionHelpers
#     include Iterator(Array(SteppedRange))
# end

# private class SubarrayIterator(A,T)
#     include Iterator(MultiIndexable(T))

#     @region_iter : RegionIterator(A)

#     def initialize(@narray : A, order : RegionIterator.class = SliceIterator)
#        @region_iter = order.new()
#     end

#     def initialize(@narray : A, region_iter : (RegionIterator | Nil) = nil)
#         @region_iter = region_iter ? region_iter : SliceIterator.new(@narray, axis = 0)
#     end

#     def next
#         region = @region_iter.next
#         return stop if region == stop
#         @narray.unsafe_fetch_region(region.as(Array(SteppedRange)))
#     end
# end

# https://en.wikiversity.org/wiki/Lexicographic_and_colexicographic_order

abstract class RegionIterator(A, T)
  include Iterator(Tuple(T, Array(Int32)))
  @coord : Array(Int32)

  @first : Array(Int32)
  @last : Array(Int32)
  @step : Array(Int32)

  def initialize(@narr : A, region = nil, reverse = false)
    if region
      @first = Array(Int32).new(initial_capacity: region.size)
      @last = Array(Int32).new(initial_capacity: region.size)
      @step = Array(Int32).new(initial_capacity: region.size)

      region.each_with_index do |region, idx|
        @first[idx] = region[idx].begin
        @last[idx] = region[idx].end
        @step[idx] = region[idx].step
      end
    else
      @first = [0] * @narr.dimensions
      @last = @narr.shape.map &.pred
      @step = [1] * @narr.dimensions
    end

    if reverse
      @last, @first = @first, @last
      @step.map! &.-
    end

    @coord = @first.dup
    setup_coord(@coord, @step)
  end

  protected def initialize(@narr, @first, @last, @step)
    @coord = @first.dup
    setup_coord(@coord, @step)
  end

  def reverse!
    @last, @first = @first, @last
    @step.map! &.-

    @coord = @first.dup
    setup_coord(@coord, @step)
    self
  end

  def reverse
    typeof(self).new(@narr, @last, @first, @step.map &.-)
  end

  abstract def setup_coord(coord, step)
  abstract def next
end

private class LexRegionIterator(A, T) < RegionIterator(A, T)
  def setup_coord(coord, step)
    coord[-1] -= step[-1]
  end

  def next
    (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
      if @step[i] > 0 ? (@coord[i] >= @last[i]) : (@coord[i] <= @last[i])
        @coord[i] = @first[i]
        return stop if i == 0 # most sig
      else
        @coord[i] += @step[i]
        break
      end
    end
    {@narr.unsafe_fetch_element(@coord), @coord}
  end
end

private class ColexRegionIterator(A, T) < RegionIterator(A, T)
  def setup_coord(coord, step)
    coord[0] -= step[0]
  end

  def next
    @coord.each_index do |i| # ## least sig .. most sig
      if @step[i] > 0 ? (@coord[i] >= @last[i]) : (@coord[i] <= @last[i])
        @coord[i] = @first[i]
        return stop if i == @coord.size - 1 # most sig
      else
        @coord[i] += @step[i]
        break
      end
    end
    {@narr.unsafe_fetch_element(@coord), @coord}
  end
end

# private class LexChunkIterator(A)
#     include RegionHelpers
#     include Iterator(Tuple(A, Array(SteppedRange)))
# end

# private class ColexChunkIterator(A)
#     include Iterator(A)
# end

# private class SliceIterator(A) < RegionIterator(A)

#     @region : Array(SteppedRange)

#     def initialize(@narray : A, @axis = 0)
#         @region = @narray.shape.map do |dim|
#             SteppedRange.new(0..(dim - 1), 1)
#         end

#         @index = -1
#         @region[@axis] = SteppedRange.new(@index)
#     end

#     def next
#         if @region[@axis].begin < @narray.shape[@axis] - 1
#             @index += 1
#             @region[@axis] = SteppedRange.new(@index)
#             @region
#         else
#             stop
#         end
#     end
# end

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }

small_arr = NArray.build([3, 3]) { |coord, index| index }

puts "Lexicographic:"
LexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem, coord }

puts "Colexicographic:"
ColexRegionIterator(typeof(small_arr), Int32).new(small_arr).each { |elem, coord| puts elem, coord }

puts "Reverse Lexicographic:"
LexRegionIterator(typeof(small_arr), Int32).new(small_arr, reverse: true).each { |elem, coord| puts elem, coord }

puts "Reverse Colexicographic:"
ColexRegionIterator(typeof(small_arr), Int32).new(small_arr, reverse: true).each { |elem, coord| puts elem, coord }

puts "Reversed Lexicographic:"
ColexRegionIterator(typeof(small_arr), Int32).new(small_arr).reverse.each { |elem, coord| puts elem, coord }

# puts "Slices, axis 0:"
# SliceIterator.new(small_arr).each {|elem| puts elem}

# puts "Slices, axis 1:"
# SliceIterator.new(small_arr, axis=1).each {|elem| puts elem}

# iter.each {|elem| puts elem}

# item_iter = ItemIterator(NArray(Int32), Int32).new(arr)
# item_iter.each {|elem| puts elem}
