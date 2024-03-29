require "./spec_helper"
require "./test_narray"

include Phase

# This test suite is a little bloated - may be useful to eventually redo it in a more targeted fashion.


bound = 10
valid = TestRanges.fully_defined(bound).merge(TestRanges.negative_indices(bound)).merge(TestRanges.implicit_bounds(bound))

def checkIndexRegion(idx_r, vals)
    idx_r.@first[0].should eq vals[:first]
    idx_r.@step[0].should eq vals[:step] 
    idx_r.@last[0].should eq vals[:last]
    idx_r.shape[0].should eq ((vals[:last] - vals[:first]) // vals[:step] + 1)
end


# NOTES
# - first, step, last are mutable from outside
#   - is this desirable?
# - shape should be safe, but test this


macro test_on(type, cast)
    describe ".new" do 

        context "(region_literal, bound_shape)" do
            valid.each do |r,v|
                it "parses a legal range literal (#{r}, bound: #{bound.{{cast}}})" do 
                    idx_r = IndexRegion.new([r], [bound.{{cast}}])

                    idx_r.should be_a IndexRegion({{type}})
                    checkIndexRegion(idx_r, v)
                end
            end

            TestRanges.out_of_bounds(bound).each do |r|
                it "throws an error when range is out of bounds (#{r}, bound: #{bound.{{cast}}})" do 
                    expect_raises IndexError do
                        idx_r = IndexRegion.new([r], [bound.{{cast}}])
                    end
                end
            end

            TestRanges.step_conflict.each do |r|
                it "throws an error when given a step conflict (#{r})" do 
                    expect_raises IndexError do
                        idx_r = IndexRegion.new([r], [bound.{{cast}}])
                    end
                end
            end

            TestRanges.empty.each do |r|
                it "gives size 0 when range spans no integers (#{r})" do 
                    idx_r = IndexRegion.new([r], [bound.{{cast}}])
                    
                    idx_r.size.should eq 0
                    idx_r.should be_a IndexRegion({{type}})
                end
            end

            it "checks bounds along the correct axes for multidimensional regions" do 
                shape = [10.{{cast}}, 4.{{cast}}]

                idx_r = IndexRegion.new([0..2..8, ..-1..], shape)
                idx_r.dimensions.should eq 2 
                idx_r.shape.should eq [5, 4]
                idx_r.@first.should eq [0,3]
                idx_r.@last.should eq [8,0]
                idx_r.@step.should eq [2, -1]

                expect_raises IndexError do 
                    idx_r = IndexRegion.new([0..3, 0..2..8], shape)
                end
            end

            pending "properly interprets degeneracy of integer inputs" do 
            end
        end 

        pending "(region_literal, *, trim_to)" do 

        end

        context "(region_literal)" do 
            TestRanges.fully_defined(bound).each do |r, v|
                it "correctly parses a fully defined range literal (#{r})" do 
                    idx_r = IndexRegion({{type}}).new([r])
                    idx_r.should be_a IndexRegion({{type}})

                    checkIndexRegion(idx_r, v)
                end
            end

            TestRanges.implicit_bounds(bound).each do |r, v|
                it "throws an error if an endpoint cannot be inferred (#{r})" do 
                    # TODO: make this a better error type
                    expect_raises Exception do
                        IndexRegion({{type}}).new([r])
                    end
                end
            end

            TestRanges.negative_indices(bound).each do |r,v|
                it "throws an error on negative (relative) indices (#{r})" do 
                    expect_raises IndexError do
                        IndexRegion({{type}}).new([r])
                    end
                end
            end

            TestRanges.step_conflict.each do |r|
                it "throws an error when given a step conflict (#{r})" do 
                    expect_raises IndexError do
                        IndexRegion({{type}}).new([r])
                    end
                end
            end

            TestRanges.empty.each do |r|
                it "gives size 0 when range spans no integers (#{r})" do 
                idx_r = IndexRegion({{type}}).new([r])
                    
                idx_r.size.should eq 0
                idx_r.should be_a IndexRegion({{type}})
                end
            end

            it "interprets multidimensional regions" do 
                idx_r = IndexRegion({{type}}).new([0..2..8, 3..-1..])
                idx_r.dimensions.should eq 2 
                idx_r.shape.should eq [5, 4]
                idx_r.@first.should eq [0,3]
                idx_r.@last.should eq [8,0]
                idx_r.@step.should eq [2, -1]
            end
        end

        context "(index_region, bound_shape)" do 
            valid.each do |r,v|
                it "copies an IndexRegion that is in bounds (#{r})" do 
                    idx_r = IndexRegion.new([r],[bound.{{cast}}])
                    copy = IndexRegion.new(idx_r, [bound.{{cast}} + 5])
                    
                    pointerof(idx_r).should_not (eq pointerof(copy)), "Equal references; copy not made"
                    idx_r.@first.should eq copy.@first
                    idx_r.@last.should eq copy.@last
                    idx_r.@step.should eq copy.@step
                    idx_r.shape.should eq copy.shape 
                    idx_r.degeneracy.should eq copy.degeneracy 
                    idx_r.drop.should eq copy.drop
                end

                it "throws an error for an IndexRegion that is out of bounds" do 
                    idx_r = IndexRegion.new([r],[bound.{{cast}}])

                    max_val = {v[:first], v[:last]}.max
                    if max_val > 0
                        new_bound = {{type}}.new(max_val - 1)
                        expect_raises ShapeError do 
                            copy = IndexRegion.new(idx_r, [new_bound])
                        end
                    end
                end
            end
        end

        pending "(first, step, *, last)" do 
            # first, step,, last not same size
            # first, last invalid coords
            # step conflict
            # passing degeneracy
                # catch: if degeneracy is set to true for some axis where size != 0
        end

        pending "(first, step, *, shape)" do 
        end

    end

    describe "#shape" do 

        it "returns [1] if all dimensions are dropped" do 
        end
        
    end

    describe "#size" do 
    end

    describe "#proper_dimensions" do 

    end

    describe "#dimensions" do 

        it "behaves like proper_dimensions if no dimensions are dropped" do 
        end

        it "gives the number of preserved dimensions" do 
        end

        it "is consistent with the size of `shape`" do 
        end

        it "returns 1 if all dimensions are dropped" do 
        end
    end

    describe "#unsafe_fetch_chunk" do 
    end

    describe "#unsafe_fetch_element" do 
    end

    describe "#includes?" do 

        it "detects coordinates outside the region's bounds" do 
            r = IndexRegion({{type}}).new([3..5, 10..-2..2])

            r.includes?([6, 4]).should be_false
            r.includes?([2, 4]).should be_false
            r.includes?([4, 11]).should be_false 
            r.includes?([4, 0]).should be_false 
            r.includes?([0, 0]).should be_false
        end

        it "detects coordinates that do not align with the region's step" do 
            r = IndexRegion({{type}}).new([3..5, 10..-2..2])

            r.includes?([4, 5]).should be_false
        end

        it "returns true for coordinates in the region" do 
            r = IndexRegion({{type}}).new([3..5, 10..-2..2])

            (3..5).each do |a|
                10.step(by: -2, to: 2).each do |b|
                    r.includes?([a,b]).should be_true 
                end
            end
        end
    end

    describe "#fits_in?" do 
        valid.each do |r,v|
            it "returns true if the region fits in shape (#{r}, bound: #{bound.{{cast}}})" do 
                IndexRegion.new([r],[bound.{{cast}}]).fits_in?([bound.{{cast}}]).should be_true
            end

            it "returns false if the region does not fit in shape" do 
                max_val = {v[:first], v[:last]}.max
                new_bound = {{type}}.new(max_val)
                IndexRegion.new([r],[bound.{{cast}}]).fits_in?([new_bound]).should be_false
            end
        end

        it "checks bounds on proper axis for multidimensional regions" do 
            idx_r = IndexRegion({{type}}).new([0..2..8, 3..-1..])

            idx_r.fits_in?([10,4]).should be_true 
            idx_r.fits_in?([4,10]).should be_false
        end

    end

    describe "#trim!" do 
        valid.each do |r,v|
            it "preserves regions that fit in shape (#{r}, bound: #{bound.{{cast}}})" do 
                idx_r = IndexRegion.new([r], [bound.{{cast}}])
                idx_r.trim!([bound])

                checkIndexRegion(idx_r, v)
            end

            idx_r = IndexRegion.new([r], [bound.{{cast}}])

            if v[:last] > v[:first]
                it "trims from the end if only last is out of bounds (#{idx_r})" do 
                    idx_r.trim!([v[:last]])
                    new_last = v[:last] - v[:step]
                    checkIndexRegion(idx_r, {first: v[:first], step: v[:step], last: new_last})
                end
            elsif v[:first] > v[:last]
                it "trims from the start if only first is out of bounds (#{idx_r})" do 
                    idx_r.trim!([v[:first]])
                    new_first = v[:first] + v[:step]
                    checkIndexRegion(idx_r, {first: new_first, step: v[:step], last: v[:last]})
                end
            else
                it "returns an empty region if both are out of bounds (#{idx_r})" do 
                    idx_r.trim!([v[:last]])
                    idx_r.size.should eq 0
                end
            end
        end

        it "trims along the correct axes for multidimensional regions" do 
            idx_r = IndexRegion.cover([20, 20])
            idx_r.trim!([10, 4])
            idx_r.fits_in?([10, 4]).should be_true 
            idx_r.fits_in?([4, 10]).should be_false
        end
    end

    describe "#translate!" do 

        offset = [-3, 5]
        idx_r = IndexRegion({{type}}).new([3..4..20, 7..-2..])
        translated = idx_r.clone.translate!(offset)

        it "preserves the shape of the region" do 
            translated.shape.should eq idx_r.shape
        end

        it "offsets first and last by the translation vector" do 
            translated.@first.should eq idx_r.@first.map_with_index {|el, i| el + offset[i]}
            translated.@last.should eq idx_r.@last.map_with_index {|el, i| el + offset[i]}
        end

        it "offsets internal coordinates by the translation vector" do
            translated.get(3, 1).should eq idx_r.get(3,1).map_with_index {|el, i| el + offset[i]}
        end

        # DISCUSS OverflowError
        it "throws an error if the translation causes coordinates to become negative" do 
            # checking last
            expect_raises IndexError do 
                idx_r.clone.translate!([0, -2])
            end

            # checking first
            expect_raises IndexError do 
                idx_r.clone.translate!([-4, 0])
            end
        end
    end

    describe "#reverse!" do 
        it "can operate in-place" do 
            idx_r = IndexRegion({{type}}).new([2..6, 8..-2..1])
            idx_r.reverse!

            idx_r.@first.should eq [6, 2]
        end

        it "swaps first and last" do 
            idx_r = IndexRegion({{type}}).new([2..6, 8..-2..1])
            reverse = idx_r.clone.reverse!

            reverse.@first.should eq idx_r.@last 
            reverse.@last.should eq idx_r.@first
        end

        it "negates step" do 
            idx_r = IndexRegion({{type}}).new([2..6, 8..-2..1])
            reverse = idx_r.clone.reverse!

            reverse.@step.zip(idx_r.@step).each {|rev, fwd| rev.should eq -fwd} 
        end

        it "preserves shape and degeneracy" do 
            idx_r = IndexRegion({{type}}).new([2..6, 8..-2..1])
            reverse = idx_r.clone.reverse!

            idx_r.shape.should eq reverse.shape 
            idx_r.degeneracy.should eq reverse.degeneracy
        end
    end

    describe "#local_to_absolute_unsafe" do 

        it "does stuff" do 
            idx_r = IndexRegion({{type}}).new([3, 0..4], drop: false)

        end


        it "takes degeneracy into account" do 
            idx_r = IndexRegion({{type}}).new([3, 0..4])
        end

    end

    describe "#absolute_to_local_unsafe" do

        it "takes degeneracy into account" do 
        end
    end

    describe "#each" do 
    end
end



    
    
describe "Phase::IndexRegion" do
    context "(Int32)" do 
        test_on(Int32, to_i32)
    end

    context "(UInt8)" do
        test_on(UInt8, to_u8)
    end

    context "(BigInt)" do 
        test_on(BigInt, to_big_i)
    end
end
