require "./spec_helper.cr"

include Phase

describe RV do
  describe RV::IdentityTransform do
    describe "#apply" do
      it "has no effect on its inputs" do        
        coord = [3, 0, 2, 4]
        tf = RV::IdentityTransform.new
        tf.apply(coord).should eq coord
      end
    end
  end
end