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

    def bounded?(range_literal : Int)
      true
    end

    def bounded?(range_literal : Range)
      case first = range_literal.begin
      when Int
        return false if range_literal.end.nil?
      when Range
        if first.end >= 0 && range_literal.end.nil?
          return false
        elsif first.begin.nil?
          return false
        end
      end

      true
    end

    def ensure_nonnegative(*range_literal : Int?)
      range_literal.each do |int|
        next if int.nil?
        if int < 0
          raise IndexError.new("Negative indices have no meaning when a bounding shape is not provided.")
        end
      end
    end

    def ensure_nonnegative(range_literal : Range)
      case first = range_literal.begin
      when Int
        self.ensure_nonnegative(first, range_literal.end)
      when Range
        self.ensure_nonnegative(first.begin, range_literal.end)
      end
    end

    # NOTE: be careful with range.@var
    def infer_range(range : Steppable::StepIterator, bound)
      infer_range(bound, range.@current, range.@limit, range.@exclusive, range.@step)
    end

    def infer_range(range : Range, step, bound)
      infer_range(bound, range.begin, range.end, range.excludes_end?, step)
    end

    def infer_range(range : Range, bound)
      case first = range.begin
      when Range
        # For an input of the form `a..b..c`, representing a range `a..c` with step `b`
        case last = range.end
        when Int, Nil
          return infer_range(bound, first.begin, last, range.excludes_end?, first.end)
        end
      when Int, Nil
        case last = range.end
        when Range
          return infer_range(bound, first, last.end, last.excludes_end?, last.begin)
        when Int, Nil
          return infer_range(bound, first, last, range.excludes_end?)
        end
      end

      raise "bad infer_range interpretation (improve this error message)"
    end

    def infer_range(index : Int, bound)
      canonical = CoordUtil.canonicalize_index_unsafe(index, bound)
      {first: canonical, step: 1, last: canonical, size: 1}
    end

    def infer_range(bound : T, first : T?, last : T?, exclusive : Bool,
                    step : Int32? = nil) : NamedTuple(first: T, step: Int32, last: T, size: T) forall T
      # Infer endpoints
      if !step
        first = first ? CoordUtil.canonicalize_index_unsafe(first, bound) : T.zero
        temp_last = last ? CoordUtil.canonicalize_index_unsafe(last, bound) : bound - 1

        step = (temp_last >= first) ? 1 : -1
      else
        first = first ? CoordUtil.canonicalize_index_unsafe(first, bound) : (step > 0 ? T.zero : bound - 1)
        temp_last = last ? CoordUtil.canonicalize_index_unsafe(last, bound) : (step > 0 ? bound - 1 : T.zero)
      end

      # Account for exclusivity
      if last && exclusive
        if temp_last == first
          # Range spans no integers; we use the convention first, last, step, size = 0 to indicate this
          return {first: 0, step: 0, last: 0, size: 0}
        end
        temp_last -= step.sign
      end

      # Until now we haven't raised errors for invalid endpoints, because it was possible
      # that exclusivity would allow seemingly invalid endpoints (e.g., -6 is a valid exclusive
      # endpoint for bound=5, but not a valid *inclusive* one). We have to catch the case
      # where the range wasn't even valid here.
      if first < 0 || temp_last < 0
        raise IndexError.new("Invalid index: At least one endpoint of #{first..last} is negative after canonicalization.")
      end

      begin
        # Align temp_last to an integer number of steps from first
        size = get_size(first, temp_last, step)
        last = first + (size - 1) * step

        {first: first, step: step.to_i32, last: last, size: size}
      rescue ex : IndexError
        # This doesn't change any functionality, but makes debugging easier
        raise IndexError.new("Could not canonicalize range: Conflict between implicit direction of #{Range.new(first, last, exclusive)} and provided step #{step}")
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
