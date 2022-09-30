module Phase
  # A collection of convenience functions and optimizations targeted at multidimensional arrays stored linearly in memory
  # (in lexicographic/row major/C order).
  # This suggests the concept of a singular "index" representing each element, alongside the multidimensional coordinate.
  # TODO: This should probably be parameterized by the buffer index type
  module Buffered(T)
    include MultiIndexable(T)

    # Returns the lexicographic buffer that stores the elements of this `MultiIndexable`.
    abstract def buffer : Indexable

    # Given an array of step sizes in each coordinate axis, returns the offset
    # in the buffer that a step of that size represents. The buffer index of a
    # multidimensional coordinate, x, is equal to x dotted with axis_strides
    def self.axis_strides(shape)
      ret = shape.clone
      ret[-1] = typeof(shape[0]).zero + 1
      
      ((ret.size - 2)..0).step(-1) do |idx|
        ret[idx] = ret[idx + 1] * shape[idx + 1]
      end
      
      ret
    end
    
    # Converts an n-dimensional relative coordinate (e.g. negative indexing
    # allowed) into a lexicographic buffer index.
    def coord_to_index(coord) : Int
      coord = CoordUtil.canonicalize_coord(coord, shape_internal)
      {{@type}}.coord_to_index_fast(coord, shape_internal, @axis_strides)
    end
    
    # Converts an n-dimensional relative coordinate (e.g. negative indexing
    # allowed) into a lexicographic buffer index.
    def self.coord_to_index(coord, shape) : Int
      coord = CoordUtil.canonicalize_coord(coord, shape)
      steps = axis_strides(shape)
      {{@type}}.coord_to_index_fast(coord, shape, steps)
    end
    
    # Converts an n-dimensional canonicalized coordinate (all ordinates
    # must be in bounds and nonnegative) into a lexicographic buffer index.
    # This allows a slight performance increase at the expense of safety.
    def self.coord_to_index_fast(coord, shape, axis_strides) : Int
      index = typeof(shape[0]).zero
      coord.each_with_index do |elem, idx|
        index += elem * axis_strides[idx]
      end
      index
    rescue exception
      raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds along at least one dimension.")
    end
    
    # Convert from a buffer location to an n-dimensional coord
    # Converts a lexicographic buffer index into its corresponding coordinate
    # in this `MultiIndexable`. The coordinate will be produced in canonical 
    # form (nonnegative indexes).
    def index_to_coord(index) : Array
      typeof(self).index_to_coord(index, shape_internal)
    end
    
    # TODO: OPTIMIZE: This could (maybe) be improved with use of `axis_strides`
    # Convert from a buffer location to an n-dimensional coord
    # Converts a lexicographic buffer index into its corresponding coordinate
    # in this `MultiIndexable`. The coordinate will be produced in canonical 
    # form (nonnegative indexes).
    def self.index_to_coord(index, shape) : Array
      if index > shape.product
        raise IndexError.new("Cannot convert index to coordinate: the given index is out of bounds along at least one dimension.")
      end
      coord = shape.dup # <- untested; was: Array(Int32).new(shape.size, typeof(shape[0]).zero)
      shape.reverse.each_with_index do |length, dim|
        coord[dim] = index % length
        index //= length
      end
      coord.reverse
    end
  end
end
