require "./spec_helper.cr"

include Phase

# Provides barebones versions of NArray used to test MultiEnumerable, MultiIndexable, and MultiWritable methods,
# and provide a minimum standard for implementing a usable multidimensional array type.

# Defines instance variables, constructors, and general utils for a buffer-backed multi-array.
abstract class TestNArray(T)
  getter buffer : Slice(T)
  @shape : Array(Int32)

  def initialize(shape, @buffer : Slice(T))
    @shape = shape.dup
  end
end

# Read only NArray
class RONArray(T) < TestNArray(T)
  include MultiIndexable(T)

  def shape : Array(Int32)
    @shape.dup
  end

  def unsafe_fetch_element(coord) : T
    12
  end
end