require "yaml"
require "../src/lattice"
require "colorize"

include Lattice

struct FormatterSettings
  include YAML::Serializable

  property brackets = [{"[", "]"}] # cycles
  property colors = [:default, :light_green, :light_yellow, :cyan, :light_magenta, :light_red] # cycles
  property colors_enabled = false
  property indent = 4
  property max_elem_length = 20 # not implemented
  property display_elements = [10,5] # last one repeats
  property cascade_height = 5 # starts having effect from 2

  def initialize()
  end
end

class FormatIterator(T) < MultiIndexable::LexRegionIterator(AT)
    
    def skip(axis, amount) : Nil
        @coord[axis] += amount + 1
    end

    def unsafe_next
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
        settings ||= FormatterSettings.new
        if settings.colors_enabled
            display_shape = narr.shape.map_with_index do |dim, i|
                color = settings.colors_enabled ? settings.colors[(-i-1) % settings.colors.size] : :default
                dim.to_s.colorize(color)
            end
        else
            display_shape = narr.shape
        end
        
        io << "#{display_shape.join('x')}#{" element" if narr.shape.size == 1} #{narr.class}\n"
        fmt = Formatter.new(narr, io, settings)
        fmt.print
    end

    def self.print_literal(narr : MultiIndexable(T), io = STDOUT)
        fmt = Formatter.new(narr, io, FormatterSettings.new)
        fmt.print_literal
    end

    def initialize(narr : MultiIndexable(T), @io, @settings)
        @depth = 0
        @iter = FormatIterator(MultiIndexable(T), T).new(narr)
        @shape = narr.shape
    end

    private def capped_iterator(depth, max_count, &action)
        size = @shape[depth]
        if size > max_count
            left = max_count // 2
            right = max_count - left - 1

            left.times do |idx|
                yield Flags::ELEM, idx
            end
            
            @iter.skip(depth, size - max_count)
            yield Flags::SKIP, -1

            right.times do |idx|
                yield (idx == right - 1 ? Flags::LAST : Flags::ELEM), size - right + idx
            end
        else
            size.times do |idx|
                yield (idx == size - 1 ? Flags::LAST : Flags::ELEM), idx
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

    def print_literal
        walk_n_print_flat
        @io << "\n"
        @iter.reset
    end

    protected def color_print(text, height)
        color = @settings.colors_enabled ? @settings.colors[ height % @settings.colors.size ] : :default
        @io << text.colorize(color)
    end

    protected def walk_n_measure(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_elements[{@settings.display_elements.size - 1, height}.min]

        max_length = 0
        if depth < @shape.size - 1
            capped_iterator(depth, max_columns) do |flag, i|
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

    protected def walk_n_print_flat(depth = 0)
        height = @shape.size - depth - 1
        @io << "["

        if @shape.size - 1 > depth
            @shape[depth].times do |i|
                walk_n_print_flat(depth + 1)
                @io << ", " unless i == @shape[depth] - 1
            end
        else 
            @shape[depth].times do |i|
                @io << @iter.unsafe_next_value
                @io << ", " unless i == @shape[depth] - 1
            end
        end

        @io << "]"
    end
        
    protected def walk_n_print(depth = 0, idx = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_elements[{@settings.display_elements.size - 1, height}.min]

        open(height, idx)
        if height > 0
            # iterating over rows
            capped_iterator(depth, max_columns) do |flag, i|
                if flag == Flags::SKIP
                    color_print(" ⋮ %d total, #{max_columns -1} shown" % @shape[depth], height)
                    newline
                    newline if height == 2 || (@settings.cascade_height < 2 && height != 1)
                else
                    walk_n_print(depth + 1, i)
                    unless flag == Flags::LAST
                        color_print(",", height)
                        newline
                        newline if height == 2 || (@settings.cascade_height < 2 && height != 1)
                    end
                end
            end
        else
            # printing elements in a single "row" (deepest axis)
            capped_iterator(depth, max_columns) do |flag, i|
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
        close(height, idx)
    end

    protected def compact?(height)
        height > @settings.cascade_height || height == 1
    end

    def newline(indent_change = 0)
        @io << "\n"
        @current_indentation += indent_change * @settings.indent
        @io << " " * @current_indentation
    end

    def open(height, idx)
        brackets = @settings.brackets[height % @settings.brackets.size]
        color_print(brackets[0] % idx, height)
        if compact?(height)
            @current_indentation += (brackets[0] % idx).size
        elsif height != 0
            newline(1)
        end
    end

    def close(height, idx)
        brackets = @settings.brackets[height % @settings.brackets.size]
        if compact?(height)
            @current_indentation -= (brackets[0] % idx).size
        elsif height != 0
            newline(-1)
        end
        color_print(brackets[1] % idx, height)
    end
end
