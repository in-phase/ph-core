require "./spec_helper.cr"

include Phase

describe RV do
  describe RV::ReshapeTransform do
    describe "#apply" do
      it "properly permutes the coordinates according to a pattern" do
        src_shape = [3, 4]
        new_shape = [6, 2]

        tf = RV::ReshapeTransform.new(src_shape, new_shape)
        tf.apply(coord).should eq coord
      end
    end
  end
end