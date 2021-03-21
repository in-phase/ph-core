require "./spec_helper.cr"

include Lattice

# Provides barebones versions of NArray used to test MultiEnumerable, MultiIndexable, and MultiWritable methods,
# and provide a minimum standard for implementing a usable multidimensional array type.

# Defines instance variables, constructors, and general utils for a buffer-backed multi-array.
abstract class TestNArray(T)

    getter buffer : Slice(T)
    getter size : Int32
    @shape : Array(Int32)
    @buffer_step_sizes : Array(Int32)

    def initialize(shape, @buffer : Slice(T))
        @size = shape.product.to_i32
        if @size != @buffer.size
          raise ArgumentError.new("Cannot create {{@type}}: Given shape does not match number of elements in buffer.")
        end
  
        @shape = shape.dup
        @buffer_step_sizes = {{@type}}.buffer_step_sizes(@shape)
    end

    def shape : Array(Int32)
        @shape.dup
    end

    protected def self.unsafe_coord_to_index_fast(coord, buffer_step_sizes) : Int32
        begin
          index = 0
          coord.each_with_index do |elem, idx|
            index += elem * buffer_step_sizes[idx]
          end
          index
        rescue exception
          raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this {{@type}} along at least one dimension.")
        end
    end

    protected def unsafe_coord_to_index(coord) : Int32
        TestNArray.unsafe_coord_to_index_fast(coord, @buffer_step_sizes)
    end

    def self.buffer_step_sizes(shape)
      ret = shape.clone
      ret[-1] = 1

      ((ret.size - 2)..0).step(-1) do |idx|
        ret[idx] = ret[idx + 1] * shape[idx + 1]
      end

      ret
    end
end

# implementation of required MultiIndexable methods
module ReadUtils(T)
    include MultiIndexable(T)

    def unsafe_fetch_region(region)

        shape = RegionHelpers.measure_canonical_region(region)
        iter = each_in_canonical_region(region)
  
        buffer = Slice(T).new(shape.product) do |idx|
            iter.next.as(Tuple(T, Array(Int32)))[0]
        end
       
        {{@type}}.new(shape, buffer)
    end
  
    def unsafe_fetch_element(coord) : T
        @buffer.unsafe_fetch(unsafe_coord_to_index(coord))
    end
end

# implementation of required MultiWritable methods
module WriteUtils(T)
    include MultiWritable(T)

    def unsafe_set_region(region : Enumerable, src : MultiIndexable(T))
        each_in_canonical_region(region) do |elem, coord|
            @buffer[unsafe_coord_to_index(coord)] = src.unsafe_fetch_element(coord)
        end
    end

    def unsafe_set_region(region : Enumerable, value : T)
        each_in_canonical_region(region) do |elem, coord|
            @buffer[unsafe_coord_to_index(coord)] = value
        end
    end

    def unsafe_set_element(coord : Enumerable, value : T)
        @buffer[unsafe_coord_to_index(coord)] = value
    end
end



# Read only NArray
class RONArray(T) < TestNArray(T)
    include ReadUtils(T)
end

# Write only NArray
class WONArray(T) < TestNArray(T)
    include WriteUtils(T)
end

# Read-Write NArray
class RWNArray(T) < TestNArray(T)
    include ReadUtils(T)
    include WriteUtils(T)
end
