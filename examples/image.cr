require "stumpy_png/src/stumpy_png"
require "../src/lattice.cr"

include StumpyPNG
include Lattice

canvas = StumpyPNG.read("rainbow.png")

narr = canvas.to_narr

narr[20..200, 50..100, 1] = narr[20..200, 50..100, 1] // 2
narr[20...220, 20...220, 2..0] = narr[220...20, 20...220, 2..-1..0]

edited = Canvas.new(narr)

StumpyPNG.write(edited, "output.png")

class StumpyCore::Canvas
    def initialize(narr : NArray(UInt16))
        @height, @width = narr.shape
        @pixels = narr.buffer.clone.unsafe_as(Slice(RGBA))
    end

    def to_narr : NArray(UInt16)
        NArray.new(
            [@height, @width, 4],
            Slice.new(@pixels.to_unsafe.unsafe_as(Pointer(UInt16)), @pixels.size * 4).clone
        )
    end
end