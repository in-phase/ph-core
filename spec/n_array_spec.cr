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

  describe "[]=(mask, value)" do
    it "sets the correct elements for an NArray mask (scalar source)" do
      src = 6
      mask = NArray[[true, false, true], [false, true, false]]
      expected = NArray[[6, 1, 6], [3, 6, 5]]
      narr = stock_narr.clone
      narr[mask] = src
      narr.should eq expected
    end

    it "sets the correct elements for a generic mask (scalar source)" do
      src = 6
      mask = RWNArray.new([2, 3], Slice[true, false, true, false, true, false])
      expected = NArray[[6, 1, 6], [3, 6, 5]]
      narr = stock_narr.clone
      narr[mask] = src
      narr.should eq expected
    end

    it "sets the correct elements for an NArray mask (MultiIndexable source)" do
      src = stock_narr + 10
      mask = NArray[[true, false, true], [false, true, false]]
      expected = NArray[[10, 1, 12], [3, 14, 5]]
      narr = stock_narr.clone
      narr[mask] = src
      narr.should eq expected
    end

    it "sets the correct elements for a generic mask (MultiIndexable source)" do
      src = stock_narr + 10
      mask = RWNArray.new([2, 3], Slice[true, false, true, false, true, false])
      expected = NArray[[10, 1, 12], [3, 14, 5]]
      narr = stock_narr.clone
      narr[mask] = src
      narr.should eq expected
    end
  end

  describe "#each" do
    it "yields all elements in lexicographic order" do
      copy = [] of Int32
      stock_narr.each do |el|
        copy << el
      end

      copy.should eq stock_narr.@buffer.to_a
    end

    it "stops immediately for 1D empty NArrays" do
      zerodim = NArray[0][...-1]
      zerodim.each do |el|
        fail("unexpected element: #{el}")
      end
    end

    it "stops immediately for empty NArrays" do
      empty = NArray.fill([3, 0, 2], 0)
      empty.each do |el|
        fail("unexpected element: #{el}")
      end
    end
  end

  describe "#each_coord" do
    it "yields all coordinates in lexicographic order" do
      coords = Array(Array(Int32)).new
      stock_narr.each_coord do |coord|
        coords << coord.to_a
      end

      expected = [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]]

      coords.should eq expected
    end

    it "stops immediately for 1D empty NArrays" do
      zerodim = NArray[0][...-1]
      zerodim.each_coord do |el|
        fail("unexpected element: #{el}")
      end
    end

    it "stops immediately for empty NArrays" do
      empty = NArray.fill([3, 0, 2], 0)
      empty.each_coord do |el|
        fail("unexpected element: #{el}")
      end
    end
  end

  describe "#each_with_coord" do
    it "yields all coordinates and elements in lexicographic order" do
      coords = Array(Array(Int32)).new
      copy = [] of Int32
      stock_narr.each_with_coord do |el, coord|
        coords << coord.to_a
        copy << el
      end

      expected = [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]]

      coords.should eq expected
      copy.should eq stock_narr.@buffer.to_a
    end

    it "stops immediately for 1D empty NArrays" do
      zerodim = NArray[0][...-1]
      zerodim.each_with_coord do |el, coord|
        fail("unexpected element: #{el} at #{coord}")
      end
    end

    it "stops immediately for empty NArrays" do
      empty = NArray.fill([3, 0, 2], 0)
      empty.each_with_coord do |el, coord|
        fail("unexpected element: #{el} at #{coord}")
      end
    end
  end

  describe "#each_with_index" do
    it "yields all elements in lexicographic order with their index" do
      copy = [] of Int32

      stock_narr.each_with_index do |el, idx|
        idx.should eq copy.size
        copy << el
      end

      copy.should eq stock_narr.@buffer.to_a
    end

    it "stops immediately for 1D empty NArrays" do
      zerodim = NArray[0][...-1]
      zerodim.each_with_index do |el, index|
        fail("unexpected element: #{el} at #{index}")
      end
    end

    it "stops immediately for empty NArrays" do
      empty = NArray.fill([3, 0, 2], 0)
      empty.each_with_index do |el, index|
        fail("unexpected element: #{el} at #{index}")
      end
    end
  end

  describe "#map" do
    it "correctly maps each element" do
      expected = NArray[[0, 1, 4], [9, 16, 25]]
      stock_narr.map { |x| x ** 2 }.should eq expected
    end
  end

  describe "#map_with_coord" do
    it "correctly maps each element with a coord" do
      expected = NArray[[0, 2, 4], [13, 15, 17]]
      stock_narr.map_with_coord do |el, c|
        10 * c[0] + c[1] + el
      end.should eq expected
    end
  end

  describe "#map_with_index" do
    it "correctly maps each element with a lex buffer index" do
      narr = stock_narr * 2
      narr.map_with_index do |el, idx|
        idx + el
      end.should eq stock_narr * 3
    end
  end

  describe "#map!" do
    it "correctly maps each element in place" do
      expected = NArray[[0, 1, 4], [9, 16, 25]]
      narr = stock_narr.clone
      narr.map! { |x| x ** 2 }
      narr.should eq expected
    end

    it "returns self" do
      expected = NArray[[0, 1, 4], [9, 16, 25]]
      narr = stock_narr.clone
      narr.map! { |x| x ** 2 }.should eq expected
    end
  end

  describe "#map_with_coord!" do
    it "correctly maps each element with a coord in place" do
      expected = NArray[[0, 2, 4], [13, 15, 17]]
      narr = stock_narr.clone
      narr.map_with_coord! do |el, c|
        10 * c[0] + c[1] + el
      end
      narr.should eq expected
    end

    it "returns self" do
      expected = NArray[[0, 2, 4], [13, 15, 17]]
      narr = stock_narr.clone
      narr.map_with_coord! do |el, c|
        10 * c[0] + c[1] + el
      end.should eq expected
    end
  end

  describe "#map_with_index!" do
    it "correctly maps each element with a lex buffer index in place" do
      narr = stock_narr * 2
      narr.map_with_index! do |el, idx|
        idx + el
      end
      narr.should eq stock_narr * 3
    end

    it "returns self" do
      narr = stock_narr * 2
      narr.map_with_index! do |el, idx|
        idx + el
      end.should eq stock_narr * 3
    end
  end

  describe "#to_json" do
    it "converts the NArray to json" do
      stock_narr.to_json.should eq %({"shape":[2,3],"elements":[0,1,2,3,4,5]})
    end

    it "converts a 1D empty NArray to json" do
      NArray.fill([0], 0).to_json.should eq %({"shape":[0],"elements":[]})
    end
  end

  describe ".from_json" do
    it "converts json into an NArray" do
      NArray(Int32).from_json(%({"shape":[2,3],"elements":[0,1,2,3,4,5]})).should eq stock_narr
    end
    
    it "converts json into a 1D empty NArray" do
      NArray(Int32).from_json(%({"shape":[0],"elements":[]})).should eq NArray.fill([0], 0)
    end
  end

  describe "#to_yaml" do
    it "converts the NArray to yaml" do
      stock_narr.to_yaml.should eq "---\nshape: [2, 3]\nelements: [0, 1, 2, 3, 4, 5]\n"
    end

    it "converts a 1D empty NArray to yaml" do
      NArray.fill([0], 0).to_yaml.should eq "---\nshape: [0]\nelements: []\n"
    end
  end

  describe ".from_yaml" do
    it "converts yaml into an NArray" do
      NArray(Int32).from_yaml("---\nshape: [2, 3]\nelements: [0, 1, 2, 3, 4, 5]\n").should eq stock_narr
    end

    it "converts yaml into a 1D empty NArray" do
      NArray(Int32).from_yaml("---\nshape: [0]\nelements: []\n").should eq NArray.fill([0], 0)
    end
  end
end
