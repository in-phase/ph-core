
require "./spec_helper.cr"
require "./test_narray.cr"

include Lattice

slice1 = Slice(Int32).new(9) { |idx| idx }
slice1transpose = Slice(Int32).new(9) {|idx| [0,3,6,1,4,7,2,5,8][idx] }

small_arr = RONArray.new([3,3], slice1)
transpose = RONArray.new([3,3], slice1transpose)

# TODO: revise unit tests seriously. These serve more as demos than exhaustive tests.

describe Lattice::MultiEnumerable do
    describe ".map" do
        it "produces an NArray(U) where U is the result of the block" do
            typeof(small_arr.map {|e| e.to_s}).should eq NArray(String)
        end
        it "maps each element to the result of the block" do
            new_arr = small_arr.map {|e| e + 2 }
            new_arr.get(0,0).should eq small_arr.get(0,0) + 2
        end
        it "responds to order parameters" do
            small_arr.map(Order::COLEX) {|e| e}.should eq transpose
            small_arr.map {|e| e}.should_not eq transpose
            small_arr.map(Order::REV_LEX) {|e| e}.should eq transpose.map(Order::REV_COLEX) {|e| e}
        end
    end
    describe ".to_a" do
        it "produces an Array(T)" do
            typeof(small_arr.to_a).should eq Array(Int32)
        end
        it "responds to order parameters" do
            small_arr.to_a.should eq [0,1,2,3,4,5,6,7,8]
            small_arr.to_a(Order::COLEX).should eq [0,3,6,1,4,7,2,5,8]
        end
    end
    describe ".reduce" do
        it "does stuff" do
            small_arr.reduce(3) {|memo, elem| memo + elem}.should eq 39
        end
    end
    describe ".sum" do
        it "does stuff" do
            small_arr.sum(3).should eq 39
        end
    end
    describe ".product" do
        it "computes products" do
            small_arr.product.should eq 0
        end
        it "accpets an initial value" do
            small_arr.map {|e| e + 1}.product(-1).should eq -362880
        end
        it "accepts a block" do
            small_arr.product {|e| e + 1}.should eq 362880
        end
        
    end
    describe ".all?" do
        it "does stuff" do
            small_arr.all? {|e| e >= 0}.should be_true
            small_arr.all? {|e| e > 0}.should be_false
        end
        
    end
    describe ".any?" do
        it "does stuff" do
            small_arr.any? {|e| e > 5}.should be_true
            small_arr.any? {|e| e > 9}.should be_false    
        end
    end
    describe ".none?" do
        it "does stuff" do
            small_arr.none? {|e| e > 9}.should be_true
            small_arr.none? {|e| e > 5}.should be_false
        end
        
    end
    describe ".one?" do
        it "does stuff" do
            small_arr.one? {|e| e > 7}.should be_true
        end
        it "responds to order parameters" do
            # A sample of how order may affect one of the seemingly "order-independent" methods
            idx = -1
            small_arr.one?(Order::LEX) { |e| idx += 1; e == idx}.should be_false
            idx = -1
            small_arr.one?(Order::REV_LEX) { |e| idx += 1; e == idx}.should be_true
        end
    end
    describe ".count" do
        it "does stuff" do
            small_arr.count.should eq small_arr.size
            small_arr.count {|e| e > 5}.should eq 3
        end
        it "counts elements that match a pattern" do 
            small_arr.count(5..10).should eq 4
        end
    end
    describe ".first" do
        it "by default gets element `[0] * dimensions`" do
            small_arr.first.should eq 0
        end
        it "gets the first element according to any iterator" do 
            small_arr.first(Order::REV_LEX).should eq 8
        end
    end
    describe ".find" do
        it "does stuff" do
            
        end
        it "finds the first instance for which this occurs" do
            small_arr.find {|e| e > 3}.should eq 4
        end
    end
end