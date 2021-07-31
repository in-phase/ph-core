require "./spec_helper"
require "./test_narray"

include Phase


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
    ..-1...2     => {first: bound - 1, step: -1, last: 3},
    (..-4)..    => {first: bound - 1, step: -4, last: (bound - 1) % 4},
    ..(-4..)   => {first: bound - 1, step: -4, last: (bound - 1) % 4},
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

invalid = [
    4..1..2,
    2..-1..4,
    4.step(by: 1, to: 2),
    2.step(by: -1, to: 4),
    # 3.step(by: 0, to: 5), # throws ArgumentError on creation
]

# restricted IndexRegion


describe "IndexRegion" do
    
    # TODO: Need to test multi-dimensional ranges!
    describe ".new" do 

        context "(range_literal, bound_shape)" do
            valid = fully_defined.merge(negative_indices).merge(implicit_bounds)
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

            invalid.each do |r|
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

        context "(range_literal, *, trim_to)" do 


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
        end

        context "(index_region, bound_shape)" do 
        end

        context "(first, step, *, last)" do 
        end

        context "(first, step, *, shape)" do 
        end

    end
end

    
    
