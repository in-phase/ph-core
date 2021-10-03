require "./elem_coord_iterator"

module Phase
  module MultiIndexable(T)
    class ElemIterator(S, E, I)
      include Iterator(E)

      getter ec_iter : ElemAndCoordIterator(S, E, I)
      def_clone
      delegate :reset, :reverse!, to: @ec_iter

      def initialize(@ec_iter : ElemAndCoordIterator(S, E, I))
      end

      def self.new(src : MultiIndexable, idx_r : IndexRegion)
        new(ElemAndCoordIterator.new(src, idx_r))
      end

      def self.new(src : MultiIndexable, coord_iter : StrideIterator)
        new(ElemAndCoordIterator.new(src, coord_iter))
      end

      def next : E | Stop
        ec_pair = @ec_iter.next

        if ec_pair.is_a? Stop
          stop
        else
          ec_pair[0]
        end
      end

      def with_coord : ElemAndCoordIterator(S, E, I)
        @ec_iter
      end

      def with_coord(&block)
        @ec_iter.each do |tuple|
          yield tuple
        end
      end

      def reverse_each
        inst = clone
        inst.reverse!
        inst
      end

      def reverse_each(&block)
        reverse_each.each do |elem|
          yield elem
        end
      end
    end
  end
end
