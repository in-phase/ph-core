require "./spec_helper"

include Lattice::RegionHelpers

describe Lattice::RegionHelpers do
    describe ".has_index?" do
        shape = [1,5,1]
        it "determines whether a positive index is in bounds" do 
            has_index?(4, shape, 1).should be_true
            has_index?(5, shape, 1).should be_false
        end
        it "determines if a negative index is in bounds" do 
            has_index?(-5, shape, 1).should be_true
            has_index?(-6, shape, 1).should be_false
        end
        it "handles empty axes" do 
            has_index?(0, [0, 2], 0).should be_false
        end
        it "handles large sizes" do 
            max_shape = [Int32::MAX]
            has_index?(Int32::MAX, max_shape, 0).should be_false
            has_index?(Int32::MAX - 1, max_shape, 0).should be_true

            has_index?(Int32::MIN, max_shape, 0).should be_false
            has_index?(Int32::MIN + 1, max_shape, 0).should be_true
        end
        it "fails predictably when given an invalid axis" do 
            expect_raises(IndexError) do
                has_index?(-2, shape, 4)
            end
        end
    end
    describe ".has_coord?" do
        shape = [1,3,5]
        it "correctly labels an in-bounds canonical coordinate" do 
            has_coord?([0,2,4], shape).should be_true
        end
        it "correctly labels a non-canonical, in-bounds coordinate" do
            has_coord?([-1,-3,-5], shape).should be_true
            has_coord?([0,-1,-2], shape).should be_true
        end
        it "correctly detects out-of-bounds coordinates" do
            has_coord?([1, 2, 4], shape).should be_false
            has_coord?([0, 2, -6], shape).should be_false
            has_coord?([-Int32::MAX, Int32::MAX, 0], shape).should be_false
        end
        pending "rejects coordinates of the wrong dimensionality" do 
            has_coord?([0,0], shape).should be_false
            has_coord?([0,0,0,0], shape).should be_false

            # TODO : discuss these cases. 
            # What if shape extends only with ones? what if coord extends only 0's?
            has_coord?([2,2], [4,3,1,1]).should be_false
            # has_coord?([2,2,0,0], [4,3]).should   ???
        end
        it "handles empty axes" do
            has_coord?([4,2,5], [10,10,0]).should be_false
        end
        it "handles large sizes" do 
            max_shape = [Int32::MAX, Int32::MAX]
            has_coord?([Int32::MAX - 1, Int32::MIN + 1], max_shape).should be_true
            has_coord?([Int32::MAX - 1, Int32::MAX], max_shape).should be_false
        end
    end
    pending ".has_region?" do
        it "rejects region specifiers of the wrong dimensionality" do 
        end
    end
    describe ".canonicalize_index" do
        shape = [0, 1, 10, Int32::MAX]
        it "preserves legal positive indices" do 
            canonicalize_index(9, shape, 2).should eq 9
            canonicalize_index(0, shape, 3).should eq 0
        end
        it "converts legal negative indices" do
            canonicalize_index(Int32::MIN + 1, shape, 3).should eq 0
            canonicalize_index(-10, shape, 2).should eq 0
            canonicalize_index(-1, shape, 2).should eq 9
            canonicalize_index(-1, shape, 1).should eq 0
        end
        it "raises an IndexError when given an invalid index" do 
            expect_raises(IndexError) do
                canonicalize_index(-2, shape, 1)
            end
            expect_raises(IndexError) do
                canonicalize_index(0, shape, 0)
            end
        end
    end

    describe ".canonicalize_coord" do
        shape = [1, 10, Int32::MAX]
        it "preserves canonical coordinates" do 
            tests = [[0, 9, Int32::MAX - 1], [0,0,0], [0,5,200]]
            tests.each do |coord|
                canonicalize_coord(coord, shape).should eq coord
            end
        end
        it "converts any negative indices to positive" do 
            tests = [[-1, -10, Int32::MIN + 1], [-1,-1,-1], [0,-5,200]]
            expected = [[0,0,0], [0,9,Int32::MAX - 1], [0, 5, 200]]
            tests.each_with_index do |coord, i|
                canonicalize_coord(coord, shape).should eq expected[i]
            end
        end
        it "raises an IndexError if at least one index is out of range" do 
            tests = [shape, [0,0, Int32::MAX], [0,-11,Int32::MIN + 1]]
            tests.each do |coord|
                expect_raises(IndexError) do
                    canonicalize_coord(coord, shape)
                end
            end
        end
    end
    describe ".canonicalize_range" do
        shape = [1, 10, 1000]
        it "preserves a canonical SteppedRange" do 
            data = [{1..7, 2}, {200..0, -50}, {0..0, 1}]
            data.each do |el|
                range = SteppedRange.new(*el)
                canonicalize_range(range, shape, 2).should eq range
            end
        end
        it "converts a non-canonical SteppedRange to canonical" do 
            data = [{1..8, 2}, {-10..-5, 1}, {-1..1, -3}]
            exp_data = [{1..7, 2}, {0..5, 1}, {9..3, -3}]
            data.each_with_index do |el, i|
                range = SteppedRange.new(*el)
                expected = SteppedRange.new(*exp_data[i])
                canonicalize_range(range, shape, 1).should eq expected
            end
        end
        it "correctly parses endpoints of a regular Range" do
            data = [1..7, -4..3, -1..0]
            data.each_with_index do |range, i|
                output = canonicalize_range(range, shape, 1)
                output.begin.should eq canonicalize_index(range.begin, shape, 1)
                output.end.should eq canonicalize_index(range.end, shape, 1)
            end
        end
        it "infers the correct step direction for a regular Range" do 
            data = [1..6, -6..-1, 6..1, -1..-6]
            expected = [1,1,-1,-1]
            data.each_with_index do |range, i|
                canonicalize_range(range, shape, 1).step.should eq expected[i]
            end
        end
        it "correctly parses input of the form start..step_size..end" do 
            data = [{1,2,5}, {-3,-1,2}, {0, 5, -5}]
            data.each_with_index do |el, i|
                start, step, finish = el
                output = canonicalize_range(start..step..finish, shape, 1)
                output.begin.should eq canonicalize_index(start, shape, 1)
                output.end.should eq canonicalize_index(finish, shape, 1)
                output.step.should eq step
            end
        end
        it "adjusts end of stepped ranges such that step evenly divides the range" do 
            data = [3..3..9, 4..4..7, 3..-2..0]
            expected = [9, 4, 1]
            data.each_with_index do |range, i|
                canonicalize_range(range, shape, 1).end.should eq expected[i]
            end
        end
        it "adjusts for end-exclusive inputs" do 
            data = [0...10, 9...-11, 1..3...8, 1..3...7, -5...-2]
            expected = [9, 0, 7, 4, 7]
            data.each_with_index do |range, i|
                canonicalize_range(range, shape, 1).end.should eq expected[i]
            end
        end
        pending "infers range start" do 
            # currently: always sets start to 0. But what if using fancy ranges?
            data = [.., ..5, ...-3, ..1..5, ..-1..5, ..2..7, ..-3..2]
            # 2..3.. [2, 5, ...] ..-3..2 [.., 5, 2]
            #                    ..-3...2 [.., something, something != 2]
            # 2...3..
            # 1..2..6
            # 1..2...6
            # ..-3..2
            # size = 10: 9, 6, 3
            expected = [0, 0, 0,    0,      9,       0,      9]
            data.each_with_index do |range, i|
                canonicalize_range(range, shape, 1).begin.should eq 0
            end
        end
        pending "infers range end" do 
            data =     [.., 5.., -3..., -1.., 5..1..., 5..-1..., 2..2..., 5..-3...]
            expected = [9,  9,   9,     9,    9,       0,        8,       2]
            data.each_with_index do |range, i|
                canonicalize_range(range, shape, 1).end.should eq expected[i]
            end
        end
        pending "accepts a StepIterator" do
        end
        pending "raises an IndexError if the input step direction and inferred step direction do not match" do 

        end
        it "raises an IndexError if the range start or end are out of bounds" do 
            data = [-11..-3, 10..-3, 2..-11, 2...-12]
            data.each do |range|
                expect_raises(IndexError) do 
                    canonicalize_range(range, shape, 1).end
                end
            end
        end
        it "raises an IndexError if the range spans no integers" do
            data = [4...4, -5...5, ...0]
            data.each do |range|
                expect_raises(IndexError) do
                    canonicalize_range(range, shape, 1)
                end
            end
        end
    end
    pending ".canonicalize_region" do
      
    end
    pending ".measure_canonical_region" do
        it "measures correctly" do
            # region = canonicalize_region([])
        end
    end
    pending ".measure_region" do
      
    end
    pending "SteppedRange" do
        # TODO: discuss: should part of canonicalization happen on SteppedRange creation rather than separately?
    
        describe ".new" do
            it "accepts a single index" do
            end
            it "accepts a positive range and compatible step" do 
            end
            it "measures the size of (number of elements traversed by) the SteppedRange" do 
                
            end
            pending "warns against invalid inputs" do 
            end
        end
        describe ".reverse" do
            # These would not necessarily be valid if a SteppedRange is not restricted to canonical
            it "swaps the start and end of a range" do 
            end
            it "reverses the step" do 
            end
            it "preserves size" do 
            end
        end
        describe ".local_to_absolute" do
            # for inputs n between begin and end,

      
        end
        describe ".compose" do
      
        end
        describe ".each" do
      
        end
    end
end