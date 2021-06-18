require "./spec_helper"

include Lattice

describe SteppedRange do
    describe ".new" do
      pending "computes size" do
      end

      describe "(range : SteppedRange, size)" do
        it "preserves SteppedRanges that are in-bounds" do
          data = [{1..7, 2}, {200..0, -50}, {0..0, 1}]
          data.each do |el|
            range = SteppedRange.new(*el, 1000)
            SteppedRange.new(range, 1000).should eq range
            SteppedRange.new(range, 300).should eq range
          end
        end
        pending "throws error for SteppedRanges that are out of bounds" do
        end
      end
      describe "(range : Range, size)" do
        it "correctly parses endpoints of a regular Range" do
          data = [1..7, -4..3, -1..0]
          data.each_with_index do |range, i|
            output = SteppedRange.new(range, 10)
            output.begin.should eq canonicalize_index(range.begin, 10)
            output.end.should eq canonicalize_index(range.end, 10)
          end
        end
        it "infers the correct step direction for a regular Range" do
          data = [1..6, -6..-1, 6..1, -1..-6]
          expected = [1, 1, -1, -1]
          data.each_with_index do |range, i|
            output = SteppedRange.new(range, 10)
            output.step.should eq expected[i]
          end
        end
        it "correctly parses input of the form start..step_size..end" do
          data = [{1, 2, 5}, {-3, -1, 2}, {0, 5, -5}]
          data.each_with_index do |el, i|
            start, step, finish = el
            output = SteppedRange.new(start..step..finish, 10)
            output.begin.should eq canonicalize_index(start, 10)
            output.end.should eq canonicalize_index(finish, 10)
            output.step.should eq step
          end
        end
        it "adjusts end of stepped ranges such that step evenly divides the range" do
          data = [3..3..9, 4..4..7, 3..-2..0]
          expected = [9, 4, 1]
          data.each_with_index do |range, i|
            SteppedRange.new(range, 10).end.should eq expected[i]
          end
        end
        it "adjusts for end-exclusive inputs" do
          data = [0...10, 9...-11, 1..3...8, 1..3...7, -5...-2]
          expected = [9, 0, 7, 4, 7]
          data.each_with_index do |range, i|
            SteppedRange.new(range, 10).end.should eq expected[i]
          end
        end
        it "infers range start" do
          data = [.., ..5, ...-3, ..1..5, ..-1..5, ..2..7, ..-3..2]
          expected = [0, 0, 0, 0, 9, 0, 9]
          data.each_with_index do |range, i|
            SteppedRange.new(range, 10).begin.should eq expected[i]
          end
        end
        it "infers range end" do
          data = [.., 5.., -3..., -1.., 5..1..., 5..-1..., 2..2..., 5..-3...]
          expected = [9, 9, 9, 9, 9, 0, 8, 2]
          data.each_with_index do |range, i|
            SteppedRange.new(range, 10).end.should eq expected[i]
          end
        end
        it "raises an IndexError if the input step direction and inferred step direction do not match" do
          data = [0..-2..5, 8..1..4]
          data.each do |range|
            expect_raises(IndexError) do
              SteppedRange.new(range, 10)
            end
          end
        end
        it "raises an IndexError if the range start or end are out of bounds" do
          data = [-11..-3, 10..-3, 2..-11, 2...-12]
          data.each do |range|
            expect_raises(IndexError) do
              SteppedRange.new(range, 10)
            end
          end
        end
        it "raises an IndexError if the range spans no integers" do
          data = [4...4, -5...5, ...0]
          data.each do |range|
            expect_raises(IndexError) do
              SteppedRange.new(range, 10)
            end
          end
        end
      end

      pending "(index, size)" do
      end
    end

    pending ".reverse" do
      # These would not necessarily be valid if a SteppedRange is not restricted to canonical
      it "swaps the start and end of a range" do
      end
      it "reverses the step" do
      end
      it "preserves size" do
      end
    end
    pending ".local_to_absolute" do
      # for inputs n between begin and end,
    end
    pending ".compose" do
    end
    pending ".each" do
    end
  end