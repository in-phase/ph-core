require "complex"

# this patch makes it possible to operate elementwise on a Number and an NArray (in that order)
# e.g.
# ``` 5 + NArray.new([1,2,3]) #=> [6,7,8] ```
abstract struct Complex
  {% begin %}
      {% for name in %w(+ - * / // > < >= <= &+ &- &- ** &** % & | ^) %}
        # Invokes `#{{name.id}}` element-wise between `self` and *other*, returning
        # an `NArray` that contains the results.
        def {{name.id}}(other : MultiIndexable(U)) forall U
          other.map do |elem|
            self.{{name.id}} elem
          end
        end
      {% end %} 
    {% end %}

  def eq(other : MultiIndexable(U)) : MultiIndexable(Bool) forall U
    other.map do |elem|
      self == elem
    end
  end
end
