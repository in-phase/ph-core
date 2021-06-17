require "../region_helpers"

module Lattice
  module MultiIndexable(T)
    abstract class CoordIterator
      include Iterator(Array(Int32))

      MOST_SIG = 0
      LEAST_SIG = -1

      getter coord : Array(Int32) = [] of Int32

      @first : Array(Int32)
      @last : Array(Int32)
      @step : Array(Int32)

      @empty : Bool = false
      getter size : Int32

      abstract def next_if_nonempty
      
      # Set up any incrementing variables (such as @coord) here prior to iteration.
      # See: LexIterator.reset for inspiration
      abstract def reset : self

      def self.from_canonical(first, last, step, size = nil)
        if !size
          size = measure(first, last, step)
        end
        self.new(first, last, step, size)
      end

      def initialize(shape, region : Array(SteppedRange)? = nil, reverse : Bool = false)
        @first, @last, @step, @size = CoordIterator.iteration_params(shape, region)
        @empty = (@size == 0)
        reset
        reverse! if reverse
      end

      def initialize(@first, @last, @step, @size)
        @empty = @size == 0
        reset
      end

      def next : (Array(Int32) | Stop)
        return stop if @empty
        next_if_nonempty
      end

      # TODO: constrain, figure out what +1 means and if it should depend on step, generally test heavily
      def skip(axis, amount) : Nil
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
      
      def setup_coord(decrement_axis)
        @coord = @first.dup
        @coord[decrement_axis] -= @step[decrement_axis]
      end

      protected def self.measure(firsts, lasts, steps) : Int32
        size = 1
        steps.each_with_index do |step, i|
          size *= (lasts[i] - firsts[i]) // step + 1
        end
        size
      end

      # Explicit return is necessary for initialization of instance vars
      def self.iteration_params(shape, region) : Tuple(Array(Int32), Array(Int32), Array(Int32), Int32)
        if shape.size == 0
          raise DimensionError.new("Failed to create {{@type.id}}: cannot iterate over empty shape \"[]\"")
        end

        size = 1
        if region
          first = Array(Int32).new(initial_capacity: region.size)
          last = Array(Int32).new(initial_capacity: region.size)
          step = Array(Int32).new(initial_capacity: region.size)

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

    class LexIterator < CoordIterator
    
      def reset : self
        setup_coord(CoordIterator::LEAST_SIG)
        self
      end

      def next_if_nonempty
        (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @coord[i] = @first[i]
            return stop if i == 0 # most sig
          else
            @coord[i] += @step[i]
            break
          end
        end
        @coord
      end
    end

    class ColexIterator < CoordIterator
      def reset : self
        setup_coord(CoordIterator::MOST_SIG)
        self
      end

      def next_if_nonempty
        @coord.each_index do |i| # ## least sig .. most sig
          if @coord[i] == @last[i]
            @coord[i] = @first[i]
            return stop if i == @coord.size - 1 # most sig
          else
            @coord[i] += @step[i]
            break
          end
        end
        @coord
      end
    end
  end
end
