# class Parent(T)
#   def self.build(shape, &block)
#     {{@type}}.new(shape) do |el|
#       yield el
#     end
#   end

#   protected def initialize(shape, &block)
#     yield 5
#   end

#   def self.new(nested)
#     self.new(5)
#   end
# end

# class Child(T) < Parent(T)
# end

# Child(Int32).build(:shape) do |el|
#   puts el
# end

class NArray
  def get(array : Enumerable)
    puts "enumerable version"
  end

  def [](*args)
    puts "tuple version"
  end
end

class Matrix < NArray
  def [](x, y)
    puts "dyad version"
  end

  def [](*args : *U) forall U
    {% if U.size > 2 %}
      {% raise "jenkies" %}
    {% end %}
  end

  def get(array)
    raise("bad") if array.size > 2
  end
end

matrix = Matrix.new
matrix[1, 2] # this should work
# matrix.get [1, 2, 3] # this should runtime error
# matrix[1, 2, 3] # this should give a compile error



# Notes for Matrix:
# extend NArray
# basic compiler errors on construction, getters if dimensions > 2
# Matrix.new([1,2,3]) => Matrix(@shape=[1,3]) # infer second dimension if necessary
# convenience methods using 2d language get_row, get_column, rows
# go through NArray and see if things don't make sense for 2d
# optimizers (esp re. things with buffer strides)


narr[0] , narr[1]

[[[[[[[
              [[ 0,  1, ...,  2,  3],
                  ⋮ (2 of 1002 shown)
               [ 2,  3]],
               
              [[ 4,  5],
                  ⋮ (2 of 1002 shown)
               [ 6,  7]]
            ],
              ⋮ (4 of 50 shown)
            [
              [[ 8,  9],
               [10, 11]],
          
              [[12, 13],
               [14, 15]]
            ]
]]]]]]]

[[
    [[ 0,  1, ...,  2,  3],
        ⋮ (2 of 1002 shown)
     [ 2,  3]],
     
    [[ 4,  5],
        ⋮ (2 of 1002 shown)
     [ 6,  7]]
  ],
    ⋮ (4 of 50 shown)
  [
    [[ 8,  9],
     [10, 11]],

    [[12, 13],
     [14, 15]]
]]