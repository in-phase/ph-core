require "big"

module Lattice
  abstract class CoordIterator(T)
    include Iterator(Coord)

    getter coord : Array(T)

    @first : Array(T)
    @last : Array(T)
    @step : Array(T)

    # Informs the iterator to not update the coord, i.e. if the iterator 
    # is empty or when returning the first item
    @hold_coord : Bool = true
    @empty : Bool = false
    getter size : BigInt

    abstract def advance_coord

    # Set up any incrementing variables (such as @coord) here prior to iteration.
    def reset : self
      @coord = @first.dup
      @hold_coord = true 
      self
    end

    def self.from_canonical(first, last, step, size = nil)
      if !size
        size = measure(first, last, step)
      end
      self.new(first, last, step, size)
    end

    def initialize(shape : Indexable(T), region : CanonicalRegion? = nil, reverse : Bool = false)
      # TODO: When crystal 1.1.0 comes out, move the @coord initializer up to `getter coord = [] of T`.
      # this is a known bug
      @coord = [] of T
      @first, @last, @step, @size = iteration_params(shape, region)
      @empty = (@size == 0)
      reset
      reverse! if reverse
    end

    def initialize(@first, @last, @step, @size)
      # TODO: When crystal 1.1.0 comes out, move the @coord initializer up to `getter coord = [] of T`.
      # this is a known bug
      @coord = [] of T
      @empty = @size == 0
      reset
    end

    def next : (Array(T) | Stop)
      if @hold_coord
        return stop if @empty 
        # if the iterator is nonempty, we only hold for the first coord
        @hold_coord = false 
        return @coord
      end
      advance_coord
    end

    # TODO: constrain, figure out what +1 means and if it should depend on step, generally test heavily
    def unsafe_skip(axis, amount) : Nil
      @coord[axis] += amount + 1
    end

    def reverse!
      @last, @first = @first, @last
      @step.map! &.-
      reset
    end

    def reverse
      typeof(self).new(@last, @first, @step.map &.-, @size)
    end

    protected def self.measure(firsts, lasts, steps) : BigInt
      size = BigInt.new(1)
      steps.each_with_index do |step, i|
        size *= (lasts[i] - firsts[i]) // step + 1
      end
      size
    end

    # Explicit return is necessary for initialization of instance vars
    protected def iteration_params(shape, region) : Tuple(Array(T), Array(T), Array(T), BigInt)
      if shape.size == 0
        raise DimensionError.new("Failed to create {{@type.id}}: cannot iterate over empty shape \"[]\"")
      end

      size = BigInt.new(1)
      if region
        first = Array(T).new(initial_capacity: region.size)
        last = Array(T).new(initial_capacity: region.size)
        step = Array(T).new(initial_capacity: region.size)

        region.each do |range|
          size *= range.size
          first << range.begin
          step << range.step
          last << range.end
        end
      else
        first = [0] * shape.size
        step = [1] * shape.size
        last = shape.map do |el|
          size *= el
          next el - 1
        end
      end
      {first, last, step, size}
    end
  end
end
