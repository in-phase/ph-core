require "./spec_helper"

include Lattice

describe Lattice do
    describe NArray do
        it "can create an NArray of zeros" do
            pp NArray.zeros([1])
        end
    end
end
