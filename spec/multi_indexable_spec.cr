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
# test_buffer must not contain any duplicate elements! test_buffer.to_set is used to simulate a bag/multiset
test_buffer = Slice[1, 2, 3, 4, 'a', 'b', 'c', 'd', 1f64, 2f64, 3f64, 4f64]
r_narr = uninitialized RONArray(Int32 | Char | Float64)

test_slices = [[[1, 2, 3, 4], ['a', 'b', 'c', 'd'], [1f64, 2f64, 3f64, 4f64]], [[1, 'a', 1f64], [2, 'b', 2f64], [3, 'c', 3f64], [4, 'd', 4f64]]]

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

  it "raises for coordinates with too many dimensions", do
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
  before_each do
    r_narr = RONArray.new(test_shape, test_buffer)
  end

end
