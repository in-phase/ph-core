require "spec"
require "../src/ph-core"

include Phase

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
  coords = Array(Array(T)).new(initial_capacity: ShapeUtil.shape_to_size(shape))
  all_coords_lex_order(shape) do |coord|
    coords << coord
  end

  coords
end

def all_coords_lex_order(shape : Array(T), &block : Array(T) ->) forall T
  # turns [1, 2] into [[0], [0, 1]]
  axis_coords = shape.map &.times.to_a

  Indexable.each_cartesian(axis_coords) do |coord|
    yield coord
  end
end

def all_coords_colex_order(shape : Array(T)) : Array(Array(T)) forall T
  coords = Array(Array(T)).new(initial_capacity: ShapeUtil.shape_to_size(shape))
  all_coords_colex_order(shape) do |coord|
    coords << coord
  end

  coords
end

def all_coords_colex_order(shape : Array(T), &block : Array(T) ->) forall T
  # turns [1, 2] into [[0], [0, 1]]
  axis_coords = shape.map &.times.to_a
  # Reverse so that the deepest axes become the shallowest
  axis_coords.reverse!

  Indexable.each_cartesian(axis_coords) do |coord|
    yield coord.reverse!
  end
end


module TestRanges

  def self.fully_defined(bound)

    mid = bound // 2
    full = {first: 0, step: 1, last: bound - 1}

    {
    mid..mid    => {first: mid, step: 1, last: mid},

    # implicit start
    ..mid       => {first: 0, step: 1, last: mid},
    ...mid      => {first: 0, step: 1, last: mid - 1},

    # integer
    0           => {first: 0, step: 1, last: 0},
    bound - 1   => {first: bound - 1, step: 1, last: bound - 1},

    # Backward iteration
    mid..0      => {first: mid, step: -1, last: 0},
    mid..-1..   => {first: mid, step: -1, last: 0},

    # Explicit step
    # these catch both the case where the step evenly divides to the end, and not
    0..2...bound        => {first: 0, step: 2, last: bound - 1 - ((bound - 1) % 2) },
    0..2...(bound - 1)  => {first: 0, step: 2, last: bound - 2 - (bound % 2)},
    # Order should matter, associativity should not
    (5..-3)..1  => {first: 5, step: -3, last: 2},
    5..(-3..1)  => {first: 5, step: -3, last: 2},

    # Steppable::StepIterator
    (bound - 1).step(by: -1, to: 0)  =>  {first: bound - 1, step: -1, last: 0},
    0.step(by: 2, to: bound, exclusive: true)         => {first: 0, step: 2, last: bound - 1 - ((bound - 1) % 2) },
    0.step(by: 2, to: bound - 1, exclusive: true)     => {first: 0, step: 2, last: bound - 2 - (bound % 2)},
}
  end

 # these may only be used on trimmed regions
 def self.implicit_bounds(bound)
  mid = bound // 2
  full = {first: 0, step: 1, last: bound - 1}

  {
  ..          => full, 
  ...         => full,
  mid..       => {first: mid, step: 1, last: bound - 1},

  # explicit step
  ..-1..      => {first: bound - 1, step: -1, last: 0},
  ..-1...2    => {first: bound - 1, step: -1, last: 3},
  (..-4)..    => {first: bound - 1, step: -4, last: (bound - 1) % 4},
  ..(-4..)    => {first: bound - 1, step: -4, last: (bound - 1) % 4},
}
end

  # these may only be used when a bounding shape is provided
def self.negative_indices(bound) 
  mid = bound // 2
  full = {first: 0, step: 1, last: bound - 1}

  {
  -bound..    => full,
  ..-bound    => {first: 0, step: 1, last: 0},
  ..-1        => full,
  -mid..(-mid + 2) => {first: bound - mid, step: 1, last: bound - mid + 2},
  -mid        => {first: bound - mid, step: 1, last: bound - mid},
}
end

def self.out_of_bounds(bound)
 [
    ..bound,
    bound..,
    (-bound - 1)..,
    ..(-bound - 1),
    ...(bound + 1)
]
end

def self.empty
  [
    ...0,
    3...3
]
end

def self.step_conflict
  [
    4..1..2,
    2..-1..4,
    4.step(by: 1, to: 2),
    2.step(by: -1, to: 4),
    # 3.step(by: 0, to: 5), # throws ArgumentError on creation
  ]
end

def self.ndim 
  [
    # check it operates in the right dimension
    [0..2..8, 0..3],
    
    # size 0
    [3...3, 0..3],

    # size 1, no dimension dropping
    [0..0, 0..0]

]
end

def self.ndim_dropped 
  [
    # try dropping first dimension
    [0, 0..2..8],

    # size 0 with dimension dropping
    [3...3, 1] ,
    
    # size 1, partial dimension dropping
    [0..0, 1]  ,

    # size 1, full dimension dropping 
    [1, 1],

    # multiple dimensions dropped
    [0..1, 4, 3, 1..1]
  ]
end

end




