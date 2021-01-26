class MutableObject
    @value = 0

    def get : String
        @value
    end

    def set(val)
        @value = val
    end

    def clone : MutableObject
        copy = MutableObject.new()
        copy.set(@value)
        copy
    end
end

#one = MutableObject.new()
#two = one

#puts one.get()
#puts two.get()

#two.set("Two")

#puts one.get()
#puts two.get()