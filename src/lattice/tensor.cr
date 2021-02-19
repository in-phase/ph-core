require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"

module Lattice
  class Tensor(T) < NArray(T)
    def self.from_narr(narr : NArray(T))
      Tensor(T).new(narr.shape, narr.buffer.dup)
    end










    
    # def initialize(shape, @buffer : Slice(T))
    #   @shape = shape.dup
    # end

    # protected def initialize(shape, &block : Int32 -> T)
    #   @shape = shape.map do |dim|
    #     if dim < 1
    #       raise DimensionError.new("Cannot create {{@type}}: One or more of the provided dimensions was less than one.")
    #     end
    #     dim
    #   end

    #   num_elements = shape.product.to_i32
    #   @buffer = Slice(T).new(num_elements) { |i| yield i }
    # end


    # def self.build(shape, &block : Array(Int32), Int32 -> T) : Tensor(T)
    #     puts "it's our build"
    #     NArray(T).build(shape) do |indices, index|
    #         yield indices, index
    #     end.to_tensor
    # end
    narr = Lattice::NArray.build([1, 2, 3]) { |multidim_index, i| i.to_i32 }

    # puts narr

    # arr = Tensor.new(narr)
     #arr = Lattice::Tensor(Bool).build([3, 3]) { |coord| coord[0] != coord[1] }

     # TODO make this work without type parameter explicit?
    arr = Lattice::Tensor(Int32).build([1, 2, 3]) { |multidim_index, i| i }
    puts arr
    puts arr.class

    puts arr[..,1]

    puts arr.clone




    


  

    # protected def initialize(shape, &block : Int32 -> T)
    #     super(shape) { |index| yield index }
    #     puts "yay"
    # end
    # evil = Lattice::Tensor(Int32).new([1, 2, 3]) { |i| i }
    # puts evil
    # puts evil.class

    # def self.new(nested_array)
    #     puts "it's our new"
    #     NArray.new(nested_array).to_tensor
    # end
    # # two = Lattice::Tensor.new([[1], [2], [3]])
    # # puts two
    # # puts two.class

    # # # Convenience initializer for making copies.
    # protected def initialize(shape, @buffer : Slice(T))
    #     super(shape, @buffer)
    #     puts "huzzah"
    # end
    # # tree = Tensor.new([3, 2, 1], evil.buffer)

    # protected def check_type
        
    # end
  end
end