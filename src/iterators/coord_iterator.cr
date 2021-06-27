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

    def initialize(shape : Indexable(T), region : IndexRegion? = nil, reverse : Bool = false)
      # TODO: When crystal 1.1.0 comes out, move the @coord initializer up to `getter coord = [] of T`.
      # this is a known bug
      @coord = [] of T
      if region.nil?
        idx_r = IndexRegion.cover(shape)
      else
        idx_r = IndexRegion.new(region, shape)
      end
      @first, @step, @last, @size = idx_r.start, idx_r.step, idx_r.stop, BigInt.new(idx_r.size)
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

    # Explicit return is necessary for initialization of instance vars
    # protected def iteration_params(shape, region) : Tuple(Array(T), Array(T), Array(T), BigInt)
    #   if shape.size == 0
    #     raise DimensionError.new("Failed to create {{@type.id}}: cannot iterate over empty shape \"[]\"")
    #   end

    #   size = BigInt.new(1)
    #   if region

        
    #     first = Array(T).new(initial_capacity: region.size)
    #     last = Array(T).new(initial_capacity: region.size)
    #     step = Array(T).new(initial_capacity: region.size)

    #     region.each do |range|
    #       size *= range.size
    #       first << range.begin
    #       step << range.step
    #       last << range.end
    #     end
    #   else
    #     first = [0] * shape.size
    #     step = [1] * shape.size
    #     last = shape.map do |el|
    #       size *= el
    #       next el - 1
    #     end
    #   end
    #   {first, last, step, size}
    # end
  end
end
