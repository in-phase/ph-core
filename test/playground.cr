def format_element(el : Float, justify_length) : String
  str = "%f" % el

  if str.size > justify_length
    separator = str.rindex(/[pe]/i)
    if separator.nil?
      str = "%e" % el
      separator = str.rindex(/[pe]/i).not_nil!
    end

    truncate_length = str.size - justify_length

    if separator - truncate_length < 3
      mantissa = str[0]
    else
      mantissa = str[...(separator - truncate_length)]
    end

    exponent = str[separator..]

    str = mantissa + exponent
  end
  str
end

15.times do |i|
  puts "#{i}: #{format_element(2.3456, i)}"
end
