module Phase
  module ShapeUtil
    extend self

    # checks if two shapes define the same data layout, i.e. are equal up to trailing ones.
    def compatible_shapes?(shape1, shape2)
      # If either shape is the empty array (no information), then we must
      # ensure that they are both empty , because [] and [1] cannot be compatible.
      if shape1.size == 0 || shape2.size == 0
        return shape1 == shape2
      end

      if shape1.size > shape2.size
        larger = shape1
        shared_dims = shape2.size
      else
        larger = shape2
        shared_dims = shape1.size
      end

      # Check that sizes match along shared dimensions
      shared_dims.times do |i|
        return false if shape1[i] != shape2[i]
      end

      # Check that any extra dimensions are 1
      (shared_dims...larger.size).step(1) do |i|
        return false if larger[i] != 1
      end

      true
    end

    # Returns the number of elements that exist in a `MultiIndexable` of a given *shape*.
    # See `MultiIndexable#size`.
    # ```crystal
    # shape_to_size([] of Int32) # => 0
    # shape_to_size([1]) # => 1
    # shape_to_size([2, 3]) # => 6
    # ```
    def shape_to_size(shape : Shape(T)) : T forall T
      {% if T.union? %}
        {% raise "Phase requires shape axes to be of homogeneous type, but #{T} is a union." %}
      {% end %}
      if shape.size == 0
        T.zero
      else
        shape.product
      end
    end
  end
end
