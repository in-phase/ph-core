require "../src/ph-core"
require "benchmark"

include Phase

narr = NArray.build([10, 10, 10]) { |c, i| i }
region = [0..4, 5..8, ..]

Benchmark.ips do |x|
  x.report("regular iterator") do
  end

  x.report("narray each in canonical") do
  end
end
