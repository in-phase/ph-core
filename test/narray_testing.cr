require "../src/lattice"

include Lattice

# These are some exercises from https://github.com/ruby-numo/numo-narray/wiki/100-narray-exercises.
# They are for numpy, but we want our library to be able to do everything so we're making
# sure they can be ported

puts "Create a null vector of size 10"
puts narr = NArray.fill([10], 0) # in the future, NArray(Int32).zeros([10])

puts "Find memory size of an NArray"
memsize = narr.buffer.bytesize
puts "#{memsize} bytes\n"

puts "Create a null vector of size 10 but the fifth value is 1"
narr[4] = 1
puts narr

puts "Create a vector with values ranging from 10 to 49"
narr = NArray.new((10..49).to_a)
puts narr

puts "Reverse a vector"
narr = narr[-1..-1..]
puts narr

puts "Create a 3x3 matrix with values ranging from 0 to 8"
narr = NArray.build(3, 3) { |_, i| i }
puts narr

puts "Find indices of non-zero elements from [1, 2, 0, 0, 4, 0]"
narr = NArray.new([1, 2, 0, 0, 4, 0])
narr.each_with_index { |e, idx| puts idx if e.zero? }

puts "Create a 3x3 identity matrix"
narr = NArray.build(3, 3) { |c| (c[0] == c[1]).to_unsafe }
puts narr

puts "Create a 3x3x3 NArray with random values"
narr = NArray.build(3, 3, 3) { Random.rand }
puts narr

puts "Create a 10x10 NArray with random values and find the minimum and maximum values"
narr = NArray.build(10, 10) { Random.rand }
min, max = narr.minmax
puts min, max

puts "Create a random vector of size 30 and find the mean value"
narr = NArray.build(30) { Random.rand }
puts narr.sum / narr.size

puts "Create a 2D array with 1 on the border and 0 inside"
narr = NArray.fill([10, 10], 1)
narr[[1...-1] * 2] = 0
puts narr

puts "Add a border of zeros to an existing array"
# TODO: Use pad instead
narr = NArray.build(5, 5) { Random.rand }
narr_outer = NArray.fill([7, 7], 0f64)
narr_outer[[1...-1] * 2] = narr
puts narr_outer

puts "Create a 5x5 matrix with 1,2,3,4 just below the diagonal"
narr = NArray.build(5, 5) { |c| c[1] + 1 == c[0] ? c[0] : 0 }
puts narr

puts "Create an 8x8 matrix and fill it with a checkerboard pattern"
narr = NArray.build(4,4,4) { |c, i| c.sum % 2 }
puts narr

puts "Consider a (6,7,8) shape array, what is the index (x,y,z) of the 100th element?"
puts NArray::BufferUtil.index_to_coord(100, [6,7,8])

module Lattice::NArray(T)
  protected class WrappedLexIterator(T) < CoordIterator(T)
    getter smaller_coord : Array(T)
    @smaller_shape : Array(T)

    def initialize(region : IndexRegion(T), @smaller_shape)
      super(region)
      @smaller_coord = wrap_coord(@first)
    end

    def initialize(region_literal, @smaller_shape)
      super(IndexRegion(T).new(region_literal))
      @smaller_coord = wrap_coord(@first)
    end

    def wrap_coord(coord)
        coord.map_with_index { |axis, idx| axis % @smaller_shape[idx] }
    end

    def advance_coord
      (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
        if @coord[i] == @last[i]
          @coord[i] = @first[i]
          @smaller_coord[i] = @coord[i] % @smaller_shape[i]
          return stop if i == 0 # most sig
        else
          @coord[i] += @step[i]
          @smaller_coord[i] = @coord[i] % @smaller_shape[i]
          break
        end
      end
      @coord
    end
  end

    def self.tile(narr : MultiIndexable(T), counts : Enumerable)
    shape = narr.shape.map_with_index { |axis, idx| axis * counts[idx] }
    
    iter = WrappedLexIterator.new(IndexRegion.cover(shape), narr.shape).each
    
    build(shape) do |coord|
        iter.next
        narr.get(iter.smaller_coord)
    end
    end

    def tile(counts : Enumerable) : self
        NArray.tile(self, counts)
    end
end


class Lattice::NArray(T)
end

puts "Create a checkerboard 8x8 matrix using the tile function"
# TODO make a real tile function
# puts NArray.tile(NArray.new([[0,1],[1,0]]), [4,4])
puts NArray.new([[0,1],[1,0]]).tile([4,4])

puts "Normalize a 5x5 random matrix"
narr = NArray.build(5, 5) { Random.rand }
puts narr
zmin, zmax = narr.minmax
narr = (narr - zmin)/(zmax - zmin)
puts narr