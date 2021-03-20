require "../src/lattice.cr"

include Lattice

T_LEFT    =   0f64 # C
T_RIGHT   = 100f64 # C
T_INITIAL =  20f64 # C

LENGTH     =    1 # m
SPACING    = 0.05 # m
TIMESTEP   = 0.01 # seconds
NUM_POINTS = LENGTH // SPACING + 1

CONDUCTIVITY  =  237 # W/m/k
DENSITY       = 2700 # kg/m^3
SPECIFIC_HEAT =  900 # J/kg/K

# This is just a long coefficient that many steps of heat simulation use - it's factored out
# here to prevent pointless recomputation.
COEFF = (CONDUCTIVITY * TIMESTEP) / (DENSITY * SPECIFIC_HEAT * (SPACING ** 2))

state = NArray.fill([NUM_POINTS], T_INITIAL)
state[0] = T_LEFT
state[-1] = T_RIGHT

def simulate(state, duration)
  steps = (duration / TIMESTEP).to_i32 + 1

  steps.times do |current_step|
    state = update_temp(state)
    # puts "Time: #{current_step * TIMESTEP}"
    # puts state
  end

  state
end

abstract struct Number
  {% begin %}
    {% for name in %w(+ - * / // > < >= <= &+ &- &- ** &** % & | ^) %}
      # Invokes `#{{name.id}}` element-wise between `self` and *other*, returning
      # an `NArray` that contains the results.
      def {{name.id}}(other : MultiIndexable(U)) forall U
          other.{{name.id}}(self)
      end
    {% end %} 
  {% end %}
end

def update_temp(state) : NArray(Float64)
  temp_diff = NArray.fill(state.shape, 0f64)

  # Boundary conditions have to be dealt with seperately, as they don't have a
  # second derivative approximation
  temp_diff[0] = (state[1] - state[0]) * COEFF
  temp_diff[-1] = (state[-2] - state[-1]) * COEFF

  (state[1...-1]).each_with_index do |center_temp, idx|
    temp_diff[idx + 1] = (state[idx] - 2 * center_temp + state[idx + 2]) * COEFF
  end
  
  return state.map_with_coord { |el, idx| temp_diff[idx] + el }
end



# state = update_temp(state)

# steps = (0.1 / TIMESTEP).to_i32

puts simulate(state, 100)
