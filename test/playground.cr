



# def compare(type, size)

#     # crystal built-in method to allocate and initialize to 0
#     Slice(type).new(size)

    

#     pointer = Pointer(T).malloc(size)

# end




# def zeros(size) 
    
# end

# @[Link("libc")]
# lib LibC
#     fun 
# end

# puts malloc(5)

# require "benchmark"



# Benchmark.ips do |x|
#     x.report("Slice constructor (with zero)") do
#         Slice.new(1_000_000, 0)
#     end

#     x.report("Slice constructor (no passed value)") do
#         Slice(Int32).new(1_000_000)
#     end


# class Test(T)
#     @var : Int

#     def initialize(@var : Int)
#     end
# end

# def test(a : Int) : Int
# #     a
# # end

# # pp Test(Int32).new(1)
# # pp test(2)

# # require "../src/lattice"

# # include Lattice

# # narr = NArray.build([5, 3]) {|c,i| i}
# # puts narr[2..3]

# require "benchmark"

# def test(region : Enumerable, last)
#     return last
# end

# def use_macro(*args : *U) forall U
#     {% begin %}
#         test([{% for i in 0...(U.size - 1) %}args[{{i}}] {% if i < U.size - 2 %}, {% end %}{% end %}], args.last)
#     {% end %}
# end

# def use_runtime(*args)
#     test(args[...-1].to_a, args.last)
# end

# Benchmark.ips do |x|
#     x.report("using macro") do
#         use_macro(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
#     end

#     x.report("using runtime") do
#         use_runtime(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
#     end
# end