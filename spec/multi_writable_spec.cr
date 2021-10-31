require "./spec_helper"
require "./test_narray"

include Phase

test_shape = [3, 4]
test_buffer = Slice[1, 2, 3, 4, 'a', 'b', 'c', 'd', 1f64, 2f64, 3f64, 4f64]
w_narr = uninitialized WONArray(Int32 | Char | Float64)

Spec.before_each do
  w_narr = WONArray.new(test_shape, test_buffer.clone)
end

macro test_set_chunk(name)
  it "sets a chunk to a scalar" do
    w_narr.{{name.id}}([1.., 1..], 10)
    
    modded_buffer = test_buffer.to_a
    modded_buffer[5..7] = [10, 10, 10]
    modded_buffer[9..11] = [10, 10, 10]
    w_narr.buffer.to_a.should eq modded_buffer
  end

  it "sets a chunk to a MultiIndexable" do
    chunk = RONArray.new([2, 3], Slice[10, 11, 12, 13, 14, 15])
    w_narr.{{name.id}}([1.., 1..], chunk)
    
    modded_buffer = test_buffer.to_a
    modded_buffer[5..7] = [10, 11, 12]
    modded_buffer[9..11] = [13, 14, 15]
    w_narr.buffer.to_a.should eq modded_buffer
  end

  it "raises when setting a chunk that is out of bounds" do
    chunk = RONArray.new([2, 3], Slice[10, 11, 12, 13, 14, 15])

    expect_raises(ShapeError) do
      w_narr.{{name.id}}([2.., 2..], chunk)
    end
  end
end

describe Phase::MultiWritable do
  describe "#unsafe_set_chunk" do
    it "sets a chunk to a scalar" do
      idx_r = IndexRegion.new([1.., 1..], test_shape)
      w_narr.unsafe_set_chunk(idx_r, 10)
      
      modded_buffer = test_buffer.to_a
      modded_buffer[5..7] = [10, 10, 10]
      modded_buffer[9..11] = [10, 10, 10]
      w_narr.buffer.to_a.should eq modded_buffer
    end

    it "sets a chunk to a MultiIndexable" do
      chunk = RONArray.new([2, 3], Slice[10, 11, 12, 13, 14, 15])
      idx_r = IndexRegion.new([1.., 1..], test_shape)
      w_narr.unsafe_set_chunk(idx_r, chunk)
      
      modded_buffer = test_buffer.to_a
      modded_buffer[5..7] = [10, 11, 12]
      modded_buffer[9..11] = [13, 14, 15]
      w_narr.buffer.to_a.should eq modded_buffer
    end
  end

  describe "#set_element" do
    it "properly sets an element with canonical coordinates" do
      w_narr.set_element([0, 0], 'z')
      w_narr.buffer[0].should eq 'z'
      w_narr.buffer[1..].should eq test_buffer[1..]
    end

    it "properly sets an element with relative coordinates" do
      coord = [-1, -2]
      w_narr.set_element(coord, 'z')
      idx = (test_shape[0] + coord[0]) * test_shape[1] + (test_shape[1] + coord[1])
      modded_buffer = test_buffer.clone.tap &.[]=(idx, 'z')
      w_narr.buffer.should eq modded_buffer
    end

    it "raises for out of bound positive coordinates" do
      expect_raises(IndexError) do
        w_narr.set_element([10, 10], 1)
      end
    end

    it "raises for out of bound relative coordinates" do
      expect_raises(IndexError) do
        w_narr.set_element([-10, -10], 1)
      end
    end
  end

  describe "#set_chunk" do
    test_set_chunk(:set_chunk)
  end

  pending "#set_available" do
    it "sets a chunk to a scalar" do
      w_narr.set_available([1.., 1..], 10)
      
      modded_buffer = test_buffer.to_a
      modded_buffer[5..7] = [10, 10, 10]
      modded_buffer[9..11] = [10, 10, 10]
      w_narr.buffer.to_a.should eq modded_buffer
    end

    it "sets a chunk to a MultiIndexable" do
      chunk = RONArray.new([2, 3], Slice[10, 11, 12, 13, 14, 15])
      w_narr.set_available([1.., 1..], chunk)
      
      modded_buffer = test_buffer.to_a
      modded_buffer[5..7] = [10, 11, 12]
      modded_buffer[9..11] = [13, 14, 15]
      w_narr.buffer.to_a.should eq modded_buffer
    end

    it "sets only what is available for a chunk that is out of bounds" do
      chunk = RONArray.new([2, 3], Slice[10, 11, 12, 13, 14, 15])
      w_narr.set_available([1.., 1..], chunk)
      
      modded_buffer = test_buffer.to_a
      modded_buffer[5..7] = [10, 11, 12]
      modded_buffer[9..11] = [13, 14, 15]
      w_narr.buffer.to_a.should eq modded_buffer
    end
  end

  describe "#[]=" do
    test_set_chunk(:[]=)
  end
end
