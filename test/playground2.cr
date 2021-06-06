# Understanding the memory layout of union types

<<-DOC

While doing some low-level work in crystal, I started printing out some of my variables'
representation in binary. I am aware that union types are handled at runtime using a
32-bit type ID that prefixes the variable's data in memory. When I was printing out
this data, however, I found a second 32-bit value after the type ID and before the
variable data. I have no idea what it is, and haven't been able to find any information
about it.

Here's an example that shows what I'm talking about:

```crystal
def print_binary(pointer, byte_count)
    bytes = Bytes.new(pointer.unsafe_as(Pointer(UInt8)), byte_count)
    puts "hex: " + bytes.map { |byte| byte.to_s(16).rjust(2, '0').center(8, ' ') }.join(" ")
    puts "bin: " + bytes.map { |byte| byte.to_s(2).rjust(8, '0') }.join(" ")
end

puts "Because `val` is not a union type, there is no type id stored in memory for it."
val = 0x01234567_u32
print_binary(pointerof(val), 4)

puts

puts "Here, `val2` has a compile-time type of (UInt32 | UInt16), so a type id is stored"
val2 = [0x01234567_u32, 0xabcd_u16][0]
print_binary(pointerof(val2), 12)
puts "Type ID: 0x#{val2.crystal_type_id.to_s(base: 16)}"

puts "As you can see, the first word stores the little-endian type ID."
puts "The last word, '67 45 23 01', stores the little-endian version of 0x01234567." 
puts "However, there is a word between these two that is seemingly random."
```

When I run the program above on my computer, this is the output:

```
Because `val` is not a union type, there is no type id stored in memory for it.
hex:    67       45       23       01   
bin: 01100111 01000101 0010001  1 00000001

Here, `val2` has a compile-time type of (UInt32 | UInt16), so a type id is stored
hex:    a6       00       00       00       ba       55       00       00       67       45       23       01   
bin: 10100110 00000000 00000000 00000000 10111010 01010101 00000000 00000000 01100111 01000101 00100011 00000001
Type ID: 0xa6
As you can see, the first word stores the little-endian type ID.
The last word, '67 45 23 01', stores the little-endian version of 0x01234567.
However, there is a word between these two that is seemingly random.
```

What exactly is this middle value, and what purpose does it serve?

Thanks!

DOC

def print_binary(pointer, byte_count)
    bytes = Bytes.new(pointer.unsafe_as(Pointer(UInt8)), byte_count)
    puts "hex: " + bytes.map { |byte| byte.to_s(16).rjust(2, '0').center(8, ' ') }.join(" ")
    puts "bin: " + bytes.map { |byte| byte.to_s(2).rjust(8, '0') }.join(" ")
end

puts "Because `val` is not a union type, there is no type id stored in memory for it."
val = 0x01234567_u32
print_binary(pointerof(val), 4)

puts

puts "Here, `val2` has a compile-time type of (UInt32 | UInt16), so a type id is stored"
val2 = [0x01234567_u32, 0xabcd_u16][0]
print_binary(pointerof(val2), 12)
puts "Type ID: 0x#{val2.crystal_type_id.to_s(base: 16)}"

puts "As you can see, the first word stores the little-endian type ID."
puts "The last word, '67 45 23 01', stores the little-endian version of 0x01234567." 
puts "However, there is a word between these two that is seemingly random."


# 
# val = MyStruct.new
# print_binary(pointerof(val), 20)
# puts val.crystal_type_id
# 
# 
# uval = 0x9988u16
# val = 0xffeeu16
# 
# print_binary(pointerof(uval), 12)
# print_binary(pointerof(val), 12)
# 
# puts uval.crystal_type_id
# puts val.crystal_type_id