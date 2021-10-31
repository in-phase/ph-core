require "benchmark"

abstract class BaseIterator
    include Iterator(Indexable(Int32))
    
    @start = 0
    @stop = 1000
    @current : Array(Int32)

    def initialize
        @current = [@start] * 20
    end

    def advance
        @current.map! &.succ
        return stop if @current.unsafe_fetch(0) == @stop
        return @current
    end
end

class CloningIterator < BaseIterator
    def next
        prev = @current.clone
        if advance.is_a? Stop
            return stop
        end
        prev
    end
end

class CloningDoubleBuffered < BaseIterator
    @buffer : Array(Int32)

    def initialize
        @current = [@start] * 20
        @buffer = @current.clone
    end

    def next
        @buffer.clear
        20.times { |i| @buffer << @current.unsafe_fetch(i) }
        
        if advance.is_a? Stop
            return stop
        end

        @buffer
    end
end

class BufferedHoldingIterator < BaseIterator
    @hold = true
    @buffer : Array(Int32)


    def initialize
        @current = [@start] * 20
        @buffer = @current.clone
    end

    def next
        to_use = update
        case to_use
        when Stop
            stop
        else
            @buffer.clear
            20.times { |i| @buffer << to_use.unsafe_fetch(i) }
            @buffer
        end
    end

    def update
        if @hold
            @hold = false
            return @current
        else
            return advance
        end
    end
end

class HoldingIterator < BaseIterator
    @hold = true

    def next
        if @hold
            @hold = false
            return @current
        else
            return advance
        end
    end
end

class OptionallyBufferedHoldingIterator < BaseIterator
    @hold = true
    @buffer : Array(Int32)


    def initialize(@safe : Bool)
        @current = [@start] * 20

        if @safe
            @buffer = @current.clone
        else
            @buffer = uninitialized Array(Int32)
        end
    end

    def next
        if @safe
            to_use = update
            case to_use
            when Stop
                stop
            else
                @buffer.clear
                20.times { |i| @buffer << to_use.unsafe_fetch(i) }
                @buffer
            end
        else
            update
        end
    end

    def update
        if @hold
            @hold = false
            return @current
        else
            return advance
        end
    end
end

class ReadonlyHoldingIterator < BaseIterator
    @hold = true

    def initialize()
        @current = [@start] * 20
    end

    def next
        if @hold
            @hold = false
        else
            return stop if advance.is_a? Stop
        end

        ::Slice.new(@current.to_unsafe, @current.size, read_only: true)
    end
end

private class ReadonlyWrapper(T)
    include Indexable(T)

    getter size : Int32
    @buffer : Pointer(T)

    def initialize(@buffer, @size)
    end

    def unsafe_fetch(index : Int)
        @buffer[index]
    end
end

class ReadonlyWrapperHoldingIterator < BaseIterator
    @hold = true
    # @wrapper : ReadonlyWrapper(Int32)

    def initialize()
        @current = [@start] * 20
        # @wrapper = ReadonlyWrapper.new(@current)
    end

    def next
        if @hold
            @hold = false
        else
            return stop if advance.is_a? Stop
        end

        # @wrapper
        ReadonlyWrapper(Int32).new(@current.to_unsafe, @current.size)
    end
end

Benchmark.ips do |x|
    x.report("Unsafe Holding Iterator") do
        HoldingIterator.new.each do |value|
            value.sum
        end
    end

    x.report("Cloning Double Buffered") do
        CloningDoubleBuffered.new.each do |value|
            value.sum
        end
    end

    x.report("Buffered Holding Iterator") do
        BufferedHoldingIterator.new.each do |value|
            value.sum
        end
    end

    x.report("Cloning Iterator") do
        CloningIterator.new.each do |value|
            value.sum
        end
    end

    x.report("Optionally Buffered Holding Iterator - safe") do
        OptionallyBufferedHoldingIterator.new(true).each do |value|
            value.sum
        end
    end

    x.report("Optionally Buffered Holding Iterator - fast") do
        OptionallyBufferedHoldingIterator.new(false).each do |value|
            value.sum
        end
    end

    x.report("Readonly Holding Iterator - safe") do
        ReadonlyHoldingIterator.new.each do |value|
            value.sum
        end
    end

    x.report("ReadonlyWrapper Holding Iterator - safe") do
        ReadonlyWrapperHoldingIterator.new.each do |value|
            value.sum
        end
    end
end