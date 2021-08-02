module ModuleA 
  abstract def val
end

module ModuleB
end

abstract class Abstract
  @val : String
  def initialize(@val)
  end
end

class ClassA < Abstract
  include ModuleA 

  def val
    @val
  end
end

class ClassAB < Abstract 
  include ModuleA  
  include ModuleB

  def val
    @val
  end
end

class Class2 < Abstract 
  include ModuleB
end

class Lonely
  include ModuleA 

  def val
    "HI"
  end
end

class MyIterator 
  include Iterator(ModuleA)

  @obj : ModuleA

  def initialize(@obj)
  end

  def next : ModuleA | Stop
    @obj
  end
end


a = ClassA.new("a")
ab = ClassAB.new("ab")
b = Class2.new("b")

puts MyIterator.new(a).next
puts MyIterator.new(ab).next
puts MyIterator.new(Lonely.new).next