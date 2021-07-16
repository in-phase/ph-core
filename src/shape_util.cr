module Phase
    module ShapeUtil
        extend self

        # checks if two shapes define the same data layout, i.e. are equal up to trailing ones.
        def compatible_shapes?(shape1, shape2)
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
    end
end