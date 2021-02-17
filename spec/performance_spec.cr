require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
  describe NArray do
    it "creates large, many-dimensional arrays" do

        # An excessively large array (with total # elements > max Int32) causes arithmetic overload error
        #shape = [100]*20

        size = 20
        dims = 5
        shape = [size]*dims

        duration = Time.measure do
            arr = NArray.fill(shape, 3f64)
        end
        
        puts "\nNArray of shape #{shape}  (#{size ** dims} elements)"
        puts "  Creation time: #{duration}"
           
        arr = NArray.fill(shape, 3f64)

        regions = [[0,0,..., 1,1], [(size // 4)...(size * 3 // 4), (size // 4)..., ...(size * 3 // 4), ..., ...], [..., ..., ..., ..., ... ]]
        descriptors = ["   Small", "Moderate", "   Whole"]

        regions.each_with_index do  |region, idx|
            duration = Time.measure do
                indices = arr[region]
            end
            puts "#{descriptors[idx]} region: #{duration}"

        end
    end
  end
end