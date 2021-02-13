require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"
require "./n_array.cr"

module Lattice
  class NArray(T) < AbstractNArray(T)
    # Applies `#canonicalize_index` and `#canonicalize_range` to each element of a region specification.
    # In order to fully canonicalize the region, it will also add wildcard selectors if the region
    # has implicit wildcards (if `region.size < shape.size`).
    #
    # Returns a tuple containing (in this order):
    # - The input region in canonicalized form
    # - An array of equal size to the region that indicates if that index is a scalar (0),
    #     a range with increasing index (+1), or a range with decreasing index (-1).
    def canonicalize_region(region : T) : Tuple(T, Array(Int32)) forall T
      axis_directions = Array(Int32).new(region.size, initial_value: 0)

      canonical_region = region.to_a.map_with_index do |rule, axis|
        case rule
        when Range
          # Ranges are the only implementation we support
          range, dir = canonicalize_range(rule, axis)
          axis_directions[axis] = dir
          next range
        else
          # This branch is supposed to capture numeric objects. We avoid specifying type
          # explicitly so we can have the most interoperability.
          next canonicalize_index(rule, axis)
        end
      end

      {canonical_region, axis_directions}
    end

    # See `NArray#measure_region`. The only difference is that this method assumes
    # the region is already canonicalized, which can provide speedups.
    protected def measure_canonical_region(region) : Array(Int32)
      shape = [] of Int32

      if region.size != @shape.size
        raise DimensionError.new("Could not measure canonical range - A region with #{region.size} dimensions cannot be canonical over a #{@shape.size} dimensional NArray.")
      end

      # Measure the effect of applied restrictions (if a rule is a number, a dimension
      # gets dropped. If a rule is a range, a dimension gets resized)
      region.each_with_index do |rule, axis|
        if rule.is_a? Range
          shape << (rule.end - rule.begin).abs.to_i32
        end
      end

      return [1] if shape.empty?
      return shape
    end

    # Returns the `shape` of a region when sampled from this `NArray`.
    # For example, on a 5x5x5 NArray, `measure_shape(1..3, ..., 5)` => `[3, 5]`.
    def measure_region(region) : Array(Int32)
      measure_canonical_region(canonicalize_region(region))
    end

    def [](*raw_region) : NArray(T)
      region, axis_dirs = canonicalize_region(raw_region)
    end

    def each_in_region(region, &block : T, Array(Int32), Int32 ->)
      region, axis_dirs = canonicalize_region(region)
      shape = measure_canonical_region(region)

      shape.product.times do |new_buf_idx|
      end
    end

    def [](region)
        view(region).to_n_array
    end
  end
end

class NArray(T) < AbstractNArray(T)
  def view(region) : View(T)
    # Returns a view of this NArray
  end

  def [](region) : NArray(T)
    # Returns a proper NArray, fully copied - not linked to the original
  end
end

class View(T) < AbstractNArray(T)
  @source : NArray(T)
  @region : Array(Range | Int32)

  def self.from_region(@source, @region)
    # Creates a view of an NArray
  end

  def unlink : NArray(T)
    # Turns this view into an NArray by copying elements into a new buffer
  end

  def [](region) : View(T)
    # Returns a view to the same NArray as this one, but for an even narrower view
  end
end
