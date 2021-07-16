module Phase
  class DimensionError < Exception
    def self.initialize(message = "Wrong number of dimensions for this operation.")
      super
    end
  end

  class ShapeError < IndexError
    def self.initialize(message = "Shape was invalid for this operation.")
      super
    end
  end
end
