- skipping coords can be useful!
- if you have two NArrays for example, you can go faster by doing:

iter = one.each 
two.map do ||
    iter.next
end