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
  private def get_empty(&block : M -> )
    if inst = make_volumetric_empty || make_pure_empty
      yield inst
    end
  end

  # Yields a scalar {{@type}} once if possible.
  # Attempts to provide a volumetric one first, then falls back to scalar.
  private def get_scalar(&block : M -> )
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
          0...axis-1
        else
          0...axis
        end
      end,

      # Region with >1 stride
      shape.map { |axis| 0..2..axis },

      # Region with negative stride
      shape.map { |axis| axis..-2..0 },

      # Region with 

      [] of I,
      [] of Range(Nil, Nil)
    }
  end

  private def make_invalid_regions(shape : Indexable(I)) : Array
    regions = [] of IndexRegion(I)

    regions << IndexRegion.cover(shape).translate!(shape)
  end

  def test_target
    describe M do
      m_inst, narr = make_pair

      valid_regions = make_valid_regions(narr.shape)
      invalid_regions = make_invalid_regions(narr.shape)

      puts valid_regions
      puts invalid_regions

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
        it "returns the element at the zero coordinate from a populated MultiIndexable" do
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
    end
  end
end
