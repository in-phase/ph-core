class View(T)
  def initialize(@src : T)
  end

  def process(process)
    View(PView(T)).new(PView.new(process, @src))
  end

  def reshape(shape)
    RView(T).new(process, @src)
  end
end

class PView(T)
  def initialize(@process : String, @src : T)
  end

  def process(process)
    PView(T).new(@process + process, @src)
  end
  
  def reshape(shape)
    # don't want the multiindexable behaviour
    @src.reshape(shape)
    #RView(PView(T)).new(shape, self)
  end
end

class RView(T)
  def initialize(@shape : String, @src : T)
  end

  def reshape(shape)
    RView(T).new(@shape + shape, @src)
  end

  def process(process)
    PView(RView(T)).new(process, self)
  end
end

pp View.new(1).process("a").process("b") #.reshape("b").process("c")


coord_to_index, index_to_coord


View(B,T)
  => coord_transforms: [] of Proc(Array(Int32), Array(Int32))

ProcView(B,T,R)
  @view : View(B,T)
  => elem_transforms @proc : Proc(T,R)
  
  forward_missing_to @view

PView(View(PView(View(PView))))
