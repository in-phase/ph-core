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
  end

  describe ".new(data : Enumerable)" do
    it "accepts data from a nested Array" do
      narr = NArray.new([[1, 2], [3, 4]])
      narr.should eq(NArray.build(2, 2) {|c, i| i + 1})
    end

    it "raises for inconsistent array shape" do
      expect_raises ArgumentError do
        
      end
    end
  end
end