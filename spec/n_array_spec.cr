require "./spec_helper.cr"

describe NArray do
  describe ".of_buffer" do
    it "creates an NArray from buffer and shape" do
      buf = Slice[1, 2, 3, 4, 5, 6]
      shape = [2, 3]
      narr = NArray.of_buffer(shape, buf)
      expected = NArray[[1, 2, 3], [4, 5, 6]]
      narr.should eq expected
    end

    it "raises for a mismatch between buffer size and shape product" do
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
      narr = NArray.fill([1, 2], 3)
      narr.size.should eq narr.buffer.size
    end

    it "is equal to the product of the shape" do
      narr = NArray.fill([3, 4], 3)
      narr.size.should eq 12
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
      clone_narr = src_narr.clone

      clone_narr.shape.should eq [2, 3]
      clone_narr.@shape.should_not be src_narr.@shape
      clone_narr.buffer.should eq src_narr.buffer
      clone_narr.should_not be src_narr
      clone_narr.buffer[0].should be arr
    end
  end

  
end