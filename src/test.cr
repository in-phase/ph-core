macro whatever
end

# 1  procedure BFS(G, root) is
# 2      let Q be a queue
# 3      label root as discovered
# 4      Q.enqueue(root)
# 5      while Q is not empty do
# 6          v := Q.dequeue()
# 7          if v is the goal then
# 8              return v
# 9          for all edges from v to w in G.adjacentEdges(v) do
# 10              if w is not labeled as discovered then
# 11                  label w as discovered
# 12                  Q.enqueue(w)

# Push to array: << or push
#

# A GENERIC COMPILE-TIME ITERATIVE BREADTH FIRST SEARCH TYPE CHECKING ALGORITHM

# 1 type param + Enumerable == array like
# not enumerable == scalar
# enumerable but != 1 type parameter = scalar

# Given a nested array with arbitrarily complicated union types,
# this macro will return an ArrayLiteral storing each individual non-enumerable the array
# contains
def union_of_base_types(nested : T) forall T
  {% begin %}
        {%
          scalar_types = [] of TypeNode
          identified = [] of TypeNode
          identified << T
        %}

        {% for type_to_check in identified %}

            # If the object is array-like, mark each type in its type parameter as needing to be checked
            {% if type_to_check.type_vars.size == 1 && type_to_check < Enumerable %} # has one generic type var that extends enumerate
                {% type_var = type_to_check.type_vars[0] %}

                {% for type in type_var.union_types %}
                    {% identified << type %}     
                {% end %}
            
            # If the object is a scalar, push the type to the scalar_types list    
            {% else %} 
                {% scalar_types << type_to_check %}
            {% end %}
        {% end %}

        {% ret_types = scalar_types.uniq %}
        
        return {% for i in 0...(ret_types.size) %} {% if i > 0 %} | {% end %} {{ ret_types[i] }} {% end %}
    {% end %}
end

puts "test".as(Int32 | String)

# def initialize(nested_array)
#      # probe array for dimensions
#     @buffer = Slice(union_of_best_types(nested_array)) do ||
#     # nest into arrays to get desired value based on coordinates
#      end

#     # For nonprimitives: must initialize with something (can't just set size)

# # end

# if Array -> .type_vars[0].union_types  -> list of types
# check

# A = [[3], ["Hi"], [0.45]]
# puts test_typing([[[1, 2, 3]], ["hello", 1f64, 10], [12, 13, 14]])

# puts get_best_type(4)

# get_best_type([[1, 2], ['a', 'b']])
puts union_of_base_types([[[1, 2, 3]], ["hello", 1f64, 10], [12, 13, 14]])

arr = [[[1, 2, 3]], ["hello", 1f64, 10], [12, 13, 14]]
puts typeof(arr.flatten[0])
flat_arr = arr.flatten
puts typeof(flat_arr)

my_slice = Slice(typeof(flat_arr[0])).new(flat_arr.size) { |i| flat_arr[i] }
puts my_slice




