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

  property settings = [{"[", "]"},{'{', '}'},{'(', ')'}] # cycles
  property colors = [:red, :orange, :yellow, :green] # cycles
  property indent = "   "
  property max_elem_length = 20
  property display_elements = [5] # last one repeats
  property newline_between = true

  property cascade_depth = 4

  def initialize()
  end
end

class FormatIterator(A,T) < MultiIndexable::LexRegionIterator(A,T)
    
    def skip(axis, amount) : Nil
        @coord[axis] += amount + 1
    end

    def next

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
        
        {@narr.unsafe_fetch_element(@coord), @coord}
    end

    def peek
        @coord.clone
    end

    def unsafe_next_value
        self.next.unsafe_as(Tuple(T, Array(Int32)))[0]
    end
end

class Formatter(T)

    @settings : FormatterSettings
    @io : IO

    @shape : Array(Int32)
    @col = 0
    @current_indentation = 0
    @cutoff_length = 8
    @justify_length = 8

    def self.print(narr : MultiIndexable(T), settings = nil, io = STDOUT)
        io << "#{narr.shape.join('x')} #{narr.class}\n"
        fmt = Formatter.new(narr, io, settings)

        fmt.measure
        fmt.print
    end

    def initialize(narr : MultiIndexable(T), @io, @settings)
        @depth = 0
        @iter = FormatIterator(MultiIndexable(T), T).new(narr)
        @shape = narr.shape
    end

    def write(str)
        @io << str
        @col += str.size
    end

    private def capped_iterator(depth, max_count, message, &action)
        if @shape[depth] > max_count
            left = max_count // 2
            right = max_count - left - 1

            left.times do |idx|
                yield false
            end
            
            @io << message % @shape[depth]
            newline unless depth == @shape.size - 1
            @iter.skip(depth, @shape[depth] - max_count)

            right.times do |idx|
                yield idx == right - 1
            end
        else
            @shape[depth].times do |idx|
                yield idx == @shape[depth] - 1
            end
        end
    end

    def measure
        @justify_length = walk_n_measure
        @iter.reset
    end

    def print
        walk_n_print
        @io << "\n"
        @iter.reset
    end

    protected def walk_n_measure(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_elements[{@settings.display_elements.size - 1, height}.min]

        max_length = 0
        if depth < @shape.size - 1
            capped_iterator(depth, max_columns, "") do |last|
                max_length = {max_length, walk_n_measure(depth + 1)}.max
            end
        else
            capped_iterator(depth, max_columns, "") do |last|
                elem_length = @iter.unsafe_next_value.inspect.size
                max_length = {max_length, elem_length}.max
            end
        end
        return max_length
    end
        
    protected def walk_n_print(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_elements[{@settings.display_elements.size - 1, height}.min]

        open(height)
        if depth < @shape.size - 1
            # iterating over rows
            capped_iterator(depth, max_columns, " ⋮ (%d total, #{max_columns -1} shown)") do |last|
                walk_n_print(depth + 1)
                unless last
                    @io << ","
                    newline
                    newline if height == 2
                end
            end
        else
            # printing elements in a single "row" (deepest axis)
            capped_iterator(depth, max_columns, "..., ") do |last|
                str = @iter.unsafe_next_value.inspect
                # str = str.rjust(@cutoff_length, ' ')[0...@cutoff_length]
                str = str.rjust(@justify_length, ' ')
                @io << str
                @io << ", " unless last
            end
        end
        close(height)
    end


    def newline(indent_change = 0)
        @io << "\n"
        @current_indentation += indent_change * 4
        @io << " " * @current_indentation
    end

    def open(height)
        @io << "["
        newline(1) unless height <= 1
        @current_indentation += 1 if height == 1
    end
        
    def close(height)
        @current_indentation -= 1 if height == 1
        newline(-1) unless height <= 1
        @io << "]"
    end

end


#arr = ["hi", "wo\nrld"]
#puts arr
#puts "wo\nrld".inspect

# "2626262
# "2626"...
# 2.6e10

my_narr = NArray.build([3, 3, 3]) {|c, i| i.to_s*(i//2 + 1)}
Formatter.print(my_narr, FormatterSettings.new)

#puts my_narr

#puts ["Hello", "wo\nrld"]
# iter =  FormatIterator(NArray(Int32), Int32).new(my_narr)

# puts iter.next
# iter.skip(1, 2) # => []
# puts iter.next # =>

# max_columns = 4
# if 7 > max_columns
#     to_print = max_columns // 2

#     to_print.times do
#         print "#{iter.unsafe_next_value},"
#     end

#     print "...,"
#     iter.skip(2, 7 - 2 * to_print)

#     (to_print).times do
#         print "#{iter.unsafe_next_value},"
#     end
# else
    
# end



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