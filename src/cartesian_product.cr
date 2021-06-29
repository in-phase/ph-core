require "./lattice"

module Lattice

    # class CartesianProduct(*U) # < MultiIndexable(Tuple(*U))
    class CartesianProduct(*U)
        include MultiIndexable(U)

        @shape : Array(Int32)
        @lists : Pointer(Int64)

        def self.make(lists : T) forall T
            {% begin %}
                # We assume T is a Tuple(Array(A), Array(B), ...) etc
                # and want to construct a CartesianProduct(A,B,...)
                CartesianProduct( 
                    {% for type in T.type_vars %} {{type}}.type_vars[0], {% end %} 
                    ).new(lists)
            {% end %}
        end

        def initialize(lists)
            @shape = lists.map {|list| list.size}.to_a
            @lists = pointerof(lists).as(Pointer(Int64))
        end

        def lists_typed
            {% begin %}
            @lists.as(Pointer(Tuple( {% for type in U %} Array({{type}}), {% end %} ))).value
            {% end %}
        end      
        # like out of the blue?
        # hahaha so I just ran it and it worked for some reason

        # I have a suspicion it's because I redefined lists
        
        def shape : Array
            @shape.dup 
        end

        def unsafe_fetch_chunk(region : IndexRegion)

            # CartesianProduct.make()
            "Hi, not currently working"
        end

        def unsafe_fetch_element(coord : Coord) : U
        # is it because this is all hardcoded
            # listsb = lists_typed
            # # puts typeof(listsb)
            # # lists = {['a', 'b', 'c'], [1,2,3]}
            {% begin %}


            lists = @lists.as(Pointer(Tuple( {% for type in U %} Array({{type}}), {% end %} ))).value
            vals = lists.map_with_index do |list, dim|
                list[coord[dim]]
            end
            puts vals

            # vals = listsb.map_with_index do |list, dim|
            #     list[coord[dim]]
            # end
            # puts vals

            {% end %}

            {'b',1}
        end

        def get_first(arr)

            one = 0
            two = 1
    
            coord = [one, two]

            lists = lists_typed
            vals = lists.map_with_index do |list, dim|
                list[coord[dim]]
            end
            puts vals


        end

        # def self.do_stuff(cp : CartesianProduct, coord)
        #     lists = cp.lists_typed
        
        #     vals = lists.map_with_index do |list, dim|
        #         list[coord[dim]]
        #     end
        #     puts vals
        # end
    end

    class SpecificCartesianProduct < CartesianProduct(Char, Int32)
    end

    def self.do_stuff(coord : Array(Int32), cp : CartesianProduct)
        lists = cp.lists_typed
        one = 0
        two = 1

        coord = [one, two]
    
        vals = lists.map_with_index do |list, dim|
            list[coord[dim]]
        end
        puts vals
    end

    def self.do_stuff2(coord : Array(Int32), lists)

        vals = lists.map_with_index do |list, dim|
            list[coord[dim]]
        end
        puts vals
    end


    letters = ['a', 'b', 'c']
    numbers = [1, 2, 3]

    lists = {letters, numbers}

    # ptr = pointerof(lists).as(Pointer(Int64))
    # lists2 = ptr.as(Pointer(Tuple( Array(Char), Array(Int32), ))).value

    # puts lists2

    # do_stuff2([1,1], lists2)






    # a = {'a', 1}
    # b = pointerof(a).as(Pointer(Int64))
    # c = ptr.as(Pointer(Tuple(Char, Int32)))


    # okay so i thought that it might be that lists was an Array but it's a tuple
    # so that should be okay

    # yeah I'd expect so.... and yet haha

    # coord = [1,1]
    cp = CartesianProduct(Char, Int32).new(lists)
    puts cp.get_first([1])
    
    # # do_stuff2([1,1], cp.lists_typed)

    # # CartesianProduct.do_stuff(cp, [1,1])
    # do_stuff([1,1], cp)

    # # listsb = cp.lists_typed

    # # vals = listsb.map_with_index do |list, dim|
    # #     list[coord[dim]]
    # # end
    # # puts vals


    # puts cp.get(1,1)

end



