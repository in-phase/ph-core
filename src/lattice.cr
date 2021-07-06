# type aliases, region/coordutil, steppedrange

# iterators (coord, region)

require "./exceptions/*"

require "./type_aliases.cr"
require "./coord_util.cr"
require "./index_region.cr"

require "./multi_indexable.cr"
require "./multi_writable.cr"

require "./iterators/general_coord_iterator.cr"
require "./iterators/coord_iterator.cr"
require "./iterators/region_iterator.cr"
require "./iterators/chunk_iterator.cr"
require "./iterators/*"

require "./n_array/*"
require "./n_array.cr"

require "./view_util/*"
require "./readonly_view.cr"
require "./proc_view.cr"
require "./view.cr"

require "./formatter/settings.cr"
require "./formatter/formatter.cr"

require "./patches/*"

# TODO: Write documentation for `Lattice::Core`
module Lattice
  VERSION = "0.1.0"

  # TODO: Put your code here
end
