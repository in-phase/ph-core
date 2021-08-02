require "./spec_helper"
require "./test_narray"

include Phase

# Test on: Int32, Uint8, BigInt

bound = 10
mid = 7
full = {first: 0, step: 1, last: bound - 1}



fully_defined = {
    mid..mid    => {first: mid, step: 1, last: mid},

    # implicit start
    ..mid       => {first: 0, step: 1, last: mid},
    ...mid      => {first: 0, step: 1, last: mid - 1},

    # integer
    0           => {first: 0, step: 1, last: 0},
    bound - 1   => {first: bound - 1, step: 1, last: bound - 1},

    # Backward iteration
    mid..0      => {first: mid, step: -1, last: 0},
    mid..-1..   => {first: mid, step: -1, last: 0},

    # Explicit step
    # these catch both the case where the step evenly divides to the end, and not
    0..2...bound        => {first: 0, step: 2, last: bound - 1 - ((bound - 1) % 2) },
    0..2...(bound - 1)  => {first: 0, step: 2, last: bound - 2 - (bound % 2)},
    # Order should matter, associativity should not
    (5..-3)..1  => {first: 5, step: -3, last: 2},
    5..(-3..1)  => {first: 5, step: -3, last: 2},

    # Steppable::StepIterator
    (bound - 1).step(by: -1, to: 0)  =>  {first: bound - 1, step: -1, last: 0},
    0.step(by: 2, to: bound, exclusive: true)         => {first: 0, step: 2, last: bound - 1 - ((bound - 1) % 2) },
    0.step(by: 2, to: bound - 1, exclusive: true)     => {first: 0, step: 2, last: bound - 2 - (bound % 2)},
}

# these may only be used when a bounding shape is provided
negative_indices = {
    -bound..    => full,
    ..-bound    => {first: 0, step: 1, last: 0},
    ..-1        => full,
    -mid..(-mid + 2) => {first: bound - mid, step: 1, last: bound - mid + 2},
    -mid        => {first: bound - mid, step: 1, last: bound - mid},
}

# these may only be used on trimmed regions
implicit_bounds = {
    ..          => full, 
    ...         => full,
    mid..       => {first: mid, step: 1, last: bound - 1},

    # explicit step
    ..-1..      => {first: bound - 1, step: -1, last: 0},
    ..-1...2    => {first: bound - 1, step: -1, last: 3},
    (..-4)..    => {first: bound - 1, step: -4, last: (bound - 1) % 4},
    ..(-4..)    => {first: bound - 1, step: -4, last: (bound - 1) % 4},
}

out_of_bounds = [
    ..bound,
    bound..,
    (-bound - 1)..,
    ..(-bound - 1),
    ...(bound + 1)
]

empty = [
    ...0,
    3...3
]

step_conflict = [
    4..1..2,
    2..-1..4,
    4.step(by: 1, to: 2),
    2.step(by: -1, to: 4),
    # 3.step(by: 0, to: 5), # throws ArgumentError on creation
]

valid = fully_defined.merge(negative_indices).merge(implicit_bounds)

describe "IndexRegion" do
    
    # TODO: Need to test multi-dimensional ranges!
    describe ".new" do 

        context "(range_literal, bound_shape)" do
            valid.each do |r,v|
                it "parses a legal range literal (#{r}, bound: #{bound})" do 
                    idx_r = IndexRegion.new([r], [bound])

                    idx_r.first[0].should eq v[:first]
                    idx_r.step[0].should eq v[:step] 
                    idx_r.last[0].should eq v[:last]
                    idx_r.shape[0].should eq ((v[:last] - v[:first]) // v[:step] + 1)
                end
            end

            out_of_bounds.each do |r|
                it "throws an error when range is out of bounds (#{r}, bound: #{bound})" do 
                    expect_raises IndexError do
                        idx_r = IndexRegion.new([r], [bound])
                    end
                end
            end

            step_conflict.each do |r|
                it "throws an error when given a step conflict (#{r})" do 
                    expect_raises IndexError do
                        idx_r = IndexRegion.new([r], [bound])
                    end
                end
            end

            empty.each do |r|
                it "gives size 0 when range spans no integers (#{r})" do 
                    IndexRegion.new([r], [bound]).size.should eq 0
                end
            end

            pending "properly interprets degeneracy of integer inputs" do 
            end
        end 

        pending "(range_literal, *, trim_to)" do 

        end

        context "(range_literal)" do 
            fully_defined.each do |r, v|
                it "correctly parses a fully defined range literal (#{r})" do 
                    idx_r = IndexRegion(Int32).new([r])

                    idx_r.first[0].should eq v[:first]
                    idx_r.step[0].should eq v[:step] 
                    idx_r.last[0].should eq v[:last]
                    idx_r.shape[0].should eq ((v[:last] - v[:first]) // v[:step] + 1)
                end
            end

            implicit_bounds.each do |r, v|
                it "throws an error if an endpoint cannot be inferred (#{r})" do 
                    # TODO: make this a better error type
                    expect_raises Exception do
                        IndexRegion(Int32).new([r])
                    end
                end
            end

            negative_indices.each do |r,v|
                it "throws an error on negative (relative) indices (#{r})" do 
                    expect_raises IndexError do
                        IndexRegion(Int32).new([r])
                    end
                end
            end

            step_conflict.each do |r|
                it "throws an error when given a step conflict (#{r})" do 
                    expect_raises IndexError do
                        IndexRegion(Int32).new([r])
                    end
                end
            end

            empty.each do |r|
                it "gives size 0 when range spans no integers (#{r})" do 
                    IndexRegion.new([r], [bound]).size.should eq 0
                end
            end
        end

        context "(index_region, bound_shape)" do 
            valid.each do |r,v|
                it "copies an IndexRegion that is in bounds (#{r})" do 
                    idx_r = IndexRegion.new([r],[bound])
                    copy = IndexRegion.new(idx_r, [bound + 5])
                    
                    pointerof(idx_r).should_not (eq pointerof(copy)), "Equal references; copy not made"
                    idx_r.first.should eq copy.first
                    idx_r.last.should eq copy.last
                    idx_r.step.should eq copy.step
                    idx_r.shape.should eq copy.shape 
                    idx_r.degeneracy.should eq copy.degeneracy 
                    idx_r.drop.should eq copy.drop
                end

                it "throws an error for an IndexRegion that is out of bounds" do 
                    idx_r = IndexRegion.new([r],[bound])
                    new_bound = {v[:first], v[:last]}.max - 1
                    expect_raises IndexError do 
                        copy = IndexRegion.new(idx_r, [new_bound])
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
    end

    describe "#size" do 
    end

    describe "#proper_dimensions" do 
    end

    describe "#unsafe_fetch_chunk" do 
    end

    describe "#unsafe_fetch_element" do 
    end

    describe "#includes?" do 

        it "detects coordinates outside the region's bounds" do 
            r = IndexRegion(Int32).new([3..5, 10..-2..2])

            r.includes?([6, 4]).should be_false
            r.includes?([2, 4]).should be_false
            r.includes?([4, 11]).should be_false 
            r.includes?([4, 0]).should be_false 
            r.includes?([0, 0]).should be_false
        end

        it "detects coordinates that do not align with the region's step" do 
            r = IndexRegion(Int32).new([3..5, 10..-2..2])

            r.includes?([4, 5]).should be_false
        end

        it "returns true for coordinates in the region" do 
            r = IndexRegion(Int32).new([3..5, 10..-2..2])

            (3..5).each do |a|
                10.step(by: -2, to: 2).each do |b|
                    r.includes?([a,b]).should be_true 
                end
            end
        end
    end

    describe "#fits_in?" do 
        valid.each do |r,v|
            it "returns true if the region fits in shape" do 
                IndexRegion.new([r],[bound]).fits_in?([bound]).should be_true
            end

            it "returns false if the region does not fit in shape" do 
                new_bound = {v[:first], v[:last]}.max - 1
                IndexRegion.new([r],[bound]).fits_in?([new_bound]).should be_false
            end
        end
    end

    describe "#trim!" do 
    end

    describe "#translate!" do 
    end

    describe "#reverse!" do 
        it "can operate in-place" do 
            idx_r = IndexRegion(Int32).new([2..6, 8..-2..1])
            idx_r.reverse!

            idx_r.first.should eq [6, 2]
        end

        it "swaps first and last" do 
            idx_r = IndexRegion(Int32).new([2..6, 8..-2..1])
            reverse = idx_r.clone.reverse!

            reverse.first.should eq idx_r.last 
            reverse.last.should eq idx_r.first
        end

        it "negates step" do 
            idx_r = IndexRegion(Int32).new([2..6, 8..-2..1])
            reverse = idx_r.clone.reverse!

            reverse.step.zip(idx_r.step).each {|rev, fwd| rev.should eq -fwd} 
        end

        it "preserves shape and degeneracy" do 
            idx_r = IndexRegion(Int32).new([2..6, 8..-2..1])
            reverse = idx_r.clone.reverse!

            idx_r.shape.should eq reverse.shape 
            idx_r.degeneracy.should eq reverse.degeneracy
        end
    end

    describe "#local_to_absolute_unsafe" do 
    end

    describe "#absolute_to_local_unsafe" do
    end

    describe "#each" do 
    end
end






    
    
