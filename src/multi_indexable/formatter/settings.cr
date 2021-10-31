require "colorize"
require "yaml"

module Phase::MultiIndexable
  class Formatter(S, E, I)
    # Every instance of `Settings` stores configuration options that can
    # be provided to `MultiIndexable::Formatter`. Additionally, `Settings`
    # can store a project-wide formatter configuration (via `.project_settings`
    # and `.project_settings=`), and load system-wide configuration (via `self.user_settings`).
    #
    # ### Where does `Settings` get it's data from?
    # All user-configurable printing methods in `Formatter` will accept an
    # optional *settings* parameter. If you provide an instance of `Settings`
    # to that formatter method, it will always be used, no matter what project
    # or system-wide configuration is enabled. If you do not provide a
    # `Settings` instance in the call to `Formatter`, `Formatter` will load its
    # configuration from `Settings.new`.
    #
    # `Settings.new` will check everything on this list (starting at the top)
    # until it finds suitable settings, and then returns those.
    # - `Settings.project_settings` (`nil` by default, but can be altered via
    # `.project_settings=`)
    # - `Settings.user_settings` (attempts to cache and return settings from a
    # `formatter.yaml` file. See `.user_settings` for details)
    # - `Settings.default` (the default configuration that we, the developers
    # of Phase, think is nice)
    class Settings
      include YAML::Serializable

      USER_CONFIG_FILENAME = "formatter.yaml"

      @@cached_user_settings : self?
      @@disable_user_settings = false

      class_property project_settings : self?

      # Controls the number of spaces that will be used to produce each indentation.
      property indent_width : Int32

      # Controls the maximum number of characters to display for each element.
      # Elements that stringify to something longer than this will be
      # truncated, and numbers that are too long will be put into scientific
      # notation to attempt to fit them into this length.
      property max_element_width : Int32

      # The maximum number of elements to display in a single row before truncating output.
      @[YAML::Field(key: "omit_after")]
      property display_limit : Array(Int32)

      # The formatter is capable of using different brackets for different structures - this may help disambiguate rows, columns, and higher dimensional arrays.
      # 
      # ```crystal
      # narr = NArray.build([2, 2, 2, 2]) { |_, idx| idx }
      # 
      # settings = MultiIndexable::Formatter::Settings.default
      # settings.brackets = [{"<", ">"}, {"begin", "end"}]
      # 
      # MultiIndexable::Formatter.print(narr, settings: settings)
      # 
      # # Output (note how the 0th element in brackets was used for the innermost arrays)
      # # begin
      # #     <
      # #         begin< 0,  1>,
      # #              < 2,  3>end,
      # #         
      # #         begin< 4,  5>,
      # #              < 6,  7>end
      # #     >,
      # #     <
      # #         begin< 8,  9>,
      # #              <10, 11>end,
      # #         
      # #         begin<12, 13>,
      # #              <14, 15>end
      # #     >
      # # end
      # ```
      property brackets : Array(Tuple(String, String))

      # The formatter output can be colorized according to its nesting level -
      # the brackets around sets of elements are colored with `colors[0]`, the
      # brackets around sets of rows are colored with `colors[1]`, and so on.
      # Note that this array can be whatever length you want - the formatter
      # will restart the color cycle after reaching the end of the color array.
      #
      # For a list of valid colors, see the `Colorize` module in the standard
      # library.
      @[YAML::Field(converter: YAML::ArrayConverter(Phase::MultiIndexable::Formatter::Settings::ColorConverter))]
      property colors : Array(Colorize::ColorRGB | Symbol)

      @[YAML::Field(key: "collapse_brackets_after")]
      property collapse_height : Int32

      property integer_format : String
      property decimal_format : String

      def self.new
        @@project_settings || user_settings || default
      end

      def initialize(@indent_width, @max_element_width, omit_after @display_limit,
                     @brackets, colors, collapse_brackets_after @collapse_height,
                     @integer_format, @decimal_format)
        @colors = colors.map &.as(Colorize::ColorRGB | Symbol)
      end

      # TODO: document properly once this is set in stone
      # tries to read from PHASE_CONFIG_DIR - if the file isn't there,
      # reads from XDG_CONFIG_DIR/phase. if still not there, tries ~/.config
      # BETTER_ERROR: Better error message for failed read
      def self.user_settings : self?
        return nil if @@disable_user_settings
        return @@cached_user_settings if @@cached_user_settings

        if dir = ENV["PHASE_CONFIG_DIR"]?
          path = (Path[dir] / USER_CONFIG_FILENAME).expand(home: true)

          if File.exists?(path)
            return @@cached_user_settings = from_yaml(File.read(path))
          end
        end

        {ENV["XDG_CONFIG_DIR"]?, "~/.config"}.each do |dir|
          if dir
            path = (Path[dir] / "phase" / USER_CONFIG_FILENAME).expand(home: true)

            if File.exists?(path)
              return @@cached_user_settings = from_yaml(File.read(path))
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
          max_element_width: 15,
          omit_after: [10, 5],
          brackets: [{"[", "]"}],
          colors: [:red, :yellow, :blue],
          collapse_brackets_after: 5,
          integer_format: "%d",
          decimal_format: "%.3g"
        )
      end

      class ColorConverter
        # NOTE: I tried generating this with macros, but nothing was
        # as effective as just hardcoding it.
        COLOR_MAP = {"default"       => :default,
                     "black"         => :black,
                     "red"           => :red,
                     "green"         => :green,
                     "yellow"        => :yellow,
                     "blue"          => :blue,
                     "magenta"       => :magenta,
                     "cyan"          => :cyan,
                     "light_gray"    => :light_gray,
                     "dark_gray"     => :dark_gray,
                     "light_red"     => :light_red,
                     "light_green"   => :light_green,
                     "light_yellow"  => :light_yellow,
                     "light_blue"    => :light_blue,
                     "light_magenta" => :light_magenta,
                     "light_cyan"    => :light_cyan,
                     "white"         => :white}

        def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Symbol | Colorize::ColorRGB
          unless node.is_a?(YAML::Nodes::Scalar)
            node.raise "Expected scalar, not #{node.kind}"

            # HACK: This isn't reachable, but it seems that the compiler can't
            # figure that out - to appease ArrayConverter, I needed to add this.
            return :yikes
          end

          if str = node.value
            if sym = COLOR_MAP[str]?
              return sym
            elsif (rgb = str.hexbytes?) && rgb.size == 3
              return Colorize::ColorRGB.new(rgb[0], rgb[1], rgb[2])
            end
          end

          node.raise <<-MSG
            Expected #{(COLOR_MAP.keys.map &.inspect).join(", ")}, 
            or an RGB hex string, not #{node.value.inspect}. 
            #{"Recall that '#' starts a comment in YAML, and should be 
            omitted from your color codes." if node.value.empty?}
          MSG

          # HACK: Same one as above.
          return Colorize::ColorRGB.new(0, 0, 0)
        end

        def self.to_yaml(value : Symbol, yaml : YAML::Nodes::Builder)
          yaml.scalar(value.to_s)
        end

        def self.to_yaml(v : Colorize::ColorRGB, yaml : YAML::Nodes::Builder)
          yaml.scalar("##{Bytes[v.red, v.green, v.blue].hexdump.upcase}")
        end
      end
    end
  end
end
