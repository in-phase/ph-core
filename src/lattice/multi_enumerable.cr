require "./exceptions.cr"

module Lattice
  module MultiEnumerable(T)



    # Like `Enumerable`, `MultiEnumerable` provides collection classes with several traversal, searching, filtering and querying methods,
    # but have been specifically designed for optimized use with `MultiIndexable`s and generalizability for different ordering.


    # By default, methods for which iteration order always has a chance to impact the value will use `Order::LEX`, 
    # while methods that are order-independent unless given an order-dependent block will use `Order::FASTEST`.
    # For example, one may need to be mindful of order when running the following code:
    # ```
    # idx = 0
    # narr.any?(Order::LEX) do |elem|
    #   val = (elem == idx)
    #   idx += 1
    #   val
    # end
    # ```
    # If calling `.any?(Order::COLEX)`, for example, a different result might be obtained.


    abstract def each(order : Order = Order::LEX)


    # I'm the map ~
    def map(order : Order = Order::LEX, &block : T -> U) forall U
      map_with_coord(order) do |elem, coord|
        yield elem
      end
    end

    # I'm the map ~
    def map_with_coord(order : Order = Order::LEX, &block : T -> U) forall U
      iter = each(order)
      buffer = Slice(U).new(size) do |idx|
        yield *(iter.next.as(Tuple(T, Array(Int32))))
      end
      NArray(U).new(shape, buffer)
    end

    # Reduce
    def reduce(memo, order : Order = Order::LEX)
      each(order) do |elem|
        memo = yield memo, elem
      end
      memo
    end

    # Reduce
    def reduce?(order : Order = Order::LEX)
      memo = uninitialized T
      found = false

      each(order) do |elem|
        memo = found ? (yield memo, elem) : elem
        found = true
      end

      found ? memo : nil
    end

    # Reduce
    def reduce(order : Order = Order::LEX)
      memo = uninitialized T
      found = false

      each(order) do |elem|
        memo = found ? (yield memo, elem) : elem
        found = true
      end

      found ? memo : raise MultiEnumerable::EmptyError.new("Could not reduce: {{@type}} was empty")
    end

    # Converts to an `Array(T)`
    def to_a(order : Order = Order::LEX)
      iter = each(order)
      Array(T).new(size) do 
        iter.next.as(Tuple(T, Array(Int32)))[0]
      end
    end





    def product(initial : Number, order : Order = Order::FASTEST)
      product(initial, Order::FASTEST, &.itself)
    end

    def product(order : Order = Order::FASTEST)
      product Reflect(T).first.multiplicative_identity
    end

    def product(order : Order = Order::FASTEST, &block)
      product(Reflect(T).first.multiplicative_identity, order) {|e| yield e}
    end

    # Accepts an order since the passed block may have a changing variable that thus depends on order.
    # By default assumes commutativity of multiplication to use the fastest defined order.
    def product(initial : Number, order : Order = Order::FASTEST, &block)
      reduce(initial, order) { |memo, e| memo * (yield e) }
    end


    
    def sum(order : Order = Order::FASTEST)
      {% if T == String %}
        # optimize for string
        #join
      {% elsif T < Array %}
        # optimize for array
        #flat_map &.itself
      {% else %}
        sum additive_identity(Reflect(T))
      {% end %}
    end

    def sum(initial, order : Order = Order::FASTEST)
      sum(initial, order, &.itself) 
    end

    # By default assumes commutativity of addition to use the fastest defined order of iteration.
    # Note that for some types (e.g., string "addition") this may not hold.
    def sum(initial, order : Order = Order::FASTEST, &block)
      reduce(initial) { |memo, e| memo + (yield e) }
    end


    # product, sum
    # min max min_by min_of


    # For the following: For a large MultiIndexable, if it is known that a true/false value is more likely to 
    # be found in a particular area of the array, it may be advantageous to define a an order that reflects this

    # all?
    def all?(order : Order = Order::FASTEST, &block)
      each(order) { |e| return false unless yield(e) }
      true
    end

    # none?
    def none?(order : Order = Order::FASTEST, &block)
      each(order) { |e| return false if yield(e) }
      true
    end

    # any?
    def any?(order : Order = Order::FASTEST, &block)
      each(order) { |e| return true if yield e }
      false
    end

    # count
    # order here should be irrelevant (all items in the array must be iterated over anyway) UNLESS
    # the user passes an order-dependent block.
    def count(order : Order = Order::FASTEST, &block)
      count = 0
      each(order) do |elem|
        count += 1 if yield elem
      end
      count
    end

    # one?
    def one?(order : Order = Order::FASTEST, &block)
      return 1 == count(order) {|e| yield e} # TODO: find out if &.tap works and how I'm using it wrong?
    end


    {% begin %}
      {% for name in %w(all? none? any? count one) %}
        # Version of {{name}} that accepts a pattern to match
        def {{name.id}}(pattern, order : Order = Order::FASTEST)
          {{name.id}} { |e| pattern === e }
        end

        # Version of {{name}} takes no block - directly checks truthiness of elements
        def {{name.id}}(order : Order = Order::FASTEST)
          {{name.id}} &.itself
        end
      {% end %}
    {% end %}

    


    # empty?
    # For once, fully order-independent!
    def empty?
      each { return false }
      true
    end

    # first
    def first?(order : Order = Order::LEX)
      first(order) { nil }
    end

    def first(order : Order = Order::LEX)
      first(order) { raise Enumerable::EmptyError.new }
    end

    def first(order : Order = Order::LEX, &block)
      each(order) { |e| return e }
      yield
    end



    # sample

    # find
    def find(if_none = nil, order : Order = Order::LEX)
      each(order) do |elem|
        return elem if yield elem
      end
      if_none
    end




    private def additive_identity(reflect)
      type = reflect.first
      if type.responds_to? :additive_identity
        type.additive_identity
      else
        type.zero
      end
    end

    private struct Reflect(X)
      # For now it's just a way to implement `Enumerable#sum` in a way that the
      # initial value given to it has the type of the first type in the union,
      # if the type is a union.
      def self.first
        {% if X.union? %}
          {{X.union_types.first}}
        {% else %}
          X
        {% end %}
      end
    end
  end
end
