module ReadFunctions
    def read : self
      {{@type}}.new
    end
end
  
class Parent
# defines instance variables and some core methods
end

class A < Parent
include ReadFunctions
end

class B < Parent
include ReadFunctions

end

class ReadableIterator
    include Iterator(ReadFunctions)
    @src : ReadFunctions

    def initialize(@src)
    end

    def next
        return stop if Random.rand < 0.1
        case val = @src.read
        when ReadFunctions 
            val.as(ReadFunctions)
        else 
            # code never actually gets here
            stop
        end
    end
end

readonly = A.new
rw = B.new
puts ReadableIterator.new(readonly).each.to_a
  

# puts A < Readable
# puts A < Parent

case readonly 
when ReadFunctions 
    puts "Readable"
end

puts 5.unsafe_as(String)