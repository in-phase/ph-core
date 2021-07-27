require "./spec_helper"
require "./test_narray"

include Phase

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
small_arr = NArray.build([3, 3]) { |coord, index| index }

bufferA = Slice[1, 2, 3, 'a', 'b', 'c', 1f64, 2f64, 3f64]
r_narr = RONArray.new([3, 3], bufferA)
w_narr = WONArray.new([3, 3], bufferA)
rw_narr = RWNArray.new([3, 3], bufferA)

pending Phase::MultiWritable do
  describe ".unsafe_set_chunk" do
  end

  describe ".set_element" do
  end

  describe ".set_chunk" do
  end

  describe ".set_available" do
  end

  describe ".[]=" do
  end
end
