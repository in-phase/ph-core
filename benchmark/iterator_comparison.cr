require "../src/lattice.cr"

include Lattice

shape = [20, 20, 20, 20, 20]

large_arr = NArray.build(shape) {|coord, i| i}

module Lattice
    class NArray(T)
        #Control: a regular "each" over the buffer indices
        def each_with_coord(&block : T, Array(Int32), Int32 ->)
            puts "Version A called"
            each_with_index do |elem, idx|
            yield elem, index_to_coord(idx), idx
            end
        end

        def each(&block : T ->)
            puts "Version B called"
            each_with_index do |elem|
            yield elem
            end
        end
    end
end


puts "\n Iterating full array:"
control1 = Time.measure do
    count = 0
    large_arr.each do |e|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"

end


control2 = Time.measure do
    count = 0
    large_arr.each_with_coord do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"

end



# Version 1: MultiIndexable::LexRegionIterator
class LexRegionIterator(A, T) < MultiIndexable::RegionIterator(A, T)
    def setup_coord(coord, step)
      coord[-1] -= step[-1]
    end

    def next
      (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
        if @step[i] > 0 ? (@coord[i] > @last[i] - @step[i]) : (@coord[i] < @last[i] - @step[i])
            @coord[i] = @first[i]
          return stop if i == 0 # most sig
        else
          @coord[i] += @step[i]
          break
        end
      end
      {@narr.unsafe_fetch_element(@coord), @coord}
    end
end

multi = Time.measure do
    count = 0
    LexRegionIterator(typeof(large_arr), Int32).new(large_arr).each do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"
end




# Version 2: NArray::BufferedLexRegionIterator

buffered = Time.measure do
    count = 0
    NArray::BufferedLexRegionIterator(typeof(large_arr), Int32).new(large_arr).each do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"
end


buffered_colex = Time.measure do
    count = 0
    NArray::BufferedColexRegionIterator(typeof(large_arr), Int32).new(large_arr).each do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"
end

buffered_revlex =  Time.measure do
    count = 0
    NArray::BufferedLexRegionIterator(typeof(large_arr), Int32).new(large_arr, reverse: true).each do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"
end

buffered_revcolex =  Time.measure do
    count = 0
    NArray::BufferedColexRegionIterator(typeof(large_arr), Int32).new(large_arr, reverse: true).each do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"
end


puts   "\nControl 1 (fastest each):       #{control1}"
puts   "Control 2 (each with coord):    #{control2}"
puts   "MultiIndexable version:         #{multi}"
puts   "Buffered version:               #{buffered}"
puts   "New orders in buffered:         #{buffered_colex}, 
                                #{buffered_revlex}, 
                                #{buffered_revcolex}"

puts "\nIterating a region:\n\n"

region = RegionHelpers.canonicalize_region([3..15, 15..-3..3, 5..2..10, 5..10], shape)


puts "Each in canonical region"

samples = [] of Int32
sampling_rate = 100000

idx = 0
large_arr.narray_each_in_canonical_region(region) do |e|
    if idx % sampling_rate == 0 
        samples << e
    end
    idx += 1
end

control = Time.measure do
    idx = 0
    large_arr.narray_each_in_canonical_region(region) do |e|
        puts "#{idx}, #{e}, #{large_arr.index_to_coord(e)}" if samples.any?(e)
        idx += 1
    end
end
puts "MultiIndexable Lex"

multi = Time.measure do
    idx = 0
    LexRegionIterator(typeof(large_arr), Int32).new(large_arr, region: region).each do |e, coord|
        puts "#{idx}, #{e}, #{coord}" if samples.any?(e)
        idx += 1
    end
end

puts "Buffered Lex"


buffered = Time.measure do
    idx = 0
    NArray::BufferedLexRegionIterator(typeof(large_arr), Int32).new(large_arr, region: region).each do |e, coord|
        puts "#{idx}, #{e}, #{coord}" if samples.any?(e)
        idx += 1
    end
end

puts "Buffered Colex"



buffered_colex = Time.measure do
    idx = 0
    NArray::BufferedColexRegionIterator(typeof(large_arr), Int32).new(large_arr, region: region).each do |e, coord|
        puts "#{idx}, #{e}, #{coord}" if samples.any?(e)
        idx += 1
    end
end
puts "Buffered RevLex"

# TODO: interesting! If we have a range (5..10).step(2) => 5, 7, 9
# and call reverse: then it becomes     (10..5).step(2) => 10, 8, 6 (an entirely different set of values!)
buffered_revlex = Time.measure do
    idx = 0
    NArray::BufferedLexRegionIterator(typeof(large_arr), Int32).new(large_arr, region: region, reverse: true).each do |e, coord|
        puts "#{idx}, #{e}, #{coord}" if samples.any?(e)
        idx += 1
    end
end
puts "\n"

puts   "Control (NArray's each in canonical region):    #{control}"
puts   "MultiIndexable version:                         #{multi}"
puts   "Buffered version:                               #{buffered}"
puts   "New orders in buffered:                         #{buffered_colex}, 
                                                #{buffered_revlex}"