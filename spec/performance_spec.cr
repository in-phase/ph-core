require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
  describe NArray do
    it "creates large, many-dimensional arrays" do

        # An excessively large array (with total # elements > max Int32) causes arithmetic overload error
        # shape = [100]*20

        size = 4
        dims = 5
        shape = [size]*dims
        #shape = [2**8, 2**8, 2**8, 2**6 - 1]

        duration = Time.measure do
            arr = NArray.fill(shape, 3f64)
        end
        
        puts "\nNArray of shape #{shape}  (#{shape.product} elements)"
        puts "  Creation time: #{duration}"
           
        arr = NArray.fill(shape, 3f64)

        regions = [[0,0,..., 1,1], [(size // 4)...(size * 3 // 4), (size // 4)..., ...(size * 3 // 4), ..., ...], [..., ..., ..., ..., ... ]]
        descriptors = ["   Small", "Moderate", "   Whole"]

        regions.each_with_index do  |region, idx|
            duration = Time.measure do
              arr.each_in_region(region) do |elem, idx, source_idx|

              end
            end
            puts "#{descriptors[idx]} region: #{duration}"

        end
    end
  end
end