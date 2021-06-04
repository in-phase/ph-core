require "../region_helpers"

module Lattice
    module MultiIndexable(T)
        abstract class CoordIterator
            include Iterator(Array(Int32))
                    
            @coord : Array(Int32)

            @first : Array(Int32)
            @last : Array(Int32)
            @step : Array(Int32)

            @empty : Bool = false

            abstract def next_if_nonempty

            # The initializer will initially set @coord to @first 
            # (the coordinate of the first element to be returned)
            # and then call this method. Override this if needed based
            # on the implementation of `next_if_nonempty` - for example,
            # if `next_if_nonempty` increments `@coord` before returning.
            def setup_coord(coord,step)
                coord
            end

            def initialize(shape, region : Array(RegionHelpers::SteppedRange)? = nil, reverse : Bool = false)
                if shape.size == 0
                    raise DimensionError.new("Failed to create {{@type.id}}: cannot iterate over empty shape \"[]\"")
                end
                if region
                  @first = Array(Int32).new(initial_capacity: region.size)
                  @last = Array(Int32).new(initial_capacity: region.size)
                  @step = Array(Int32).new(initial_capacity: region.size)
        
                  region.each do |range|
                    @empty ||= range.empty?
                    @first << range.begin
                    @step << range.step
                    @last << range.end
                  end
                else
                  @first = [0] * shape.size
                  @step = [1] * shape.size
                  @last = shape.map do |el|
                    @empty ||= el == 0
                    next el - 1
                  end
                end
        
                if reverse
                  @last, @first = @first, @last
                  @step.map! &.-
                end
        
                @coord = @first.dup
                setup_coord(@coord, @step)
            end
        
            protected def initialize(@first, @last, @step)
                @coord = @first.dup
                setup_coord(@coord, @step)
            end
    
            def reset : self
                @coord = @first.dup
                setup_coord(@coord, @step)
                self
            end
    
            def reverse!
                @last, @first = @first, @last
                @step.map! &.-
                reset
            end
    
            def reverse
                typeof(self).new(@last, @first, @step.map &.-)
            end
    
            def next : (Array(Int32) | Stop)
                return stop if @empty
                next_if_nonempty
            end
        end

        class LexIterator < CoordIterator
            def setup_coord(coord, step)
                coord[-1] -= step[-1]
            end
    
            def next_if_nonempty
                (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
                    if @coord[i] == @last[i]
                        @coord[i] = @first[i]
                        return stop if i == 0 # most sig
                    else
                        @coord[i] += @step[i]
                        break
                    end
                end
                @coord
            end
        end


        class ColexIterator < CoordIterator
            def setup_coord(coord, step)
                coord[0] -= step[0]
            end
        
            def next_if_nonempty
                @coord.each_index do |i| # ## least sig .. most sig
                  if @coord[i] == @last[i]
                    @coord[i] = @first[i]
                    return stop if i == @coord.size - 1 # most sig
                  else
                    @coord[i] += @step[i]
                    break
                  end
                end
                @coord
            end
        end

    end
end