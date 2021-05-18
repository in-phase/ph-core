my_settings = FormatterSettings.new 
my_settings.cascade_height = 4
my_settings.colors_enabled = true
my_settings.indent = 3
my_settings.brackets = [{"〈", "〉"}, {"❮", "❯"}, {"❰", "❱"}]
my_settings.colors = [:red, :yellow, :green, :blue]
my_settings.display_elements = [4]

my_settings = FormatterSettings.new 

my_narr = NArray.build([10,10,10,10,10]) {|c, i| i}

dur = Time.measure do 
    Formatter.print(my_narr, my_settings)
end
puts dur

# small_narr = NArray.build([3,3,3]) {|c,i| i}
# Formatter.print_literal(small_narr)

# puts narr # read formatter settings from your computer, print according to those
# # first check project directory for config file
# # checks your system config
# # uses default
# format = FormatterSettings...
# narr.to_s(io, format)

# first thing in printing a blocK: check the number of columns
# if there are too many, print the first few, a separator, and the last few
# always check if the element character cot fits, if not, substring and append ...un