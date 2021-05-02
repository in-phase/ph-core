require "yaml"
require "json"


alias Any = YAML::Serializable | JSON::Serializable | Int32 | String

class Wrapper(T)

    # We shall never speak of this method
    def sample : T?
        {% if T.name == "Int32" %}
            return 3
        {% end %}
        {% if T.name == "String" %}
            return "hi"
        {% end %}
        {% if T.name == "Float64" %}
            return 0f64
        {% end %}
    end
end

class MixedArray(T)

    # https://github.com/crystal-lang/crystal/issues/4039
    # ^ the issue we ran into earlier (unable to infer type of @data inside a macro). TL;DR it's known and they don't consider it a bug.


    macro extract(marr, *symbols)
        # this first approach is runtime, doesn't work for specifying type of new MixedArray
        my_tuple = {
        {% for sym in symbols %}
            {{sym.id}}: {{marr}}.{{sym.id}}_type ,
        {% end %}
        }

        # This sorta works - but using "sample" still feels iffy
        {% begin %}
            MixedArray({
                {% for sym in symbols %}
                    {{sym.id}}: typeof({{marr}}.{{sym.id}}.sample) ,
                {% end %}
            }).new
        {% end %}
    end

    # possible to make these on construction time? This may or may not help: https://github.com/crystal-lang/crystal/issues/6028
    macro method_missing(call)
        def {{call.name}}
            # This chunk can probably go
            {% if call.name.split('_')[1] == "type" %}
                \{% for i in (0...T.size) %} 
                    \{% if T.keys[i] == {{call.name.split('_')[0]}} %}
                        return \{{T[T.keys[i]] }}
                    \{% end %}  
                \{% end %}  
            {% end %}

            \{% for i in (0...T.size) %} 
                \{% if T.keys[i] == "{{call.name}}" %}
                    return Wrapper( \{{T[T.keys[i]] }} ).new # rather than a "Wrapper" this will probably be a Column? Maybe?
                \{% end %}  
            \{% end %}  

            # Compile error?
            raise "Name not found"
        end
    end

    # For syntactic symmetry with extract, which can't be an instance method
    def self.join(a, b)
        a.join(b)
    end

    def join(other : B) forall B
        {%begin %}
            {% if !(B < MixedArray) %}
                {{raise "Can only join another MixedArray"}}
            {% end %}
        {% end%}

        # incredibly, it seems they forgive line breaks and trailing commas here!
        {% begin %}
            MixedArray({
                {% for i in (0...T.size) %} 
                    {{T.keys[i]}}: {{T[T.keys[i]]}} , 
                {% end %}  
                {% for i in (0...B.type_vars[0].size) %} 
                    {{B.type_vars[0].keys[i]}}: {{B.type_vars[0][B.type_vars[0].keys[i]]}} , 
                {% end %}    
            }).new
        {% end %} 
    end

end



# puts String < JSON::Serializable # => false. Same for YAML
# puts String < Any # => true
# so we may need to alias Any to include all standard types, plus Serializable (for custom data type purposes)?

one = MixedArray({name: String, birthday: Float64}).new
two = MixedArray({age: Int32}).new
not_ma = 5
puts one
puts two
joined = one.join(two)
# puts MixedArray.join(one, two) - a wrapper method for syntactic symmetry with extract
#puts one.join(not_ma) # => causes compile error like we want

puts joined

#puts one.name
#puts one.birthday
puts MixedArray.extract(joined, :birthday, "age") # StringLiterals and SybolLiterals work