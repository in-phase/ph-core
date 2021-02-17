
  
class Range::StepIterator
    getter range
    getter step
end
  
  iter = (6..0).step(-2)
  
  iter.each do |i|
    puts i
  end

  elem.range.step(elem.step)

  puts typeof(iter)


iter2 = Number::StepIterator.new(9, 3, -2, false)


  puts typeof(iter2)

{0..5, 2}
(0..5).step(2)

