class MutableObject
    @value = "One"

    def get : String
        @value
    end

    def set(val)
        @value = val
    end
end

#one = MutableObject.new()
#two = one

#puts one.get()
#puts two.get()

#two.set("Two")

#puts one.get()
#puts two.get()