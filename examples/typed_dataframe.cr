require "../src/lattice"
require "yaml"
require "json"

module Lattice::Data
    class DataFrame(T)
        alias Serializable = YAML::Serializable | JSON::Serializable
        # include MultiIndexable(Serializable)

        
        def initialize
            # @data = {age: Column(Int32).new}
            {% begin %}
            @data = {
                {% for i in (0...T.size) %}
                    {{T.keys[i]}}: Column({{T[T.keys[i]]}}).new {% if i != T.size - 1 %},{% end %}
                {% end %}
            }
            {% end %}
            pp data

        end

        def dummy
        end

        # def get_column(index) : Column(Serializable)
        #     @data[index]
        # end

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

# DataFrame({name: String, age: Int32}) , DataFrame({birthday : Date})

# DataFrame.extract(df, {:name, :birthday})

# def column_join(other : DataFrame(U)) forall U
# end



# data = load_csvnew DataFrame.nwew()()[]{}name: String, age: Int32
# data = DataFrame({name: String, age: Int32}).new(load_csv) [][]()[]{}EEE = -34e.

# data = DataFrame({name: String, age: Int32}).new(load_csv)
# data[2..5, ...] #=> DataFrame({name: String, age: Int32})
# data[..., 0] #=> DataFrame({name: String, age: Int32}, @columns_stored=0..0)
# data[..., 0].ages # raises error
# data[2..5]
# data.age


a = [0.12, 0.23, 0.34, 0.45] of (Int32 | Float64)
b = a.unsafe_as(Array(Float64))
puts a
    puts b
