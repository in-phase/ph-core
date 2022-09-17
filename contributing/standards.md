# Pre-amble
- These are the standards *we* try to follow in our code
- Don't let them intimidate you from contributing - but if you are able to follow some or all of these, it may make our lives easier when accepting a pull request
- We are also new to this business so if you'd like to talk about these standards please let us know :)

# General
- Follow the crystal stdlib way of doing things unless you have good reason
- In core: plan for inheritance, modularize where possible
    - know what your theoretical entity is (MultiIndexable is a readable n-dimensional array),
        and try to allow a user to implement anything that fits under that definition. For example,
        MultiIndexable only implements shape as an instance method - we don't expect shape to ever change,
        but we allow users to override shape if need be, because in theory a MultiIndexable with changing shape
        is still a MultiIndexable.
    - you might have to make sacrifices to the above for the sake of code clarity, simplicity, speed, or correctness.
- try to be consistent with existing terminology, and be considerate of the user
- In general, don't have special functions to do everything, but make sure almost anything can be done by chaining a few powerful statements
    - don't implement .each_in_region when you could implement .view(region).each
- make users specify types as little as possible. This may mean special constructors (not direct `def initialize`) or macros
- Try to make the folder and file structure reflect the heirarchy of types and modules in code - loosely speaking,
    a module is a folder, and a class/struct is a file
- mutability safety: Any objects that are passed into or returned from a class should either be by-value or copied internally (unless there is good reason for the user being able to edit them externally)
- when implementing a producer method (one that uses an existing instance to create a new copy, like `index_region.reverse`),
    first implement an in place version (`index_region.reverse!`) and then implement the producer by cloning `self` and
    invoking the in-place version (`index_region.clone.reverse!`) - two birds with one stone

# Pull requests
- General courtesy! 
    - change as little as possible
    - one PR per feature/fix
    - Either update spec to reflect changes, or inform on the PR that spec needs to be updated

# Errors
- give as much information as possible without making the non-erroring branch slower
- make type-related errors happen at compile time (where possible) - by method signature restrictions or by macros
- general syntax:
    - for functions that involve multiple steps and cannot be factored into units, state what step the problem occurred in
        - short description of what part of the method could not be completed ("Failed to unsafe_fetch element from NArray")
        - end the description with a colon, not a period (unless you have none of the following information available)
    - short description of what went wrong, at the implementation level
        - at the very least, give a quick explanation ("index was out of bounds")
        - if possible, provide as much useful information as you can: "coord[3] was -11, but a canonicalized coordinate must only have positive entries." 
    - (if relevant or a common error) suggest how to fix it ("try canonicalizing before calling this method")
    - use proper grammar (capitalize sentences, use commas, end with periods)
    - all together:
        - for a method with multiple steps:
            - (allowed, but bad) "Failed to unsafe_fetch element from NArray: Index was out of bounds."
            - (best practise) "Failed to unsafe_fetch element from NArray: coord[3] was -11, but a canonicalized coordinate must only have positive entries. Try canonicalizing before calling this method."
        - for a well-factored method whose name describes what it does accurately:
            - (allowed, but bad) "Index was out of bounds."
            - (best practise) "coord[3] was -11, but a canonicalized coordinate must only have positive entries. Try canonicalizing before calling this method."
- Do not use any pointless preamble like "Error:" before your message - crystal adds its own
- throw the error to the user at the highest level that makes a semantic difference; catch and re-throw if necessary
    - (inform them what THEY did that caused the error; not what problem it caused downstream)
- Don't make pointless classes that implement Exception where another one would do
    - don't raise `IndexWasNegativeException`, raise `IndexError`
    - at the same time, don't be too general: raise `ArgumentError` when you should have created `DimensionError`
    - only create new exceptions for broad categories of issues that users will want to distinguish from other error types

# Language
- Coord (`coord`) - coordinate, represented by an indexable where `coord[i]` is the index along axis i
- Shape (`shape`)- an indexable that stores the number of elements in each axis, such that a 3 row, 2 column MultiIndexable has shape [3, 2]
- Elem (`el`)
    - a scalar type pointed at by a unique coordinate
- Chunk (`chunk`)
    - the n-dimensional collection of elements mirroring the coordinates in a region 
- Region 
    - an abstract concept representing an n-dimensional range of coordinates
    - IndexRegion (`region`) - most canonical (details here)
    - Region Literal (`region_literal`) - least canonical form, made of ranges and ints
- Source (`src`)
- Size (`size`) - number of elements stored in 
    
- MultiIndexable - an n-dimensional array where elements can be accessed from coordinates, but not neccessarily modified
- MultiWritable - an n-dimensional array where elements can be stored at a coordinate, but not neccessarily read
- View (`view`)
- NArray (`narr`) - generally refers specifically to the class `NArray`, though may in some instances refer to the abstract concept of an n-dimensional array????

- Lexicographic (`lex`)
- Colexicographic (`colex`)

# Methods
- every class has a "new" (unless VERY good reason not to)
    - Lowers the barrier to entry for someone looking to create an instance
- other constructors: use simple, descriptive words that are as consistent as make semantic sense
    - e.g. of, build, fill
    - a `new` method should take inputs in the most canonical form (and be type restricted where possible - loosely is ok)
    - use other names for constructors that are semantically different
- add return types wherever feasible, restrict input types as generally as possible
    - you want the compiler error to happen at the method signature, not at the code inside
    - stick to high-level types like "Indexable" or "Int", not implementations like "Array", "Int32"
- argument order: be consistent where it makes sense to. But in general do what makes the most sense semantically.
    - if the method is a verb, the "object" of the verb should be the first parameter so it reads well
    - i.e. `canonicalize(region)`
- use external and internal names if it helps readability
    - example: `def multiply(by value)`

- follow crystal convention on !, ?, unsafe
    - ! means "in-place operation", "dangerous operation", or "can raise"
    - ? means "won't raise", "returns a boolean"
    - unsafe means "faster", "no validation", "can raise"
- return `self` where appropriate for chaining
