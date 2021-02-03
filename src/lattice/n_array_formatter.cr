require "./n_array.cr"

module Lattice
  module NArrayFormatter
    extend self

    protected def print_internal(narr, io, start_dim, buffer_idx, shape)
      io << "["

      # If we are above a vector still, recurse.
      if start_dim < narr.dimensions - 1
        shape[start_dim].times do |index|
          print_internal(narr, io, start_dim + 1, buffer_idx, shape)
          io << ",\n" if index < shape[start_dim] - 1
          io << "\n" if start_dim == narr.dimensions - 3
        end
      else
        # base case: row
        shape[start_dim].times do |col_idx|
          io << narr.buffer[buffer_idx[0] + col_idx]
          io << ", " if col_idx < shape[start_dim] - 1
        end

        buffer_idx[0] += shape[start_dim]
      end

      io << "]"
    end

    def print(narr, io = STDOUT)
      print_internal(narr, io, start_dim: 0, buffer_idx: [0], shape: narr.shape)
    end

    def format(narr) : String
      builder = String::Builder.new
      print(narr, io: builder)
      builder.to_s
    end
  end
end

# set defaults

# narr.format(options)
# narr.format(**namedtuple)
# narr.foramt(Formatter)
# formatter.format(narr)

# puts narr

# options = {colorized: true}
# NArrayFormatter.format(narr, **options)

# format = NArrayFormatter.new
# format.colorized = true
# format.format(narr)
