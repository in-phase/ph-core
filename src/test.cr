class A(T)
    def multiply(number)
        if T == A
            @arg.each do |element|
                element.multiply(number)
            end
        else
            @arg.each_with_index do |element, index|
                @arg[index] = element * number
            end
        end
    end

    def initialize(@arg : Array(T))
    end
end

# arr = A[A[1, 2], A[1, 2]] # A(A(Int32))
#arr = A.new([ A.new([1, 2]), A.new([1, 2]) ]) # A(A(Int32))

#puts(arr)

#arr = arr.multiply(3)

#puts(arr)

class B
    def self.reflect(var : T) : T
        var
    end


    def self.fill(size, val : T) : Slice(T)
        Slice(T).new(5, "hello")
    end
end




puts Slice.new(5) { |i| i}