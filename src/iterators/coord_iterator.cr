module Phase
  # Strictly finite regions
  abstract class CoordIterator(T) < GeneralCoordIterator(T)
    @last : Array(T)
    getter size : BigInt

    def self.cover(shape : Shape)
      new(IndexRegion.cover(shape))
    end

    protected def initialize(region : IndexRegion(T))
      initialize(region.first, region.last, region.step, BigInt.new(region.size))
    end

    protected def initialize(@first, @last, @step, @size)
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
      clone.reverse!
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
