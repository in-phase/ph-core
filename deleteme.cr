module Phase
    module MultiWritable(T)
    end

    # module MultiIndexable(T)
    #     DROP_BY_DEFAULT = true

    #     def sample : T
    #         x = uninitialized T
    #     end

    #     def to_narr : NArray(T)
    #         NArray.build(@shape.dup) do |coord, _|
    #             unsafe_fetch_element(coord)
    #         end
    #     end

    #     def dimensions
    #         shape.size
    #     end

    #     macro method_added(call)
    #         {% puts call %}
    #     end
    # end
end

require "./src/exceptions/*"

require "./src/multi_indexable.cr"
require "./src/index_region.cr"

# require "./src/multi_writable.cr"

require "./src/iterators/general_coord_iterator.cr"
require "./src/iterators/coord_iterator.cr"
require "./src/iterators/lex_iterator.cr"
require "./src/iterators/elem_coord_iterator.cr"
require "./src/iterators/elem_iterator.cr"

require "./src/n_array/buffer_util.cr"
require "./src/n_array.cr"

require "./src/view_util/*"
require "./src/readonly_view.cr"

require "./src/formatter/settings.cr"
require "./src/formatter/formatter.cr"

require "./spec/test_narray"

module Phase

    class Ham(S, R) < ReadonlyView(S, R)
    end  

    test_shape = [3, 4]

    # narr = uninitialized NArray(Int32) # NArray.build(test_shape) {|c,i| i}
    test_buffer = Slice[1,2,3,4,5,6,7,8,9,10,11,12]

    ronarr = RONArray.new(test_shape, test_buffer)
    data = ReadonlyView.of(ronarr).to_narr

    puts "after making"
    puts data
end