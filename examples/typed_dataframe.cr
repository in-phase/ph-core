require "../src/lattice"
require "yaml"
require "json"

module Lattice::Data
    class DataFrame(T)
        alias Serializable = YAML::Serializable | JSON::Serializable
        # include MultiIndexable(Serializable)

        @data : NamedTuple(age: Column(Int32))

        def initialize
            @data = {age: Column(Int32).new}
            {% begin %}
            data = {
                {% for i in (0...T.size) %}
                    {{T.keys[i]}}: Column({{T[T.keys[i]]}}).new {% if i != T.size - 1 %},{% end %}
                {% end %}
            }
            {% end %}
            pp data

        end

        def dummy
        end

        def get_column(index) : Column(Serializable)
            @data[index]
        end

        def ages
            {%begin%}
            get_column(0).unsafe_as(Column( {{T[:age] }} ))
            {%end%}
        end


        # @data = Array(Column(union of T)) ???
        macro method_missing(call)
            def {{call.name}}()
                {% puts call.name %}

                
                \{% puts T %}

                {% if @type.has_method?(call.name) %}
                {% end %}

                # check if DataFrame responds to call
                # if so raise error

                \{% begin %}
        
                    \{% for key, value in T %}
                        \{% puts key %}
                        \{% puts value %}
                    \{% end %}
                \{% end %}
            end
        end
    end

    class Column(T) 
        @info : Float64
        def initialize
            @info = Random.rand * 1000
            puts @info
        end
    end

    # struct Any
    #     alias Type = YAML::Serializable | JSON::Serializable

    #     def initialize(@raw : Type)
    #     end

    #     def get
    #         @raw
    #     end
    # end

    df = DataFrame({age: Int32}).new
    df.names
    df.dummy
    #df.dummy(1)
end