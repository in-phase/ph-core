macro whatever
end

def get_best_type(nested : T) forall T
    {% begin %}
        {% puts T < Array %}
        {% puts T.type_vars %}
        {% puts T.type_vars[0] %}
        {% puts T.type_vars[0].union_types %}
        {% puts T.type_vars[0].union_types[2].type_vars[0].union_types %}

        
    {% end %}

end

[ [1], ["hello"] ] # Array(Int32) | Array(String)

# if Array -> .type_vars[0].union_types  -> list of types
# check 


A = [[3], ["Hi"], [0.45]]

puts get_best_type([[[1, 2, 3]], ["hello", 1f64, 10], [12, 13, 14]])

# puts get_best_type(4)