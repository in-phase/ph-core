require "benchmark"
require "../src/lattice"

include Lattice
shape = [20, 20, 400]
narr = NArray.fill(shape, 1)
region = RegionUtil.canonicalize_region([1.., 1..], shape)
samples = 40

sums = [] of Int32

Benchmark.bm do |x|
  x.report("Iterating a region with a view") do
    samples.times do |idx|
      sum = 0
      narr.view.reverse.permute.each do |el|
        sum += el
      end
      sums << sum if idx == 0
    end
  end

  x.report("Iterating a region with the iterator directly") do
    samples.times do |idx|
      sum = 0
      narr.each_in_canonical_region(region: nil, order: Order::REV_COLEX).each do |el, coord|
        sum += el
      end
      sums << sum if idx == 0
    end
  end

  x.report("Doing what the iterator does without a method") do
    samples.times do |idx|
      iter = MultiIndexable::ColexRegionIterator(typeof(narr), Int32).new(narr, region, reverse: true)
      sum = 0
      iter.each do |el, _|
        sum += el
      end
      sums << sum if idx == 0
    end
  end

  puts sums
  # Iterating a region with the iterator directly
end
