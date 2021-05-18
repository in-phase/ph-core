struct SteppedRange
    getter size : Int32
    getter range : Range(Int32, Int32)
    getter step : Int32

    def initialize(@range : Range(Int32, Int32), @step : Int32)
      @size = ((@range.end - @range.begin) // @step).abs.to_i32 + 1
    end

    def initialize(index)
      @size = 1
      @step = 1
      @range = index..index
    end

    # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
    # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
    # going forwards or backwards.
    # TODO: Better docs
    # TODO find out why these 2 implementations are so drastically different in performance! Maybe because the functionality has been recently modified? (Crystal 0.36)
    def each(&block)
      idx = @range.begin
      if @step > 0
        while idx <= @range.end
          yield idx
          idx += @step
        end
      else
        while idx >= @range.end
          yield idx
          idx += @step
        end
      end
      #   @range.step(@step) do |i|
      #     yield i
      #   end
    end

    def inspect(io)
      if @size == 1
        io << @range.begin.to_s
      else
        io << "(#{@range}).step(#{@step})"
      end
    end

    def begin
      @range.begin
    end

    def end
      @range.end
    end

    def excludes_end?
      false
    end
end

struct SteppedRangeIterator
    include Iterator(Int32)

    getter size : Int32
    getter range : Range(Int32, Int32)
    getter step : Int32
    getter current : Int32

    def initialize(@range : Range(Int32, Int32), @step : Int32)
      @size = ((@range.end - @range.begin) // @step).abs.to_i32 + 1
      @current = @range.begin
    end

    def initialize(index)
      @size = 1
      @step = 1
      @range = index..index
      @current = @range.begin
    end

    # Given __subspace__, a canonical `Range`, and a  __step_size__, invokes the block with an index
    # for every nth integer in __subspace__. This is more or less the same as range.each, but supports
    # going forwards or backwards.
    # TODO: Better docs
    # TODO find out why these 2 implementations are so drastically different in performance! Maybe because the functionality has been recently modified? (Crystal 0.36)
    # def each(&block)
    #   idx = @range.begin
    #   if @step > 0
    #     while idx <= @range.end
    #       yield idx
    #       idx += @step
    #     end
    #   else
    #     while idx >= @range.end
    #       yield idx
    #       idx += @step
    #     end
    #   end
    #   #   @range.step(@step) do |i|
    #   #     yield i
    #   #   end
    # end

    def next
        if last?
            return stop
        end
        val = @current
        @current += @step
        val
    end

    def last?
        return @current == @range.end
    end

    def reverse
        @step *= -1
        @range = @range.end..@range.begin
    end

    def inspect(io)
      if @size == 1
        io << @range.begin.to_s
      else
        io << "(#{@range}).step(#{@step})"
      end
    end

    def begin
      @range.begin
    end

    def end
      @range.end
    end

    def excludes_end?
      false
    end
end

max = 5 #Int32::MAX // 3

range = SteppedRange.new(0..max, 1)

range_iter = SteppedRangeIterator.new(0..max, 1)

step_iter = (0..max).step(1)

puts range 
puts range_iter, step_iter

memo = 0
one = Time.measure do
    range.each do |i|
        puts i if i % 100000000 == 0
    end
end

two = Time.measure do
    range_iter.each do |i|
        puts i if i % 100000000 == 0
    end
end

three = Time.measure do
    step_iter.each do |i|
        puts i if i % 100000000 == 0
    end
end

puts one, two, three