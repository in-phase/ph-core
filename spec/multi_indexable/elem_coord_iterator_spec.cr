require "./spec_helper"

include Phase
alias ElemAndCoordIterator = MultiIndexable::ElemAndCoordIterator

def to_a(iter : ElemAndCoordIterator)
  arr = [] of Tuple(Int32, Array(Int32))
  iter.each { |t| arr << {t[0], t[1].to_a} }
  arr
end

describe MultiIndexable do
  narr = NArray[[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  describe ElemAndCoordIterator do
    it "Iterates over elements and coordinates in lexicographic order" do
      lex = LexIterator.cover(narr)
      actual = ElemAndCoordIterator.new(narr, lex).to_a
      expected = [{1, [0, 0]}, {2, [0, 1]}, {3, [0, 2]}, {4, [1, 0]}, {5, [1, 1]}, {6, [1, 2]}, {7, [2, 0]}, {8, [2, 1]}, {9, [2, 2]}]
      actual.should eq expected
    end

    it "Iterates over elements and coordinates in colexicographic order" do
      colex = ColexIterator.cover(narr)
      actual = ElemAndCoordIterator.new(narr, colex).to_a
      expected = [{1, [0, 0]}, {4, [1, 0]}, {7, [2, 0]}, {2, [0, 1]}, {5, [1, 1]}, {8, [2, 1]}, {3, [0, 2]}, {6, [1, 2]}, {9, [2, 2]}]
      actual.should eq expected
    end

    describe "#reverse_each" do
      it "reverses a lexicographic iteration" do
        lex = LexIterator.cover(narr)
        actual = ElemAndCoordIterator.new(narr, lex).reverse_each.to_a
        expected = [{1, [0, 0]}, {2, [0, 1]}, {3, [0, 2]}, {4, [1, 0]}, {5, [1, 1]}, {6, [1, 2]}, {7, [2, 0]}, {8, [2, 1]}, {9, [2, 2]}].reverse
        actual.should eq expected
      end

      it "reverses a colexicographic iteration" do
        colex = ColexIterator.cover(narr)
        actual = ElemAndCoordIterator.new(narr, colex).reverse_each.to_a
        expected = [{1, [0, 0]}, {4, [1, 0]}, {7, [2, 0]}, {2, [0, 1]}, {5, [1, 1]}, {8, [2, 1]}, {3, [0, 2]}, {6, [1, 2]}, {9, [2, 2]}].reverse
        actual.should eq expected
      end
    end
  end
end