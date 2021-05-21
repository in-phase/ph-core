require "spec"
require "../src/lattice"




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
