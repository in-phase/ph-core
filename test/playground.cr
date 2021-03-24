require "../src/lattice"

include Lattice


arr = [[1,2,3]]
arr2 = [[4,5,6]]

# narr = NArray.new(arr)
# narr2 = NArray.new(arr2)

# narr << narr2
# puts narr, "\n"
# narr << narr
# puts narr
# puts narr.axis_strides


# puts my1, my2
# my1 << my2



# puts 1..2..3
# puts typeof(1..2..3)

# puts typeof((1..5).step(1))

# def test(range, step)
#     puts (range.end - range.begin) % step
# end

# test(1..6, 3)
# test(6..1, 3)
# test(6..2, -2)
# test(2..6, 2)

# include RegionHelpers

# shape = [5,5,5,5,5,5,5]

# region1 = [1.., ..., ..3, ...5, 3...1, 4.., 1...2]
# region2 = [0..2..4, 1..1..4, 3..-1..2, 1..2..4, ..2.., ..1...5, 1..2..]


# puts canonicalize_region(region1, shape)
# puts canonicalize_region(region2, shape)

# puts NArray.concatenate(my, my0, axis: 0), "\n"
# my0 = my0.reshape([2,3,2])
# puts NArray.concatenate(my, my0, axis: 1), "\n"
# my0 = my0.reshape([2,2,3])
# puts NArray.concatenate(my, my0, axis: 2), "\n"


large = NArray.build([5,5,10]) {|coord, i| coord}


pv = ProcessedView.of(large) {|x| x.to_s }

pvv = pv.process {|x| x + "%"}

pvvv = pvv.view(1..2, 1..2, 1..2..9)

puts pvvv, typeof(pvvv), pvvv.region

v =  View.of(large)

puts v.get(3,4,7)

vv = v.process {|x| x.to_s}

# puts vv

# puts vv.region


# procA = Proc(Int32, Float64).new {|x| x.to_f64}
# procB = Proc(Float64, String).new {|x| x.to_s}

# tempA = procA.clone
# tempB = procB.clone
# composition = Proc(Int32, String).new {|x| tempB.call(tempA.call(x))}

# puts composition.call(1)

# procB = Proc(Float64, String).new {"Broken!"}

# puts composition.call(1)


# my = NArray.build([2,2,2]) {|coord, i| i + 1}
# my0 = NArray.build([2,2,2]) {|coord, i| -i - 1}

# my[..,..,1] = my[..,..,1]


