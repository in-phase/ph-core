require "big"

module Lattice
    abstract class GeneralCoordIterator(T)
    include Iterator(Coord)

    getter coord : Array(T)
    @first : Array(T)
    @step : Array(T)

    # def initialize(region):
    #   canonicalize_stuff
      # - negative to positive 
      # - inferred endpoints: forgive  (throw error on inferred start)
      # - -------------exclusivity <=  ONLY HANDLE THIS


    # Informs the iterator to not update the coord, i.e. if the iterator 
    # is empty or when returning the first item
    @hold_coord : Bool = true
    @empty : Bool = false

    abstract def advance_coord
    
    # Made an initializer to placate the compiler
    # https://github.com/crystal-lang/crystal/issues/2827
    protected def initialize(@first, @step)
        @coord = @first.dup
    end

    # Set up any incrementing variables (such as @coord) here prior to iteration.
    def reset : self
      @coord = @first.dup
      @hold_coord = true 
      self
    end

    def next : (Array(T) | Stop)
      if @hold_coord
        return stop if @empty 
        # if the iterator is nonempty, we only hold for the first coord
        @hold_coord = false 
        return @coord
      end
      advance_coord
    end

    def unsafe_next : Array(T)
      self.next.as(Array(T))
    end

    # TODO: constrain, figure out what +1 means and if it should depend on step, generally test heavily
    def unsafe_skip(axis, amount) : Nil
      @coord[axis] += amount + 1
    end
  end
end