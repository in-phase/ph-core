require "../src/ph-core.cr"

module Phase
  class NArray(T)
    def apply : ElemSet
      ElemSet.new(self)
    end

    def apply! : InPlaceElemSet
      InPlaceElemSet.new(self)
    end

    def ap
      apply
    end

    def ap!
      apply!
    end
  end

  # This one should not be in MultiIndexable (since by default it doesn't accept setters)
  class InPlaceElemSet(T)
    @src : MultiIndexable(T)

    def initialize(@src : MultiIndexable(T))
    end

    # method missing here
  end

  class ElemSet(T)
    @src : MultiIndexable(T)

    def initialize(@src : MultiIndexable(T))
    end

    # If a method signature not defined on {{@type}} is called, then `method_missing` will attempt
    # to apply the method to every element contained in the {{@type}}. Any argument to the method call
    # that is also an {{@type}} will be applied element-wise.
    # For example:
    # ```arr = {{@type}}(Int32).new([2,2,2]) { |i| i }
    # arr > 4```
    # will give: [[[false, false], [false, false]], [[false, true], [true true]]]
    # WARNING: fully exhaustive testing is not possible for this method; use at your own risk.
    # If a method is defined on both {{@type}} and the type parameter T, precedence will be
    # given to {{@type}}. Complex overloading may cause problems.
    macro method_missing(call)
            def {{call.name.id}}(*args : *U) forall U
                \{% if !@type.type_vars[0].has_method?({{call.name.id.stringify}}) %}
                \{% raise( <<-ERROR
                            undefined method '{{call.name.id}}' for #{@type.type_vars[0]}.
                            This error is a result of Phase attempting to apply `{{call.name.id}}`,
                            an unknown method, to each element of an `{{@type}}`. (See the documentation
                            of `{{@type}}#method_missing` for more info). For the source of the error, 
                            use `--error-trace`.
                            ERROR
                            ) %}
                \{% end %}


                \{% for i in 0...(U.size) %}
                \{% if U[i] < MultiIndexable %}
                    if args[\{{i}}].shape != @src.shape_internal
                        raise DimensionError.new("Could not apply .{{call.name.id}} elementwise - Shape of argument does match dimension of `self`")
                    end
                \{% end %}
                \{% end %}

                # Note: Be careful with this section. Adding newlines can break this code because it might put commas on their own lines.
                @src.map_with_coord do |elem, coord|
                \{% begin %}
                    elem.{{call.name.id}}(
                    \{% for i in 0...(U.size) %}
                        \{% if U[i] < MultiIndexable %} args[\{{i}}].get(coord) \{% else %} args[\{{i}}]\{% end %}\{% if i < U.size - 1 %}, \{% end %}
                    \{% end %}
                    )
                \{% end %}
                end
            end
        end
  end
end

include Phase

narr = NArray.build(2, 2) { |c| c.sum }
# puts narr
# puts narr.apply.+(2)

# should fail
# shape mismatch
# long_narr = narr.concatenate(narr)
# puts narr.apply * long_narr
# error: undefined method
# puts narr.apply.substring
# error: bad argument
# puts narr.apply.+("hi", "yo")

str_narr = NArray.build(3, 4) { |c| (c.sum % 2) == 0 ? "hello" : "world" }
puts str_narr
puts str_narr.apply.[2]

puts str_narr.apply + str_narr
puts narr.map &.+(3 + 94)
