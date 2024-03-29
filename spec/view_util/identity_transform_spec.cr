require "./spec_helper.cr"

include Phase

describe View do
  describe View::IdentityTransform do
    describe "#apply" do
      it "has no effect on its inputs" do        
        coord = ReadonlyWrapper.new([3, 0, 2, 4])
        tf = View::IdentityTransform.new
        tf.apply(coord).should eq coord
      end
    end
  end
end
