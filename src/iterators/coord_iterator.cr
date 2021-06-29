module Lattice

  # Strictly finite regions
  abstract class CoordIterator(T) < GeneralCoordIterator(T)
    @last : Array(T)
    getter size : BigInt

    def self.from_canonical(first, last, step, size = nil)
      if !size
        size = measure(first, last, step)
      end
      self.new(first, last, step, size)
    end

    def self.cover(shape : Shape)
      new(IndexRegion.cover(shape))
    end

    def initialize(region : IndexRegion, reverse : Bool = false)
      # TODO: When crystal 1.1.0 comes out, move the @coord initializer up to `getter coord = [] of T`.
      # this is a known bug
      @coord = [] of T
      @first, @step, @last, @size = region.start, region.step, region.stop, BigInt.new(region.size)
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
  end
end
