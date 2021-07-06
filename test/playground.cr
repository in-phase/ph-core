# module GeneralCI(T)

#     def mutate 
#         @first = @first * 2
#         self
#     end

# end

# module CI(T)
#     include GeneralCI(T)

#     def initialize(@first : Array(T))
#         # @first = first
#     end
# end

# class LI(T)
#     include CI(T)
# end

# puts LI(Int32).new([1, 2])

# module ICI(T)
#     include GeneralCI(T)

#     def initialize(@first : Array(T), @shape : Array(Int32))
#     end
# end

# class LICI(T)
#     include ICI(T)
# end

# puts LICI.new(['a', 'b'], [1, 2]).mutate



require "../src/lattice"
include Lattice 

narr = NArray.build([4,4,4]) {|c, i| i}
region = [.., ..2..]

# narr[region] = 5

puts narr.view[region]