# require "../src/lattice"

# include Lattice

# include MultiIndexable(Int32)

# narr = NArray.build([5]) { |c, i| i }

# puts narr
# puts narr[2..]

# region = [..2.., ..2.., ..-1..]

# puts ElemIterator.of(narr, iter: ColexIterator).each { |i| puts i }

# puts ElemIterator.new(narr, reverse: true, colex: true).each { |i| puts i }

    #   def next_if_nonempty
    #     (@coord.size - 1).downto(0) do |i| # ## least sig .. most sig
    #       @coord[i] += @step[i]
    #       break unless @coord[i] * @step[i].sign > @last[i] * @step[i].sign
    #       @coord[i] = @first[i]
    #       return stop if i == 0 # most sig
    #     end
    #     @coord
    #   end

# puts narr.view.reverse.permute

# class Array(T)
#     getter buffer : Pointer(T)
#     getter capacity : Int32

#     def clone_but_change_type(klass)
#         union_id = [Array.mock_type(T), Array.mock_type(klass)][0].crystal_type_id.to_u64

#         Array.new(size) do |idx|
#             {union_id, self.[idx]}.unsafe_as(T | klass)
#         end
#     end

#     def self.mock_type(klass : U.class) : U forall U
#         case klass
#         when Int
#             0.unsafe_as(klass)
#         else
#             klass.allocate
#         end
#     end
# end

# record A,
#     integer : Int32

# record B

# val = [A.new(1)]
# pp val

# val2 = val.clone_but_change_type(B)
# val2 << B.new
# puts typeof(val2)
# pp val2

# puts ["test"] + [1]


# data = [3, 5, "Hi"]

# puts typeof(data)
# data = data[0..2]
# puts data[0].crystal_type_id
# puts typeof(data)

# data = data.cast_to(Int32)
# puts typeof(data)
# puts data
# puts data[0].crystal_type_id

# value = 1u8 # no runtime type id
# value = [3, "hi"][0] # this has a type id

require "colorize"

def print_binary(pointer, byte_count)
    bytes = Bytes.new(pointer.unsafe_as(Pointer(UInt8)), byte_count)
    puts bytes.map { |byte| byte.to_s(16).rjust(8, ' ') }.join(" ")
    puts bytes.map { |byte| byte.to_s(10).rjust(8, ' ') }.join(" ")
    puts bytes.map { |byte| byte.to_s(2).rjust(8, '0') }.join(" ")
    puts bytes.map_with_index { |_, idx| idx.to_s.rjust(8, ' ') }.join(" ").colorize(:red)
    puts
end

# 1u8 # 0000001
# val = [1u32, 2u16].unsafe_fetch(0) # Random.rand > 0.000001f64 ? 10u32 : 2u16
# print_binary(pointerof(val), 8)

# if a variable ever has (before or after) a type ID, the type ID will stay even after a restriction
# if a variable has a single (non-union) type, it will not have a type ID (at least until modified)

# If it has a type id, there are 8 bytes preceeding?

# puts "plain integer"
# val = 0xabababab
# print_binary(pointerof(val), 12)

# puts "Array access with hardcoded int16"
# val2 = [val, 0i16][0] # val.unsafe_as(Int32 | Int16)
# print_binary(pointerof(val2), 12)

# puts "unsafe_as Int32|Int16"
# val3 = val.unsafe_as(Int32 | Int16)
# print_binary(pointerof(val3), 12)

# puts "array access with fake instance"
# val4 = [val, String.allocate][0]
# print_binary(pointerof(val4), 12)

# puts "synthetic value"
# typeid = val4.crystal_type_id
# val5 = {typeid.to_u64, val}
# print_binary(pointerof(val5), 12)
# puts val4.crystal_type_id
# puts String | Int32

# uval = 0x9987u16
# val = 0xffeeu16

# print_binary(pointerof(uval), 12)
# print_binary(pointerof(val), 12)

# puts uval.crystal_type_id
# puts val.crystal_type_id

# puts UInt16.crystal_type_id
#puts 1u8.unsafe_as(UInt8 | String)

# puts (Array(Int32 | String).new(5) do |idx|
#     1.unsafe_as(Int32 | String)
# end)


# puts [1,2,3].clone_but_change_type(String)



# val = 1u8
# print_binary(pointerof(val), 8)
# val = val.unsafe_as(UInt16)
# print_binary(pointerof(val), 8)
# exit 0

# #      32 32  32
# og_data = [1u32, 2u32, 3u32]
# pp og_data

# og_data.each do |el|
#     puts "0" * el.trailing_zeros_count  + el.to_s(base: 2)
# end

# data = og_data
# buffer = data.buffer
# capacity = data.capacity
# print_binary(buffer, capacity * sizeof(typeof(og_data[0])))
# # pp data.clone_but_change_type(Int128)

# # pp typeof(data.clone_but_change_type(Int128))

# data = og_data.clone_but_change_type(UInt64)
# puts typeof(data)
# buffer = data.buffer
# capacity = data.capacity
# print_binary(buffer, capacity * sizeof(typeof(og_data[0])))
# puts typeof(data[0]).crystal_type_id
# # puts (UInt64 | UInt32).crystal_type_id
# # puts (Class<UInt64 | UInt32>).crystal_type_id


# # 1                                   2                                   3 
# # 10000000 00000000 00000000 00000000 10000000 00000000 00000000 00000000 11000000 00000000 00000000 00000000
# # 10000000 00000000 00000000 00000000 00000000 00000000 00000000 00000000 11010000 10101100 00000000 00000000
# # 00000000 00000000 00000000 00000001

# # pp bytes

# # val = 1
# # pp val.unsafe_as(Int8 | Int32)

# # i32 size; i32 capacity; i32 offset_to_buffer

#   # In 64 bits the Array is composed then by:
#   # - type_id            : Int32   # 4 bytes -|
#   # - size               : Int32   # 4 bytes  |- packed as 8 bytes
#   #
#   # - capacity           : Int32   # 4 bytes -|
#   # - offset_to_buffer   : Int32   # 4 bytes  |- packed as 8 bytes
#   #
#   # - buffer             : Pointer # 8 bytes  |- another 8 bytes
#   #
#   # So in total 24 bytes. Without offset_to_buffer it's the same,
#   # because of aligning to 8 bytes (at least in 64 bits), and that's
#   # why we chose to include this value, because with it we can optimize
#   # `shift` to let Array be used as a queue/deque.
 
# #  00000001 00000000 00000000 00000000 00000010 00000000 00000000 00000000 00000011 00000000 00000000 00000000

# int = [10i32, 20i32, 30i32]
# str = ["hi", "hello", "goodbye"]

# int_ptr = int.to_unsafe
# str_ptr = str.to_unsafe

# buffer = Pointer(Int32 | String).malloc(6)
# buffer.copy_from(int_ptr, 3)
# (buffer + 3).copy_from(str_ptr, 3)

# puts Int32 < (Int32 | String)

class Array(T)
    def clone_with_other(klass : U.class) : Array(T | U) forall U
        Array(T | U).build(size) do |buffer|
            buffer.copy_from(@buffer, size)
            size
        end
    end

    def downcast(klass : U.class) : Array(U) forall U
        Array(U).build(size * 8) do |buffer|
            buffer.copy_from(@buffer.unsafe_as(Pointer(U)), size)
            size * 8
        end
    end
end

arr = [1, 2]
puts arr = arr.clone_with_other(String)
# arr << "hi"
# puts arr

puts arr.downcast(Int32)