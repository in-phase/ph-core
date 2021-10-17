require "./multi_indexable/multi_indexable_tester.cr"
require "./test_narray.cr"

class VanillaMultiIndexableTester(T) < MultiIndexableTester(RONArray(T), T, Int32)
  def initialize(@buffer : Slice(T), @shape : Array(Int32))
    raise "buffer size doesn't match shape" unless @buffer.size == @shape.product
  end

  def make : RONArray(T)
    RONArray.new(@shape.clone, @buffer.clone)
  end

  def test_make
    it "should have the correct buffer" do
      make.buffer.should eq @buffer
    end

    it "should have the correct shape" do
      make.shape.should eq @shape
    end
  end

  def test_to_narr
    narr = make.to_narr

    it "should have the correct buffer" do
      narr.buffer.should eq @buffer
    end

    it "should have the correct shape" do
      narr.shape.should eq @shape
    end
  end

  def make_pure_empty : RONArray(T)
    RONArray(T).new([0], Slice(T).new(0, @buffer[0]))
  end

  def make_volumetric_empty : RONArray(T)
    RONArray(T).new([5, 0, 2], Slice(T).new(0, @buffer[0]))
  end

  def make_pure_scalar : RONArray(T)
    RONArray(T).new([1], Slice(T).new(1, @buffer[0]))
  end

  def make_volumetric_scalar : RONArray(T)
    RONArray(T).new([1, 1, 1], Slice(T).new(1, @buffer[0]))
  end
end

buffer = Slice['a', 'b', 'c', 'd', 1, 2, 3, 4, :e, :f, :g, :h]
VanillaMultiIndexableTester.new(buffer, [3, 4]).run
