module Lattice
  # struct MyOrder

  #   getter iter_type : MultiIndexable::RegionIterator.class

  #   # Converts a coord in this order to a coord in Lex.
  #   @converter = Proc(Array(Int32), Array(Int32))

  #   def initialize()
  #   end

  #   def compose(other : MyOrder)
  #   end

  #   def convert(other : MyOrder)
  #   end
  # end

  # According to the link below, these shorthands are used in lieu of
  # lexicographic, colexicographic, and their reverse forms.
  # https://en.wikiversity.org/wiki/Lexicographic_and_colexicographic_order
  enum Order
    LEX
    COLEX
    REV_LEX
    REV_COLEX
    FASTEST # Could represent any mode of iteration, but will be used by the implementing type to choose whatever method is fastest.

    def self.reverse?(o)
      o == REV_LEX || o == REV_COLEX
    end

    def self.colex?(o)
      o == COLEX || o == REV_COLEX
    end

    # Composition of the basic orders is commutative.
    # reverse and colex properties behave independently, and are each their own inverse
    # with LEX as the identity.
    # If one of two composing orders is FASTEST, we assume order is not relevant and
    # return FASTEST as the composition.
    def self.compose(o1 : Order, o2 : Order) : Order
      return FASTEST if o1 == FASTEST || o2 == FASTEST

      if reverse?(o1) ^ reverse?(o2)
        if colex?(o1) ^ colex?(o2)
          return REV_COLEX
        else
          return REV_LEX
        end
      else
        if colex?(o1) ^ colex?(o2)
          return COLEX
        else
          return LEX
        end
      end
    end
  end
end
