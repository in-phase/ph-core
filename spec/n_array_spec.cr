require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
    describe NArray do
        it "can create an NArray of zeros" do
            pp NArray.zeros([1])
        end
        it "can create an NArray of strings" do 
            pp NArray.fill([2,2], "HELLO")
        end
        it "can retrieve a scalar from a single-element vector" do 
            (NArray.fill([1], 5).to_scalar() == 5).should be_true
        end
        it "Will throw errors if trying to retrieve scalar from an array of wrong dimensions" do
            # Empty array
            expect_raises(DimensionError) do
                NArray.fill([0], 5).to_scalar()        
            end
            # Vector
            expect_raises(DimensionError) do 
                NArray.fill([2], 5).to_scalar()
            end
            # Column vector
            expect_raises(DimensionError) do
                NArray.fill([1, 2], 5).to_scalar()
            end
            # Single-element nested array
            expect_raises(DimensionError) do
                NArray.fill([1,1], 5).to_scalar()
            end
        end
        it "can return a safe copy of its shape" do
            arr = NArray.zeros([3,7])
            shape1 = arr.shape()
            (shape1 == [3,7]).should be_true
            shape1[0] = 4
            (arr.shape == [3,7]).should be_true
        end

        # TODO test shallow, and deep, copy once values can be edited
        it "can create a shallow copy" do
            one = NArray.fill([1], MutableObject.new())
            two = NArray.dup()

            # change the value of two[0] to "Two"
            # Assert that one[0] is now "Two"
        end
        it "can create a deep copy" do
            one = NArray.fill([1], "One")
            two = NArray.clone()

            # change the value of two[0] to "Two"
            # Assert that one[0] is still "One"
        end

        # TODO formalize or remove
        it "can make other nifty arrays (possibly)" do
            pp NArray.integers([3,2])
        end
    end
end
