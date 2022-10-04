require "./spec_helper.cr"
require "./test_narray.cr"

# Note: The correctness of NArray is used to boostrap the MultiIndexable tester,
# and thus NArray cannot use that tool for its testing. Other MultiIndexables
# can be tested using MultiIndexableTester without any circularity, however.
describe NArray do
  stock_narr = NArray.build(2,3) { |_, i| i }

  describe ".of_buffer" do
    it "creates an NArray from buffer and shape" do
      buf = Slice[1, 2, 3, 4, 5, 6]
      shape = [2, 3]
      narr = NArray.of_buffer(shape, buf)
      expected = NArray[[1, 2, 3], [4, 5, 6]]
      narr.should eq expected
    end

    it "raises for a shape whose computed size doesn't match the buffer size" do
      buf = Slice[1, 2, 3, 4, 5 ,6]
      shape = [4, 4]

      expect_raises ShapeError do
        NArray.of_buffer(shape, buf)
      end
    end

    it "clones shape" do
      shape = [1]
      narr = NArray.of_buffer(shape, Slice[2])
      narr.@shape.should_not be shape
    end
  end

  describe ".build" do
    it "creates an NArray from a shape and a block" do
      narr = NArray.build([2, 3]) { |c, i| c.sum * i }
      narr.should eq NArray[[0, 1, 4], [3, 8, 15]]
    end

    it "has a tuple-accepting form" do
      narr = NArray.build(2, 3) { |c, i| c.sum * i }
      narr.should eq NArray[[0, 1, 4], [3, 8, 15]]
    end

    it "raises for negative shape" do
      expect_raises ShapeError do
        NArray.build([-10, -10]) { |c, i| i }
      end
    end

    it "clones shape" do
      shape = [1]
      narr = NArray.build(shape) { 2 }
      narr.@shape.should_not be shape
    end
  end

  describe ".new(data : Enumerable)" do
    it "accepts data from a nested Array" do
      narr = NArray.new([[1, 2], [3, 4]])
      narr.should eq(NArray.build(2, 2) {|c, i| i + 1})
    end

    it "raises for inconsistent array shape" do
      expect_raises ShapeError do
        NArray.new([[1, 2], [3]])
      end
    end
  end

  describe ".[](*contents)" do
    it "accepts data from a nested Array", do
      narr = NArray[[1, 2], [3, 4]]
      narr.should eq(NArray.build(2, 2) {|c, i| i + 1})
    end

    it "raises for inconsistent array shape" do
      expect_raises ShapeError do
        NArray.[[1, 2], [3]]
      end
    end
  end

  describe ".fill" do
    it "creates a filled NArray" do
      narr = NArray.fill([2, 4], 'a')
      expected_buffer = Slice['a', 'a', 'a', 'a', 'a', 'a', 'a', 'a']
      narr.buffer.should eq expected_buffer
      narr.shape.should eq [2, 4]
    end

    it "clones shape" do
      shape = [1]
      narr = NArray.fill(shape, 2)
      narr.@shape.should_not be shape
    end
  end

  pending ".tile" do
  end

  pending "#pad" do
  end

  pending "#fit" do
  end

  pending ".wrap" do
  end

  describe "#shape" do
    it "returns the shape" do
      narr = NArray.fill([1, 2], 3)
      narr.shape.should eq [1, 2]
    end

    it "cannot be used to mutate the NArray" do
      narr = NArray.fill([1, 2], 3)
      narr.shape[1] = 20
      narr.shape.should eq [1, 2]
    end
  end

  describe "#size" do
    it "returns the number of elements in the buffer" do
      stock_narr.size.should eq stock_narr.buffer.size
    end

    it "is equal to the calculated value based on the shape" do
      stock_narr.size.should eq ShapeUtil.shape_to_size(stock_narr.shape)
    end
  end

  describe "#clone" do
    it "creates a new NArray with distinct buffer and shape, cloning objects recursively" do
      arr = ["should be cloned"]
      src_narr = NArray.fill([2, 3], arr)
      clone_narr = src_narr.clone

      clone_narr.shape.should eq [2, 3]
      clone_narr.@shape.should_not be src_narr.@shape
      clone_narr.buffer.should eq src_narr.buffer
      clone_narr.should_not be src_narr
      clone_narr.buffer[0].should_not be arr
    end
  end

  describe "#dup" do
    it "creates a new NArray with distinct buffer and shape, but same buffer references" do
      arr = ["should not be cloned"]
      src_narr = NArray.fill([2, 3], arr)
      clone_narr = src_narr.dup

      clone_narr.shape.should eq [2, 3]
      clone_narr.@shape.should_not be src_narr.@shape
      clone_narr.buffer.should eq src_narr.buffer
      clone_narr.should_not be src_narr
      clone_narr.buffer[0].should be arr
    end
  end

  describe "#flatten" do
    it "does not mutate self" do
      stock_narr.flatten
      stock_narr.shape.should eq [2, 3]
    end

    it "flattens properly" do
      flat = stock_narr.flatten
      flat.buffer.should eq stock_narr.buffer
      flat.shape.should eq [ShapeUtil.shape_to_size(stock_narr.shape)]
    end
  end

  describe "#reshape" do
    it "does not mutate self" do
      stock_narr.reshape(1, 6, 1)
      stock_narr.shape.should eq [2, 3]
    end

    it "works for change in shape and dimensionality" do
      stock_narr.reshape(1, 6, 1).shape.should eq [1, 6, 1]
    end
  end

  describe "#==" do
    it "returns true for equal NArrays" do
      same_narr = NArray.build(2,3) { |_, i| i }
      stock_narr.should eq same_narr
    end

    it "returns true for equal-shape empty NArrays" do
      a = NArray.build(0, 0, 0) {0}
      b = NArray.build(0, 0, 0) {0}
      a.should eq b
    end

    it "returns false for different NArrays" do
      other_narr = NArray.fill([2, 3], 9)
      other_narr.should_not eq stock_narr
    end

    it "returns false for a different type of MultiIndexable" do
      buf = stock_narr.buffer
      r_narr = RONArray.new([2, 3], buf.clone)
      stock_narr.should_not eq r_narr
    end
  end

  describe "#unsafe_fetch_chunk" do
    it "returns the correct data for a simple chunk" do
      region = IndexRegion.new([1, 0..2..2], bound_shape: [2, 3])
      expected = NArray[3, 5]
      stock_narr.unsafe_fetch_chunk(region).should eq expected
    end

    it "returns the correct data for a relative chunk" do
      region = IndexRegion.new([-2, -1..0], bound_shape: [2, 3])
      expected = NArray[2, 1, 0]
      stock_narr.unsafe_fetch_chunk(region).should eq expected
    end

    it "returns the empty NArray for a zero-size chunk" do
      region = IndexRegion.new([0...0, 0...0], bound_shape: [2, 3])
      expected = NArray.build(0, 0) { 0 }
      stock_narr.unsafe_fetch_chunk(region).should eq expected
    end
  end

  describe "#unsafe_fetch_element" do
    it "returns the correct value for a given coordinate" do
      value = stock_narr.unsafe_fetch_element([1, 1])
      value.should eq 4
    end
  end

  describe "#unsafe_set_chunk" do
    it "correctly sets data for a simple chunk (MultiIndexable source)" do
      region = IndexRegion.new([1, 0..2..2], bound_shape: [2, 3])
      src = NArray[6, 7]
      expected = NArray[[0, 1, 2], [6, 4, 7]]

      narr = stock_narr.clone
      narr.unsafe_set_chunk(region, src)
      narr.should eq expected
    end

    it "correctly sets data for a relative chunk (MultiIndexable source)" do
      region = IndexRegion.new([-2, -1..0], bound_shape: [2, 3])
      src = NArray[6, 7, 8]
      expected = NArray[[8, 7, 6], [3, 4, 5]]

      narr = stock_narr.clone
      narr.unsafe_set_chunk(region, src)
      narr.should eq expected
    end

    it "does not modify the NArray when given a zero-size chunk (MultiIndexable source)" do
      region = IndexRegion.new([0...0, 0...0], bound_shape: [2, 3])
      # TODO: If it becomes possible to directly instantiate the empty
      # narray, use that
      src = NArray[0][...-1]
      expected = stock_narr.clone
      narr = stock_narr.clone
      narr.unsafe_set_chunk(region, src)
      narr.should eq expected
    end

    it "correctly sets data for a simple chunk (scalar source)" do
      region = IndexRegion.new([1, 0..2..2], bound_shape: [2, 3])
      expected = NArray[[0, 1, 2], [6, 4, 6]]

      narr = stock_narr.clone
      narr.unsafe_set_chunk(region, 6)
      narr.should eq expected
    end

    it "correctly sets data for a relative chunk (scalar source)" do
      region = IndexRegion.new([-2, -1..0], bound_shape: [2, 3])
      expected = NArray[[6, 6, 6], [3, 4, 5]]

      narr = stock_narr.clone
      narr.unsafe_set_chunk(region, 6)
      narr.should eq expected
    end

    it "does not modify the NArray when given a zero-size chunk (scalar source)" do
      region = IndexRegion.new([0...0, 0...0], bound_shape: [2, 3])
      expected = stock_narr.clone
      narr = stock_narr.clone
      narr.unsafe_set_chunk(region, 6)
      narr.should eq expected
    end
  end
end
