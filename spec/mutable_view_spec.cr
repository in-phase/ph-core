require "./multi_indexable/multi_indexable_tester.cr"
require "./spec_helper.cr"

class MutableViewTester < MultiIndexableTester(MutableView(NArray(CIS), CIS), CIS, Int32)
  alias ViewType = MutableView(NArray(CIS), CIS)
  @data : Array(Tuple(Array(Int32), Slice(CIS))) = [
    {[2, 3, 4], Slice['a', 'b', 'c', 'd', 1, 2, 3, 4, :e, :f, :g, :h, 'i', 'j', 'k', 'l', 5, 6, 7, 8, :m, :n, :o, :p]},
    {[3, 5], Slice['a', 'b', 'c', 'd', 'e', 1, 2, 3, 4, 5, :e, :f, :g, :h, :i]},
  ]

  def make : Array(ViewType)
    @data.map { |shape, buf| MutableView.new(NArray.of_buffer(shape.clone, buf.clone)) }
  end

  def test_make
    it "should contain the correct data" do
      @data.zip(make) do |pair, view|
        shape, buf = pair
        narr = NArray.of_buffer(shape, buf)
        view.shape.should eq shape

        narr.each_with_coord do |el, coord|
          view.get(coord).should eq el
        end
      end
    end
  end

  def test_to_narr
    it "should properly convert to a NArray" do
      @data.zip(make).each do |pair, view|
        shape, buf = pair
        narr = NArray.of_buffer(shape, buf)
        view.to_narr.should eq narr
      end
    end
  end

  private def get_value : CIS
    @data[0][1][0]
  end

  def make_pure_empty : ViewType
    MutableView.new(NArray.of_buffer([0], Slice.new(0, get_value)))
  end

  def make_volumetric_empty : ViewType
    MutableView.new(NArray.of_buffer([3, 0, 0, 1], Slice.new(0, get_value)))
  end

  def make_pure_scalar : ViewType
    MutableView.new(NArray.of_buffer([1], Slice.new(1, get_value)))
  end

  def make_volumetric_scalar : ViewType
    MutableView.new(NArray.of_buffer([1, 1, 1], Slice.new(1, get_value)))
  end
end

MutableViewTester.new.run
