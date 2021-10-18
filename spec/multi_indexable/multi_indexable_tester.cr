require "../spec_helper.cr"

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
  abstract def make : M

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

  private def make_pair : Tuple(M, NArray(T))
    m_inst = make
    {m_inst, m_inst.to_narr}
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
    }
  end

  def test_target
    describe M do
      m_inst, narr = make_pair

      valid_regions = make_valid_regions(narr.shape)
      invalid_regions = make_invalid_regions(narr.shape)

      before_each do
        m_inst, narr = make_pair
      end

      describe "#to_narr" do
        test_to_narr
      end

      # The tests we do on #empty? and #scalar? are almost identical. This is
      # mostly here to entertain me while I write specs
      {% for test in {:empty, :scalar} %}
        describe("#" + "{{test.id}}?") do
          it "returns false when not {{test.id}}" do
            m_inst.{{test.id}}?.should be_false
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

      {% for method in {:get_chunk} %}
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

      # describe "#get_available" do
      #   it "returns the correct output for a simple region literal" do
      #     expected_buffer = Slice[3, 'c', 3f64]
      #     r_narr.get_available([0..8, 5..-3..2]).buffer.should eq expected_buffer
      #   end
    
      #   it "returns the correct output for a simple region literal (tuple accepting)" do
      #     expected_buffer = Slice[3, 'c', 3f64]
      #     r_narr.get_available(0..8, 5..-3..2).buffer.should eq expected_buffer
      #   end
    
      #   it "returns the correct output for an IndexRegion" do
      #     expected_buffer = Slice[3, 'c', 3f64]
      #     idx_r = IndexRegion(Int32).new([0..8, 5..-3..2])
      #     r_narr.get_available(idx_r).buffer.should eq expected_buffer
      #   end
      # end
    end
  end
end
