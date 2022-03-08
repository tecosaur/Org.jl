# Thanks to load order issues, we have to do the documentation seperately

const README, compatability =
    let readme=read("$(dirname(dirname(@__DIR__)))/README.org", String)
        prolouge=match(r"\n([^#\n][\s\S]*)\n\* Progress", readme).captures[1]
        progress=match(r"\n\* Progress\s*((?:\|[^\n]+\n)+)", readme).captures[1]
        Base.Docs.doc!(@__MODULE__,
                       Base.Docs.Binding(@__MODULE__, Symbol(@__MODULE__)),
                       Base.Docs.docstr(parse(OrgDoc, prolouge),
                                        Dict(:path => joinpath(@__DIR__, @__FILE__),
                                             :linenumber => @__LINE__,
                                             :module => @__MODULE__)),
                       Union{})
        (parse(OrgDoc, readme),
         parse(OrgDoc,
               replace(replace(replace(progress,
                                       "| X " => "| =✓="),
                               r"\| +\|" => "| ~⋅~ |"),
                       r"\| +\|" => "| ~⋅~ |")))
    end

@doc org"""
#+begin_src julia
@org_str -> Union{OrgDoc, OrgComponent}
#+end_src

Parse the string as Org, sepecifically to ~OrgDoc~ by default.

This supports a /type flag/ listed after the ending quote,
e.g. src_julia{org"A paragraph"p}.
This sets the type of object the string is parsed to.

The following type flags are currently supported:
- =d=, ~OrgDoc~ (/default/)
- =e=, ~Element~
- =o=, ~Object~
- =h=, ~Heading~
- =s=, ~Section~
- =p=, ~Paragraph~
- =ts=, ~Timestamp~
- =m=, ~TextMarkup~
- =t=, ~TextPlain~
""" :@org_str

@doc org"""
#+begin_src julia
orgmatcher(::Type{C}) where {C <: OrgComponent}
#+end_src

Return a /matcher/ for components of type ~C~.
This will either be:
+ nothing, if no matcher is defined
+ a regular expression which matcher the entire component
+ a function which takes a string and returns either
  - nothing, if the string does not start with the component
  - the substring which has been identified as an instance of the component
  - a tuple of the substring instance of the component, and the component data structure
""" orgmatcher

@doc org"""
#+begin_src julia
consume(component::Type{<:OrgComponent}, text::SubString{String})
#+end_src
Try to /consume/ a ~component~ from the start of ~text~.

Returns a tuple of the consumed text and the resulting component
or =nothing= if this is not possible.
""" consume

@doc org"""
An ~Org~ wrapper type, which when ~iterated~ over yeilds
each component of the ~Org~ document.
""" OrgIterator

@doc org"""
An ~Org~ wrapper type, which when ~iterated~ over yeilds
each element of the ~Org~ document.
""" OrgElementIterator
