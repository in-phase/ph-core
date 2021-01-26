require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
    describe NArray do
        it "creates an NArray of zeros" do
            pp NArray.zeros([1])
        end
        it "can create an NArray of strings" do 
            pp NArray.fill([2,2], "HELLO")
        end
        it "can retrieve a scalar from a single-element vector" do 
            NArray.fill([1], 5).to_scalar().should eq 5
        end
        it "throws an error if trying to retrieve scalar from an array of wrong dimensions" do
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
        it "returns a safe copy of its shape" do
            arr = NArray.zeros([3,7])
            shape1 = arr.shape()
            shape1.should eq [3,7]
            shape1[0] = 4
            arr.shape().should eq [3,7]
        end
        it "recognizes vectors" do 
            NArray.zeros([1]).vector?.should be_true
            NArray.zeros([5]).vector?.should be_true
            NArray.zeros([1,5]).vector?.should be_true
            NArray.zeros([2,2]).vector?.should be_false

            # Decide
            # NArray.zeros([0]).vector?
        end

        # TODO revise tests for shallow, and deep, copy once values can be edited
        it "creates a shallow copy" do
            one = NArray.fill([1], MutableObject.new())
            two = one.dup()

            one.get_by_buffer_index(0).should be two.get_by_buffer_index(0)
            # change the value of two[0] to "Two"
            # Assert that one[0] is now "Two"
        end
        it "creates a deep copy" do
            one = NArray.fill([1], MutableObject.new())
            two = one.clone()

            one.get_by_buffer_index(0).should_not be two.get_by_buffer_index(0)
            # change the value of two[0] to "Two"
            # Assert that one[0] is still "One"
        end

        # TODO formalize or remove
        it "can make other nifty arrays (possibly)" do
            one =  NArray.integers([3,2])
            two =  NArray.wrap(1,7,9,4)
            three = NArray.fill([3,2], 0)

            pp one.class, two.class

            #NArray.wrap(one, two, pad: true)
            NArray.wrap(one, three)

            expect_raises(DimensionError) do
                NArray.wrap(one, two)
            end
            
            # this doesn't work
            #pp NArray.wrap(1, 7, "foo")
        end

    end
end
