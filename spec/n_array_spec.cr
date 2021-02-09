require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
  describe NArray do
    it "canonicalizes ranges" do
      narr = NArray.fill([4], 0)

      good_ranges = [0...4, -1..0, 1.., 1..., ..2, -2..-1, -2...-5, 1..1]
      canon = [0..3, 3..0, 1..3, 1..3, 0..2, 2..3, 2..0, 1..1]
      good_ranges.each_with_index do |range, i|
        range, dir = narr.canonicalize_range(range, 0)
        range.should eq canon[i]
      end
      bad_ranges = [-5..-3, 2..4, 1...1]
      bad_ranges.each do |range|
        expect_raises(IndexError) do
          narr.canonicalize_range(range, 0)
        end
      end
    end

    it "makes slices" do
      narr = NArray.fill([2, 2], 0)
      # puts narr.extract_buffer_indices([1,0])
      narr = NArray.fill([3, 3, 3], 0)
      # puts narr.extract_buffer_indices([0..2 , 0]) # first item of each rows 1-3

      # narr = NArray.build([3,3,3]) {|i| i} # Builds an NArray where the value of each element is its coords
      narr = NArray.fill([3, 3, 3], 0)

      narr[1..2, 1..2, 1..2] = 5
      # puts narr

      # matrix[2, ..]
      # mapping = [1]
      # mapping[sliced_array_axis] == where in matrix you must put that index

      # output_arr = new(shape) do |indices|
      # goes from output array index to full array index

      # end

      # begin >= -shape, < shape
      # end >= -shape, < shape
      # 1...1 raises indexerror? (range of no elements)
      # 3..1 flips horizontally
      # ... -> all
      # 2.. -> index 2 (inclusive) to end
      # ..-1 -> up to that
      # .. -> all

      # img : 128 x 64 x 3, we want a 32 x 32 square from the top left corner
      # img[0...32, 0...32] <- type: Range (not full depth)

      # just the top row:
      # img[..., 6] <- Range and Integer (not full depth)

      # just red:
      # img[..,..,0] <- Range/Integer, at full depth

      # img[.., -32..32] <- puts the beach above the sky

      # img[0..-10] <- everything but the last ten rows

      # img[-10..-5] <- Only the five rows five before the end

      # img[-1..0] <- horizontal flip of the image
      # img[0..-1] <- identity

      # boolean mask: find all elems that are 0 and make them 1
      # mask = img[..,..] == 0
      # img[mask] = 1

    end
    it "edits values by a boolean map" do
      mask = NArray(Bool).build([3, 3]) { |coord| coord[0] != coord[1] }

      narr = NArray.fill([3, 3], 0)

      narr[mask] = 1
      # puts narr

    end

    it "properly packs an n-dimensional index" do
      shape = [3, 7, 4]
      narr = NArray.fill(shape, 0)
      narr.coord_to_index([1, 1, 1]).should eq (28 + 4 + 1)

      # TODO check edge cases, failure cases
      shape = [5]
      narr = NArray.fill(shape, 0)
      narr.coord_to_index([2]).should eq 2
    end

    it "properly packs and unpacks an n-dimensional index" do
      shape = [3, 7, 4]
      narr = NArray.fill(shape, 0)

      100.times do
        random_index = shape.map { |dim| (Random.rand * dim).to_u32 }
        packed = narr.coord_to_index(random_index)
        narr.index_to_coord(packed).should eq random_index
      end
    end

    it "exposes unpacked indices to the user in a constructor" do
      narr = NArray(Int32).build([3, 3, 3]) do |coord|
        next 1 if coord[0] == coord[1] == coord[2]
        next 0
      end
      narr[2, 2, 2] = 437
      # puts narr

      # pp narr
    end

    it "can access an element given a fully-qualified index" do
      shape = [1, 2, 3]
      narr = NArray(Int32).new(shape) { |i| i }
      narr.get(0, 1, 2).should eq 5
      narr.get(0, 0, 0).should eq 0
      expect_raises(IndexError) do
        narr.get(1, 1, 1)
      end
    end

    it "creates an NArray of primitives" do
      arr = NArray.fill([1], 0f64)
      arr.should_not be_nil
      arr.shape.should eq [1]
      arr.get(0).should eq 0f64
    end
    it "can create an NArray of non-primitives" do
      arr = NArray.fill([2, 2], "HELLO")
      arr.should_not be_nil
      arr.shape.should eq [2, 2]
      arr.get(1, 1).should eq "HELLO"
    end
    it "can retrieve a scalar from a single-element vector" do
      NArray.fill([1], 5).to_scalar.should eq 5
    end
    it "throws an error if trying to retrieve scalar from an array of wrong dimensions" do
      # Empty array
      expect_raises(DimensionError) do
        NArray.fill([0], 5).to_scalar
      end
      # Vector
      expect_raises(DimensionError) do
        NArray.fill([2], 5).to_scalar
      end
      # Column vector
      expect_raises(DimensionError) do
        NArray.fill([1, 2], 5).to_scalar
      end
      # Single-element nested array
      expect_raises(DimensionError) do
        NArray.fill([1, 1], 5).to_scalar
      end
    end
    it "returns a safe copy of its shape" do
      arr = NArray.fill([3, 7], 0f64)
      shape1 = arr.shape
      shape1.should eq [3, 7]
      shape1[0] = 4
      arr.shape.should eq [3, 7]
    end
    # TODO revise tests for shallow, and deep, copy once values can be edited
    it "creates a shallow copy" do
      one = NArray.fill([1], MutableObject.new)
      two = one.dup

      one.get(0).should be two.get(0)
    end
    it "creates a deep copy" do
      one = NArray.fill([1], MutableObject.new)
      two = one.clone

      one.get(0).should_not be two.get(0)
    end

    it "can do Enumerable stuff" do
      # override
      # zip
      # map

      narr_small = NArray(Int64).new([2, 3]) { |i| (i + 1).to_i64 }
      # puts narr_small.product

      # don't override
      # puts narr.partition {|i| i % 2 == 0}

      # stringnarr = NArray(String).new([3,3,3]) { |i| "na" * i + " batman\n" }

      # puts stringnarr.join

      narr = NArray(Int32).new([2, 3]) { |i| i + 2 }
      # puts narr

      # puts narr.reshape([3, 2])
    end
    # TODO formalize or remove
    it "can make other nifty arrays (possibly)" do
      one = NArray.fill([3, 2], 1)
      two = NArray.wrap(1, 7, 9, 4)
      three = NArray.fill([3, 2], 0)

      # NArray.wrap(one, two, pad: true)
      NArray.wrap(one, three)

      expect_raises(DimensionError) do
        NArray.wrap(one, two)
      end

      # puts NArray.wrap(1, 7, "foo")

      # puts NArray.new([[1, 2, 3], ["hello", 1f64, 10], [12, 13, 14]])

    end
    it "can generalize unknown methods" do
      a = NArray(Int32).new([2, 2, 2]) { |i| i }
      b = NArray(Int32).new([2, 2, 2]) { |i| 20 - i }

      strarr = NArray(String).new([2, 2, 2]) { |i| "Hello World" }
      ones = NArray(Int32).new([2, 2, 2]) { |i| 1 }

      # puts a + b

      puts "Hello World".byte_slice(3, 1)

      # puts strarr.byte_slice(0, a)
      # puts strarr.byte_slice(a, 2)
      puts strarr.byte_slice(a, ones)
      
      # This should cause compile error!
      # puts strarr.extreme(a)

      # This should cause a different compile error :)
      # puts strarr.byte_slice("party", 16, :cool)
    end
    it "can iterate slices" do
      b = NArray(Int32).new([2, 2, 2]) { |i| 20 - i }

      b.slices.each do |slice|
        puts slice.sum
      end

    end
  end
end