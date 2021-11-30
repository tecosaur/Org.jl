# Thanks to load order issues, we have to do the documentation seperately

const README = parse(Org, read("$(dirname(dirname(@__DIR__)))/README.org", String))
const compatability = Org([README.contents[3].section])

@doc org"""
#+begin_src julia
orgmatcher(::Type{C}) where {C <: OrgComponent}
#+end_src

Return a /matcher/ for components of type ~C~.
This will either be:
+ a regular expression which matcher the entire component
+ a function which takes a string and returns either
  - nothing, if the string does not start with the component
  - the substring which has been identified as an instance of the component
  - a tuple of the substring instance of the component, and the component data structure
""" matcher

@doc org"""
#+begin_src julia
consume(component::Type{<:OrgComponent}, text::AbstractString)
#+end_src
Try to /consume/ a ~component~ from the start of ~text~.

Returns a tuple of the consumed text and the resulting component
or =nothing= if this is not possible.
""" consume
