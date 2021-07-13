require "../src/lattice"

include Lattice

def not_supported 
    puts %(            ===================================
                not currently supported
            ===================================)
end

# These are some exercises from https://github.com/ruby-numo/numo-narray/wiki/100-narray-exercises.
# They are for numpy, but we want our library to be able to do everything so we're making
# sure they can be ported

puts "3. Create a null vector of size 10"
puts narr = NArray.fill([10], 0) # in the future, NArray(Int32).zeros([10])

puts "4. Find memory size of an NArray"
memsize = narr.buffer.bytesize
puts "#{memsize} bytes\n"

puts "6. Create a null vector of size 10 but the fifth value is 1"
narr[4] = 1
puts narr

puts "7. Create a vector with values ranging from 10 to 49"
narr = NArray.new((10..49).to_a)
puts narr

puts "8. Reverse a vector"
narr = narr[-1..-1..]
puts narr

puts "9. Create a 3x3 matrix with values ranging from 0 to 8"
narr = NArray.build(3, 3) { |_, i| i }
puts narr


puts "10. Find indices of non-zero elements from [1, 2, 0, 0, 4, 0]"
narr = NArray.new([1, 2, 0, 0, 4, 0])
narr.each_with_index { |e, idx| puts idx if e.zero? }

# TODO: diagonal iterators? or at least a convenience method to populate the diagonal
puts "11. Create a 3x3 identity matrix"
narr = NArray.build(3, 3) { |c| (c[0] == c[1]).to_unsafe }
puts narr

puts "12. Create a 3x3x3 NArray with random values"
narr = NArray.build(3, 3, 3) { Random.rand }
puts narr

puts "13. Create a 10x10 NArray with random values and find the minimum and maximum values"
narr = NArray.build(10, 10) { Random.rand }
min, max = narr.minmax
puts min, max

puts "14. Create a random vector of size 30 and find the mean value"
narr = NArray.build(30) { Random.rand }
puts narr.sum / narr.size

puts "15. Create a 2D array with 1 on the border and 0 inside"
narr = NArray.fill([10, 10], 1)
narr[[1...-1] * 2] = 0
puts narr

puts "16. Add a border of zeros to an existing array"
# TODO: Use pad instead
narr = NArray.build(5, 5) { Random.rand }
narr_outer = NArray.fill([7, 7], 0f64)
narr_outer[[1...-1] * 2] = narr
puts narr_outer

puts "18. Create a 5x5 matrix with 1,2,3,4 just below the diagonal"
narr = NArray.build(5, 5) { |c| c[1] + 1 == c[0] ? c[0] : 0 }
puts narr

puts "19. Create an 8x8 matrix and fill it with a checkerboard pattern"
narr = NArray.build(8,8) { |c, i| c.sum % 2 }
puts narr

puts "20. Consider a (6,7,8) shape array, what is the index (x,y,z) of the 100th element?"
puts NArray::BufferUtil.index_to_coord(100, [6,7,8])

class Lattice::NArray(T)
  private class WrappedLexIterator(T) < CoordIterator(T)
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

puts "21. Create a checkerboard 8x8 matrix using the tile function"
# puts NArray.tile(NArray.new([[0,1],[1,0]]), [4,4])
puts NArray.new([[0,1],[1,0]]).tile([4,4])

puts "22. Normalize a 5x5 random matrix"
narr = NArray.build(5, 5) { Random.rand }
zmin, zmax = narr.minmax
narr = (narr - zmin)/(zmax - zmin)
puts narr

puts "23. Create a custom dtype that describes a color as four unisgned bytes (RGBA)"
not_supported
# TODO: should we support this? I don't think so but there might be some argument for

puts "24. Multiply a 5x3 matrix by a 3x2 matrix (real matrix product)"
not_supported
# TODO: matrix multiplication! Is there good reason to put it in core vs linalg?

puts "25. Given a 1D array, negate all elements which are between 3 and 8, in place."
z = NArray.new((0..11).to_a)
z[(3 < z) & (z <= 8)] *= -1
puts z
# faster 
z.map_with_index! {|el, i| i.in?(4..8) ? -el : el}

# TODO: do we want to support this type of boolean indexing? 
# `z[(3 < z) && (z <= 8)] *= -1`
# May not be possible without our own parser? May not be necessary either?

puts "27. Consider an integer vector Z, which of these expressions are legal?"
# TODO: what are these supposed to do and should we support the behaviour and/or the syntax?
require "complex"
z = NArray.new((0..5).to_a)
puts "Elementwise exponentiation: #{z**z}"
puts "Complex: #{1.i*z}"

puts "28. What are the result of the following expressions?"
puts "\t(i.e.: NaN handling is consistent with stdlib)"
zero = NArray.new([0])
puts zero / zero
begin
  zero // zero
rescue DivisionByZeroError
  puts "Threw division by 0 (consistent with stdlib)"
end
# DISCUSS: typecasting from NaN?? print(np.array([np.nan]).astype(int).astype(float))

# TODO: 29
# TODO: 30

# 31 not (currently) applicable (we don't have warnings)

# OOS (Outside our scope)
puts "32. Is the following expression true?"
puts Math.sqrt(-1) == Math.sqrt(-1 + 0.i)

# OOS
puts "33. How to get the dates of yesterday, today and tomorrow?"
today = Time.local.date
yesterday = 1.day.ago.date
tomorrow = 1.day.from_now.date
puts yesterday, today, tomorrow 

puts "34. How to get all the dates corresponding to the month of July 2016?"
not_supported
# OOS; but in Crystal 1.1 should become trivial
# https://github.com/crystal-lang/crystal/pull/10279

puts "35. Compute ((A+B)*(-A/2)) in place (without copy)"
# DISCUSS: do we want special notation?
a = NArray.fill([3], 1.0)
b = NArray.fill([3], 2.0)
puts (a+b)*(-a/2)
a.map_with_coord! do |el, coord|
  (el + b.get(coord))*(-el/2)
end
puts a

puts "36. Extract the integer part of a random array using 5 different methods"
not_supported


puts "37. Create a 5x5 matrix with row values ranging from 0 to 4"
narr = NArray.build(5,5) {|c,_| c[0]}
puts narr
# DISCUSS: is the ability to add different-dimensioned objects like this valuable???

puts "38. Consider a generator function that generates 10 integers and use it to build an array"
# no way it seems to directly pipe results of this into an NArray
def generate
  10.times {|i| yield i}
end
y = [] of Int32
generate {|x| y << x}
puts NArray.new(y)

puts "39. Create a vector of size 10 with values ranging from 0 to 1, both excluded"
# TODO: make this better. worth adding a linspace?
puts NArray.build(10) {|_,i| (i + 1)/11 }

puts "40. Create a random vector of size 10 and sort it"
not_supported


puts "41. How to sum a small array faster than np.sum?"
# NOTE: speed unknown
narr = NArray.build(10) {|c,i| i}
puts narr.sum

puts "42. Consider two random array A anb B, check if they are equal"
a = NArray.build(5) {Random.rand(2)}
b = NArray.build(5) {Random.rand(2)}
puts a == b

puts "43. Make an array immutable (read-only)"
not_supported
# TODO: this should be relatively easy since Slice implements a read-only flag

puts "44. Consider a random 10x2 matrix representing cartesian coordinates, convert them to polar coordinates"
narr = NArray.build(10,2) {Random.rand}
r = [] of Float64 
t = [] of Float64
# slice[0, preserve: true]
# slice[[0, 1, 2], preserve: true]
# slice.crop()
narr.slices.each do |slice|
  x,y = slice[0], slice[1]

  x,y = slice

  # x,y = slice.get(0,0), slice.get(0,1)
  # My first instinct: slice[0], slice[1]
  # NOTE: because of how the crystal compiler does multiple assignment 
  # (just converts source code to a sequence of var_x = tmp[x], https://github.com/crystal-lang/crystal/issues/132)
  # we can theoretically do multiple assignment to divide up NArrays! But would only work on first dimension.
  # Possible reason to go for dropping dimensions? (at bare minimum, in #slices)
  # Could become: x,y = slice
  # (unpacking block args is only for tuples - can't just "do |x,y|"
  
  # probelm 1: 
  # - slice is 2d; must use [0,0], [0,1]. When I am certian it's conceptually a vector it's a little annoying
  # - sqrt doesn't work on NArray (calls to_f)
  #     - added to_f to MultiIndexable
  # - slice[0,0] is 2x2, to_scalar doesn't work
  r << Math.sqrt(x**2 + y**2)
  t << Math.atan2(y,x)
end
puts r,t
# DISCUSS: 
# - numpy, numo support operations on arrays elementwise, eg np.sqrt(X). Consider method_missing, or alternatives, one more time?
      # X,Y = Z[:,0], Z[:,1]
      # R = np.sqrt(X**2+Y**2)
      # # TODO: possibly implement math functions to work on arrays
      # T = np.arctan2(Y,X)
      # print(R)
# - to_scalar allowing for squishing any number of dimensions? e.g. succeed on shape (1,1,1)
#       - I feel like we need at least one of dimension dropping or this... else to_scalar feels very pointless.
#       - also was a little annoying to specify the first "0" in slice.get here

# module MultiMath
#   def self.sqrt()
#     # square root algorithm
#   end
# end

# narr.sqrt
# Phase.sqrt(narr)

# (x**2 + y**2).sqrt

# # 
# class NArray
#   include MultiMath
# end

# TODO: 46
# TODO: 47

puts "48. Print the minimum and maximum representable value for each numpy scalar type"
{% begin %}
{% for type in Int.all_subclasses %}
  {% unless type == BigInt %}
    puts "#{{{type}}}: #{{{type}}::MIN}, #{{{type}}::MAX}"
  {% end %}
{% end %}
{% end %}
# TODO: try this without macro? Don't think :: operator works on variables of type "class" so difficult to iterate classes


# TODO: 49

puts "50. How to find the closest value (to a given scalar) in an array?"
# TODO
# Is there a method in Enumerable to get the index of the min?