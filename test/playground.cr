require "../src/lattice"

include Lattice

yaml = <<-YAML
---
indent_width: 4
max_element_width: 20
omit_after:
- 10
- 5
brackets:
- - '['
  - ']'
colors: 
- red
- FF8000
collapse_brackets_after: 5
YAML

# ctx = YAML::ParseContext.new
# node = YAML::Nodes::Scalar.new("test")
# puts typeof(MultiIndexable::Formatter::Settings::ColorConverter.from_yaml(ctx, node)) # .from_yaml(yaml)

narr = NArray.build([5, 5]) { |_, i| i }
puts narr
alias F = MultiIndexable::Formatter
F::Settings.project_settings = F::Settings.from_yaml(yaml)

puts narr
