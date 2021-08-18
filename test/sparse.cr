require "../src/ph-core"
require "benchmark"

module Phase
  class SparseArray(T)
    include MultiIndexable(T)
    include MultiWritable(T)

    @shape : Array(Int32)
    @default : T
    @values : Hash(Array(Int32), T)

    def self.fill(shape, default : T) forall T
      new(shape, default, Hash(Array(Int32), T).new(default))
    end

    def self.new(shape, default)
      fill(shape, default)
    end

    def initialize(@shape, @default : T, @values)
    end

    def shape : Array
      @shape.dup
    end

    def unsafe_fetch_element(coord : Coord) : T
      @values[coord]
    end

    def unsafe_set_element(coord : Coord, value)
      if value == @default
        @values.reject!(coord)
      else
        @values[coord] = value
      end
    end

    def unsafe_fetch_chunk(region : IndexRegion) : self
      # assumes that the default for self is also the default of the region
      new_hash = Hash(Array(Int32), T).new(@default)
      # region.each {}
      @values.each_key do |key|
        if region.includes?(key)
          new_hash[region.absolute_to_local_unsafe(key)] = @values[key]
        end
      end
      SparseArray.new(region.shape, @default, new_hash)
    end

    def fast
      NTimesIterator.new(@default, size - @values.size)
    end

    def fast2
      @values.each_value
    end
  end

  class NTimesIterator(T)
    include Iterator(T)

    @times : Int32
    @value : T

    def initialize(@value : T, @times)
      @count = 0
    end

    def next
      @count += 1
      if @count <= @times
        @value
      else
        stop
      end
    end
  end

  # sp = SparseArray.new([10,10,10], 5)
  # sp[0,1,0] = 8
  # iter = NArray::BufferUtil::IndexedLexIterator.cover(sp.shape)
  # iter.each do |coord|
  #     next if Random.rand > 0
  #     sp[coord] = iter.current_index
  # end

  sp = NArray.fill([10, 10, 10], 5)

  # puts sp
  # region = IndexRegion.new([.., 1], sp.shape)
  # puts sp[region]

  Benchmark.ips do |x|
    sum = 0
    # x.report("fast") do
    #     sp.fast.each do |value|
    #         sum = (sum + value) % 50
    #     end

    #     sp.fast2.each do |value|
    #         sum = (sum + value) % 50
    #     end
    # end

    sum = 0
    x.report("not fast") do
      sp.each do |value|
        sum = (sum + value) % 50
      end
    end

    sum = 0
    x.report("with coord") do
      sp.each_with_coord do |val, coord|
        sum = (sum + val) % 50
      end
    end

    # sum = 0
    # size = sp.size
    # x.report(".times") do
    #     size.times do
    #         sum = (sum + 5) % 50
    #     end
    # end

    # sum = 0
    # x.report("vanilla iterator, created dynamically") do
    #     NTimesIterator.new(5, size).each do |val|
    #         sum = (sum + val) % 50
    #     end
    # end
  end
end

#                                  fast  46.71k ( 21.41µs) (± 2.67%)   644B/op   6.52× slower
#                              not fast  61.33k ( 16.31µs) (± 2.83%)   585B/op   4.97× slower
#                            with coord  60.30k ( 16.58µs) (± 1.78%)   547B/op   5.05× slower
#                                .times 304.55k (  3.28µs) (± 0.89%)   0.0B/op        fastest
# vanilla iterator, created dynamically 159.13k (  6.28µs) (± 1.07%)  32.0B/op   1.91× slower

#  not fast 160.64k (  6.23µs) (± 1.37%)  48.0B/op        fastest
# with coord  91.05k ( 10.98µs) (± 3.63%)   615B/op   1.76× slower
