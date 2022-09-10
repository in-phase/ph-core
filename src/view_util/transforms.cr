module Phase
  class ReadonlyView(S, R)
    # probably done
    abstract struct CoordTransform
      @@commutes = [] of CoordTransform.class

      def compose(t : CoordTransform) : CoordTransform
        return ComposedTransform[t, self]
      end

      # Possibly
      # def commute?(t : CoordTransform) : Tuple(Transform, CoordTransform)
      # end

      def commutes_with?(t : CoordTransform) : Bool
        return commutes.any? { |type| type == t.class } || t.commutes.any? { |type| type == self.class }
      end

      protected def commutes
        @@commutes
      end

      # must not mutate coord
      abstract def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
    end

    # probably done for now
    struct ComposedTransform < CoordTransform
      @transforms : Array(CoordTransform)
      
      # This is used when the transform list is empty
      @id : IdentityTransform = IdentityTransform.new()

      def initialize(@transforms = [] of CoordTransform)
      end

      def self.[](*transforms)
        new((transforms.map &.as(CoordTransform)).to_a)
      end

      def clone
        # TODO: decide if this needs to be clone (we will have to define a clone method on all transforms then)
        ComposedTransform.new(@transforms.dup)
      end

      def compose!(t : CoordTransform)
        @transforms.unshift(t)
      end

      # stolen from our attempt at View class
      # def push_transform(t : Transform) : Nil
      #     if t.composes?
      #         (@transforms.size - 1).downto(0) do |i|
      #             if new_transform = t.compose?(@transforms[i])
      #                 if new_transform < IdentityTransform # If composition => annihiliation
      #                     @transforms.delete_at(i)
      #                 else
      #                     @transforms[i] = new_transform
      #                 end
      #                 return
      #             elsif !t.commutes_with?(@transforms[i])
      #                 break
      #             end
      #         end
      #     end
      #     @transforms << t
      # end

      def compose!(t : ComposedTransform)
        @transforms = t.transforms + @transforms
      end

      def compose(t : CoordTransform) : ComposedTransform
        clone.compose!(t)
      end

      def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
        # NOTE: if we ever add a PadTransform, this could break. If a PadTransform encounters a coord outside the src, it should return a default/computed value early.
        if @transforms.empty?
          @id.apply(coord)
        else
          output = @transforms.reduce(coord) do |coord, trans|
            trans.apply(coord)
          end

          # The compiler is concerned that output might be equal to coord
          # (in the case when transforms has no elements). We checked that
          # isn't true at runtime, but we still need to typecast
          output.as(ReadonlyWrapper(OutputCoord(Int32), Int32))
        end
      end

      # TODO: see clone
      def transforms
        @transforms.dup
      end

      protected def transforms!
        @transforms
      end
    end

    # done
    struct IdentityTransform < CoordTransform
      def compose(t : CoordTransform) : CoordTransform
        t
      end

      def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
        # TODO: Optimize. There should be an internal buffer and readonly wrapper stored as member
        # variables, and coord should just get copied to that buffer. This also requires that
        # a coordtransform should be initialized with its container shape / num dimensions
        ReadonlyWrapper.new(coord.to_a)
      end
    end

    # probably done
    struct ReshapeTransform < CoordTransform
      @new_shape : Array(Int32)
      @src_shape : Array(Int32)

      @buffer : Array(Int32) # has same size as output coord (and @src_shape)
      @view_axis_strides : Array(Int32)
      @wrapper : ReadonlyWrapper(Array(Int32), Int32)

      def initialize(src_shape : Enumerable(Int32), new_shape : Enumerable(Int32))
        @src_shape = src_shape.to_a
        @new_shape = new_shape.to_a
        @buffer = @src_shape.clone
        @wrapper = ReadonlyWrapper.new(@buffer)
        @view_axis_strides = axis_strides(@new_shape)
      end

      def compose(t : CoordTransform) : CoordTransform
        case t
        when self
          # Always yield to the latest 'reshape' call in a chain
          return t
        else
          return super
        end
      end

      # TODO: these three methods were stolen from NArray. Move to somewhere more mutually useful?
      # Also TODO: brainstorm if there is a faster algorithm for doing this directly, without an intermediate index
      protected def index_to_coord(index, shape)
        coord = Array(Int32).new(shape.size, 0)
        shape.reverse.each_with_index do |length, dim|
          coord[dim] = index % length
          index //= length
        end
        coord.reverse
      end

      protected def index_to_coord(index, shape, coord_buffer)
        dim = shape.size - 1
        shape.reverse_each do |length|
          coord_buffer[dim] = index % length
          index //= length
          dim -= 1
        end
        coord_buffer
      end

      protected def coord_to_index(coord, axis_strides) : Int32
        index = 0
        coord.each_with_index do |elem, idx|
          index += elem * axis_strides[idx]
        end
        index
      end

      protected def axis_strides(shape)
        ret = shape.clone
        ret[-1] = 1

        ((ret.size - 2)..0).step(-1) do |idx|
          ret[idx] = ret[idx + 1] * shape[idx + 1]
        end

        ret
      end

      def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
        index = coord_to_index(coord, @view_axis_strides)
        index_to_coord(index, @src_shape, @buffer)
        @wrapper
      end
    end

    struct RegionTransform < CoordTransform
      # each of these has size = dimensions
      # TODO: Try to make this accept a generic coordinate type
      getter region : IndexRegion(Int32)
      @buffer : Array(Int32)
      @wrapper : ReadonlyWrapper(Array(Int32), Int32)

      def initialize(@region)
        @buffer = Array.new(@region.dimensions, 0)
        @wrapper = ReadonlyWrapper.new(@buffer)
      end

      # TODO: check reaaaaally carefully
      def compose(t : CoordTransform) : CoordTransform
        case t
        when self
          # compose regions
          @region.unsafe_fetch_chunk(t.region)
        when ReverseTransform
        else
          return super
        end
      end

      def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
        # TODO: Optimize by directly populating the buffer with
        # this calculation
        @region.unsafe_fetch_element(coord).each_with_index do |el, idx|
          @buffer[idx] = el
        end

        @wrapper
      end
    end

    struct PermuteTransform < CoordTransform
      # each of these has size = dimensions
      getter pattern : Array(Int32)
      @buffer : Array(Int32)
      @wrapper : ReadonlyWrapper(Array(Int32), Int32)

      def initialize(pattern : Enumerable(Int32))
        @pattern = pattern.to_a
        @buffer = @pattern.clone
        @wrapper = ReadonlyWrapper.new(@buffer)
      end

      def self.new(size : Int32)
        new(Array.new(size) { |i| size - i - 1 })
      end

      def compose(t : CoordTransform) : CoordTransform
        case t
        when PermuteTransform
          return new(t.permute(@pattern))
        else
          return super
        end
      end

      def permute(src_coord)
        view_coord = Array.new(@pattern.size) do |src_idx|
          src_coord[pattern[src_idx]]
        end
      end

      def unpermute(view_coord)
        src_coord = view_coord.clone
        unpermute(view_coord, src_coord)
      end

      def unpermute(view_coord, src_coord_buffer)
        @pattern.each_with_index do |el, idx|
          src_coord_buffer[el] = view_coord[idx]
        end
        src_coord_buffer
      end

      def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
        unpermute(coord, @buffer)
        @wrapper
      end
    end

    struct ReverseTransform < CoordTransform
      # each of these has size = dimensions
      @shape : Array(Int32)
      @buffer : Array(Int32)
      @wrapper : ReadonlyWrapper(Array(Int32), Int32)

      def initialize(@shape)
        @buffer = @shape.clone
        @wrapper = ReadonlyWrapper.new(@buffer)
      end

      def compose(t : CoordTransform) : CoordTransform
        case t
        when self
          return IdentityTransform.new
          # when RegionTransform
          #     region = t.region.each do |range|
          #         range.reverse
          #     end
          #     return RegionTransform.new(region)
        else
          return super
        end
      end

      def apply(coord : InputCoord(Int32)) : ReadonlyWrapper(OutputCoord(Int32), Int32)
        coord.each_with_index do |el, i|
          @buffer[i] = @shape[i] - 1 - el
        end

        @wrapper
      end
    end
  end
end
