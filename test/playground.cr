class Test

    def initialize(@thing : String)
    end

    def compare(other)
        other.@thing == @thing
    end

end


puts Test.new("Hi").compare(Test.new("Hi"))
puts Test.new("hi").@thing