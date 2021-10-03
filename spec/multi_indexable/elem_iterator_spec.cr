require "./spec_helper"

include Phase
alias ElemIterator = MultiIndexable::ElemIterator

describe MultiIndexable do
  narr = NArray[[1, 2, 3], [4, 5, 6], [7, 8, 9]]

  describe ElemIterator do
    it "Iterates over elements lexicographic order" do
      lex = LexIterator.cover(narr)
      actual = ElemIterator.new(narr, lex).to_a
      expected = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      actual.should eq expected
    end

    it "Iterates over elements in colexicographic order" do
      colex = ColexIterator.cover(narr)
      actual = ElemIterator.new(narr, colex).to_a
      expected = [1, 4, 7, 2, 5, 8, 3, 6, 9]
      actual.should eq expected
    end

    it "raises a ShapeError when the iterator has the wrong number of dimensions" do
      lex = LexIterator.cover([3])
      expect_raises ShapeError do
        ElemIterator.new(narr, lex)
      end
    end

    it "raises an IndexError when the iterator is out of bounds" do
      lex = LexIterator.cover([3, 10])
      expect_raises IndexError do
        ElemIterator.new(narr, lex)
      end
    end

    describe "#reverse_each" do
      it "reverses a lexicographic iteration" do
        lex = LexIterator.cover(narr)
        actual = ElemIterator.new(narr, lex).reverse_each.to_a
        expected = [1, 2, 3, 4, 5, 6, 7, 8, 9].reverse
        actual.should eq expected
      end

      it "reverses a colexicographic iteration" do
        colex = ColexIterator.cover(narr)
        actual = ElemIterator.new(narr, colex).reverse_each.to_a
        expected = [1, 4, 7, 2, 5, 8, 3, 6, 9].reverse
        actual.should eq expected
      end
    end

    describe "#with_coord" do
      it "Iterates over elements and coordinates in lexicographic order" do
        lex = LexIterator.cover(narr)
        actual = ElemIterator.new(narr, lex).with_coord.to_a
        expected = [{1, [0, 0]}, {2, [0, 1]}, {3, [0, 2]}, {4, [1, 0]}, {5, [1, 1]}, {6, [1, 2]}, {7, [2, 0]}, {8, [2, 1]}, {9, [2, 2]}]
        actual.should eq expected
      end

      it "Iterates over elements and coordinates in colexicographic order" do
        colex = ColexIterator.cover(narr)
        actual = ElemIterator.new(narr, colex).with_coord.to_a
        expected = [{1, [0, 0]}, {4, [1, 0]}, {7, [2, 0]}, {2, [0, 1]}, {5, [1, 1]}, {8, [2, 1]}, {3, [0, 2]}, {6, [1, 2]}, {9, [2, 2]}]
        actual.should eq expected
      end
    end
  end
end