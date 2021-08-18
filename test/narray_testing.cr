require "../src/ph-core"
require "spec"
require "complex"

include Phase

# tags:
# "Cr-v1.1+"
# "OOS" - outside our scope (uses Crystal stdlib or some other package, not Phase)

def generate
  10.times { |i| yield i }
end

verbose = true

# These are some exercises from https://github.com/ruby-numo/numo-narray/wiki/100-narray-exercises.
# They are for numpy, but we want our library to be able to do everything so we're making
# sure they can be ported

describe "ph-core exercises:" do
  context "3. Create a null vector of size 10" do
    it do
      narr = NArray.fill([10], 0) # in the future, NArray(Int32).zeros([10])
    end
  end

  context "4. Find memory size of an NArray" do
    it do
      narr = NArray.fill([10], 0)
      memsize = narr.buffer.bytesize
      puts "#{memsize} bytes\n"
    end
  end

  context "6. Create a null vector of size 10 but the fifth value is 1" do
    it do
      narr = NArray.fill([10], 0)
      narr[4] = 1
      puts narr
    end
  end

  context "7. Create a vector with values ranging from 10 to 49" do
    it do
      narr = NArray.new((10..49).to_a)
      puts narr
    end
  end

  # Broken?
  pending "8. Reverse a vector" do
    it do
      narr = NArray.fill([10], 0)
      narr = narr[-1..-1..]
      puts narr
    end
  end

  context "9. Create a 3x3 matrix with values ranging from 0 to 8" do
    it do
      narr = NArray.build(3, 3) { |_, i| i }
      puts narr
    end
  end

  context "10. Find indices of non-zero elements from [1, 2, 0, 0, 4, 0]" do
    it do
      narr = NArray.new([1, 2, 0, 0, 4, 0])
      narr.each_with_index { |e, idx| puts idx if e.zero? }
    end
  end

  # TODO: diagonal iterators? or at least a convenience method to populate the diagonal
  context "11. Create a 3x3 identity matrix" do
    it do
      narr = NArray.build(3, 3) { |c| (c[0] == c[1]).to_unsafe }
      puts narr
    end
  end

  context "12. Create a 3x3x3 NArray with random values" do
    it do
      narr = NArray.build(3, 3, 3) { Random.rand }
      puts narr
    end
  end

  context "13. Create a 10x10 NArray with random values and find the minimum and maximum values" do
    it do
      narr = NArray.build(10, 10) { Random.rand }
      min, max = narr.minmax
      puts min, max
    end
  end

  context "14. Create a random vector of size 30 and find the mean value" do
    it do
      narr = NArray.build(30) { Random.rand }
      puts narr.sum / narr.size
    end
  end

  context "15. Create a 2D array with 1 on the border and 0 inside" do
    it do
      narr = NArray.fill([10, 10], 1)
      narr[[1...-1] * 2] = 0
      puts narr
    end
  end

  context "16. Add a border of zeros to an existing array" do
    it do
      # TODO: Use pad instead
      narr = NArray.build(5, 5) { Random.rand }
      narr_outer = NArray.fill([7, 7], 0f64)
      narr_outer[[1...-1] * 2] = narr
      puts narr_outer
    end
  end

  context "18. Create a 5x5 matrix with 1,2,3,4 just below the diagonal" do
    it do
      narr = NArray.build(5, 5) { |c| c[1] + 1 == c[0] ? c[0] : 0 }
      puts narr
    end
  end

  context "19. Create an 8x8 matrix and fill it with a checkerboard pattern" do
    it do
      narr = NArray.build(8, 8) { |c, i| c.sum % 2 }
      puts narr
    end
  end

  context "20. Consider a (6,7,8) shape array, what is the index (x,y,z) of the 100th element?" do
    it do
      puts NArray::BufferUtil.index_to_coord(100, [6, 7, 8])
    end
  end

  context "21. Create a checkerboard 8x8 matrix using the tile function" do
    it "(class method)" do
      puts NArray.tile(NArray.new([[0, 1], [1, 0]]), [4, 4])
    end

    it "(instance method)" do
      puts NArray.new([[0, 1], [1, 0]]).tile([4, 4])
    end
  end

  context "22. Normalize a 5x5 random matrix" do
    it do
      narr = NArray.build(5, 5) { Random.rand }
      zmin, zmax = narr.minmax
      narr = (narr - zmin)/(zmax - zmin)
      puts narr
    end
  end

  context "23. Create a custom dtype that describes a color as four unisgned bytes (RGBA)" do
    # not_supported
    # TODO: should we support this? I don't think so but there might be some argument for
  end

  context "24. Multiply a 5x3 matrix by a 3x2 matrix (real matrix product)" do
    # not_supported
    # TODO: matrix multiplication! Is there good reason to put it in core vs linalg?
  end

  context "25. Given a 1D array, negate all elements which are between 3 and 8, in place." do
    it do
      z = NArray.new((0..11).to_a)
      z[(3 < z) & (z <= 8)] *= -1
      puts z
      # faster
      z.map_with_index! { |el, i| i.in?(4..8) ? -el : el }
    end
  end

  context "27. Consider an integer vector Z, which of these expressions are legal?" do
    it do
      # TODO: what are these supposed to do and should we support the behaviour and/or the syntax?
      z = NArray.new((0..5).to_a)
      puts "Elementwise exponentiation: #{z**z}"
      puts "Complex: #{1.i*z}"
    end
  end

  context "28. What are the result of the following expressions?" do
    it do
      puts "\t(i.e.: NaN handling is consistent with stdlib)"
      zero = NArray.new([0])
      puts zero / zero
      begin
        zero // zero
      rescue DivisionByZeroError
        puts "Threw division by 0 (consistent with stdlib)"
      end
    end
  end
  # DISCUSS: typecasting from NaN?? print(np.array([np.nan]).astype(int).astype(float))

  # TODO: 29
  # TODO: 30

  # 31 not (currently) applicable (we don't have warnings)

  # OOS (Outside our scope)
  context "32. Is the following expression true?" do
    it do
      puts Math.sqrt(-1) == Math.sqrt(-1 + 0.i)
    end
  end

  # OOS
  context "33. How to get the dates of yesterday, today and tomorrow?" do
    it do
      today = Time.local.date
      yesterday = 1.day.ago.date
      tomorrow = 1.day.from_now.date
      puts yesterday, today, tomorrow
    end
  end

  # OOS
  context "34. How to get all the dates corresponding to the month of July 2016?", tags: "Cr-v1.1+" do
    it do
      jul1 = Time.utc(2016, 7, 1)
      puts jul1.step(by: 1.day, to: jul1 + 1.month).to_a
    end
  end

  context "35. Compute ((A+B)*(-A/2)) in place (without copy)" do
    it do
      # DISCUSS: do we want special notation?
      a = NArray.fill([3], 1.0)
      b = NArray.fill([3], 2.0)
      puts (a + b)*(-a/2)
      a.map_with_coord! do |el, coord|
        (el + b.get(coord))*(-el/2)
      end
      puts a
    end
  end

  context "36. Extract the integer part of a random array using 5 different methods" do
    # not_supported
  end

  context "37. Create a 5x5 matrix with row values ranging from 0 to 4" do
    it do
      narr = NArray.build(5, 5) { |c| c[0] }
      # narr = NArray[0, 1, 2, 3, 4].tile([5, 5]) # make this happen
      puts narr
      # DISCUSS: is the ability to add different-dimensioned objects like this valuable???
    end
  end

  context "38. Consider a generator function that generates 10 integers and use it to build an array" do
    it do
      # no way it seems to directly pipe results of this into an NArray

      y = [] of Int32
      generate { |x| y << x }
      puts NArray.new(y)
    end
  end

  context "39. Create a vector of size 10 with values ranging from 0 to 1, both excluded" do
    it do
      # TODO: make this better. worth adding a linspace?
      puts NArray.build(10) { |_, i| (i + 1)/11 }
    end
  end

  context "40. Create a random vector of size 10 and sort it" do
    # not_supported
  end

  context "41. How to sum a small array faster than np.sum?" do
    it do
      # NOTE: speed unknown
      narr = NArray.build(10) { |c, i| i }
      puts narr.sum
    end
  end

  context "42. Consider two random array A anb B, check if they are equal" do
    it do
      a = NArray.build(5) { Random.rand(2) }
      b = NArray.build(5) { Random.rand(2) }
      puts a == b
    end
  end

  context "43. Make an array immutable (read-only)" do
    # not_supported
    # TODO: this should be relatively easy since Slice implements a read-only flag
  end

  context "44. Consider a random 10x2 matrix representing cartesian coordinates, convert them to polar coordinates" do
    it do
      narr = NArray.build(10, 2) { Random.rand }
      r = [] of Float64
      t = [] of Float64
      # slice[0, preserve: true]
      # slice[[0, 1, 2], preserve: true]

      narr.slices.each do |slice|
        x, y = slice
        r << Math.sqrt(x**2 + y**2)
        t << Math.atan2(y, x)
      end
      puts r, t
    end
  end

  # TODO: 46
  # TODO: 47

  context "48. Print the minimum and maximum representable value for each numpy scalar type" do
    it do
      {% begin %}
      {% for type in Int.all_subclasses %}
        {% unless type == BigInt %}
          puts "#{{{type}}}: #{{{type}}::MIN}, #{{{type}}::MAX}"
        {% end %}
      {% end %}
      {% end %}
      # TODO: try this without macro? Don't think :: operator works on variables of type "class" so difficult to iterate classes
    end
  end

  context "50. How to find the closest value (to a given scalar) in an array?" do
    # TODO
    # Is there a method in Enumerable to get the index of the min?
  end
end
