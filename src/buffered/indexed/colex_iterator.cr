require "./stride_iterator.cr"

module Phase::Buffered::Indexed
  class ColexIterator(I) < Indexed::StrideIterator(I)
    def_standard_clone
    
    def advance! : ::Slice(I) | Stop
      0.upto(@coord.size - 1) do |i| # ## least sig .. most sig
        if @coord.unsafe_fetch(i) == @last.unsafe_fetch(i)
          @buffer_index -= (@coord.unsafe_fetch(i) - @first.unsafe_fetch(i)) * @buffer_step.unsafe_fetch(i)
          @coord[i] = @first.unsafe_fetch(i)
          return stop if i == @coord.size - 1 # most sig
        else
          @coord[i] += @step[i]
          @buffer_index += @buffer_step.unsafe_fetch(i) * @step.unsafe_fetch(i)
          break
        end
      end
      
      @coord
    end
  end
end