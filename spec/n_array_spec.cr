require "./spec_helper"
require "./test_objects"

include Lattice

describe Lattice do
    describe NArray do
        it "canonicalizes ranges" do
            narr = NArray.new([4], 0)

            good_ranges = [0...4, -1..0, 1..,  1..., ..2,  -2..-1, -2...-5, 1..1]
            canon =       [0..3,   3..0, 1..3, 1..3, 0..2, 2..3,    2..0,   1..1]
            good_ranges.each_with_index do |range, i|
                range, dir = narr.canonicalize_range(range, 0)
                range.should eq canon[i]
            end
            bad_ranges = [-5..-3, 2..4, 1...1]
            bad_ranges.each do |range|
                expect_raises(IndexError) do
                    narr.canonicalize_range(range,0)
                end
            end
        end

        it "makes slices" do
            narr = NArray.new([2,2], 0)
            puts narr.extract_buffer_indices(1,0)
            narr = NArray.new([3,3,3], 0)
            puts narr.extract_buffer_indices(0..2 , 0) # first item of each rows 1-3

            narr = NArray.build([3,3,3]) {|i| i} # Builds an NArray where the value of each element is its coords
            pp narr
            pp narr[1..2, 1..2, 1..2]

        end
        it "edits values by a boolean map" do
            mask = NArray(Bool).build([3, 3]) { |coord| coord[0] != coord[1] }

            narr = NArray.new([3,3], 0)

            narr[mask] = 1
            pp narr
            
        end
        
        it "properly packs an n-dimensional index" do
            shape = [3, 7, 4]
            narr = NArray.new(shape, 0)
            narr.pack_index([1, 1, 1]).should eq (28 + 4 + 1)

            # TODO check edge cases, failure cases
            shape = [5]
            narr = NArray.new(shape, 0)
            narr.pack_index([2]).should eq 2
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

        it "exposes unpacked indices to the user in a constructor" do
            narr = NArray(Int32).build([3, 3]) do |coord|
                next 1 if coord[0] == coord[1]
                next 0
            end

            pp narr
        end

        it "can access an element given a fully-qualified index" do
            shape = [1, 2, 3]
            narr = NArray(Int32).new(shape) { |i| i }
            narr.get(0,1,2).should eq 5
            narr.get(0,0,0).should eq 0
            expect_raises(IndexError) do
                narr.get(1,1,1)
            end
        end
        
        it "creates an NArray of primitives" do
            arr = NArray.new([1], 0f64)
            arr.should_not be_nil
            arr.shape.should eq [1]
            arr.get(0).should eq 0f64
        end
        it "can create an NArray of non-primitives" do 
            arr = NArray.new([2,2], "HELLO")
            arr.should_not be_nil
            arr.shape.should eq [2,2]
            arr.get(1,1).should eq "HELLO"
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

            one.get(0).should be two.get(0)
        end
        it "creates a deep copy" do
            one = NArray.new([1], MutableObject.new())
            two = one.clone()

            one.get(0).should_not be two.get(0)
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
