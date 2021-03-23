require "stumpy_png/src/stumpy_png"
require "../src/lattice.cr"

include StumpyPNG
include Lattice

canvas = StumpyPNG.read("rainbow.png")

narr = canvas.to_narr

narr[.., ..] = narr[.., .., 1]
# narr[20...220, 20...220] = narr[220...20, 20...220]

edited = Canvas.new(narr)

StumpyPNG.write(edited, "output.png")

class StumpyCore::Canvas
    def initialize(narr : NArray(UInt16))
        shape = narr.shape
        buffer = narr.buffer
        @height, @width = shape[0], shape[1]
        
        @pixels = Slice(RGBA).new(@height * @width) do |idx|
            RGBA.new(buffer[3 * idx], buffer[3 * idx + 1], buffer[3 * idx + 2])
        end
    end

    def to_narr : NArray(UInt16)
        buf = Slice(UInt16).new(@pixels.size * 3, 0u16)
        shape = [@height, @width, 3]

        @pixels.each_with_index do |rgba, idx|
            start = 3 * idx
            buf[start] = rgba.r
            buf[start + 1] = rgba.g
            buf[start + 2] = rgba.b
        end

        NArray.new(shape, buf)
    end
end