module Lattice
    # According to the link below, these shorthands are used in lieu of
    # lexicographic, colexicographic, and their reverse forms.
    # https://en.wikiversity.org/wiki/Lexicographic_and_colexicographic_order
    enum Order
        LEX
        COLEX
        REV_LEX
        REV_COLEX
        FASTEST # Could represent any mode of iteration, but will be used by the implementing type to choose whatever method is fastest.
    end
end