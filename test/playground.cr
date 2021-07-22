require "../src/ph-core"

include Phase 

# image = NArray.build(3, 3) { |c| c.sum }
# puts image

# image[1.., ..1] *= 10
# puts image

# puts image[1.., ..1]



# class Foo(T, U)
#     def initialize(@var : Enumerable(T), @var2 : Enumerable(U))
#         {@var, @var2}.map &.each
#     end
# end

# # This works fine when T and U are the same type
# puts Foo.new([1], [1])
# # but causes a crash when they are not
# puts Foo.new([1], [1.0])

# def foo
#   x = uninitialized Enumerable(Int32)
#   y = uninitialized Enumerable(Float64)
#   yield x
#   yield y
# end

# class Foo(T)
#     @enum : Enumerable(T)
    
#     def whatever
#         @enum.each
#     end
# end

# foo { |v| }