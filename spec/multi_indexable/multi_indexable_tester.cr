require "../spec_helper.cr"

# This class implements an abstract test suite that verifies your
# `MultiIndexable ` implementation (`M`) against the standard `NArray(T)` type.
# This suite relies only on the correctness of `NArray(T)` and `M#to_narr`,
# which leads to some complications. For example, if a test should be run only
# on equal `MultiIndexables`, `m_inst_1 == m_inst_2` is not the correct
# condition - if the implementation `M` incorrectly implements equality, this
# will return false, creating a red herring. Instead. use `m_inst_1.to_narr ==
# m_inst_2.to_narr`. This will always return the correct value, given that
# `NArray#==` and `#to_narr` are implemented correctly, which is somewhat
# axiomatic. `I` is the index type of `M` - `M#shape` has elements of type `I`.
abstract class MultiIndexableTester(M, T, I)
  # Produces a new instance of `M`, which is a MultiIndexable.
  # If `M` has a generic element type, it is good idea to return
  # a union type (like `NArray(Int32 | Char)`) here, as
  # certain memory bugs could pass through otherwise.
  # Additionally, avoid returning a trivial instance at all costs - for example,
  # returning `NArray[[0, 0], [0, 0]]` is awful for testing, because there is
  # no way to distinguish between the elements. Must return a MultiIndexable
  # with more than one element! The shape can be anything you want, but
  # we reccommend something like [3, 4, 5] (3 dimensions captures most complex
  # behaviour, and differing extents >=3 allow for more robust bug detection)
  abstract def make : Array(M)

  # If your `MultiIndexable` supports it, this should return a pure empty container (`#shape.to_a == [0]`). If not, return nil.
  abstract def make_pure_empty : M?

  # If your `MultiIndexable` supports it, this should return an empty container (its shape should contain at least one zero and at least one positive integer). If not, return nil.
  abstract def make_volumetric_empty : M?

  # If your `MultiIndexable` supports it, this should return a container with only a single element (dimensions are unrelated). If not, return nil,
  abstract def make_pure_scalar : M?

  # If your `MultiIndexable` supports it, this should return a container with only a single element (dimensions are unrelated). If not, return nil.
  abstract def make_volumetric_scalar : M?

  # It isn't possible to test `#make` without domain knowledge of your `MultiIndexable`.
  # Because it is so critical, you must write a test for it here. This function
  # will be called from within a `describe "#make"` block, so you'll want to
  # write tests contained in `it` calls.
  abstract def test_make

  # It isn't possible to test `#to_narr` without domain knowledge of your `MultiIndexable`.
  # Because it is so critical, you must write a test for it here. This function
  # will be called from within a `describe "#to_narr"` block, so you'll want to
  # write tests contained in `it` calls.
  abstract def test_to_narr

  {% for category in {:pure_empty, :volumetric_empty, :pure_scalar, :volumetric_scalar} %}
  # If it is possible to construct one, invokes the block with a {{category.id}} {{@type}}.
  private def get_{{category.id}}(&block : M -> )
    if inst = make_{{category.id}}
      yield inst
    end
  end
  {% end %}

  # Yields an empty {{@type}} once if possible.
  # Attempts to provide a volumetric one first, then falls back to scalar.
  private def get_empty(&block : M ->)
    if inst = make_volumetric_empty || make_pure_empty
      yield inst
    end
  end

  # Yields a scalar {{@type}} once if possible.
  # Attempts to provide a volumetric one first, then falls back to scalar.
  private def get_scalar(&block : M ->)
    if inst = make_volumetric_scalar || make_pure_scalar
      yield inst
    end
  end

  # Runs the test suite for `MultiIndexable` on the provided data type
  def self.run
    new.run
  end

  def run
    test_integrity
    test_target
  end

  private def test_integrity
    describe typeof(self) do
      describe "#{M}#make" do
        test_make
      end

      get_pure_empty do |inst|
        describe "#{M}#make_pure_empty" do
          it "returns the correct shape" do
            inst.shape.to_a.should eq [0]
          end
        end
      end

      get_volumetric_empty do |inst|
        describe "#{M}#make_volumetric_empty" do
          it "returns the correct shape" do
            make_volumetric_empty.shape.includes?(0).should be_true
          end
        end
      end

      if make_pure_scalar
        describe "#{M}#make_pure_scalar" do
          it "returns the correct shape" do
            make_pure_scalar.not_nil!.shape.to_a.should eq [1]
          end
        end
      end

      if make_volumetric_scalar
        describe "#{M}#make_volumetric_scalar" do
          it "returns the correct shape" do
            make_volumetric_scalar.not_nil!.shape.all? { |size| size == 1 }.should be_true
          end
        end
      end
    end
  end

  private def make_pairs : Array(Tuple(M, NArray(T)))
    make.map { |m_inst| {m_inst, m_inst.to_narr} }
  end

  private def make_valid_regions(shape : Indexable(I))
    {
      # Cover the whole region
      shape.map { |axis| 0...axis },

      # Contiguous section of whole region, shifted start
      shape.map do |axis|
        if axis > 1
          1...axis
        else
          0...axis
        end
      end,

      # Contiguous section of whole region, shifted end
      shape.map do |axis|
        if axis > 2
          0...axis - 1
        else
          0...axis
        end
      end,

      # Region with >1 stride
      shape.map { |axis| 0..2...axis },

      # Region with negative stride
      shape.map { |axis| (axis - 1)..-2..0 },

      # Full-region specifiers
      [..] * shape.size,
      [] of I,
      [] of Range(Nil, Nil),
    }
  end

  private def make_invalid_regions(shape : Indexable(I))
    {
      # Region that's too positively large
      shape.map { |axis| axis..(2 * axis) },

      # Region with the wrong number of dimensions
      shape.map { |axis| 0...axis } + [0..0],

      # Region that is too negatively large
      shape.map { |axis| (-axis - 1)... },

      # Region that starts in bounds but is too large
      shape.map { |axis| (axis // 2)..(axis + 3) },

      # Region who's stride and bounds are misaligned
      shape.map { |axis| axis..1..0 },
    }
  end

  # `#slices` and `#each_slice` have effectively the same API, and can
  # both be tested in this way.
  macro test_each_slice(name)
    it "returns axis zero slices by default" do
      m_inst.{{name.id}}.to_a.map(&.to_narr).should eq narr.slices 
    end

    it "returns the correct slices along each axis as an Enumerable" do
      narr.dimensions.times do |axis|
        expected_slices = narr.each_slice(axis)
        actual_slices = m_inst.{{name.id}}(axis)
        count = 0

        actual_slices.zip(expected_slices) do |actual_slice, expected_slice|
          actual_slice.to_narr.should eq expected_slice
          count += 1
        end

        count.should eq narr.shape[axis]
      end
    end
  end

  def test_target
    describe M do
      pairs = make_pairs
      m_inst, narr = pairs[0]

      valid_regions = make_valid_regions(narr.shape)
      invalid_regions = make_invalid_regions(narr.shape)

      before_each do
        pairs = make_pairs
        m_inst, narr = pairs[0]
      end

      describe "#to_narr" do
        test_to_narr
      end

      # The tests we do on #empty? and #scalar? are almost identical. This is
      # mostly here to entertain me while I write specs
      {% for test in {:empty, :scalar} %}
        describe("#" + "{{test.id}}?") do
          it "returns false when not {{test.id}}" do
            pairs.each do |m, _|
              m.{{test.id}}?.should be_false
            end
          end

          {% for type in [:pure, :volumetric] %}
            {% inst_name = "#{type.id}_#{test.id}".id %}
            if {{inst_name.id}} = make_{{type.id}}_{{test.id}}
              it "returns true for a {{type.id}} {{test.id}}" do
                {{inst_name.id}}.{{test.id}}?.should be_true
              end
            end
          {% end %}
        end
      {% end %}

      describe "#to_scalar" do
        it "raises for a non-scalar #{M}" do
          expect_raises ShapeError do
            m_inst.to_scalar
          end
        end

        get_pure_scalar do |inst|
          it "converts a one-dimensional scalar to its value" do
            inst.to_scalar.should eq inst.to_narr.first
          end
        end

        get_volumetric_scalar do |inst|
          it "converts a multidimensional scalar to its value" do
            inst.to_scalar.should eq inst.to_narr.first
          end
        end
      end

      describe "#first" do
        it "returns the element at the zero coordinate from a populated #{M}" do
          m_inst.first.should eq narr.first
        end

        get_empty do |inst|
          it "raises an ShapeError when there are no elements" do
            expect_raises(ShapeError) do
              inst.first
            end
          end
        end
      end

      describe "#sample" do
        get_scalar do |inst|
          it "returns the only element in a one-element #{M}" do
            inst.sample.should eq inst.to_narr.first
          end
        end

        it "raises when given a negative sample count" do
          expect_raises ArgumentError do
            m_inst.sample(-1)
          end
        end

        get_empty do |inst|
          it "raises when called on an empty MultiIndexable" do
            expect_raises ShapeError do
              inst.sample
            end
          end
        end
      end

      describe "#dimensions" do
        it "returns the correct number of dimensions" do
          m_inst.dimensions.should eq narr.dimensions
        end
      end

      describe "#has_coord?" do
        it "returns true for a coordinate within the shape" do
          all_coords_lex_order(m_inst.shape) do |(row, col)|
            m_inst.has_coord?([row, col]).should be_true
            m_inst.has_coord?(row, col).should be_true
          end
        end

        it "returns false for a coordinate outside the shape" do
          oversized_shape = m_inst.shape.map &.+(2)
          proper_coords = all_coords_lex_order(m_inst.shape)

          all_coords_lex_order(oversized_shape) do |(row, col)|
            next if proper_coords.includes? [row, col]

            m_inst.has_coord?([row, col]).should be_false
            m_inst.has_coord?(row, col).should be_false
          end
        end

        it "returns false when the coordinate is of the wrong dimension" do
          m_inst.has_coord?([0]).should be_false
          m_inst.has_coord?(0).should be_false
        end
      end

      describe "#has_region?" do
        it "returns true for valid literal regions", tags: ["bad"] do
          make_valid_regions(m_inst.shape).each do |region|
            unless m_inst.has_region?(region)
              fail(m_inst.shape.join("x") + " #{M} should include #{region}, but has_region? was false")
            end
          end
        end

        it "returns false for invalid regions" do
          make_invalid_regions(m_inst.shape).each do |region|
            if m_inst.has_region?(region)
              fail(m_inst.shape.join("x") + " #{M} should not include #{region}, but has_region? was true")
            end
          end
        end

        it "returns true for valid IndexRegions" do
          make_valid_regions(m_inst.shape).each do |region_literal|
            idx_r = IndexRegion.new(region_literal, m_inst.shape)

            unless m_inst.has_region?(idx_r)
              fail(m_inst.shape.join("x") + " #{M} should include #{idx_r}, but has_region? was false")
            end
          end
        end

        it "returns false for invalid IndexRegions" do
          # Note: We want to use valid regions (so that IndexRegions can be constructed),
          # and then make them invalid for this shape by translating them massively.
          # TODO: I'm not sure what happens here if you make an IndexRegion that
          # spans zero elements, or if that's even possible.
          make_valid_regions(m_inst.shape).each do |region_literal|
            idx_r = IndexRegion.new(region_literal, m_inst.shape).translate!(m_inst.shape)

            if m_inst.has_region?(idx_r)
              fail(m_inst.shape.join("x") + " #{M} should not include #{idx_r}, but has_region? was true")
            end
          end
        end
      end

      {% for method in {:get, :get_element} %}
        describe "#" + {{method.id.stringify}} do
          it "returns the correct element for all valid coordinates" do
            all_coords_lex_order(m_inst.shape) do |coord|
              expected_elem = narr.{{method.id}}(coord)
              actual = m_inst.{{method.id}}(coord)

              # Note: This architecture cannot test the tuple version, because
              # the number of dimensions is not known at compile-time.
              if actual != expected_elem
                fail("Indexable accepting verision failed: #" + "narr.{{method.id}}(#{coord}) should have been #{expected_elem}, but was #{actual}")
              end
            end
          end

          it "raises for for invalid coordinates" do
            oversized_shape = narr.shape.map &.+(2)
            proper_coords = all_coords_lex_order(narr.shape)

            all_coords_lex_order(oversized_shape) do |coord|
              next if proper_coords.includes? coord

              expect_raises IndexError do
                m_inst.{{method.id}}(coord)
              end
            end
          end

          it "raises for coordinates with too many dimensions", do
            expect_raises(DimensionError) do
              m_inst.{{method.id}}(narr.shape.map &.pred + [0])
            end
          end

          it "raises for coordinates with too few dimensions" do
            expect_raises(DimensionError) do
              m_inst.{{method.id}}([0] * (narr.dimensions - 1))
            end
          end
        end
      {% end %}

      {% for method in {:get_chunk, :[]} %}
        describe "#" + {{method.id.stringify}} do
          it "returns a chunk for each valid region" do
            {true, false}.each do |drop|
              make_valid_regions(narr.shape).each do |region_literal|
                expected = narr.{{method.id}}(region_literal, drop: drop)
                actual = m_inst.{{method.id}}(region_literal, drop: drop)

                actual.to_narr.should eq expected
              end
            end
          end

          it "returns a chunk for each valid indexregion" do
            {true, false}.each do |drop|
              make_valid_regions(narr.shape).each do |region_literal|
                idx_r = IndexRegion.new(region_literal, bound_shape: narr.shape, drop: drop)
                expected = narr.{{method.id}}(idx_r)
                actual = m_inst.{{method.id}}(idx_r)

                actual.to_narr.should eq expected
              end
            end
          end

          pending "does something appropriate when you pass an IndexRegion but also give drop" do
            # right now, this gives a very confusing error because it gets caught by the tuple
            # accepting overload of #get_chunk (get_chunk(*tuple, drop)), and then tries
            # to canonicalize IndexRegion :p
            #
            # I propose we either add a get_chunk(_ : IndexRegion, drop : Bool) that either
            # does { % raise % } or overrides the degeneracy of the IndexRegion.
            {true, false}.each do |drop|
              make_valid_regions(narr.shape).each do |region_literal|
                idx_r = IndexRegion.new(region_literal, bound_shape: narr.shape, drop: drop)
                actual = m_inst.{{method.id}}(idx_r, drop: true)
              end
            end
          end
        end
      {% end %}

      describe "#get_available" do
        oversize_region = narr.shape.map { |axis| (axis // 2)..(axis + 4) }

        it "returns the same result as get_chunk for valid regions" do
          make_valid_regions(narr.shape).each do |region|
            m_inst.get_available(region).to_narr.should eq narr.get_chunk(region)
          end
        end

        it "returns a partial result for an oversize region" do
          m_inst.get_available(oversize_region).to_narr.should eq narr.get_available(oversize_region)
        end

        it "returns the correct output for valid IndexRegions" do
          make_valid_regions(narr.shape).each do |region|
            idx_r = IndexRegion.new(region, m_inst.shape)
            m_inst.get_available(idx_r).to_narr.should eq narr.get_available(idx_r)
          end
        end

        it "returns a partial result for an oversize region" do
          idx_r = IndexRegion(I).new(oversize_region)
          m_inst.get_available(idx_r).to_narr.should eq narr.get_available(idx_r)
        end
      end

      describe "#[]?(region)" do
        it "returns a chunk for each valid region" do
          make_valid_regions(narr.shape).each do |region|
            m_inst[region]?.try(&.to_narr).should eq narr[region]?
          end
        end

        it "returns a chunk for each valid indexregion" do
          make_valid_regions(narr.shape).each do |region|
            idx_r = IndexRegion.new(region, m_inst.shape)
            m_inst[idx_r]?.try(&.to_narr).should eq narr[idx_r]?
          end
        end

        it "returns nil for invalid regions" do
          make_invalid_regions(narr.shape).each do |region|
            m_inst[region]?.should be_nil
          end
        end
      end

      describe "#[]?(mask)" do
        it "raises a ShapeError for mismatched mask size" do
          mask = NArray.fill(m_inst.shape + [2], false)

          expect_raises ShapeError do
            m_inst[mask]?
          end
        end

        it "returns nil where the mask is false and the copied element where the mask is true" do
          mask = NArray.build(m_inst.shape) { |_, i| i % 2 == 0 }
          m_inst[mask]?.to_narr.should eq narr[mask]?
        end
      end

      describe "#each_coord" do
        it "yields only the correct coordinates in the correct order" do
          m_inst.each_coord.to_a.should eq narr.each_coord.to_a
        end
      end

      describe "#colex_each_coord" do
        it "yields only the correct coordinates in the correct order" do
          m_inst.colex_each_coord.to_a.should eq narr.colex_each_coord.to_a
        end
      end

      describe "#each" do
        it "yields all elements in lexicographic order" do
          elem_iter = narr.each

          m_inst.each do |el|
            el.should eq elem_iter.next
          end

          elem_iter.empty?.should be_true
        end

        it "provides an iterator over every element in lexicographic order" do
          elem_iter = m_inst.each

          narr.each do |el|
            el.should eq elem_iter.next
          end

          elem_iter.empty?.should be_true
        end
      end

      describe "#colex_each" do
        it "yields all elements in colexicographic order" do
          elem_iter = narr.colex_each

          m_inst.colex_each do |el|
            el.should eq elem_iter.next
          end

          elem_iter.empty?.should be_true
        end

        it "provides an iterator over every element in colexicographic order" do
          elem_iter = m_inst.colex_each

          narr.colex_each do |el|
            el.should eq elem_iter.next
          end

          elem_iter.empty?.should be_true
        end
      end

      describe "#each_with_coord" do
        it "yields all elements and coordinates in lexicographic order" do
          iter = narr.each_with_coord

          m_inst.each_with_coord do |el|
            el.should eq iter.next
          end

          iter.empty?.should be_true
        end

        it "iterates over all elements and coordinates in lexicographic order" do
          iter = m_inst.each_with_coord

          narr.each_with_coord do |el|
            el.should eq iter.next
          end

          iter.empty?.should be_true
        end
      end

      describe "#fast_each" do
        it "returns all the elements in whatever order" do
          # NOTE: This set testing only works because there are no duplicate items in r_narr.
          m_inst.fast_each.to_a.tally.should eq narr.fast_each.to_a.tally
        end

        it "provides a block form" do
          arr = [] of typeof(m_inst.first)
          m_inst.fast_each { |e| arr << e }
          arr.tally.should eq narr.fast_each.to_a.tally
        end
      end

      describe "#each_slice" do
        test_each_slice(:each_slice)

        it "works with a block" do
          narr.dimensions.times do |axis|
            expected_slices = narr.each_slice(axis)
            m_inst.each_slice(axis) do |slice|
              slice.to_narr.should eq expected_slices.next
            end

            expected_slices.empty?.should be_true
          end
        end
      end

      describe "#slices" do
        test_each_slice(:slices)
      end

      describe "#reshape" do
        it "returns a reshaped MultiIndexable containing the same elements" do
          m_inst.reshape([narr.size]).to_narr.should eq narr.reshape(narr.size)
        end

        it "raises a ShapeError for incompatible shapes" do
          expect_raises(ShapeError) do
            m_inst.reshape([narr.size, 2])
          end
        end
      end

      describe "#permute" do
        it "returns a permuted MultiIndexable containing the same elements" do
          pattern = narr.dimensions.times.to_a # [0, 1, 2, .., narr.dimensions - 1]
          pattern.rotate! # [1, 2, .., narr.dimensions - 1, 0]

          m_inst.permute(pattern).to_narr.should eq narr.permute(pattern)
        end

        it "raises an IndexError for illegal permutation indices" do
          pattern = narr.dimensions.times.to_a
          pattern[-1] = narr.dimensions
          pattern.rotate!

          expect_raises(IndexError) do
            m_inst.permute(pattern)
          end
        end

        pending "raises an IndexError for repeated permutation indices" do
          # TODO: We may actually want to allow this behaviour? I'm not sure.
          expect_raises(ArgumentError) do
            m_inst.permute([0] * narr.dimensions)
          end
        end
      end

      describe "#reverse", tags: ["yikes"] do
        it "returns a MultiIndexable with reversed element order" do
          m_inst.reverse.to_narr.should eq narr.reverse
        end
      end

      describe "#equals?" do
        it "returns true if the block always does" do
          m_inst.equals?(m_inst) { true }.should be_true
        end

        it "returns false for MultiIndexables of a different shape" do
          bigger = narr.tile([2] + [1] * (m_inst.dimensions - 1))
          m_inst.equals?(bigger) { true }.should be_false
        end

        it "iterates over elements of both inputs" do
          other = narr.map &.hash
          
          m_bag = [] of T
          other_bag = [] of typeof(narr.first.hash)

          m_inst.equals?(other) do |m, o|
            m_bag << m
            other_bag << o
            true
          end

          m_bag.tally.should eq narr.to_a.tally
          other_bag.tally.should eq other.to_a.tally
        end
      end

      describe "#view" do
        it "creates a View of the source MultiIndexable" do
          # we aren't testing the functionality of the view here - only that #view
          # creates what we're expecting.

          m_inst.view.is_a?(View).should be_true
        end
      end

      describe "#process" do
        it "creates a ProcView fo the source MultiIndexable" do
          # we aren't testing the functionality of the view here - only that #process
          # creates what we're expecting.

          m_inst.process { |el| el.hash }.is_a?(ProcView).should be_true
        end
      end

      describe "#eq" do
        it "returns a MultiIndexable containing elementwise equality with another MultiIndexable" do
          comparison_narr = NArray.fill(narr.shape, narr.first)
          m_inst.eq(comparison_narr).to_narr.should eq narr.eq(comparison_narr)
        end

        it "raises a DimensionError for an NArray of a different shape" do
          bigger = narr.tile([2] + [1] * (m_inst.dimensions - 1))

          expect_raises(DimensionError) do
            m_inst.eq(bigger)
          end
        end

        it "returns an NArray containing elementwise equality with a scalar" do
          comparison_el = narr.first
          m_inst.eq(comparison_el).to_narr.should eq narr.eq(comparison_el)
        end
      end

      # TODO: I don't think that testing #hash is really in our jurisdiction
      # For example, if someone makes a wierd type, like an NArray with a creation
      # timestamp, or an image buffer with a list of color channel names, the'll
      # probably want #hash to include that extra data. I imagine that #hash and #==
      # are up to the implementation, whereas #equals?(&predicate) is actually useful
      # for comparing elementwise equality
      # describe "#hash" do
      #   it "returns different hashes for different MultiIndexables", tags: ["probabilistic"] do
      #     pool = make
      #     pool.each_cartesian(pool) do |m1, m2|
      #       if m1 != m2
      #         m1.hash.should_not eq m2.hash
      #       end
      #     end
      #   end
      # 
      #   it "returns the same hash for identical MultiIndexables" do
      #     m1 = make[0]
      #     m2 = make[0]
      #     m1.hash.should eq m2.hash
      #   end
      # end

      describe "#tile" do
        it "tiles a MultiIndexable into a larger one" do
          pattern = narr.shape.map_with_index { |_, idx| (idx % 2) + 1 }
          m_inst.tile(pattern).to_narr.should eq narr.tile(pattern)
        end
      end

      # describe "arithmetic" do
      # end

      # describe "Enumerable methods" do
      #   # If we are confident enough in our #each testing we can
      #   # get rid of this
      # end
    end
  end
end
