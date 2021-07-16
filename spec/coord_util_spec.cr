require "./spec_helper"

include Phase::CoordUtil

describe Phase::CoordUtil do 
  describe ".has_index?" do
    shape = [1, 5, 1]
    it "determines whether a positive index is in bounds" do
      has_index?(4, shape, 1).should be_true
      has_index?(5, shape, 1).should be_false
    end
    it "determines if a negative index is in bounds" do
      has_index?(-5, shape, 1).should be_true
      has_index?(-6, shape, 1).should be_false
    end
    it "handles empty axes" do
      has_index?(0, [0, 2], 0).should be_false
    end
    it "handles large sizes" do
      max_shape = [Int32::MAX]
      has_index?(Int32::MAX, max_shape, 0).should be_false
      has_index?(Int32::MAX - 1, max_shape, 0).should be_true

      has_index?(Int32::MIN, max_shape, 0).should be_false
      has_index?(Int32::MIN + 1, max_shape, 0).should be_true
    end
    it "fails predictably when given an invalid axis" do
      expect_raises(IndexError) do
        has_index?(-2, shape, 4)
      end
    end
  end
  describe ".has_coord?" do
    shape = [1, 3, 5]
    it "correctly labels an in-bounds canonical coordinate" do
      has_coord?([0, 2, 4], shape).should be_true
    end
    it "correctly labels a non-canonical, in-bounds coordinate" do
      has_coord?([-1, -3, -5], shape).should be_true
      has_coord?([0, -1, -2], shape).should be_true
    end
    it "correctly detects out-of-bounds coordinates" do
      has_coord?([1, 2, 4], shape).should be_false
      has_coord?([0, 2, -6], shape).should be_false
      has_coord?([-Int32::MAX, Int32::MAX, 0], shape).should be_false
    end
    it "rejects coordinates of the wrong dimensionality" do
      has_coord?([0, 0], shape).should be_false
      has_coord?([0, 0, 0, 0], shape).should be_false
      has_coord?([2, 2], [4, 3, 1, 1]).should be_false
      has_coord?([2, 2, 0, 0], [4, 3]).should be_false
    end
    it "handles empty axes" do
      has_coord?([4, 2, 5], [10, 10, 0]).should be_false
    end
    it "handles large sizes" do
      max_shape = [Int32::MAX, Int32::MAX]
      has_coord?([Int32::MAX - 1, Int32::MIN + 1], max_shape).should be_true
      has_coord?([Int32::MAX - 1, Int32::MAX], max_shape).should be_false
    end
  end
  describe ".canonicalize_index" do
    shape = [0, 1, 10, Int32::MAX]
    it "preserves legal positive indices" do
      canonicalize_index(9, shape, 2).should eq 9
      canonicalize_index(0, shape, 3).should eq 0
    end
    it "converts legal negative indices" do
      canonicalize_index(Int32::MIN + 1, shape, 3).should eq 0
      canonicalize_index(-10, shape, 2).should eq 0
      canonicalize_index(-1, shape, 2).should eq 9
      canonicalize_index(-1, shape, 1).should eq 0
    end
    it "raises an IndexError when given an invalid index" do
      expect_raises(IndexError) do
        canonicalize_index(-2, shape, 1)
      end
      expect_raises(IndexError) do
        canonicalize_index(0, shape, 0)
      end
    end
  end

  describe ".canonicalize_coord" do
    shape = [1, 10, Int32::MAX]
    it "preserves canonical coordinates" do
      tests = [[0, 9, Int32::MAX - 1], [0, 0, 0], [0, 5, 200]]
      tests.each do |coord|
        canonicalize_coord(coord, shape).should eq coord
      end
    end
    it "converts any negative indices to positive" do
      tests = [[-1, -10, Int32::MIN + 1], [-1, -1, -1], [0, -5, 200]]
      expected = [[0, 0, 0], [0, 9, Int32::MAX - 1], [0, 5, 200]]
      tests.each_with_index do |coord, i|
        canonicalize_coord(coord, shape).should eq expected[i]
      end
    end
    it "raises an IndexError if at least one index is out of range" do
      tests = [shape, [0, 0, Int32::MAX], [0, -11, Int32::MIN + 1]]
      tests.each do |coord|
        expect_raises(IndexError) do
          canonicalize_coord(coord, shape)
        end
      end
    end
  end
end
