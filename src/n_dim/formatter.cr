require "colorize"
require "yaml"

require "./iterators/*"

# when you first print an narray, it loads whatever it should find from file, and then saves it in a static variable on FormatterSettings
module Lattice
  module MultiIndexable
    class Settings
      # include YAML::Serializable

      USER_CONFIG_FILENAME = "formatter.yaml"

      # NOTE: I tried generating this with macros, but nothing was
      # as effective as just hardcoding it.
      COLOR_MAP = {"default" => :default,
                   "black" => :black,
                   "red" => :red,
                   "green" => :green,
                   "yellow" => :yellow,
                   "blue" => :blue,
                   "magenta" => :magenta,
                   "cyan" => :cyan,
                   "light_gray" => :light_gray,
                   "dark_gray" => :dark_gray,
                   "light_red" => :light_red,
                   "light_green" => :light_green,
                   "light_yellow" => :light_yellow,
                   "light_blue" => :light_blue,
                   "light_magenta" => :light_magenta,
                   "light_cyan" => :light_cyan,
                   "white" => :white}

      @@cached_user_settings : self?
      @@disable_user_settings = false

      class_getter project_settings : self?

      property indent_width : Int32
      property max_element_width : Int32

      @[YAML::Field(key: "omit_after")]
      property display_limit : Array(Int32)

      property brackets : Array(Tuple(String, String))

      @[YAML::Field(converter: YAML::ArrayConverter(ColorConverter))]
      property colors : Array(Colorize::Color | Symbol) | Array(Colorize::Color) | Array(Symbol) = [:default] # TODO: remove value

      @[YAML::Field(key: "collapse_brackets_after")]
      property collapse_height : Int32

      def self.new
        @@project_settings || user_settings || default
      end

      #TODO: Figure out how this can be a serializable when all the colorize types arent
      def initialize(@indent_width, @max_element_width, omit_after @display_limit, @brackets, colors : Indexable(Symbol), collapse_brackets_after @collapse_height)
      end

      # TODO: document properly once this is set in stone
      # tries to read from LATTICE_CONFIG_DIR - if the file isn't there,
      # reads from XDG_CONFIG_DIR/lattice. if still not there, tries ~/.config
      def self.user_settings() : self?
        return nil if @@disable_user_settings
        return @@cached_user_settings if @@cached_user_settings

        if dir = ENV["LATTICE_CONFIG_DIR"]?
          path = Path[dir] / USER_CONFIG_FILENAME

          if File.exists?(path)
            # return @@cached_user_settings = from_yaml(File.read(path))
          end
        end

        {ENV["XDG_CONFIG_DIR"]?, "~/.config"}.each do |dir|
          if dir
            path = Path[dir] / "lattice" / USER_CONFIG_FILENAME

            if File.exists?(path)
              # return @@cached_user_settings = from_yaml(File.read(path))
            end
          end
        end

        # The loading process failed. This function is called whenever an
        # NArray is printed, so we need to remember not to do all these disk
        # operations again.
        @@disable_user_settings = true
        return nil
      end

      def self.default : self
        new(
          indent_width: 4,
          max_element_width: 20,
          omit_after: [10, 5],
          brackets: [{"[", "]"}],
          colors: [:default],
          collapse_brackets_after: 5
        )
      end

      private class ColorConverter
        def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) # : Symbol | Colorize::Color
          unless node.is_a?(YAML::Nodes::Scalar)
            node.raise "Expected scalar, not #{node.kind}"
          end

          str = node.value
          if str[0] == '#'
            rgb = str[1..].hexbytes
            unless rgb.size == 3
              node.raise "Expected a 24 bit color, but found #{rgb.size * 8} bits"
            end
          else
          end
        end
      end
    end

    # formatter settings provided programatically
    # formatter settings from project folder (cached)
    # formatter settings from your user account (cached)
    # default

        

    class Formatter(T)
      private enum Flags
        ELEM
        SKIP
        LAST
      end

      @settings : Settings
      @io : IO

      @shape : Array(Int32)
      @col = 0
      @current_indentation = 0
      @cutoff_length = 8
      @justify_length = 8

      def self.print(narr : MultiIndexable(T), io : IO = STDOUT, settings = nil)
        settings ||= Settings.new

        display_shape = narr.shape.map_with_index do |dim, i|
          color = settings.colors[(-i - 1) % settings.colors.size]
          dim.to_s.colorize(color)
        end

        io << "#{display_shape.join('x')} #{"element " if narr.shape.size == 1} #{narr.class}\n"
        Formatter.new(narr, io, settings).print
      end

      def self.print_literal(narr : MultiIndexable(T), io = STDOUT)
        fmt = Formatter.new(narr, io, Settings.new)
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
        color = @settings.colors[height % @settings.colors.size]
        @io << text.colorize(color)
      end

      protected def walk_n_measure(depth = 0)
        height = @shape.size - depth - 1
        max_columns = @settings.display_limit[{@settings.display_limit.size - 1, height}.min]

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
          capped_iterator(depth, max_columns) do |flag, i|
            if flag == Flags::SKIP
              @io << "..., "
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

      class FormatIterator(A, T) < LexRegionIterator(A, T)
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
    end

    def to_literal_s(io : IO) : Nil
      Formatter.print_literal(self, io)
    end

    # FIXME: NArrayFormatter depends on buffer indices.
    def to_s(settings = Settings.new) : String
      String.build do |str|
        Formatter.print(self, str, settings: settings)
      end
    end

    # FIXME: NArrayFormatter depends on buffer indices.
    def to_s(io : IO, settings = Settings.new) : Nil
      Formatter.print(self, io, settings: settings)
    end
  end
end
