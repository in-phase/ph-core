class Foo
    def [](index)
        puts "normal"
        5
    end

    def []?(index)
        puts "nilable"
        10
    end

    def []=(index, value)
        puts "setter"
    end

end

a = Foo.new()
a[1] *= -1

# a[1] = a[1]? * -1
# nilable
# setter