require "./spec_helper.cr"

include Phase

describe ShapeUtil do
  describe "compatible_shapes?" do
    it "returns true if two shapes are equal up to trailing ones" do
      base_shapes = [
        [2, 5, 3],
        [1, 2, 1],
        [4, 6, 3, 2],
        [1, 1, 1],
        [] of Int32
      ]

      compatible_shapes = [
        [2, 5, 3, 1, 1],
        [1, 2, 1, 1],
        [4, 6, 3, 2, 1, 1, 1, 1, 1],
        [1],
        [] of Int32
      ]

      base_shapes.each.zip(compatible_shapes) do |shape1, shape2|
        ShapeUtil.compatible_shapes?(shape1, shape2).should be_true
      end
    end
  end

  describe "compatible_shapes?" do
    it "returns false if two shapes are not compatible" do
      base_shapes = [
        [2, 5, 3],
        [1, 2, 1],
        [4, 6, 3, 2],
        [1, 1, 1],
        [] of Int32
      ]

      incompatible_shapes = [
        [2, 5],
        [2, 1, 1],
        [4, 3, 2, 1, 1, 1, 1, 1],
        [-2],
        [1]
      ]

      base_shapes.each.zip(incompatible_shapes) do |shape1, shape2|
        ShapeUtil.compatible_shapes?(shape1, shape2).should be_false
      end
    end
  end
end
