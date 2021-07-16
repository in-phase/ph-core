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
