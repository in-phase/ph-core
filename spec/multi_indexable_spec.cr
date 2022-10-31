require "./multi_indexable/multi_indexable_tester.cr"
require "./test_narray.cr"
require "./spec_helper.cr"

class VanillaMultiIndexableTester < MultiIndexableTester(RONArray(CIS), CIS, Int32)
  @data : Array(Tuple(Array(Int32), Slice(CIS))) = [
    {[3, 4], Slice['a', 'b', 'c', 'd', 1, 2, 3, 4, :e, :f, :g, :h]},
    {[3, 5], Slice['a', 'b', 'c', 'd', 'e', 1, 2, 3, 4, 5, :e, :f, :g, :h, :i]},
  ]

  def make :  Array(RONArray(CIS))
    to_return = @data.map { |shape, buf| RONArray.new(shape.clone, buf.clone) }
  end

  def test_make
    it "should contain the correct data" do
      @data.zip(make) do |pair, narr|
        shape, buf = pair
        narr.shape.should eq shape
        narr.buffer.should eq buf
      end
    end
  end

  def test_to_narr
    it "should preserve the data" do
      @data.zip(make).each do |pair, narr|
        shape, buf = pair
        narr.shape.should eq shape
        narr.buffer.should eq buf
      end
    end
  end

  private def get_value : CIS
    @data[0][1][0]
  end

  def make_pure_empty : RONArray(T)
    RONArray(T).new([0], Slice(T).new(0, get_value))
  end

  def make_volumetric_empty : RONArray(T)
    RONArray(T).new([5, 0, 2], Slice(T).new(0, get_value))
  end

  def make_pure_scalar : RONArray(T)
    RONArray(T).new([1], Slice(T).new(1, get_value))
  end

  def make_volumetric_scalar : RONArray(T)
    RONArray(T).new([1, 1, 1], Slice(T).new(1, get_value))
  end
end

VanillaMultiIndexableTester.new.run
