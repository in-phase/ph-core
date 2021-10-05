module Phase
  # A coordinate iterator that advances to the next value by taking
  # orthogonal strides. The only iteration orders that obey that criteria are
  # lexicographic, colexicographic, and their reverses.
  abstract class StrideIterator(I)
    include Iterator(Indexable(I))

    # The first coordinate that the iterator will provide.
    @first : Array(I)

    # The step sizes that can be taken in each axis. For example,
    # axis `n` will take steps of size `@step[n]`. This quantity
    # is hardcoded as Int32, because it can be signed even if the index
    # type is unsigned - moving from `8u32` to `1u32` is legal for an index
    # type of  `UInt32`, but it requires a signed step of `-7`.
    #
    # We do not expect people to construct `MultiIndexable`s with more than
    # two billion elements in any axis, so we choose 32 bit integers to
    # avoid the performance penalty of larger types.
    #
    # TODO: maybe we should switch to Int64 as most architectures are 64 bit
    # anyway?
    @step : Array(Int32)

    # The last coordinate that the iterator will provide.
    @last : Array(I)

    # The working memory buffer that stores the current coordinate.
    @coord : ::Slice(I)

    # Because @coord is writable, but we don't want the user mutating it,
    # we will only ever expose this wrapper to them. This ensures that
    # they cannot alter the working coordinate.
    @wrapper : ReadonlyWrapper(I)

    # For efficiency reasons related to reuse of the coordinate buffer,
    # `StrideIterator` must advance the coordinate before it is able
    # to return a coordinate. This would by default skip the first
    # coordinate, so instead we introduce an artificial lag of one
    # iteration with this flag.
    @hold : Bool = true

    # Constructs an iterator that will traverse from `first` to `stop` by incrementing by `step[n]` in axis `n`.
    # If `@first[i] == @last[i]`, then `@step[i]` can be 1 to indicate that all
    # values have an `i`th oordinate of `@first[i]` (as in x..x), and @step[i] can be 0 to
    # indicate that no possible values can represent the `i`th ordinate (as in x...x).
    def initialize(@first : Array(I), step : Array(Int), @last : Array(I))
      # These errors only need to be checked for in this constructor.
      # Constructors that use `IndexRegion` are automatically free from
      # step size issues and element count mismatch.
      unless @first.size == step.size && step.size == @last.size
        raise ArgumentError.new("The bounding coordinates and the step sizes must have the same number of elements, but they did not. (first coord has #{@first.size} elements, last coord has #{last.size}, and #{step.size} step sizes were provided)")
      end

      @first.each_with_index do |f, idx|
        s, l = step.unsafe_fetch(idx), @last.unsafe_fetch(idx)
        
        if (l - f) % s != 0
          raise ArgumentError.new("The step size in axis #{idx} (#{s}) did not evenly divide the gap between the first and last ordinate along that axis. (first: #{f}, last: #{l})")
        end

        direction = (l - f).sign

        if direction != s.sign && direction != 0
          sign_names = {"zero", "positive", "negative"}
          raise ArgumentError.new("The step size in axis #{idx} is #{sign_names[s.sign]}, which means it will never bring the first ordinate (#{f}) to the last ordinate (#{l}).")
        end
      end
      
      @step = step.map &.to_i32
      @coord = ::Slice(I).new(@first.size) { |i| @first[i] }
      @wrapper = ReadonlyWrapper.new(@coord.to_unsafe, @coord.size)
    end

    # Constructs an iterator that will provide every coordinate described by an `IndexRegion`.
    def initialize(idx_region  : IndexRegion(I))
      @first = idx_region.@first
      @step = idx_region.@step
      @last = idx_region.@last
      @coord = ::Slice(I).new(@first.size) { |i| @first[i] }
      @wrapper = ReadonlyWrapper.new(@coord.to_unsafe, @coord.size)
    end

    # Constructs an iterator that will provide every coordinate described by a region literal.
    def self.new(region_literal : Indexable)
      new(IndexRegion.new(region_literal))
    end

    # Constructs an iterator that will provide every coordinate in `src.shape`.
    def self.cover(src : MultiIndexable)
      cover(src.shape)
    end

    # Constructs an iterator that will provide every coordinate within `shape`.
    def self.cover(shape : Indexable(I)) forall I
      new(IndexRegion(I).cover(shape))
    end

    # Advances the internal state of this `StrideIterator` and returns the new coord (or `Iterator::Stop` if iteration is finished). 
    abstract def advance! : ::Slice(I) | Stop

    def next : ReadonlyWrapper(I) | Stop
      if @hold
        @hold = false
      else
        return stop if advance!.is_a? Stop
      end

      @wrapper
    end

    # Returns `next` typecast to an `Indexable(I)`. This will raise if the iterator returns `Stop`.
    def unsafe_next : Indexable(I)
      self.next.as(ReadonlyWrapper(I))
    end

    def reset!
      @coord.map! { |i| @first[i] }
      @hold = true
    end

    # Reverses the direction of iteration in-place.
    def reverse!
      @last, @first = @first, @last
      @step.map! &.-
      reset!
    end

    # Returns an ordered `Array` of all coordinates this `StrideIterator` will cover.
    def to_a : Array(Indexable(I))
      arr = [] of Indexable(I)
      each { |el| arr << el.to_a }
      arr
    end

    # Returns a coordinate that stores the largest possible value this `StrideIterator` can output in each ordinate.
    def largest_coord : Indexable(I)
      @step.map_with_index do |step_value, idx|
        if step_value.positive?
          @last[idx]
        else
          @first[idx]
        end
      end
    end

    macro def_standard_clone
      protected def copy_from(other : self)
        @first = other.@first.clone
        @step = other.@step.clone
        @last = other.@last.clone
        @coord = other.@coord.clone
        @wrapper = ReadonlyWrapper.new(@coord.to_unsafe, @coord.size)
        self
      end

      def clone : self
        inst = {{@type}}.allocate
        inst.copy_from(self)
      end
    end
  end
end