require "./spec_helper"
require "./test_narray"

include Phase

# arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
# small_arr = NArray.build([3, 3]) { |coord, index| index }

# These categorizations only apply to r_narr, but help simplify testing
# of region-accepting functions (because there are so many cases)
VALID_REGIONS   = [[0..2], [0...3, ..], [-3..-1, 1], [.., 2], [2..1, 0..2..2], [0, 2...2], [] of Int32, [] of Range(Nil, Nil), [2.., 0]]
INVALID_REGIONS = [[0..8], [1, 1, 1], [-1...-10]]

test_buffer = Slice[1, 2, 3, 'a', 'b', 'c', 1f64, 2f64, 3f64]
side_length = 3
r_narr = RONArray.new([side_length] * 2, test_buffer)

Spec.before_each do
  r_narr = RONArray.new([side_length] * 2, test_buffer)
end

# get and get_element are aliases, so this prevents testing redundancy.
macro test_get_element(method)
  it "returns the correct element for all valid coordinates" do
    (0...side_length).each do |row|
      (0...side_length).each do |col|
        buffer_index = row * side_length + col
        expected_elem = test_buffer[buffer_index]

        actual = r_narr.{{method.id}}(row, col)
        if actual != expected_elem
          fail("Tuple accepting verision failed: narr.{{method.id}}(#{row}, #{col}) should have been #{expected_elem}, but was #{actual}")
        end

        actual = r_narr.{{method.id}}([row, col])
        if actual != expected_elem
          fail("Indexable accepting verision failed: narr.{{method.id}}([#{row}, #{col}]) should have been #{expected_elem}, but was #{actual}")
        end
      end
    end
  end

  it "raises for for invalid coordinates" do
    (0...(side_length + 2)).each do |row|
      (0...(side_length + 2)).each do |col|
        next if row < side_length && col < side_length

        expect_raises IndexError do
          r_narr.{{method.id}}(row, col)
        end

        expect_raises IndexError do
          r_narr.{{method.id}}([row, col])
        end
      end
    end
  end
end

# get_chunk and [] are aliases, so this prevents testing redundancy.
macro test_get_chunk(method)
  it "returns a chunk for each valid region" do
    VALID_REGIONS.each do |region|
      # Really, all we can test for sensibly is that it doesn't
      # raise.
      r_narr.{{method.id}}(region)
    end
  end

  it "returns a chunk for each valid indexregion" do
    VALID_REGIONS.each do |region_literal|
      idx_r = IndexRegion.new(region_literal, r_narr.shape)
      r_narr.{{method.id}}(idx_r)
    end
  end

  it "returns the correct output" do
    chunk = r_narr.{{method.id}}([1.., 0..2..2])
    expected = Slice['a', 'c', 1f64, 3f64]

    chunk.buffer.size.should eq expected.size

    chunk.buffer.each_with_index do |value, idx|
      value.should eq expected[idx]
    end
  end

  pending "test this more exhaustively" do
  end
end

describe Phase::MultiIndexable do
  describe "#empty?" do
    it "returns true for an empty MultiIndexable" do
      empty_buffer = Slice(Int32).new(size: 0)
      RONArray.new([0], empty_buffer).empty?.should be_true
    end

    it "returns false for a nonempty MultiIndexable" do
      r_narr.empty?.should be_false
    end
  end

  describe "#scalar?" do
    it "returns true for a 1D MultiIndexable with 1 element" do
      scalar_buffer = Slice[1]
      RONArray.new([1], scalar_buffer).scalar?.should be_true
    end

    it "returns false for a 1D MultiIndexable with more than one element" do
      scalar_buffer = Slice[1, 2, 3]
      RONArray.new([3], scalar_buffer).scalar?.should be_false
    end

    it "returns true for a multidimensional MultiIndexable with only one element" do
      scalar_buffer = Slice[1]
      RONArray.new([1, 1, 1, 1], scalar_buffer).scalar?.should be_true
    end

    it "returns false for a multidimensional MultiIndexable with multiple elements" do
      scalar_buffer = Slice[1, 2, 3, 4, 5, 6]
      RONArray.new([2, 3], scalar_buffer).scalar?.should be_false
    end
  end

  describe "#to_scalar" do
    it "raises for a MultiIndexable with multiple elements in one dimension" do
      scalar_buffer = Slice[1, 2, 3]
      expect_raises ShapeError do
        RONArray.new([3], scalar_buffer).to_scalar
      end
    end

    it "raises for a MultiIndexable with multiple elements and dimensions" do
      scalar_buffer = Slice[1, 2, 3, 4]
      expect_raises ShapeError do
        RONArray.new([2, 2], scalar_buffer).to_scalar
      end
    end

    it "returns the element when the MultiIndexable is a 1D scalar" do
      scalar_buffer = Slice[1]
      RONArray.new([1], scalar_buffer).to_scalar.should eq 1
    end

    it "returns the element when the MultiIndexable is a multidimensional scalar" do
      scalar_buffer = Slice[1]
      RONArray.new([1, 1, 1], scalar_buffer).to_scalar.should eq 1
    end
  end

  describe "#first" do
    it "returns the element at the zero coordinate from a populated MultiIndexable" do
      RONArray.new([2, 2], Slice[1, 2, 3, 4]).first.should eq 1
    end

    it "raises some sort of error when there are no elements" do
      expect_raises IndexError do
        RONArray.new([1, 1, 0], Slice(Int32).new(0, 0)).first
      end
    end
  end

  describe "#sample" do
    it "returns an element from the MultiIndexable" do
      r_narr.sample(test_buffer.size * 10).each do |el|
        test_buffer.includes?(el).should be_true
      end
    end

    it "returns each element in similar proportion (note: this test is probabilistic, and there is a small chance it fails under normal operation)", tags: ["slow", "probabilistic"] do
      # Note: This shape needs to be hardcoded because it assumes 6 distinct elements (5 dof).
      shape = [1, 2, 3]
      size = shape.product
      buffer = Slice.new(size) { |idx| idx }
      narr = RONArray.new(shape, buffer)

      expected_occurrences = 1000
      sample_count = size * expected_occurrences
      frequencies = narr.sample(sample_count).tally

      # Using chi-square to determine that there is >95% chance of this sampling
      # occuring, assuming that the sample function is working properly
      chi_sq = frequencies.sum do |_, observed|
        (observed - expected_occurrences)**2 / expected_occurrences
      end

      # when dof=5, we expect a chi-square less than 11.07 in the case described above
      (chi_sq < 11.07).should be_true
    end

    it "returns the only element in a one-element MultiIndexable" do
      narr = RONArray.new([1], Slice['a']).sample(100).each do |el|
        el.should eq 'a'
      end
    end

    it "raises when given a negative sample count" do
      expect_raises ArgumentError do
        r_narr.sample(-1)
      end
    end

    it "raises when called on an empty MultiIndexable" do
      expect_raises IndexError do
        RONArray.new([1, 1, 0], Slice(Int32).new(0)).sample
      end
    end
  end

  describe "#dimensions" do
    it "returns the correct number of dimensions" do
      10.times do
        expected_dims = Random.rand(10).to_i32 + 1
        shape = Array(Int32).new(expected_dims) { Random.rand(10).to_i32 + 1 }
        data = Slice.new(shape.product, 0)
        dims = RONArray.new(shape, data).dimensions

        if dims != expected_dims
          fail("shape #{shape} has #{expected_dims} dimensions, but MultiIndexable#dimensions returned #{dims}!")
        end
      end
    end
  end

  describe "#has_coord?" do
    it "returns true for a coordinate within the shape" do
      (0...side_length).each do |x|
        (0...side_length).each do |y|
          r_narr.has_coord?([x, y]).should be_true
          r_narr.has_coord?(x, y).should be_true
        end
      end
    end

    it "returns false for a coordinate outside the shape" do
      (0...(side_length + 2)).each do |x|
        (0...(side_length + 2)).each do |y|
          next if x < side_length || y < side_length

          r_narr.has_coord?([x, y]).should be_false
          r_narr.has_coord?(x, y).should be_false
        end
      end
    end

    it "returns false when the coordinate is of the wrong dimension" do
      r_narr.has_coord?([0]).should be_false
      r_narr.has_coord?(0).should be_false
    end
  end

  describe "#has_region?" do
    it "returns true for valid literal regions", tags: ["bad"] do
      VALID_REGIONS.each do |region|
        unless r_narr.has_region?(region)
          fail(r_narr.shape.join("x") + " MultiIndexable should include #{region}, but has_region? was false")
        end
      end
    end

    it "returns false for invalid regions" do
      INVALID_REGIONS.each do |region|
        if r_narr.has_region?(region)
          fail(r_narr.shape.join("x") + " MultiIndexable should not include #{region}, but has_region? was true")
        end
      end
    end

    it "returns true for valid IndexRegions" do
      VALID_REGIONS.each do |region_literal|
        idx_r = IndexRegion.new(region_literal, r_narr.shape)

        unless r_narr.has_region?(idx_r)
          fail(r_narr.shape.join("x") + " MultiIndexable should include #{idx_r}, but has_region? was false")
        end
      end
    end

    it "returns false for invalid IndexRegions" do
      # Note: We want to use valid regions (so that IndexRegions can be constructed),
      # and then make them invalid for this shape by translating them massively.
      # TODO: I'm not sure what happens here if you make an IndexRegion that
      # spans zero elements, or if that's even possible.
      VALID_REGIONS.each do |region_literal|
        idx_r = IndexRegion.new(region_literal, r_narr.shape).translate!(r_narr.shape)

        if r_narr.has_region?(idx_r)
          fail(r_narr.shape.join("x") + " MultiIndexable should not include #{idx_r}, but has_region? was true")
        end
      end
    end
  end

  describe "#get_element" do
    test_get_element(:get_element)
  end

  describe "#get" do
    test_get_element(:get)
  end

  describe "#get_chunk" do
    test_get_chunk(:get_chunk)
  end

  describe "#get_available" do
  end

  describe "#[]" do
    test_get_chunk(:[])
  end

  describe "#[]?" do
  end

  describe "#each_coord" do
    it "yields only the correct coordinates, and all of the correct coordinates" do
      {[1, 2, 3], [5, 10], [2]}.each do |shape| 
        narr = RONArray.new(shape, Slice.new(shape.product, 0))
        actual_coords = narr.each_coord.to_a
        actual_count = actual_coords.size
        actual_coords = actual_coords.to_set

        if actual_coords.size != actual_count
          fail("the same coordinate was yielded multiple times (shape: #{shape})")
        end

        if actual_count != shape.product
          fail("not all coordinates were covered (shape: #{shape})")
        end

        all_coords_lex_order(shape) do |coord|
          unless actual_coords.includes?(coord)
            fail("#{coord}, an expected coordinate, was not present in each_coord for a MultiIndexable with shape #{shape}")
          end
        end
      end
    end
  end

  describe "#each" do
    it "yields all elements in lexicographic order" do
      elem_iter = test_buffer.each

      r_narr.each do |el|
        el.should eq elem_iter.next
      end

      elem_iter.empty?.should be_true
    end

    it "provides an iterator over every element in lexicographic order" do
      iter = r_narr.each

      test_buffer.each do |el|
        el.should eq iter.next
      end

      iter.empty?.should be_true
    end
  end

  describe "#each_with_coord" do
    it "yields all elements and coordinates in lexicographic order" do
      elem_iter = test_buffer.each
      coord_iter = all_coords_lex_order(r_narr.shape).each

      r_narr.each_with_coord do |tuple|
        expected_coord = coord_iter.next
        expected_elem = elem_iter.next

        {expected_elem, expected_coord}.should eq tuple
      end

      elem_iter.empty?.should be_true
      coord_iter.empty?.should be_true
    end

    it "iterates over all elements and coordinates in lexicographic order" do
      elem_iter = test_buffer.each
      testing_iterator = r_narr.each_with_coord
      coords = all_coords_lex_order(r_narr.shape)

      coords.each do |coord|
        case actual_value = testing_iterator.next
        when Iterator::Stop
        else
          actual_el, actual_coord = actual_value
          actual_el.should eq elem_iter.next

          actual_coord.should eq coord
        end
      end

      elem_iter.empty?.should be_true
      testing_iterator.empty?.should be_true
    end
  end

  describe "#map_with_coord" do
  end

  describe "#fast" do
  end

  describe "#each_slice" do
  end

  describe "#slices" do
  end

  describe "#reshape" do
  end

  describe "#permute" do
  end

  describe "#reverse" do
  end

  describe "#to_narr" do
  end

  describe "#equals?" do
  end

  describe "#view" do
  end

  describe "#process" do
  end

  describe "#eq_elem" do
  end

  describe "#hash" do
  end

  pending "#tile" do
  end

  describe "arithmetic" do
  end

  describe "Enumerable methods" do
    # If we are confident enough in our #each testing we can
    # get rid of this
  end
end
