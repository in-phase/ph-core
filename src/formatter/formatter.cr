require "colorize"
require "yaml"
require "big"

# when you first print an narray, it loads whatever it should find from file, and then saves it in a static variable on FormatterSettings
module Phase
  module MultiIndexable
    # Used to print `MultiIndexable`s in a user-readable fashion. The most
    # common usage of `Formatter` is the class method `Formatter.print(narr,
    # io, settings)`.
    #
    # `Formatter` can be configured at multiple different levels:
    # - Per invocation
    # - Program wide
    # - System wide
    #
    # For detailed information about how that all works, see `Formatter::Settings`.
    class Formatter(E, I)
      private enum Flags
        ELEM
        SKIP
        LAST
      end

      @settings : Settings
      @io : IO
      @iter : ElemIterator(E, I)

      @shape : Array(I)
      @depth = 0
      @col = 0
      @current_indentation = 0

      # This will be set in the measurement step, and should never be used before.
      @justify_length = 0

      def self.print(narr : MultiIndexable(E), io : IO = STDOUT, settings = nil)
        settings ||= Settings.new

        display_shape = narr.shape.map_with_index do |dim, i|
          if i < narr.dimensions - 1
            color = settings.colors[ (narr.dimensions - i + 1) % settings.colors.size]
          else
            color = :default
          end

          dim.to_s.colorize(color)
        end

        io << "#{display_shape.join('x')} #{"element " if narr.shape.size == 1}#{narr.class}\n"
        Formatter(E, typeof(narr.shape[0])).new(narr, io, settings).print
      end

      def self.print_literal(narr : MultiIndexable(E), io = STDOUT)
        fmt = Formatter(E, typeof(narr.shape[0])).new(narr, io, Settings.new)
        fmt.print_literal
      end

      def initialize(narr : MultiIndexable(E), @io, @settings)
        @iter = ElemIterator.of(narr, LexIterator.cover(narr.shape))
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

          @iter.coord_iter.unsafe_skip(depth, size - max_count)
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
        @justify_length = @settings.max_element_width
        @justify_length = walk_n_measure
        @iter.reset
      end

      def print
        measure
        walk_n_print
        @iter.reset
      end

      def print_literal
        walk_n_print_flat
        @iter.reset
      end

      protected def color_print(text, height)
        color = @settings.colors[height % @settings.colors.size]
        @io << text.colorize(color)
      end

      protected def walk_n_measure(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_limit[{@settings.display_limit.size - 1, height}.min]

        max_length = 0
        if depth < @shape.size - 1
          capped_iterator(depth, max_columns) do |flag, _|
            unless flag == Flags::SKIP
              max_length = {max_length, walk_n_measure(depth + 1)}.max
            end
          end
        else
          capped_iterator(depth, max_columns) do |flag|
            unless flag == Flags::SKIP
              elem_length = format_element(@iter.unsafe_next).size
              max_length = {max_length, elem_length}.max
            end
          end
        end

        max_length
      end

      protected def walk_n_print_flat(depth = 0)
        @io << "["

        if @shape.size - 1 > depth
          @shape[depth].times do |i|
            walk_n_print_flat(depth + 1)
            @io << ", " unless i == @shape[depth] - 1
          end
        else
          @shape[depth].times do |i|
            @io << @iter.unsafe_next.inspect
            @io << ", " unless i == @shape[depth] - 1
          end
        end

        @io << "]"
      end

      protected def walk_n_print(depth = 0, idx = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_limit[{@settings.display_limit.size - 1, height}.min]

        open(height, idx)
        if height > 0
          # iterating over rows
          capped_iterator(depth, max_columns) do |flag, i|
            if flag == Flags::SKIP
              color_print(" ⋮ %d total, #{max_columns - 1} shown" % @shape[depth], height)
              newline
              newline if height == 2 || (@settings.collapse_height < 2 && height != 1)
            else
              walk_n_print(depth + 1, i)
              unless flag == Flags::LAST
                color_print(",", height)
                newline
                newline if height == 2 || (@settings.collapse_height < 2 && height != 1)
              end
            end
          end
        else
          # printing elements in a single "row" (deepest axis)
          capped_iterator(depth, max_columns) do |flag, _|
            if flag == Flags::SKIP
              @io << "..., "
            else
              @io << format_element(@iter.unsafe_next).rjust(@justify_length, ' ')
              @io << ", " unless flag == Flags::LAST
            end
          end
        end
        close(height, idx)
      end

      def format_element(el : Int) : String
        str = @settings.integer_format % el
        if str.size > @justify_length
          return format_element(BigFloat.new(el))
        end
        str
      end

      def format_element(el : Float) : String
        # Try the user specified decimal format
        str = @settings.decimal_format % el

        if str.size > @justify_length
          # Check if the formatted string is in scientific notation, either decimal (e) or hex (p)
          separator = str.rindex(/[pe]/i)
          if separator.nil?
            # If not, reformat the value into decimal scientific notation
            str = "%e" % el
            separator = str.rindex(/[pe]/i).not_nil!
          end

          truncate_length = str.size - @justify_length
          # We want to make sure that the first digit, decimal place, and second digit are shown.
          if separator - truncate_length < 3
            # If it's not possible to fit all three, use just the first digit. This will likely break
            # the justification, but it's the shortest possible representation that is still correct.
            mantissa = str[0]
          else
            mantissa = str[...(separator - truncate_length)]
          end

          exponent = str[separator..]
          str = mantissa + exponent
        end
        str
      end

      def format_element(el : String) : String
        str = el.inspect
        if str.size > @justify_length
          str = str[0...(@justify_length - 4)] + %("...)
        end
        str
      end

      def format_element(el) : String
        if el.responds_to? :ph_to_s
          str = el.ph_to_s
        else
          str = el.inspect
        end

        if str.size > @justify_length
          str = str[0...(@justify_length - 3)] + "..."
        end
        str
      end

      protected def compact?(height)
        height > @settings.collapse_height || height == 1
      end

      def newline(indent_change = 0)
        @io << "\n"
        @current_indentation += indent_change * @settings.indent_width
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

    def to_literal_s(io : IO) : Nil
      Formatter.print_literal(self, io)
    end

    # FIXME: NArrayFormatter depends on buffer indices.
    def to_s(settings = Formatter::Settings.new) : String
      String.build do |str|
        Formatter.print(self, str, settings: settings)
      end
    end

    # FIXME: NArrayFormatter depends on buffer indices.
    def to_s(io : IO, settings = Formatter::Settings.new) : Nil
      Formatter.print(self, io, settings: settings)
    end
  end
end
