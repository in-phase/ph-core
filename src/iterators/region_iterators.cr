module Lattice
    module MultiIndexable(T)
        abstract class RegionIterator(A, T) 
            include Iterator(Tuple(T, Array(Int32)))
            @coord : Array(Int32)
        
            @first : Array(Int32)
            @last : Array(Int32)
            @step : Array(Int32)
        
            def initialize(@narr : A, region = nil, reverse = false)
                if region
                    @first = Array(Int32).new(initial_capacity: region.size)
                    @last = Array(Int32).new(initial_capacity: region.size)
                    @step = Array(Int32).new(initial_capacity: region.size)
        
                    region.each_with_index do |region, idx|
                        @first[idx] = region[idx].begin
                        @last[idx] = region[idx].end
                        @step[idx] = region[idx].step
                    end
                else
                    @first = [0] * @narr.dimensions
                    @last = @narr.shape.map &.pred
                    @step = [1] * @narr.dimensions
                end
        
                if reverse
                    @last, @first = @first, @last
                    @step.map! &.-
                end
                
                @coord = @first.dup
                setup_coord(@coord, @step)
            end
        
            protected def initialize(@narr, @first, @last, @step)
                @coord = @first.dup
                setup_coord(@coord, @step)
            end
            
            def reverse!
                @last, @first = @first, @last
                @step.map! &.-
        
                @coord = @first.dup
                setup_coord(@coord, @step)
                self
            end
        
            def reverse
                typeof(self).new(@narr, @last, @first, @step.map &.-)
            end
        
            abstract def setup_coord(coord, step)
            abstract def next
        end
        
        private class LexRegionIterator(A, T) < RegionIterator(A, T)
            def setup_coord(coord, step)
                coord[-1] -= step[-1]
            end
        
            def next
                (@coord.size - 1).downto(0) do |i| ### least sig .. most sig
                    if @step[i] > 0 ? (@coord[i] >= @last[i]) : (@coord[i] <= @last[i]) 
                        @coord[i] = @first[i]
                        return stop if i == 0 # most sig 
                    else 
                        @coord[i] += @step[i] 
                        break
                    end
                end
                {@narr.unsafe_fetch_element(@coord), @coord}
            end
        end
        
        private class ColexRegionIterator(A, T) < RegionIterator(A, T)
            def setup_coord(coord, step)
                coord[0] -= step[0]
            end
        
            def next
                @coord.each_index do |i| ### least sig .. most sig
                    if @step[i] > 0 ? (@coord[i] >= @last[i]) : (@coord[i] <= @last[i]) 
                        @coord[i] = @first[i] 
                        return stop if i == @coord.size - 1 # most sig 
                    else 
                        @coord[i] += @step[i] 
                        break
                    end
                end
                {@narr.unsafe_fetch_element(@coord), @coord}
            end
        end
    end
end