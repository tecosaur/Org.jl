module OrgMode

export Org

include("parse/structure.jl")
include("parse/operations.jl")

import Base.show
include("render/org.jl")
include("render/term.jl")

# Org([Keyword("#+title: a demo"),
#      Keyword("#+author: me"),
#      OrgSection(Heading("** demo"),
#                 Paragraph([TextPlain("Welcome to a"),
#                            TextMarkup(" *demonstration* "),
#                            TextPlain("of representing some org content in"),
#                            TextMarkup(" ~Julia~.")]))])

end
