# Improvements:
# truncate data when it's too big (...s), two dimensionally
# align elements
# (0) [
#   (1) [a, b, c]
#   (1) [d, e, f]
#   (1) [g, h, i]
# ]
require "yaml"
require "../src/lattice"

include Lattice

struct FormatterSettings
  include YAML::Serializable

  @settings = [{"[", "]"},{'{', '}'},{'(', ')'}] # cycles
  @colors = [:red, :orange, :yellow, :green] # cycles
  @indent = "   "
  @max_elem_length = 20
  @display_elements = [10, 2, 4, 6] # last one repeats
  @newline_between = true
end

class FormatIterator(A,T) < MultiIndexable::LexRegionIterator(A,T)
    @just_skipped : Bool = false
    
    def skip(axis, amount) : Nil
        @coord[axis] += amount + 1
        @just_skipped = true
    end

    def next
        if @just_skipped
            @just_skipped = false
        else
            (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
                if @coord[i] == @last[i]
                    # dimension change
                    @coord[i] = @first[i]
                    return stop if i == 0 # most sig
                else
                    @coord[i] += @step[i]
                    break
                end
            end
        end

        {@narr.unsafe_fetch_element(@coord), @coord}
    end

    def unsafe_next_value

        self.next.unsafe_as(Tuple(T, Array(Int32)))[0]
    end
end

my_narr = NArray.build([5,5,7]) {|c, i| i}
puts my_narr

iter =  FormatIterator(NArray(Int32), Int32).new(my_narr)

# puts iter.next
# iter.skip(1, 2) # => []
# puts iter.next # =>

max_columns = 4
if 7 > max_columns
    to_print = max_columns // 2

    to_print.times do
        print "#{iter.unsafe_next_value},"
    end

    print "...,"
    iter.skip(2, 7 - 2 * to_print)

    (to_print).times do
        print "#{iter.unsafe_next_value},"
    end
else
    
end



# [[[[0,  1, ...,  2,  3],
#    [ 2,  3]],

#   [[ 4,  5],
#    [ 6,  7]]

#  [[[ 8,  9], 
#    [10, 11]],

#   [[12, 13], 
#    [14, 15]]]]


# [
#   [
#     [[ 0,  1, ...,  2,  3],
#         ⋮ (2 of 1002 shown)
#      [ 2,  3]],
     
#     [[ 4,  5],
#         ⋮ (2 of 1002 shown)
#      [ 6,  7]]
#   ],
#     ⋮ (4 of 50 shown)
#   [
#     [[ 8,  9],
#      [10, 11]],

#     [[12, 13],
#      [14, 15]]
#   ]
# ]

# puts narr # read formatter settings from your computer, print according to those
# # first check project directory for config file
# # checks your system config
# # uses default
# format = FormatterSettings...
# narr.to_s(io, format)

# first thing in printing a blocK: check the number of columns
# if there are too many, print the first few, a separator, and the last few
# always check if the element character cot fits, if not, substring and append ...un