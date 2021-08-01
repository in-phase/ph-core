# type aliases, region/coordutil, steppedrange

# iterators (coord, region)

require "./exceptions/*"

require "./index_region.cr"

require "./multi_indexable.cr"
require "./multi_writable.cr"

require "./iterators/general_coord_iterator.cr"
require "./iterators/coord_iterator.cr"
require "./iterators/lex_iterator.cr"
require "./iterators/elem_iterator.cr"

require "./n_array/buffer_util.cr"
require "./n_array.cr"

require "./view_util/*"
require "./readonly_view.cr"
# require "./view.cr"

require "./formatter/settings.cr"
require "./formatter/formatter.cr"

# TODO: Write documentation for `Phase::Core`
module Phase
  VERSION = "0.1.0"
end
