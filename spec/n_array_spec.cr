require "./spec_helper"

include Lattice

describe Lattice do
    describe NArray do
        it "can create an NArray of zeros" do
            arr = NArray.zeros([1])
            pp arr
            puts arr
        end
        it "can create an NArray of strings" do 

            strarr = NArray.fill([2,2], "HELLO")
            pp strarr
            puts strarr
            
        end
    end
end
