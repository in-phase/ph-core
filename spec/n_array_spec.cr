require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
    describe NArray do
        it "properly packs an n-dimensional index" do
            shape = [3, 7, 4]
            narr = NArray.new(shape, 0)
            narr.pack_index([1, 1, 1]).should eq (28 + 4 + 1)

            # TODO check edge cases, failure cases
        end

        it "properly packs and unpacks an n-dimensional index" do
            shape = [3, 7, 4]
            narr = NArray.new(shape, 0)
            
            100.times do
                random_index = shape.map { |dim| (Random.rand * dim).to_u32 }
                packed = narr.pack_index(random_index)
                narr.unpack_index(packed).should eq random_index
            end
        end
        
        it "creates an NArray of zeros" do
            pp NArray.new([1], 0f64)
        end
        it "can create an NArray of strings" do 
            pp NArray.new([2,2], "HELLO")
        end
        it "can retrieve a scalar from a single-element vector" do 
            NArray.new([1], 5).to_scalar().should eq 5
        end
        it "throws an error if trying to retrieve scalar from an array of wrong dimensions" do
            # Empty array
            expect_raises(DimensionError) do
                NArray.new([0], 5).to_scalar()        
            end
            # Vector
            expect_raises(DimensionError) do 
                NArray.new([2], 5).to_scalar()
            end
            # Column vector
            expect_raises(DimensionError) do
                NArray.new([1, 2], 5).to_scalar()
            end
            # Single-element nested array
            expect_raises(DimensionError) do
                NArray.new([1,1], 5).to_scalar()
            end
        end
        it "returns a safe copy of its shape" do
            arr = NArray.new([3,7], 0f64)
            shape1 = arr.shape()
            shape1.should eq [3,7]
            shape1[0] = 4
            arr.shape().should eq [3,7]
        end
        # TODO revise tests for shallow, and deep, copy once values can be edited
        it "creates a shallow copy" do
            one = NArray.new([1], MutableObject.new())
            two = one.dup()

            one.get_by_buffer_index(0).should be two.get_by_buffer_index(0)
            # change the value of two[0] to "Two"
            # Assert that one[0] is now "Two"
        end
        it "creates a deep copy" do
            one = NArray.new([1], MutableObject.new())
            two = one.clone()

            one.get_by_buffer_index(0).should_not be two.get_by_buffer_index(0)
            # change the value of two[0] to "Two"
            # Assert that one[0] is still "One"
        end

        # TODO formalize or remove
        it "can make other nifty arrays (possibly)" do
            one =  NArray.new([3,2], 1)
            two =  NArray.wrap(1,7,9,4)
            three = NArray.new([3,2], 0)

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
