require "./spec_helper"

# include Lattice::RegionUtil

pending "Lattice::RegionUtil" do
  
  pending ".has_region?" do
    it "rejects region specifiers of the wrong dimensionality" do
    end
  end
  
  pending ".canonicalize_range" do
    it "creates a SteppedRange" do
    end
    # see SteppedRange.new
  end
  pending ".canonicalize_region" do
    it "infers implicit trailing ranges" do
    end
  end
  describe ".measure_canonical_region" do
    # TODO: check for robustness
    regions = [
      canonicalize_region([1..4..20, 7...2, ..], [30, 10, 10]),
      canonicalize_region([1..1, 5..5, 3..3], [30, 10, 10]),
    ]
    it "generates a shape of same dimensionality as the region" do
      regions.each do |region|
        measure_canonical_region(region).size.should eq region.size
      end
    end
    it "measures correctly" do
      measure_canonical_region(regions[0]).should eq [5, 5, 10]
      measure_canonical_region(regions[1]).should eq [1, 1, 1]
    end
  end
  describe ".measure_region" do
    # TODO: check for robustness
    regions = [[1..4..20, 7...2], [1..1, 5..5, 3..3]]
    shape = [30, 10, 10]
    it "generates a shape of the same dimensionality as the input shape" do
      regions.each do |region|
        measure_region(region, shape).size.should eq shape.size
      end
    end
    # see canonicalize region, measure_canonical_region
  end

  pending ".compatible_shapes" do 
  end

  pending ".full_region" do 
  end

  pending ".translate_shape" do 
  end

  pending ".trim_region" do
  end
end
