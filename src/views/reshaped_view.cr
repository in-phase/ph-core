# require "./view_object"


# module Lattice

#     class ReshapedView(B,T)
        
#         include ViewObject(B,T,T)


#     end

# end


# v = narr.view => @src narr
# v.process => @src narr

# View: src -> 
# ProcessedView
# ReshapedView

# View of ProcessedView of ReshapedView of NArray
# narr.view.reshape.process # process returns a ProcessedView
# narr.view.process.reshape # reshape returns a ProcessedView
# View @process, @newshape, @region
# .region() #=> @src = previous view

# narr.process View of ProcessedView of NArray

# View(ProcessedView(Narray, T), T)


# abstract def view()

# MultiIndexable.view



# narr.process.reshape.process.reshape.process

# narr.process.process.process.reshape(a).reshape(b)
# narr.process.process.process.reshape(b)
# narr.process.reshape(b)

# narr.process.process
# narr.process.reshape.process.reshape

# narr.process
# # create a processedview
# # return a view to it
# narr.process.process
# # step one: make the view(processed) as above
# # call process on view.process
# #  requires that we identify that @src is a processedview

# view = narr.View => view(narray)
# view.process => view(processedview(narray)