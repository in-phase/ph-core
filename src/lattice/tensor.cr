require "./n_array_abstract.cr"
require "./exceptions.cr"
require "./n_array_formatter.cr"

module Lattice
  class Tensor(T) < NArray(T)
    def initialize(narr : NArray(T))
      @buffer = narr.buffer.dup
      @shape = narr.shape
    end

    def self.build(shape, &block : Array(Int32), Int32 -> T) : Tensor(T)
        puts "it's our build"
        NArray(T).build(shape) do |indices, index|
            yield indices, index
        end.to_tensor
    end
    arr = Lattice::Tensor(Int32).build([1, 2, 3]) { |multidim_index, i| i }
    puts arr
    puts arr.class

    protected def initialize(shape, &block : Int32 -> T)
        super(shape) { |index| yield index }
        puts "yay"
    end
    evil = Lattice::Tensor(Int32).new([1, 2, 3]) { |i| i }
    puts evil
    puts evil.class

    def self.new(nested_array)
        puts "it's our new"
        NArray.new(nested_array).to_tensor
    end
    two = Lattice::Tensor.new([[1], [2], [3]])
    puts two
    puts two.class

    # # Convenience initializer for making copies.
    protected def initialize(shape, @buffer : Slice(T))
        super(shape, @buffer)
        puts "huzzah"
    end
    tree = Tensor.new([3, 2, 1], evil.buffer)

    protected def check_type
        
    end
  end
end