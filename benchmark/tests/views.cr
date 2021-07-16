require "../src/ph-core"

include Phase

# this breaks:

shape = [20, 20, 20, 20, 20]
large_arr = NArray.build(shape) { |coord, i| i }

region = [..] * 5

control = Time.measure do
  puts large_arr[region].map { |x| Math.sin(x) }.get(5, 5, 5, 5, 5)
end

puts "Control: #{control}"

views = Time.measure do
  puts View.of(large_arr, region, proc: Proc(Int32).new { |x| Math.sin(x) }).get(5, 5, 5, 5, 5)
end

puts "Views: #{views}"
