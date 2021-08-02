
require "benchmark"

def conv(int, target_type)
  target_type.zero + int
end

def conv_checked(int, target_type)
  case int
  when target_type
    int
  else
    target_type.zero + int
  end
end

Benchmark.ips do |x|
  x.report("Basic, unconverted") do 
    sum = 0
    (0...1000).each do |i|
      sum += conv(i, Int32)
    end
  end

  x.report("checked, unconverted") do
    sum = 0  
    (0...1000).each do |i|
      sum += conv_checked(i, Int32)
    end
  end

  x.report("Basic, converted") do 
    sum = 0
    (0...1000).each do |i|
      sum += conv(i, UInt16)
    end
  end

  x.report("checked, converted") do 
    sum = 0
    (0...1000).each do |i|
      sum += conv_checked(i, UInt16)
    end
  end
end