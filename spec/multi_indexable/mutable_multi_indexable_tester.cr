require "./multi_indexable_tester"

# This class performs a superset of the tests that `MultiIndexableTester`
# contains, adding read/write tests for `MultiIndexable::Mutable`.
#
# In addition to the caveats of `MultiIndexableTester`, this tester requires
# that mutations made to `M` must persist:
# ```crystal
# # Assignments must be persistent:
# m[coord] = value
# # arbitrary code that doesn't explicitly aim to modify m[coord]
# m.get(coord) == value # must be true
# ```
abstract class MutableMultiIndexableTester(M, T, I) < MultiIndexableTester(M, T, I)
  # :inherit:
  abstract def make : Array(M)

  # :inherit:
  abstract def make_pure_empty : M?

  # :inherit:
  abstract def make_volumetric_empty : M?

  # :inherit:
  abstract def make_pure_scalar : M?

  # :inherit:
  abstract def make_volumetric_scalar : M?

  # :inherit:
  abstract def test_make

  # :inherit:
  abstract def test_to_narr

  # *values* is an array with size equal to make_pairs.size,
  # and each nested array `values[i]` may contain a different number of values.
  # This method will yield every `pair, values[i][j]` where `pair` is
  # make_pairs[i]. `pair` can be mutated without affecting the `pair` that is
  # passed to subsequent calls - the instances of `M` and `NArray(T)` are
  # created fresh every time.
  #
  # This is a very convoluted method, but it is a common pattern in this
  # tester because many tests involve isolated mutation with a value that is
  # derived from the pair being mutated. For example, a region literal is
  # generated from an `M`, and then that region literal is used to set a chunk
  # of `M`. This is repeated, and we don't want the result of a previous test
  # to mutate the input data of the next test, so we need to call `make_pairs` to
  # keep things fresh.
  protected def broadcasted_zip_with_fresh_pairs(values : Array(Array), &block)
    iters = values.map &.each

    if iters.size != make_pairs.size
      raise "there must be one iterator for each pair"
    end

    loop do
      done = true

      make_pairs.zip(iters).each do |pair, iter|
        value = iter.next

        if value.is_a? Iterator::Stop
          next
        else
          yield pair, value
        end

        # If we've found a single value on any iter, we can keep going
        done = false
      end

      break if done
    end
  end

  def test_target
    # Run the tests for a standard MultiIndexableTester
    super

    describe M do
      pairs = make_pairs

      before_each do
        pairs = make_pairs
      end

      describe "#unsafe_set_element" do
        it "persistently sets an element at a given coordinate" do
          pairs.each do |m, n|
            first_el = n.first
            n.each_with_coord do |el, coord|
              next if el == first_el

              m[coord] = first_el
              if m.get(coord) != first_el
                fail("Assigning to m#{coord} failed (or the mutation was not persistent)")
              end
            end
          end
        end
      end

      describe "#unsafe_set_chunk" do
        # For each pair, create an iterator over valid region literals
        literals = pairs.map { |_, n| make_valid_regions(n.shape) }

        it "persistently sets a chunk to a given value" do
          # There aren't the same number of literals for each `M` instance, and
          # we need to generate fresh pairs evey time we mutate. That's why we
          # need to do this odd vector stepping until they're all checked
          broadcasted_zip_with_fresh_pairs(literals) do |pair, literal|
            m, n = pair
            first_el = n.first
            idx_r = IndexRegion.new(literal, n.shape)

            n.unsafe_set_chunk(idx_r, first_el)
            m.unsafe_set_chunk(idx_r, first_el)

            m.to_narr.should eq n
          end
        end

        it "persistently sets a chunk to the elements of another" do
          broadcasted_zip_with_fresh_pairs(literals) do |pair, literal|
            m, n = pair
            first_el = n.first
            idx_r = IndexRegion.new(literal, n.shape)

            # Generate a shuffled chunk
            new_chunk = NArray.build(idx_r.shape) { n.sample }

            n.unsafe_set_chunk(idx_r, new_chunk)
            m.unsafe_set_chunk(idx_r, new_chunk)

            m.to_narr.should eq n
          end
        end
      end

      {% begin %}
      {% for method in {:set_chunk, :[]=} %}
      describe "#" + {{method.id.stringify}} do
        # For each pair, create an iterator over valid region literals
        literals = pairs.map { |_, n| make_valid_regions(n.shape) }

        it "persistently sets a chunk to a given value" do
          broadcasted_zip_with_fresh_pairs(literals) do |pair, literal|
            m, n = pair
            first_el = n.first

            n.{{method.id}}(literal, first_el)
            m.{{method.id}}(literal, first_el)

            m.to_narr.should eq n
          end
        end

        it "persistently sets a chunk to the elements of another" do
          broadcasted_zip_with_fresh_pairs(literals) do |pair, literal|
            m, n = pair
            first_el = n.first
            idx_r = IndexRegion.new(literal, n.shape)

            # Generate a shuffled chunk
            new_chunk = NArray.build(idx_r.shape) { n.sample }

            n.{{method.id}}(idx_r, new_chunk)
            m.{{method.id}}(idx_r, new_chunk)

            m.to_narr.should eq n
          end
        end
      end
      {% end %}
      {% end %}

      describe "#set_available" do
        it "persistently sets a chunk to a given value" do
          # For each pair, create an iterator over valid region literals
          literals = pairs.map { |_, n| make_valid_regions(n.shape) }
          broadcasted_zip_with_fresh_pairs(literals) do |pair, literal|
            m, n = pair
            first_el = n.first

            n.set_available(literal, first_el)
            m.set_available(literal, first_el)

            m.to_narr.should eq n
          end
        end

        it "gets the available data from an oversized region" do
          pairs.each do |m, n|
            oversize_region = n.shape.map { |axis| (axis // 2)..(axis + 4) }
            value = n.sample

            n.set_available(oversize_region, value)
            m.set_available(oversize_region, value)

            m.to_narr.should eq n
          end
        end
      end
    end
  end
end
