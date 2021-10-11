module Phase
  # A collection of convenience functions and optimizations targeted at multidimensional arrays stored linearly in memory
  # (in lexicographic/row major/C order).
  # This suggests the concept of a singular "index" representing each element, alongside the multidimensional coordinate.
  module BufferUtil
    # Given an array of step sizes in each coordinate axis, returns the offset in the buffer
    # that a step of that size represents.
    # The buffer index of a multidimensional coordinate, x, is equal to x dotted with axis_strides
    def self.axis_strides(shape)
      ret = shape.clone
      ret[-1] = typeof(shape[0]).zero + 1
      
      ((ret.size - 2)..0).step(-1) do |idx|
        ret[idx] = ret[idx + 1] * shape[idx + 1]
      end
      
      ret
    end
    
    # Convert from n-dimensional indexing to a buffer location.
    def coord_to_index(coord) : Int
      coord = CoordUtil.canonicalize_coord(coord, @shape)
      {{@type}}.coord_to_index_fast(coord, @shape, @axis_strides)
    end
    
    def self.coord_to_index(coord, shape) : Int
      coord = CoordUtil.canonicalize_coord(coord, shape)
      steps = axis_strides(shape)
      {{@type}}.coord_to_index_fast(coord, shape, steps)
    end
    
    # Assumes coord is canonical
    def self.coord_to_index_fast(coord, shape, axis_strides) : Int
      index = typeof(shape[0]).zero
      coord.each_with_index do |elem, idx|
        index += elem * axis_strides[idx]
      end
      index
    rescue exception
      raise IndexError.new("Cannot convert coordinate to index: the given index is out of bounds for this {{@type}} along at least one dimension.")
    end
    
    # Convert from a buffer location to an n-dimensional coord
    def index_to_coord(index) : Array
      typeof(self).index_to_coord(index, @shape)
    end
    
    # OPTIMIZE: This could (maybe) be improved with use of `axis_strides`
    def self.index_to_coord(index, shape) : Array
      if index > shape.product
        raise IndexError.new("Cannot convert index to coordinate: the given index is out of bounds for this {{@type}} along at least one dimension.")
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