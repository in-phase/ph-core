require "./spec_helper"

include Lattice

# Useful variables
LEGAL_SHAPES   = [[5, 5], [2], [10, 1, 3], [1, 1, 1, 1]]
ILLEGAL_SHAPES = [[0], [] of Int32, [-4], [5, 0, 5]]

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
      LEGAL_SHAPES.each do |shape|
        narr = NArray.fill(shape, 0)

        narr.buffer.to_a.uniq.should eq [0]
      end
    end

    it "populates an NArray with shallow copies of other types" do
      LEGAL_SHAPES.each do |shape|
        narr = NArray.fill([2], TestObject.new)

        narr.get(0).should be narr.get(1)
      end
    end

    it "raises an error when an illegal shape is provided" do
      ILLEGAL_SHAPES.each do |shape|
        expect_raises(DimensionError) do
          narr = NArray.fill(shape, 0)
        end
      end
    end
  end
end
