require "../src/lattice"

include Lattice

include MultiIndexable(Int32)

narr = NArray.build([3, 2, 4]) { |c, i| i }

region = [..2.., ..2.., ..-1..]

puts ElemIterator.of(narr, iter: LexIterator).each { |i| puts i }

# puts ElemIterator.new(narr, reverse: true, colex: true).each { |i| puts i }

    #   def next_if_nonempty
    #     (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
    #       @coord[i] += @step[i]
    #       break unless @coord[i] * @step[i].sign > @last[i] * @step[i].sign
    #       @coord[i] = @first[i]
    #       return stop if i == 0 # most sig
    #     end
    #     @coord
    #   end

puts narr.view.reverse.permute