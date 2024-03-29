require "./spec_helper.cr"

include Phase

# Provides barebones versions of NArray used to test MultiEnumerable, MultiIndexable, and MultiWritable methods,
# and provide a minimum standard for implementing a usable multidimensional array type.

# Defines instance variables, constructors, and general utils for a buffer-backed multi-array.
abstract class TestNArray(T)
  # include MultiIndexable(T)

  getter buffer : Slice(T)
  getter size : Int32
  @shape : Array(Int32)
  @axis_strides : Array(Int32)

  def initialize(shape, @buffer : Slice(T))
    @size = ShapeUtil.shape_to_size(shape).to_i32
    if @size != @buffer.size
      raise ArgumentError.new("Cannot create TestNArray: Given shape does not match number of elements in buffer.")
    end

    @shape = shape.dup
    @axis_strides = TestNArray.axis_strides(@shape)
  end

  def shape_internal : Array(Int32)
    @shape
  end

  protected def self.unsafe_coord_to_index_fast(coord, axis_strides) : Int32
    begin
      index = 0
      coord.each_with_index do |elem, idx|
        index += elem * axis_strides[idx]
      end
      index
    rescue exception
      raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this TestNArray along at least one dimension.")
    end
  end

  protected def unsafe_coord_to_index(coord) : Int32
    TestNArray.unsafe_coord_to_index_fast(coord, @axis_strides)
  end

  def self.axis_strides(shape)
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

  def unsafe_fetch_element(coord) : T
    @buffer[unsafe_coord_to_index(coord)]
  end
end

# implementation of required MultiWritable methods
module WriteUtils(T)
  include MultiWritable(T)

  def unsafe_set_element(coord : Enumerable, value : T)
    @buffer[unsafe_coord_to_index(coord)] = value
  end
end

# this used to superclass RONArray to fix a wierd bug
# class ReadableTestNArray(T) < TestNArray(T)
#   include ReadUtils(T)
# end

# Read only NArray
class RONArray(T) < TestNArray(T)
  include ReadUtils(T)

  def build(shape, &block)
    coords = LexIterator.cover(shape)
    count = ShapeUtil.shape_to_size(shape)
    buffer = Slice.new(count) do
      yield coords.unsafe_next
    end
    RONArray.new(shape, buffer)
  end
end

# Write only NArray
class WONArray(T) < TestNArray(T)
  include WriteUtils(T)
  include ReadUtils(T)
end

# Read-Write NArray
class RWNArray(T) < TestNArray(T)
  include ReadUtils(T)
  include WriteUtils(T)
end
