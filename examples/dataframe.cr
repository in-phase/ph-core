require "../src/lattice"
require "yaml"
require "json"

module Lattice::Data
    alias Serializable = YAML::Serializable | JSON::Serializable

    class DataFrame < Matrix(Serializable)
        def [](*region) : DataFrame
            DataFrame.new(super, @names[region[1]])
        end

        # small = big[region]
        # small[0].source_row

        def initialize(data, column_names)
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
        @data : Array(Serializable)
        def initialize
            @info = Random.rand * 1000
            puts @info
        end

        def [](index) : T
            @data[index].unsafe_as(T)
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

    

    # df = DataFrame({age: Int32}).new([Column(Int32.new)])
    # df.names
    # df.dummy
    # #df.dummy(1)

    
    


end







