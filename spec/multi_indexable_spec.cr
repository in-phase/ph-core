require "./spec_helper"
require "./test_narray"

include Lattice

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
small_arr = NArray.build([3, 3]) { |coord, index| index }

bufferA = Slice[1, 2, 3, 'a', 'b', 'c', 1f64, 2f64, 3f64]
r_narr = RONArray.new([3,3], bufferA)
w_narr = WONArray.new([3,3], bufferA)
rw_narr = RWNArray.new([3,3], bufferA)

pending Lattice::MultiIndexable do
    describe ".empty?" do 
    end

    describe ".scalar?" do 
    end

    describe ".to_scalar " do 
    end

    describe ".first " do 
    end

    describe ".sample" do 
    end

    describe ".dimensions" do 
    end

    describe ".has_coord?" do 
    end

    describe ".has_region?" do 
    end

    describe ".get_element " do 
    end

    describe ".get " do 
    end

    describe ".get_chunk " do 
    end

    describe ".get_available" do 
    end

    describe ".[]" do 
    end

    describe ".[]?" do 
    end

    describe ".each_coord " do 
    end

    describe ".each " do 
    end

    describe ".each_with_coord " do 
    end

    describe ".map_with_coord " do 
    end

    describe ".fast " do 
    end

    describe ".each_slice " do 
    end

    describe ".slices " do 
    end

    describe ".reshape " do 
    end

    describe ".permute " do 
    end

    describe ".reverse " do 
    end

    describe ".to_narr " do 
    end

    describe ".equals? " do 
    end

    describe ".view " do 
    end

    describe ".process " do 
    end

    describe ".eq_elem " do 
    end

    describe ".hash" do 
    end

    describe "arithmetic" do 
    end

    describe "Enumerable methods" do
        # If we are confident enough in our #each testing we can
        # get rid of this
    end
end
