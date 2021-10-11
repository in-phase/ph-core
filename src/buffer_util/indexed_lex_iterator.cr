require "./indexed_stride_iterator.cr"

module Phase
  module BufferUtil
    class IndexedLexIterator(I) < IndexedStrideIterator(I)
      def_standard_clone
      
      def advance! : ::Slice(I) | Stop
        (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
          if @coord.unsafe_fetch(i) == @last.unsafe_fetch(i)
            @buffer_index -= (@coord.unsafe_fetch(i) - @first.unsafe_fetch(i)) * @buffer_step.unsafe_fetch(i)
            @coord[i] = @first.unsafe_fetch(i)
            return stop if i == 0 # most sig
          else
            @coord[i] += @step.unsafe_fetch(i)
            @buffer_index += @buffer_step.unsafe_fetch(i) * @step.unsafe_fetch(i)
            break
          end
        end

        @coord
      end
    end
  end
end