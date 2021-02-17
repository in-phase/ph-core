require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
  describe NArray do
    it "creates large, many-dimensional arrays" do

        # This causes arithmetic overflow error:
        #shape = [100]*20


        size = 40

        shape = [size]*5

        duration = Time.measure do
            arr = NArray.fill(shape, 3f64)
        end

        puts "Creation time: #{duration}"
           
        arr = NArray.fill(shape, 3f64)

        regions = [[0,0,..., 1,1], [(size // 4)...(size * 3 // 4), (size // 4)..., ...(size * 3 // 4), ..., ...], [..., ..., ..., ..., ... ]]

        # regions.each do  |region|

        #     duration = Time.measure do
        #         shape, indices = arr.extract_buffer_indices(region)
        #         indices.map {|i| arr.buffer[i] }
        #     end

        #     puts duration

        # end

        duration = Time.measure do
          arr.slices(2)
        end

        puts duration
    end
  end
end