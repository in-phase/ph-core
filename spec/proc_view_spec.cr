require "./multi_indexable/multi_indexable_tester.cr"
require "./test_narray.cr"
require "./spec_helper.cr"

class ProcViewTester < MultiIndexableTester(ProcView(NArray(CIS), CIS, Int32), Int32, Int32)
  alias ViewType = ProcView(NArray(CIS), CIS, Int32)
  @data : Array(Tuple(Array(Int32), Slice(CIS))) = [
    {[2, 3, 4], Slice['a', 'b', 'c', 'd', 1, 2, 3, 4, :e, :f, :g, :h, 'i', 'j', 'k', 'l', 5, 6, 7, 8, :m, :n, :o, :p]},
    {[3, 5], Slice['a', 'b', 'c', 'd', 'e', 1, 2, 3, 4, 5, :e, :f, :g, :h, :i]},
  ]

  @proc : CIS -> Int32 = -> (value : CIS) do
    case value
    in Char
      value.ord
    in Int
      value * 2
    in Symbol
      value.to_s[0].ord * 3
    end
  end

  def make : Array(ViewType)
    @data.map do |shape, buf|
      ProcView.of(NArray.of_buffer(shape.clone, buf.clone), @proc)
    end
  end

  def test_make
    it "should contain the correct data" do
      @data.zip(make) do |pair, view|
        shape, buf = pair
        narr = NArray.of_buffer(shape, buf).map { |x| @proc.call(x) }
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
        narr = NArray.of_buffer(shape, buf).map { |x| @proc.call(x) }
        view.to_narr.should eq narr
      end
    end
  end

  private def get_value : CIS
    @proc.call(@data[0][1][0])
  end

  def make_pure_empty : ViewType
    ViewType.new(NArray.new_buffer([0], Slice.new(0, get_value)), @proc)
  end

  def make_volumetric_empty : ViewType
    ViewType.new(NArray.new_buffer([3, 0, 0, 1], Slice.new(0, get_value)), @proc)
  end

  def make_pure_scalar : ViewType
    ViewType.new(NArray.new_buffer([1], Slice.new(1, get_value)), @proc)
  end

  def make_volumetric_scalar : ViewType
    View.new(NArray.new_buffer([1, 1, 1], Slice.new(1, get_value)))
  end
end

ViewTester.new.run
