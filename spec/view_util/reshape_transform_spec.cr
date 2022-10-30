require "./spec_helper.cr"

include Phase

describe View do
  describe View::ReshapeTransform do
    describe "#apply" do
      it "properly permutes the coordinates according to a pattern" do
        src_shape = [3, 4]
        new_shape = [6, 2]

        input_coord = [2, 1]
        output_coord = ReadonlyWrapper.new([1, 1])

        tf = View::ReshapeTransform.new(src_shape, new_shape)
        tf.apply(input_coord).should eq output_coord
      end
    end
  end
end
