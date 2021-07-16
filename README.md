# ph-core

Phase is a family of scientific computing libraries written for Crystal. This repository
implements Phase's core functionality - generic multidimensional arrays, tensors, and other
general-purpose utilities.

## Core Principles

Our primary motivation is to make scientific computing enjoyable, and we do that by putting **user experience above all else**. Phase only requires that you add it to your `shard.yml` - there are no C libraries you have to install.

We also aim to keep our contribution useful by making Phase as **modular and well-contained** as possible. Writing a serious scientific computing library is a large undertaking. Because ph-core is small and modular, it should still be useful and expansible even after core maintainers leave.


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