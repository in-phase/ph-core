# ph-core

Phase is a family of scientific computing libraries written for Crystal. This repository
implements Phase's core functionality, including generic multidimensional arrays,
views, array slicing, pretty-printing, and fluent arithmetic.

## NOTE
If you're seeing this repo right now, please note that Phase is not quite
ready for public use. We have a lot of documentation to write, compatibility
modules to test and ship, and specs to implement.

If you have any questions, feel free to reach out to [sethhinz@me.com](mailto:sethhinz@me.com) or open an issue.

## Links
- [API Documentation](https://in-phase.github.io/api)
- [Introduction & Reference Material](https://in-phase.github.io/reference)

## Examples

```crystal
# You can construct n-dimensional arrays from literals:
narr = NArray[[1, 0, 0], [0, 1, 0]]

# Or programatically using the coordinates:
narr2 = NArray.build(2,3) do |coord| 
    10 * coord[0] + coord[1]
end

puts narr2
# 2x3 Phase::NArray(Int32)
# [[1, 0, 0],
#  [0, 1, 0]]

puts narr2
# 2x3 Phase::NArray(Int32)
# [[ 0,  1,  2],
#  [10, 11, 12]]

# Use infix operators to easily do element-wise arithmetic
narr + narr2 # => NArray[[1, 1, 2], [10, 12, 12]]
narr * narr2 # => NArray[[0, 0, 0], [ 0, 11,  0]]

# Access a single element from your n-array:
narr.get(0, 0) # => 1

# Or a chunk, via slicing:
narr[.., 1] # => NArray[0, 1] (all rows, column one only)

# Create views of your data (to avoid copying it):
narr.view(.., 1) # => [0, 1] (as a View)

# And even define procedures to lazily transform data:
narr.view(.., 1).process {|x| (x + 4)**2 } # => [16, 25] (as a ProcView)

# Iterate over data in a performance and syntax friendly way:
argmax = [0, 0]
max = narr.get(argmax)
narr2.each_with_coord do |el, coord|
  max, argmax = el, coord if el > max
end
puts({max, argmax}) # => {12, [1, 2]}

# Easily take axial slices of data:
narr2.slices(axis: 1) # => [NArray[0, 10], NArray[1, 11], NArray[2, 12]]

# Perform any operation on each element of the n-array with `apply`:
str_narr = NArray.build(3,3) {|_, i| "hello world"[i] }
puts str_narr.apply.upcase
```

## Compatibility
Phase is designed to be modular, extensible, and compatible with other
scientific computing libraries via [ph-compat](https://github.com/in-phase/ph-compat).

```crystal
require "ishi"

require "ph-core"
require "ph-compat/ishi"

# demo this
```

things to show off:
- ease of constructing NArrays
- slicing
- arithmetic
- masking
- views
- iterating over an NArray
- slices
- demo of ph-compat
- #.apply

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ph-core:
       github: in-phase/ph-core
   ```

2. Run `shards install`

## Usage

```crystal
require "ph-core"
```

TODO: Write usage instructions here

## Core Principles

Our primary motivation is to make scientific computing enjoyable, and we do that by putting **user experience above all else**. Phase only requires that you add it to your `shard.yml` - there are no C libraries you have to install.

We also aim to keep our contribution useful by making Phase as **modular and well-contained** as possible. Writing a serious scientific computing library is a large undertaking. Because ph-core is small and modular, it should still be useful and expansible even after core maintainers leave.

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/in-phase/ph-core/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors
- [Emily Love](https://github.com/emgineering) - co-author
- [Seth Hinz](https://github.com/shinzlet) - co-author
