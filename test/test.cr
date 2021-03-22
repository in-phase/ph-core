class Parent(T)
  def self.build(shape, &block)
    {{@type}}.new(shape) do |el|
      yield el
    end
  end

  protected def initialize(shape, &block)
    yield 5
  end

  def self.new(nested)
    self.new(5)
  end
end

class Child(T) < Parent(T)
end

Child(Int32).build(:shape) do |el|
  puts el
end
