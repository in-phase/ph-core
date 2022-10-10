require "./spec_helper.cr"

include Phase

describe View do
  describe View::ReverseTransform do
    describe "#apply" do
      it "properly inverts each coordinate in its axis" do
        shape = [5, 3]
        coord = [1, 2]
        reversed_coord = ReadonlyWrapper.new([3, 0])
        tf = View::ReverseTransform.new(shape)
        tf.apply(coord).should eq reversed_coord
      end
    end
  end
end
