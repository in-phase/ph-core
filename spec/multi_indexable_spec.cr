require "./spec_helper"
require "./test_narray"

include Phase

ABSOLUTE_REGIONS = [[0..2], [2..1, 0..2..2], [0, 2...2], [] of Int32, [] of Range(Nil, Nil)]
RELATIVE_REGIONS = [[0...3, ..], [-3..-1, 1], [.., 2], [2.., 0]]
# These categorizations only apply to r_narr, but help simplify testing
# of region-accepting functions (because there are so many cases.
VALID_REGIONS = ABSOLUTE_REGIONS + RELATIVE_REGIONS
INVALID_REGIONS = [[0..8], [1, 1, 1], [-1...-10]]

test_shape = [3, 4]
test_buffer = Slice[1, 2, 3, 4, 'a', 'b', 'c', 'd', 1f64, 2f64, 3f64, 4f64]
r_narr = uninitialized RONArray(Int32 | Char | Float64)

test_slices = [[[1, 2, 3, 4], ['a', 'b', 'c', 'd'], [1f64, 2f64, 3f64, 4f64]], [[1, 'a', 1f64], [2, 'b', 2f64], [3, 'c', 3f64], [4, 'd', 4f64]]]

Spec.before_each do
  r_narr = RONArray.new(test_shape, test_buffer)
end

# get and get_element are aliases, so this prevents testing redundancy.
macro test_get_element(method)
  it "returns the correct element for all valid coordinates" do
    all_coords_lex_order(r_narr.shape) do |(row, col)|
      buffer_index = row * r_narr.shape[1] + col
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

  it "raises for for invalid coordinates" do
    oversized_shape = r_narr.shape.map &.+(2)
    proper_coords = all_coords_lex_order(r_narr.shape)

    all_coords_lex_order(oversized_shape) do |(row, col)|
      next if proper_coords.includes? [row, col]

      expect_raises IndexError do
        r_narr.{{method.id}}(row, col)
      end

      expect_raises IndexError do
        r_narr.{{method.id}}([row, col])
      end
    end
  end

  it "raises for coordinates with too many dimensions" do
    expect_raises(DimensionError) do
      r_narr.{{method.id}}([1, 1, 1, 1, 1])
    end

    expect_raises(DimensionError) do
      r_narr.{{method.id}}(1, 1, 1, 1, 1)
    end
  end

  it "raises for coordinates with too few dimensions" do
    expect_raises(DimensionError) do
      r_narr.{{method.id}}([1])
    end

    expect_raises(DimensionError) do
      r_narr.{{method.id}}(1)
    end
  end
end

# get_chunk and [] are aliases, so this prevents testing redundancy.
macro test_get_chunk(method)
  it "returns a chunk for each valid region" do
    {true, false}.each do |drop|
      VALID_REGIONS.each do |region_literal|
        # All we currently test for is that the shape returned is correct.
        result = r_narr.{{method.id}}(region_literal, drop: drop)

        # this indexregion is only used to compute the shape of the region.
        idx_r = IndexRegion.new(region_literal, bound_shape: r_narr.shape, drop: drop)
        expected_shape = drop ? idx_r.shape : idx_r.@proper_shape

        if result.shape != expected_shape
          fail <<-ERR
          Expected shape #{expected_shape}, but got #{result.shape}.
          drop: #{drop}
          ERR
        end
      end
    end
  end

  it "returns a chunk for each valid indexregion" do
    {true, false}.each do |drop|
      VALID_REGIONS.each do |region_literal|
        idx_r = IndexRegion.new(region_literal, bound_shape: r_narr.shape, drop: drop)
        result = r_narr.{{method.id}}(idx_r)
        expected_shape = drop ? idx_r.shape : idx_r.@proper_shape

        if result.shape != expected_shape
          fail <<-ERR
          Expected shape #{expected_shape}, but got #{result.shape}.
          drop: #{drop}
          IndexRegion: #{idx_r.pretty_inspect}
          ERR
        end
      end
    end
  end

  pending "does something appropriate when you pass an IndexRegion but also give drop" do
    # right now, this gives a very confusing error because it gets caught by the tuple
    # accepting overload of #get_chunk (get_chunk(*tuple, drop)), and then tries
    # to canonicalize IndexRegion :p
    #
    # I propose we either add a get_chunk(_ : IndexRegion, drop : Bool) that either
    # does { % raise % } or overrides the degeneracy of the IndexRegion.
    VALID_REGIONS.each do |region_literal|
      idx_r = IndexRegion.new(region_literal, r_narr.shape)
      r_narr.{{method.id}}(idx_r, drop: true)
    end
  end

  it "returns the correct output for a simple slice" do
    chunk = r_narr.{{method.id}}([1.., 0..2..2])
    expected = Slice['a', 'c', 1f64, 3f64]

    chunk.buffer.size.should eq expected.size
    chunk.shape.should eq [2, 2]

    chunk.buffer.each_with_index do |value, idx|
      value.should eq expected[idx]
    end
  end

  it "returns the correct output for a simple slice (with dropping)" do
    chunk = r_narr.{{method.id}}([1, ...], drop: true)
    expected = Slice['a', 'b', 'c', 'd']

    chunk.shape.should eq [4]

    chunk.buffer.each_with_index do |value, idx|
      value.should eq expected[idx]
    end
  end

  it "returns the correct output for a simple slice (without dropping)" do
    chunk = r_narr.{{method.id}}([1, ...], drop: false)
    expected = Slice['a', 'b', 'c', 'd']

    chunk.shape.should eq [1, 4]

    chunk.buffer.each_with_index do |value, idx|
      value.should eq expected[idx]
    end
  end

  pending "test this more exhaustively" do
  end
end

# this method allows 
def compare_slices(expected, result, axis)
  e_s = expected.size
  r_s = result.size
  e_s.should(eq(r_s), "number of slices computed (#{r_s}) was different than the number expected (#{e_s}) (slice axis = #{axis})")

  expected.each_with_index do |el, idx|
    result_el = result[idx].to_a
    result_el.should(eq(el.to_a), "computed slice #{result_el.to_a} does not match the expected value #{el} (slice axis = #{axis})")
  end
end

# each_slice and slices return the same data, but each_slice is just in iterator form.
# this method is used to test both.
macro test_each_slice(method)
  it "returns the axis 0 slices by default" do
    compare_slices(test_slices[0], r_narr.{{method.id}}.to_a, 0)
  end

  it "returns the correct slices along all axes" do
    r_narr.dimensions.times do |axis|
      slices = r_narr.{{method.id}}(axis: axis).to_a
      compare_slices(test_slices[axis], slices, axis)
    end
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
      expect_raises ShapeError do
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
      all_coords_lex_order(r_narr.shape) do |(row, col)|
        r_narr.has_coord?([row, col]).should be_true
        r_narr.has_coord?(row, col).should be_true
      end
    end

    it "returns false for a coordinate outside the shape" do
      oversized_shape = r_narr.shape.map &.+(2)
      proper_coords = all_coords_lex_order(r_narr.shape)

      all_coords_lex_order(oversized_shape) do |(row, col)|
        next if proper_coords.includes? [row, col]

        r_narr.has_coord?([row, col]).should be_false
        r_narr.has_coord?(row, col).should be_false
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
    it "returns the correct output for a simple region literal" do
      expected_buffer = Slice[3, 'c', 3f64]
      r_narr.get_available([0..8, 5..-3..2]).buffer.should eq expected_buffer
    end

    it "returns the correct output for a simple region literal (tuple accepting)" do
      expected_buffer = Slice[3, 'c', 3f64]
      r_narr.get_available(0..8, 5..-3..2).buffer.should eq expected_buffer
    end

    it "returns the correct output for an IndexRegion" do
      expected_buffer = Slice[3, 'c', 3f64]
      idx_r = IndexRegion(Int32).new([0..8, 5..-3..2])
      r_narr.get_available(idx_r).buffer.should eq expected_buffer
    end
  end

  describe "#[]" do
    test_get_chunk(:[])
  end

  describe "#[]?(region)" do
    it "returns a chunk for each valid region" do
      VALID_REGIONS.each do |region|
        # All we're testing for here is that it doesn't raise.
        # doing anything further would be a lot of work as it stands,
        # but if you want to precompute a dataset of inputs and outputs
        # for this function, please feel free to do so
        r_narr[region]?.should_not be_nil
      end
    end

    it "returns a chunk for each valid indexregion" do
      VALID_REGIONS.each do |region_literal|
        idx_r = IndexRegion.new(region_literal, r_narr.shape)
        r_narr[idx_r]?
      end
    end

    it "returns the correct output for a simple slice" do
      chunk = r_narr[1.., 0..2..2]?
      expected = Slice['a', 'c', 1f64, 3f64]

      fail("chunk was nil") if chunk.nil?

      chunk.buffer.size.should eq expected.size

      chunk.buffer.each_with_index do |value, idx|
        value.should eq expected[idx]
      end
    end

    it "returns nil for invalid regions" do
      INVALID_REGIONS.each do |region_literal|
        r_narr[region_literal]?.should be_nil
      end
    end
  end

  describe "#[]?(mask)" do
    it "raises a ShapeError for mismatched mask size" do
      mask_buf = Slice.new(10, false)
      mask = RONArray.new([10], mask_buf)

      expect_raises ShapeError do
        r_narr[mask]?
      end
    end

    it "returns nil where the mask is false and the copied element where the mask is true" do
      mask_buf = Slice[true, false, true, false, false, true, false, true, true, false, true, false]
      mask = RONArray.new(r_narr.shape, mask_buf)
      masked_copy = r_narr[mask]?

      masked_copy.@buffer.each_with_index do |value, idx|
        if mask_buf[idx]
          value.should eq test_buffer[idx]
        else
          value.should eq nil
        end
      end
    end
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
    # this is my favorite unit test because fast promises almost nothing lol
    it "returns all the elements in whatever order" do
      r_narr.fast.each.to_set.should eq test_buffer.to_set
    end
  end

  describe "#each_slice" do
    test_each_slice(:each_slice)

    it "works with a block" do
      r_narr.dimensions.times do |axis|
        slices = [] of MultiIndexable(typeof(r_narr.sample))

        r_narr.each_slice(axis) do |slice|
          slices.push(slice)
        end

        compare_slices(test_slices[axis], slices, axis)
      end
    end
  end

  describe "#slices" do
    test_each_slice(:slices)
  end

  describe "#reshape" do
    it "returns a reshaped MultiIndexable containing the same elements" do
      r_narr.reshape([12]).should eq NArray.new(test_buffer.to_a)
    end

    it "raises a ShapeError for incompatible shapes" do
      expect_raises(ShapeError) do
        r_narr.reshape([15, 20])
      end
    end
  end

  describe "#permute" do
    it "returns a permuted MultiIndexable containing the same elements" do
      permuted = NArray[[1, 'a', 1f64], [2, 'b', 2f64], [3, 'c', 3f64], [4, 'd', 4f64]]
      r_narr.permute([1, 0]).should eq permuted
      r_narr.permute(1, 0).should eq permuted
      r_narr.permute.should eq permuted
    end

    it "raises an IndexError for illegal permutation indices" do
      expect_raises(IndexError) do
        r_narr.permute([2, 3])
      end
    end
  end

  describe "#reverse", tags: ["yikes"] do
    it "returns a View with a ReverseTransform applied over this MultiIndexable" do
      r_narr.reverse.@buffer.should eq test_buffer.clone.reverse!
    end
  end

  describe "#to_narr" do
    it "converts a MultiIndexable into an NArray copy" do
      narr = r_narr.to_narr

      pointerof(narr.@buffer).should_not(eq(pointerof(r_narr.@buffer)), "buffer was not safely duplicated")

      narr.equals?(r_narr) { |x, y| x == y }.should(be_true, "data was not equivalent")
    end
  end

  describe "#equals?" do
    it "returns true for equivalent MultiIndexables" do
      copy_narr = RONArray.new(test_shape.clone, test_buffer.clone)
      r_narr.should eq copy_narr
    end

    it "returns false for MultiIndexables with the same elements in a different shape" do
      other_narr = RONArray.new([test_shape[0], 1, 1, test_shape[1]], test_buffer.clone)
      r_narr.should_not eq other_narr
    end

    it "returns false for MultiIndexables with different elements but the same shape" do
      new_buffer = test_buffer.map &.hash
      other_narr = RONArray.new(test_shape, new_buffer)
      r_narr.should_not eq other_narr
    end

    it "returns false for MultiIndexables of a different class" do
      copy_narr = r_narr.to_narr
      r_narr.should_not eq copy_narr
    end
  end

  describe "#view" do
    it "creates a View of the source MultiIndexable" do
      # we aren't testing the functionality of the view here - only that #view
      # creates what we're expecting.

      r_narr.view.is_a?(View).should be_true
    end
  end

  describe "#process" do
    it "creates a ProcView fo the source MultiIndexable" do
      # we aren't testing the functionality of the view here - only that #process
      # creates what we're expecting.

      r_narr.process { |el| el.hash % 2 }.is_a?(ProcView).should be_true
    end
  end

  describe "#eq" do
    it "returns an NArray containing elementwise equality with another MultiIndexable" do
      altered_buffer = Slice[1, 2, "string", 4, 'a', 'b', 9, 'd', 1f64, 2f64, 3f64, 4f64]
      altered_r_narr = RONArray.new(test_shape, altered_buffer)
      equality = altered_r_narr.eq(r_narr)
      equality.@buffer.should eq Slice[true, true, false, true, true, true, false, true, true, true, true, true]
    end

    it "raises a DimensionError for an NArray of a different shape" do
      altered_r_narr = RONArray.new([test_buffer.size], test_buffer)
      expect_raises(DimensionError) do
        altered_r_narr.eq(r_narr)
      end
    end

    it "returns an NArray containing elementwise equality with a scalar" do
      comparison_el = 'b'
      expected_buffer = test_buffer.map &.==(comparison_el)
      r_narr.eq(comparison_el).@buffer.should eq expected_buffer
    end
  end

  describe "#hash" do
    it "returns different hashes for different MultiIndexables", tags: ["probabilistic"] do
      h1 = RONArray.new([2, 2], Slice[1, 1, 4, 9]).hash
      h2 = RONArray.new([2], Slice[3, 4]).hash
      h1.should_not eq h2
    end

    it "returns the same hash for identical MultiIndexables" do
      h1 = RONArray.new([2, 2], Slice[1, 1, 4, 9]).hash
      h2 = RONArray.new([2, 2], Slice[1, 1, 4, 9]).hash
      h1.should eq h2
    end
  end

  describe "#tile" do
    it "tiles a MultiIndexable into a larger NArray" do
      tile = RONArray.new([2, 2], Slice[1, 0, 0, 1])
      tiled = tile.tile([2, 3])
      expected = NArray.new([[1, 0, 1, 0, 1, 0], [0, 1, 0, 1, 0, 1], [1, 0, 1, 0, 1, 0], [0, 1, 0, 1, 0, 1]])
      tiled.should eq expected
    end
  end

  describe "arithmetic" do
  end

  describe "Enumerable methods" do
    # If we are confident enough in our #each testing we can
    # get rid of this
  end
end
