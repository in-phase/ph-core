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

  property cascade_height = 2 # starts having effect from 2

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

    private enum Flags
        ELEM 
        SKIP 
        LAST 
    end

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

        fmt.print
    end

    def initialize(narr : MultiIndexable(T), @io, @settings)
        @depth = 0
        @iter = FormatIterator(MultiIndexable(T), T).new(narr)
        @shape = narr.shape
    end

    private def capped_iterator(depth, max_count, &action)
        if @shape[depth] > max_count
            left = max_count // 2
            right = max_count - left - 1

            left.times do |idx|
                yield Flags::ELEM
            end
            
            @iter.skip(depth, @shape[depth] - max_count)
            yield Flags::SKIP

            right.times do |idx|
                yield (idx == right - 1 ? Flags::LAST : Flags::ELEM)
            end
        else
            @shape[depth].times do |idx|
                yield (idx == @shape[depth] - 1 ? Flags::LAST : Flags::ELEM)
            end
        end
    end

    # get the length of the longest element to be displayed (for justification purposes)
    def measure
        @justify_length = walk_n_measure
        @iter.reset
    end

    def print
        measure
        walk_n_print
        @io << "\n"
        @iter.reset
    end

    protected def walk_n_measure(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_elements[{@settings.display_elements.size - 1, height}.min]

        max_length = 0
        if depth < @shape.size - 1
            capped_iterator(depth, max_columns) do |flag|
                unless flag == Flags::SKIP
                    max_length = {max_length, walk_n_measure(depth + 1)}.max
                end
            end
        else
            capped_iterator(depth, max_columns) do |flag|
                unless flag == Flags::SKIP
                    elem_length = @iter.unsafe_next_value.inspect.size
                    max_length = {max_length, elem_length}.max
                end
            end
        end
        return max_length
    end
        
    protected def walk_n_print(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_elements[{@settings.display_elements.size - 1, height}.min]

        open(height)
        if height > 0
            # iterating over rows
            capped_iterator(depth, max_columns) do |flag|
                if flag == Flags::SKIP
                    @io << " ⋮ (%d total, #{max_columns -1} shown)" % @shape[depth]
                    newline
                    newline if height == 2 || (@settings.cascade_height < 2 && height != 1)
                else
                    walk_n_print(depth + 1)
                    unless flag == Flags::LAST
                        @io << ","; newline
                        newline if height == 2 || (@settings.cascade_height < 2 && height != 1)
                    end
                end
            end
        else
            # printing elements in a single "row" (deepest axis)
            capped_iterator(depth, max_columns) do |flag|
                if flag == Flags::SKIP
                    @io <<  "..., "
                else
                    str = @iter.unsafe_next_value.inspect
                    # str = str.rjust(@cutoff_length, ' ')[0...@cutoff_length]
                    str = str.rjust(@justify_length, ' ')
                    @io << str
                    @io << ", " unless flag == Flags::LAST
                end
            end
        end
        close(height)
    end

    protected def compact?(height)
        height > @settings.cascade_height || height == 1
    end

    def newline(indent_change = 0)
        @io << "\n"
        @current_indentation += indent_change * 4
        @io << " " * @current_indentation
    end

    def open(height)
        @io << "["
        if compact?(height)
            @current_indentation += 1
        elsif height != 0
            newline(1)
        end
    end

    def close(height)
        if compact?(height)
            @current_indentation -= 1
        elsif height != 0
            newline(-1)
        end
        @io << "]"
    end
end


#arr = ["hi", "wo\nrld"]
#puts arr
#puts "wo\nrld".inspect

# "2626262
# "2626"...
# 2.6e10

my_settings = FormatterSettings.new 
my_settings.cascade_height = 2

my_narr = NArray.build([20,20, 20, 6]) {|c, i| i}

dur = Time.measure do 
    Formatter.print(my_narr, my_settings)
end
puts dur

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