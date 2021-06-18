require "../src/lattice"
require "benchmark"

include Lattice 

shape = [3,3,3]

class CheckedIterator < LexIterator
    @hold = true

    def setup_coord
    end

    def next
        if @hold 
            return stop if @empty
            @hold = false
            return @coord
        end
        next_if_nonempty
    end
end

puts "Small shape (#{shape})"

Benchmark.ips do |x|
    x.report("regular iterator") do
        LexIterator.new(shape)
    end
    
    x.report("checked iterator") do
        CheckedIterator.new(shape)
    end
end

shape = [10,10,10,10,10]
puts "Large shape (#{shape})"

Benchmark.ips do |x|
    x.report("regular iterator") do
        LexIterator.new(shape)
    end
    
    x.report("checked iterator") do
        CheckedIterator.new(shape)
    end
end