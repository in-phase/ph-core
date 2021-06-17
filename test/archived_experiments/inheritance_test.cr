module MultiIndexable(T)
end

module MultiWritable(T)
  def []=(index, value : T)
    puts index, value
    unsafe_set_chunk(value)
  end

  abstract def unsafe_set_chunk(value : T)
end

class NArray(T)
  include MultiIndexable(T)
  include MultiWritable(T)

  @data : Array(T) = [] of T

  def view
    View(NArray(T), T).new(self)
  end

  def unsafe_set_chunk(value)
    @data << value
  end

  def first
    @data[0]
  end
end

class RArray(T)
  include MultiIndexable(T)

  @data : Array(T) = [] of T

  def view
    View(RArray(T), T).new(self)
  end

  def first
    @data[0]
  end
end

module ViewObj(B, T, R)
  include MultiIndexable(T)

  @src : B
end

class View(B, T)
  include ViewObj(B, T, T)
  include MultiIndexable(T)
  include MultiWritable(T)

  # macro: include MultiWritable and all associated methods

  macro ensure_writable
        {% unless B < MultiWritable %}
            {% raise "Could not write to #{@type}: #{B} is not a MultiWritable." %}
        {% end %}
    end

  def self.of(src : B)
    View(B, typeof(src.first)).new(src)
  end

  def unsafe_set_chunk(value : T)
    ensure_writable
    @src.unsafe_set_chunk(value)
  end

  def self.new(src : B)
    mytype = typeof(src.first)
    puts mytype
    View(B, typeof(src.first)).new(src, 1)
  end

  def initialize(@src : B, dummy_var)
    {% puts B.type_vars %}
  end

  def process(input : R) forall R
    ProcessedView(B, T, R).new(@src)
  end

  # View(Int32) (MultiIndexable(Int32))
  # View(Int32) (NArray(Int32))
end

class ProcessedView(B, T, R)
  include ViewObj(B, T, R)
  include MultiIndexable(R)

  # def unsafe_set_chunk(value)
  #     puts "Why am I here"
  # end

  def initialize(@src : MultiIndexable(T))
  end
end

narr = NArray(Int32).new
myview = View.of(narr)

print narr
view = narr.view
view[5] = 10

view.process(5)

rarr = RArray(Int32).new
rview = rarr.view

# rview[5] = 10
