abstract struct Foo 

    def my_method : Int32 | String
        5
    end
end

struct A < Foo
end

struct B < Foo
end

struct Bar 
    @bar : Array(Foo)

    def initialize(@bar)
    end
end


arr = {A.new(), A.new()}.to_a
puts typeof(arr)
Bar.new(arr)



