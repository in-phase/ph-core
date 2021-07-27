# require "../src/lattice"
# require "./*"

# # inside a different file (view_bench.cr)
# run do
#     #
# end

# # main file
# runs all the blocks
# saves all the results

# option 1: the main file literally just calls crystal run on each benchmark and saves results
# - there's no global state
# - super slow
# - if one part crashes not all of it does

# require "spec"

# # report_dir = some_path
# #stdout = something
# # OUTFILE = File.new("test.txt", mode: "w")
# # OUTFILE << "test string"
# class WrappedIO
#     property io : IO
#     def initialize(@io)
#     end

#     forward_missing_to @io
# end

# OUTFILE = WrappedIO.new(File.new("test.txt", mode: "w"))

# puts "testing!!!"

# OUTFILE.flush
# def puts(*objects) : Nil
#   OUTFILE.puts *objects
#   OUTFILE.flush
# end

# module Spec::Methods
#     def report(description, file = __FILE__, line = __LINE__, end_line = __END_LINE__, focus : Bool = false, tags : String | Enumerable(String) | Nil = nil, &block)
#         OUTFILE.io = File.new("#{description}.txt", mode: "w")
#         describe(description.to_s, file, line, end_line, focus, tags, &block)
#     end
# end

# report "hi" do
#     it "does something!" do
#         puts "HasdfasdfI"
#     end
# end

# report "mike" do
#     it "does something!" do
#         puts "mike!!!"
#     end
# end

# module Spec
#     def self.finish_run
#         elapsed_time = Time.monotonic - @@start_time.not_nil!
#         root_context.finish(elapsed_time, @@aborted)
#         # OUTFILE.flush
#         exit 1 if !root_context.succeeded || @@aborted
#     end
# end

class Benchmarks
  class_property procs : Array(Proc(Nil)) = [] of Proc(Nil)
end

Benchmarks.procs << ->{ puts "wow!" }
Benchmarks.procs << ->{ puts "whoa" }

macro finished
    Benchmarks.procs.each &.call
end
