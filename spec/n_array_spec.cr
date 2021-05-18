require "./spec_helper"

include Lattice

# Useful variables
NONEMPTY_SHAPES   = [[5, 5], [2], [10, 1, 3], [1, 1, 1, 1]]
EMPTY_SHAPES = [[5, 0, 2], [0, 0, 0], [0]]
LEGAL_SHAPES = NONEMPTY_SHAPES + EMPTY_SHAPES
ILLEGAL_SHAPES = [[] of Int32, [-4], [-10, 0]]


describe Lattice::NArray do
  describe ".build" do
    it "creates NArrays via buffer indices" do
      LEGAL_SHAPES.each do |shape|
        narr = NArray.build(shape) do |coord, index|
          index
        end

        narr.buffer.each_with_index do |elem, index|
          elem.should eq index
        end
      end
    end

    it "creates NArrays via element coordinates" do
      LEGAL_SHAPES.each do |shape|
        narr = NArray.build(shape) do |coord, index|
          coord.product
        end

        narr.buffer.each_with_index do |elem, index|
          coord = NArray.index_to_coord(index, shape)
          elem.should eq coord.product
        end
      end
    end

    it "raises an error when an invalid shape is used" do
      ILLEGAL_SHAPES.each do |shape|
        expect_raises(DimensionError) do
          narr = NArray.build(shape) do |coord, index|
            index
          end
        end
      end
    end
  end

  describe ".new", tags: "broken" do
    it "creates an NArray from a nested array" do
      valid_nesteds = [[[1, 2, 3], [4, 5, 6]], [[[1]], [[1]]]]
      expected_results = [
        {shape: [2, 3], buffer: [1, 2, 3, 4, 5, 6]},
        {shape: [2, 1, 1], buffer: [1, 1]},
      ]

      valid_nesteds.each_with_index do |example, idx|
        narr = NArray.new(example)
        expected = expected_results[idx]

        narr.shape.should eq expected[:shape]
        narr.buffer.to_a.should eq expected[:buffer]
      end
    end

    it "raises an error when an inconsistent array is provided" do
      # true.should eq false
    end

    it "raises an error when an empty array is provided" do
      # true.should eq false
    end
  end

  describe ".fill" do
    it "populates an NArray with scalar types" do
      NONEMPTY_SHAPES.each do |shape|
        narr = NArray.fill(shape, 0)

        narr.buffer.to_a.uniq.should eq [0]
      end

      EMPTY_SHAPES.each do |shape|
        narr = NArray.fill(shape, 0)
        narr.buffer.to_a.should eq [] of Int32
      end
    end

    it "populates an NArray with shallow copies of other types" do
      narr = NArray.fill([2], TestObject.new)
      narr.get(0).should be narr.get(1)
    end

    it "raises an error when an illegal shape is provided" do
      ILLEGAL_SHAPES.each do |shape|
        expect_raises(DimensionError) do
          narr = NArray.fill(shape, 0)
        end
      end
    end
  end

  describe "serialization" do
    it "serializes numeric types as flow sequences" do
      elem = 0i32

      NONEMPTY_SHAPES.each do |shape|
        src = NArray.fill(shape, elem)
        yaml = src.to_yaml

        # Make sure that deserialization works
        reconstructed = NArray(typeof(elem)).from_yaml(yaml)
        reconstructed.should eq src

        # Verify that a flow sequence was used
        expected_text = "[" + "#{elem}," * (shape.product - 1) + "#{elem}]"
        oneline_yaml = yaml.gsub(' ', "").lines.sum
        oneline_yaml.includes?(expected_text).should be_true
      end
    end

    pending "properly serializes empty NArray" do
    end

    # it "serializes objects as block sequences" do
    #   LEGAL_SHAPES.each do |shape|
    #     src = NArray.build(shape) { |_, i| [i] }
    #     json = src.to_json
    #     yaml = src.to_yaml

    #     # Make sure that deserialization works
    #     reconstructed = NArray(typeof([0])).from_yaml(yaml)
    #     reconstructed.should eq src

    #     # Verify that a block sequence was used
    #     expected_text = Array(Int32).new(shape.product) { |i| i }.join("--")
    #     oneline_yaml = yaml.gsub(' ', "").lines.sum
    #     oneline_yaml.includes?(expected_text).should be_true
    #   end
    # end
  end
end
