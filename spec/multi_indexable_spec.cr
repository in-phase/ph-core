require "./spec_helper"

include Lattice

# Tests methods of MultiIndexable

arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
small_arr = NArray.build([3, 3]) { |coord, index| index }


describe Lattice::MultiIndexable do
    
end
