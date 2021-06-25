require "./spec_helper"
require "./test_narray"

include Lattice

# arr = NArray.build([2, 3, 2, 3]) { |coord, index| index }
# small_arr = NArray.build([3, 3]) { |coord, index| index }

VALID_REGIONS = [[0..2], [0...3, ..], [.., 3], [2..1, 0..2..2]]
test_buffer = Slice[1, 2, 3, 'a', 'b', 'c', 1f64, 2f64, 3f64]
side_length = 3
r_narr = RONArray.new([side_length] * 2, test_buffer)

Spec.before_each do
    r_narr = RONArray.new([side_length] * 2, test_buffer)
end

describe Lattice::MultiIndexable do
    describe "#empty?" do 
        it "returns true for an empty MultiIndexable" do
            empty_buffer = Slice(Int32).new(size: 0)
            RONArray.new([0], empty_buffer).empty?.should be_true
        end

        it "returns false for a nonempty MultiIndexable" do
            r_narr.empty?.should be_false
        end
    end

    describe "#scalar?" do 
        it "returns true for a 1D MultiIndexable with 1 element" do
            scalar_buffer = Slice[1]
            RONArray.new([1], scalar_buffer).scalar?.should be_true
        end

        it "returns false for a 1D MultiIndexable with more than one element" do
            scalar_buffer = Slice[1, 2, 3]
            RONArray.new([3], scalar_buffer).scalar?.should be_false
        end

        it "returns false for a multidimensional MultiIndexable with only one element" do
            scalar_buffer = Slice[1]
            RONArray.new([1, 1, 1, 1], scalar_buffer).scalar?.should be_false
        end

        it "returns false for a multidimensional MultiIndexable with multiple elements" do
            scalar_buffer = Slice[1, 2, 3, 4, 5, 6]
            RONArray.new([2, 3], scalar_buffer).scalar?.should be_false
        end
    end

    describe "#to_scalar " do 
        it "raises for a MultiIndexable with one element but multiple dimensions" do
            scalar_buffer = Slice[1]
            expect_raises DimensionError do
                RONArray.new([1, 1, 1], scalar_buffer).to_scalar
            end
        end

        it "raises for a MultiIndexable with multiple elements in one dimension" do
            scalar_buffer = Slice[1, 2, 3]
            expect_raises DimensionError do
                RONArray.new([3], scalar_buffer).to_scalar
            end
        end

        it "raises for a MultiIndexable with multiple elements and dimensions" do
            scalar_buffer = Slice[1, 2, 3, 4]
            expect_raises DimensionError do
                RONArray.new([2, 2], scalar_buffer).to_scalar
            end
        end

        it "returns the element when the MultiIndexable is a scalar" do
            scalar_buffer = Slice[1]
            RONArray.new([1], scalar_buffer).to_scalar.should eq 1
        end
    end

    describe "#first" do 
        it "returns the element at the zero coordinate from a populated MultiIndexable" do
            RONArray.new([2, 2], Slice[1, 2, 3, 4]).first.should eq 1
        end

        pending "raises some sort of error when there are no elements" do
        end
    end

    describe "#sample" do 
        it "returns an element from the MultiIndexable" do
            r_narr.sample(test_buffer.size * 10).each do |el|
                test_buffer.includes?(el).should be_true
            end
        end

        it "returns each element in similar proportion (note: this test is probabilistic, and there is a small chance it fails under normal operation)", tags: ["slow", "probabilistic"] do
            shape = [1, 2, 3]
            size = shape.product
            buffer = Slice.new(size) { |idx| idx }
            narr = RONArray.new(shape, buffer)
            
            expected_occurrences = 1000
            tolerance = 100
            sample_count = size * expected_occurrences

            tally = narr.sample(sample_count).tally
            tally.each do |_, count|
                count.should be_close(expected_occurrences, delta: tolerance)
            end
        end

        it "returns the only element in a one-element MultiIndexable" do
            narr = RONArray.new([1], Slice['a']).sample(100).each do |el|
                el.should eq 'a'
            end
        end

        it "raises when given a negative sample count" do
            expect_raises ArgumentError do
                r_narr.sample(-1)
            end
        end

        it "raises when called on an empty MultiIndexable" do
            expect_raises IndexError do
                RONArray.new([1, 1, 0], Slice(Int32).new(0)).sample
            end
        end
    end

    describe "#dimensions" do 
        it "returns the correct number of dimensions" do
            10.times do
                expected_dims = Random.rand(10).to_i32 + 1
                shape = Array(Int32).new(expected_dims) { Random.rand(10).to_i32 + 1 }
                data = Slice.new(shape.product, 0)
                dims = RONArray.new(shape, data).dimensions

                if dims != expected_dims
                    fail("shape #{shape} has #{expected_dims} dimensions, but MultiIndexable#dimensions returned #{dims}!")
                end
            end
        end
    end

    describe "#has_coord?" do 
        it "returns true for a coordinate within the shape" do
            (0...side_length).each do |x|
                (0...side_length).each do |y|
                    r_narr.has_coord?([x, y]).should be_true
                    r_narr.has_coord?(x, y).should be_true
                end
            end
        end

        it "returns false for a coordinate outside the shape" do
            (0...(side_length + 2)).each do |x|
                (0...(side_length + 2)).each do |y|
                    next if x < side_length || y < side_length

                    r_narr.has_coord?([x, y]).should be_false
                    r_narr.has_coord?(x, y).should be_false
                end
            end
        end

        it "raises an error when the coordinate is of the wrong dimension" do
            expect_raises DimensionError do
                r_narr.has_coord?([0])
            end

            expect_raises DimensionError do
                r_narr.has_coord?(0)
            end
        end
    end

    describe "#has_region?" do 
        it "returns true for valid regions" do
            VALID_REGIONS.each do |region|
                unless r_narr.has_region?(region)
                    fail(r_narr.shape.join("x") " MultiIndexable should include #{region.to_s}, but has_region? was false")
                end
            end
        end

        pending "returns false for invalid regions" do
        end
    end

    describe "#get_element" do 
    end

    describe "#get" do 
    end

    describe "#get_chunk" do 
    end

    describe "#get_available" do 
    end

    describe "#[]" do 
    end

    describe "#[]?" do 
    end

    describe "#each_coord" do 
    end

    describe "#each" do 
    end

    describe "#each_with_coord" do 
    end

    describe "#map_with_coord" do 
    end

    describe "#fast" do 
    end

    describe "#each_slice" do 
    end

    describe "#slices" do 
    end

    describe "#reshape" do 
    end

    describe "#permute" do 
    end

    describe "#reverse" do 
    end

    describe "#to_narr" do 
    end

    describe "#equals?" do 
    end

    describe "#view" do 
    end

    describe "#process" do 
    end

    describe "#eq_elem" do 
    end

    describe "#hash" do 
    end

    describe "arithmetic" do 
    end

    describe "Enumerable methods" do
        # If we are confident enough in our #each testing we can
        # get rid of this
    end
end
