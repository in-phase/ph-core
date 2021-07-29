require "spec"
require "../src/ph-core"

# An arbitrary class
class TestObject
end

class MutableObject
  property value : String

  def initialize(@value)
  end

  def clone : MutableObject
    copy = MutableObject.new
    copy.set(@value)
    copy
  end
end

def all_coords_lex_order(shape : Array(T)) : Array(Array(T)) forall T
  coords = Array(Array(T)).new(initial_capacity: shape.product)
  all_coords_lex_order(shape) do |coord|
    coords << coord
  end

  coords
end

def all_coords_lex_order(shape : Array(T), &block : Array(T) ->) forall T
  # turns [1, 2] into [[0], [0, 1]]
  axis_coords = shape.map &.times.to_a

  Array.each_product(axis_coords) do |coord|
    yield coord
  end
end