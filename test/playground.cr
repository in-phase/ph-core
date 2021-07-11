require "../src/lattice"
include Lattice 

# narr = NArray.build(10) {|c,i|i}

# masked = narr[narr < 5]
# puts masked

# puts masked + masked 
# puts masked + 5 
# puts -masked

# Note, I have only made single-direction changes, ie so that
# nilable_narr + arg 
# will be possible.
# nil arguments in the second object (at coords other where than nilable_narr is nil) will fail
# (and simi larly 5 + nilable_narr will fail)

# Alternative approach, have a separate class MaskedNArray that handles nil in this way, 
# but regular NArray does not? 

abstract class MaskedMI

    def initialize(@bool_mask)
    end

    abstract def defined?(coord : Coord)

    def *(other : MultiIndexable)
        self.process {|x| x.{{name.id}} }
    end
end

[](bool_mask) : self

class ProcMask < MaskedMI
    def initialize(@proc)
    end

    def defined?(coord : Coord)
        @proc.run(coord)
    end
end

# def [](mask)
#     # returns self
# end

# def [](mask, replacement : U) : NArray(T | U) forall U
# end

# def [](mask, as_list = true) : Array(T)
# end

# narr.to_mask { |el| .. }

# class Foo 
#     protected def [](index)
#         5
#     end
# end

# def foo(val : Array(U?)) forall U 
#     puts U
# end

# arr = [nil, nil, nil]

# foo(arr)

Foo.new()