require "../coord_util.cr"

module Phase
  module RangeSyntax
    extend self

    def get_size(first, last, step)
      if last != first && step.sign != (last <=> first)
        raise IndexError.new("Could not get size of range - step direction disagrees with first and last.")
        return 0
        # done the painful way in case first and last are unsigned
      elsif last >= first
        return (last - first) // step + 1
      else
        return (first - last) // (-step) + 1
      end
    end

    def bounded?(range_literal : Int32)
      true
    end

    def bounded?(range_literal)
      vals = parse_range(range_literal)
      step = vals[:step]

      if step.nil? || step >= 0
        # assumed to be increasing; last must be defined
        return false if vals[:last].nil?
      else
        # assumed to be decreasing; first must be defined
        return false if vals[:first].nil?
      end
      true
    end

    # Interprets stdlib `Range(Int?, Int?)`, e.g. `a..c`
    # Interprets inputs of the form `a..b..c`, representing a range `a..c` with step `b`
    # - `Range(Int?, Range(Int?, Int?))` e.g. `a..(b..c)`
    # - `Range(Range(Int?, Int?), Int?)` e.g. `(a..b)..c`
    protected def parse_range(range : Range)
      case first = range.begin
      when Range
        # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
        case last = range.end
        when Int, Nil
          return {first: first.begin, last: last, step: first.end, exclusive: range.excludes_end?}
        end
      when Int, Nil
        case last = range.end
        when Range
          return {first: first, last: last.end, step: last.begin, exclusive: last.excludes_end?}
        when Int, Nil
          return {first: first, last: last, step: nil, exclusive: range.excludes_end?}
        end
      end

      raise "poorly formatted range - should be a..c, a..b..c, (a..b)..c, or a..(b..c) where a,c are Int | Nil, b is Int (improve this error message)"
    end

    # NOTE: be careful with range.@var
    protected def parse_range(range : Steppable::StepIterator)
      {first: range.@current, last: range.@limit, step: range.@step, exclusive: range.@exclusive}
    end

    protected def parse_range(index : Int)
      # This method is included primarily to placate the compiler but should not need to actually run.
      {first: index, last: index, step: 1, exclusive: false}
    end

    def ensure_nonnegative(index : Int?)
      return if index.nil?
      if index < 0
        raise IndexError.new("Negative indices have no meaning when a bounding shape is not provided.")
      end
    end

    def ensure_nonnegative(range_literal)
      vals = parse_range(range_literal)
      ensure_nonnegative(vals[:first])
      ensure_nonnegative(vals[:last])
    end

    protected def conv(int, target_type)
      target_type.zero + int
    end

    def infer_range(index : Int, bound : T) forall T
      canonical = conv(CoordUtil.canonicalize_index_unsafe(index, bound), T)
      {first: canonical, step: 1, last: canonical, size: conv(1,T)}
    end

    def infer_range(range_literal, bound : T) : NamedTuple(first: T, step: Int32, last: T, size: T) forall T
      vals = parse_range(range_literal)
      f = vals[:first]
      l = vals[:last]
      step = vals[:step]


      # Infer endpoints
      if step.nil?
        first     = f.nil? ? T.zero    : conv(CoordUtil.canonicalize_index_unsafe(f, bound), T)
        temp_last = l.nil? ? bound - 1 : CoordUtil.canonicalize_index_unsafe(l, bound)

        step = (temp_last >= first) ? 1 : -1
      else
        first     = f.nil? ? (step > 0 ? T.zero : bound - 1) : conv(CoordUtil.canonicalize_index_unsafe(f, bound), T)
        temp_last = l.nil? ? (step > 0 ? bound - 1 : T.zero) : CoordUtil.canonicalize_index_unsafe(l, bound)
      end

      # Account for exclusivity
      if !l.nil? && vals[:exclusive]
        if temp_last == first
          # Range spans no integers; we use the convention first, last, step, size = 0 to indicate this
          return {first: T.zero, step: 0, last: T.zero, size: T.zero}
        end
        temp_last -= step.sign
      end

      # Until now we haven't raised errors for invalid endpoints, because it was possible
      # that exclusivity would allow seemingly invalid endpoints (e.g., -6 is a valid exclusive
      # endpoint for bound=5, but not a valid *inclusive* one). We have to catch the case
      # where the range wasn't even valid here.
      if first < 0 || temp_last < 0
        raise IndexError.new("Invalid index: At least one endpoint of #{Range.new(f, l, vals[:exclusive])} is negative after canonicalization.")
      end

      begin
        # Align temp_last to an integer number of steps from first
        size = conv(get_size(first, temp_last, step), T)
        last = first + step * (size - 1)

        {first: first, step: step.to_i32, last: last, size: size}
      rescue ex : IndexError
        # This doesn't change any functionality, but makes debugging easier
        raise IndexError.new("Could not canonicalize range: Conflict between implicit direction of #{Range.new(f, l, vals[:exclusive])} and provided step #{step}")
      end
    end

    def range_valid?(first, last, bound)
      last.in?(0...bound) && first.in?(0...bound)
    end

    # canonicalize_range(range, bound)
    # infer_range(range, bound)
    # all hte other stuff
    def canonicalize_range(range, bound : T) : NamedTuple(first: T, step: Int32, last: T, size: T) forall T
      r = infer_range(range, bound)

      unless range_valid?(r[:first], r[:last], bound)
        raise IndexError.new("Could not canonicalize range: #{range} is not a sensible index range for axis of length #{bound}.")
      end

      r
    end
  end
end
