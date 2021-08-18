require "../src/main.cr"
require "benchmark"
require "./*"

# things to disambiguate:
    # what specific function you called
    # what exact code you were benchmarking (shape etc)

describe "Narray"
    describe "my_method"
        it "best_case"

# semantically useful tags (best case)
# information-dense tags (identity_matrix)

describe "unsafe_fetch_identity_matrix v2" do
    explain "compares the speed of MultiIndexables getting [1...3, 1...3] from a 5x5 identity matrix"
    shape = [5, 5]
    test_is do |args|
        test_unsafe_fetch()
    end

    for "NArray" do
        narr = NArray.build(shape) { |c, i| (c[0] == c[1]).to_unsafe }
        run_test_on(narr)
    end

    for "Sparse" do
    end
end



# benchmarks run
# benchmarks compare now HEAD~5 --filter unsafe_fetch_identity_matrix
# benchmarks show
# benchmarks show NArray

# option 1: just have a function
def test_unsafe_fetch
end

NArray:
    "#unsafe_fetch_chunk":
        "best_case v1":
            mean: 5
        worst_case:
            ...
        medium_case:
            ...
        std8:
            mean: 5
Sparse:
    "#unsafe_fetch_chunk":
        best_case:

# we can't uniquely identify what the test does, when it was written, what method it uses, the context it was written in all at once.
# the best we can hope for is that this tool points out changes between versions that you weren't already watching out for.

"NArray#unsafe_fetch_chunk, best_case":
    mean: 5
"NArray#unsafe_fetch_chunk":
    mean: 5

unsafe_fetch_chunk:
    NArray:
        mean: 5
    MultiIndexable:
        mean: 8

class Job < Benchmark::IPS::Job
    alias IPS = Benchmark::IPS
    class_property all_entries : Array(IPS::Entry) = [] of IPS::Entry

    def report
        max_label = ran_items.max_of &.label.size
        max_compare = ran_items.max_of &.human_compare.size
        max_bytes_per_op = ran_items.max_of &.bytes_per_op.humanize(base: 1024).size
        @@all_entries
        ran_items.each do |item|
            @@all_entries << item
        end 
    end
end

def benchmark(name, calculation, warmup, block)
    job = SpecJob.new(calculation, warmup, interactive: false)

    job.report(Foo.name) do 
        block.call
    end

    job.execute
    job.report
end

def benchmark(name="", calculation = 5, warmup = 2, &block)
    benchmark(name, calculation, warmup, block)
end

describe "NArray#fetch_chunk" do
    it "works for valid inputs" do
        # do slow prep here
        n = 5

        benchmark do
            square(n).should eq 25
        end
    end

    it "fails for invalid inputs" do
        # do slow prep here
        n = 5

        benchmark do
            square(n).should eq 25
        end
    end
end

benchmark "NArray" do
    it "fetch_chunk", faster_than: "MultiIndexable#fetch_chunk" do
    end
end