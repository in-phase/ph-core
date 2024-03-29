# type aliases, region/coordutil, steppedrange

# iterators (coord, region)

require "./exceptions/*"

require "./type_aliases.cr"
require "./coord_util.cr"
require "./shape_util.cr"
require "./readonly_wrapper.cr"

require "./range_syntax/range_syntax.cr"
require "./index_region.cr"

require "./iterators/*"
require "./multi_writable.cr"
require "./multi_indexable.cr"
require "./multi_indexable/*"

require "./buffered/buffered.cr"
require "./buffered/indexed/*"
require "./n_array.cr"

require "./view_util/*"
require "./view.cr"
require "./proc_view.cr"
require "./mutable_view.cr"

require "./multi_indexable/formatter/settings.cr"
require "./multi_indexable/formatter/formatter.cr"

require "./patches/*"

# DOCUMENT: Write documentation for `Phase::Core`
module Phase
  VERSION = "0.1.0"
end
