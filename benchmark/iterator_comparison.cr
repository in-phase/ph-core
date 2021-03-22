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

puts "Control 1 (fastest each): #{control1}"

control2 = Time.measure do
    count = 0
    large_arr.each_with_coord do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"

end

puts "Control 1 (each with coord): #{control2}"


# Version 1: MultiIndexable::LexRegionIterator
class LexRegionIterator(A, T) < MultiIndexable::RegionIterator(A, T)
    def setup_coord(coord, step)
      coord[-1] -= step[-1]
    end

    def next
      (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
        if @step[i] > 0 ? (@coord[i] > @last[i]) : (@coord[i] < @last[i])
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

puts "MultiIndexable version: #{multi}"



# Version 2: NArray::BufferedLexRegionIterator

buffered = Time.measure do
    count = 0
    NArray::BufferedLexRegionIterator(typeof(large_arr), Int32).new(large_arr).each do |e, coord|
        count += 1 if e % 3 == 0
    end
    puts "result: #{count}"
end

puts "Buffered version: #{buffered}"


puts "\nIterating a region:"

region = RegionHelpers.canonicalize_region([3..15, 15..3, 5..10, 5..10], shape)
#region = RegionHelpers.canonicalize_region([..,..,..,..], shape)
region[2] = RegionHelpers::SteppedRange.new(15..3, -3)
region[3] = RegionHelpers::SteppedRange.new(5..10, 2)


control = Time.measure do
    idx = 0
    large_arr.narray_each_in_canonical_region(region) do |e|
        puts "#{idx}, #{e}, #{large_arr.index_to_coord(e)}" if idx % 10000 == 0
        idx += 1
    end
end

puts "Control (NArray's each in canonical region): #{control}"

multi = Time.measure do
    idx = 0
    LexRegionIterator(typeof(large_arr), Int32).new(large_arr, region: region).each do |e, coord|
        puts "#{idx}, #{e}, #{coord}" if idx % 10000 == 0
        idx += 1
    end
end

puts "MultiIndexable version: #{multi}"

buffered = Time.measure do
    idx = 0
    NArray::BufferedLexRegionIterator(typeof(large_arr), Int32).new(large_arr, region: region).each do |e, coord|
        puts "#{idx}, #{e}, #{coord}" if idx % 10000 == 0
        idx += 1
    end
end

puts "Buffered version: #{buffered}"
