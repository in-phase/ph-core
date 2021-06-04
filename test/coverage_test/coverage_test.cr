module Test

    def self.none
        return 1
    end 

    def self.one(arg1)
        return "Hi"
    end

    def self.two(arg2)
        return [0]
    end

end

begin
    a = Test.none
rescue exception
    
end