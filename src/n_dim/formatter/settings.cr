require "colorize"
require "yaml"

module Lattice::MultiIndexable
  class Formatter(T)
    class Settings
      include YAML::Serializable

      USER_CONFIG_FILENAME = "formatter.yaml"

      @@cached_user_settings : self?
      @@disable_user_settings = false

      class_property project_settings : self?

      property indent_width : Int32
      property max_element_width : Int32

      @[YAML::Field(key: "omit_after")]
      property display_limit : Array(Int32)

      property brackets : Array(Tuple(String, String))

      @[YAML::Field(converter: YAML::ArrayConverter(Lattice::MultiIndexable::Formatter::Settings::ColorConverter))]
      property colors : Array(Colorize::ColorRGB | Symbol)

      @[YAML::Field(key: "collapse_brackets_after")]
      property collapse_height : Int32

      def self.new
        @@project_settings || user_settings || default
      end

      def initialize(@indent_width, @max_element_width, omit_after @display_limit,
                     @brackets, colors, collapse_brackets_after @collapse_height)
        @colors = colors.map &.as(Colorize::ColorRGB | Symbol)
      end

      # TODO: document properly once this is set in stone
      # tries to read from LATTICE_CONFIG_DIR - if the file isn't there,
      # reads from XDG_CONFIG_DIR/lattice. if still not there, tries ~/.config
      def self.user_settings : self?
        return nil if @@disable_user_settings
        return @@cached_user_settings if @@cached_user_settings

        if dir = ENV["LATTICE_CONFIG_DIR"]?
          path = (Path[dir] / USER_CONFIG_FILENAME).expand(home: true)

          if File.exists?(path)
            return @@cached_user_settings = from_yaml(File.read(path))
          end
        end

        {ENV["XDG_CONFIG_DIR"]?, "~/.config"}.each do |dir|
          if dir
            path = (Path[dir] / "lattice" / USER_CONFIG_FILENAME).expand(home: true)

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
          max_element_width: 20,
          omit_after: [10, 5],
          brackets: [{"[", "]"}],
          colors: [:default],
          collapse_brackets_after: 5
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
