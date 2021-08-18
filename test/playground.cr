# {10, UInt8, 0, UInt8, 0, UInt8}

require "benchmark"



arr1 = Array(Int32).new(2) {|i| i+1}
arr2 = arr1.map {|el| el + 50}


def phase_zip(*indexables : Indexable, &block) 
  indexables.unsafe_fetch(0).each_index do |i|
    yield indexables.map {|arr| arr.unsafe_fetch(i)}
  end
end


# macro phase_zip_macro(*indexables, &block)
#   {% begin %}
#   {{puts indexables[0]}}
#   {{indexables[0]}}.each_index do |i|
#     puts {% for arg in indexables %} {{arg}}.unsafe_fetch(i), {% end %} "empty"
#   end
#   {% end %}
# end

# phase_zip_macro(arr1, arr2) {|a,b| puts({a,b})}


Benchmark.ips do |x|

  x.report("ignore me") do 
    ary = [] of Int32
    1000.times do |i|
      ary << i + 8
    end
  end

  x.report("direct 1") do 
    new_arr = Array.new(arr1.size) {|i|arr2.unsafe_fetch(i) % arr1.unsafe_fetch(i) }
  end


  x.report("map with index 1") do 
    new_arr = arr1.map_with_index do |a, i|
      next arr2[i] % a
    end
  end

  x.report("unsafe fetch 1") do 
    new_arr = arr1.map_with_index do |a, i|
      next arr2.unsafe_fetch(i) % a
    end
  end

  x.report("direct 2") do 
    new_arr = Array.new(arr1.size) {|i|arr2.unsafe_fetch(i) % arr1.unsafe_fetch(i) }
  end


  x.report("map with index 2") do 
    new_arr = arr1.map_with_index do |a, i|
      next arr2[i] % a
    end
  end

  x.report("unsafe fetch 2") do 
    new_arr = arr1.map_with_index do |a, i|
      next arr2.unsafe_fetch(i) % a
    end
  end

  
end

# def map(&block : T -> U) forall U
#   ary = [] of U
#   each { |e| ary << yield e }
#   ary
# end

# def self.new(size : Int, &block : Int32 -> T)
#   Array(T).build(size) do |buffer|
#     size.to_i.times do |i|
#       buffer[i] = yield i
#     end
#     size
#   end
# end

# Benchmark.ips do |x|

  # x.report("instance method zip") do 
  #   sum = 0
  #   arr1.zip(arr2).each do |a, b|
  #     sum += b % a
  #   end
  # end

  # x.report("Enumerable zip") do 
  #   sum = 0
  #   Iterator.zip_impl(arr1, arr2).each do |a, b|
  #     sum += b % a
  # #   end
  # # end

  # x.report("joint iterators") do 
  #   sum = 0
  #   iter2 = arr2.each
  #   arr1.each do |a|
  #     sum += iter2.next.as(Int32) % a
  #   end
  # end

  # x.report("each with index") do
  #   sum = 0
  #   arr1.each_with_index do |a, i|
  #     sum += arr2[i] % a
  #   end
  # end


  # x.report("each with index unsafe") do
  #   sum = 0
  #   arr1.each_with_index do |a, i|
  #     sum += arr2.unsafe_fetch(i) % a
  #   end
  # end

  # x.report("each index") do 
  #   sum = 0
  #   arr1.each_index do |i|
  #     sum += arr2.unsafe_fetch(i) % arr1.unsafe_fetch(i)
  #   end
  # end

  # x.report("my zip") do
  #   sum = 0 
  #   phase_zip(arr1, arr2) do |a,b|
  #     sum += a % b
  #   end
  # end
# end