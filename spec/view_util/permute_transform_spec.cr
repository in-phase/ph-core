require "./spec_helper.cr"

include Phase

describe View do
  describe View::PermuteTransform do
    describe "#apply" do
      it "properly permutes the coordinates according to a pattern" do
        coord = [3, 5, 2, 1, 0, 9 ,4]
        pattern = [2, 6, 5, 0, 1, 3, 4]
        permuted_coord = ReadonlyWrapper.new([1, 0, 3, 9, 4, 2, 5])
        
        tf = View::PermuteTransform.new(pattern)
        tf.apply(coord).should eq permuted_coord
      end
    end
  end
end
