const __bodyfunction__ = Dict{Method,Any}()

# Find keyword "body functions" (the function that contains the body
# as written by the developer, called after all missing keyword-arguments
# have been assigned values), in a manner that doesn't depend on
# gensymmed names.
# `mnokw` is the method that gets called when you invoke it without
# supplying any keywords.
function __lookup_kwbody__(mnokw::Method)
    function getsym(arg)
        isa(arg, Symbol) && return arg
        @assert isa(arg, GlobalRef)
        return arg.name
    end

    f = get(__bodyfunction__, mnokw, nothing)
    if f === nothing
        fmod = mnokw.module
        # The lowered code for `mnokw` should look like
        #   %1 = mkw(kwvalues..., #self#, args...)
        #        return %1
        # where `mkw` is the name of the "active" keyword body-function.
        ast = Base.uncompressed_ast(mnokw)
        if isa(ast, Core.CodeInfo) && length(ast.code) >= 2
            callexpr = ast.code[end-1]
            if isa(callexpr, Expr) && callexpr.head == :call
                fsym = callexpr.args[1]
                if isa(fsym, Symbol)
                    f = getfield(fmod, fsym)
                elseif isa(fsym, GlobalRef)
                    if fsym.mod === Core && fsym.name === :_apply
                        f = getfield(mnokw.module, getsym(callexpr.args[2]))
                    elseif fsym.mod === Core && fsym.name === :_apply_iterate
                        f = getfield(mnokw.module, getsym(callexpr.args[3]))
                    else
                        f = getfield(fsym.mod, fsym.name)
                    end
                else
                    f = missing
                end
            else
                f = missing
            end
        else
            f = missing
        end
        __bodyfunction__[mnokw] = f
    end
    return f
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc})   # time: 0.32043454
    Base.precompile(Tuple{typeof(org),IOBuffer,Table,Int64})   # time: 0.27505028
    Base.precompile(Tuple{typeof(org),IOBuffer,OrgDoc})   # time: 0.24133022
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,UnorderedList,Int64})   # time: 0.16556492
    Base.precompile(Tuple{typeof(consume),Type{Planning},SubString{String}})   # time: 0.14544973
    let fbody = try __lookup_kwbody__(which(parseorg, (SubString{String},Dict{Char, Vector{DataType}},Vector{DataType},))) catch missing end
    if !ismissing(fbody)
        precompile(fbody, (Bool,Bool,Int64,typeof(parseorg),SubString{String},Dict{Char, Vector{DataType}},Vector{DataType},))
    end
end   # time: 0.14305766
    Base.precompile(Tuple{typeof(html),IOBuffer,OrgDoc})   # time: 0.11243505
    Base.precompile(Tuple{Type{Table},Vector{Union{Nothing, SubString{String}}}})   # time: 0.09191036
    Base.precompile(Tuple{typeof(consume),Type{Timestamp},SubString{String}})   # time: 0.09087488
    Base.precompile(Tuple{typeof(consume),Type{Citation},SubString{String}})   # time: 0.069843575
    Base.precompile(Tuple{typeof(org),IOBuffer,UnorderedList,Int64})   # time: 0.0667007
    Base.precompile(Tuple{typeof(postprocess!),OrgDoc})   # time: 0.0661829
    Base.precompile(Tuple{Type{Section},Vector{Union{Nothing, SubString{String}}}})   # time: 0.055297952
    Base.precompile(Tuple{typeof(org),IOBuffer,AffiliatedKeywordsWrapper,Int64})   # time: 0.054353792
    Base.precompile(Tuple{typeof(term),IOBuffer,TextMarkup{SubString{String}},Vector{String}})   # time: 0.051143266
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,TextMarkup{Vector{Object}}})   # time: 0.045892756
    Base.precompile(Tuple{typeof(layouttable),IOBuffer,Function,Table,Dict{Char, Char},Int64})   # time: 0.04563425
    Base.precompile(Tuple{typeof(parse),Type{OrgDoc},String})   # time: 0.044654246
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,Table,Int64})   # time: 0.04446829
    Base.precompile(Tuple{Type{TableRow},Vector{Union{Nothing, SubString{String}}}})   # time: 0.041455567
    Base.precompile(Tuple{typeof(org),IOContext{IOBuffer},TextMarkup{Vector{Object}}})   # time: 0.038945496
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,SourceBlock,Int64})   # time: 0.038509842
    Base.precompile(Tuple{typeof(consume),Type{TextPlainForced},SubString{String}})   # time: 0.036461886
    let fbody = try __lookup_kwbody__(which(parseorg, (SubString{String},Dict{Char, Vector{<:Type}},Vector{Type},))) catch missing end
    if !ismissing(fbody)
        precompile(fbody, (Bool,Bool,Int64,typeof(parseorg),SubString{String},Dict{Char, Vector{<:Type}},Vector{Type},))
    end
end   # time: 0.035671674
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,LaTeXFragment})   # time: 0.035494458
    Base.precompile(Tuple{typeof(consume),Type{AffiliatedKeywordsWrapper},SubString{String}})   # time: 0.03425677
    Base.precompile(Tuple{typeof(org),IOContext{IOBuffer},UnorderedList,Int64})   # time: 0.031304054
    Base.precompile(Tuple{typeof(consume),Type{TextPlain},SubString{String}})   # time: 0.030219704
    Base.precompile(Tuple{typeof(org),IOBuffer,Paragraph,Int64})   # time: 0.029114475
    Base.precompile(Tuple{typeof(consume),Type{Comment},SubString{String}})   # time: 0.024979195
    Base.precompile(Tuple{typeof(consume),Type{AffiliatedKeyword},SubString{String}})   # time: 0.02246017
    isdefined(Org, Symbol("#98#104")) && Base.precompile(Tuple{getfield(Org, Symbol("#98#104")),Vector{String}})   # time: 0.021567201
    let fbody = try __lookup_kwbody__(which(parseobjects, (Type,SubString{String},))) catch missing end
    if !ismissing(fbody)
        precompile(fbody, (Bool,Bool,typeof(parseobjects),Type,SubString{String},))
    end
end   # time: 0.020833066
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,Keyword{SubString{String}},Int64})   # time: 0.017364282
    Base.precompile(Tuple{typeof(consume),Type{LaTeXFragment},SubString{String}})   # time: 0.01619035
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,SourceBlock,Int64})   # time: 0.01617535
    Base.precompile(Tuple{typeof(iterate),OrgIterator})   # time: 0.014937996
    Base.precompile(Tuple{Type{PropertyDrawer},Vector{Union{Nothing, SubString{String}}}})   # time: 0.014385041
    isdefined(Org, Symbol("#itemconsume#59")) && Base.precompile(Tuple{getfield(Org, Symbol("#itemconsume#59")),SubString{String},SubString{String}})   # time: 0.013828709
    Base.precompile(Tuple{typeof(consume),Type{FootnoteDefinition},SubString{String}})   # time: 0.013215547
    Base.precompile(Tuple{typeof(consume),Type{TextMarkup},SubString{String}})   # time: 0.012036697
    Base.precompile(Tuple{typeof(html),IOBuffer,ExportBlock})   # time: 0.011866605
    Base.precompile(Tuple{typeof(org),IOBuffer,AffiliatedKeyword{Nothing},Int64})   # time: 0.011750292
    Base.precompile(Tuple{typeof(org),IOBuffer,RegularLink})   # time: 0.010200925
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,SpecialBlock,Int64})   # time: 0.010012363
    isdefined(Org, Symbol("#100#106")) && Base.precompile(Tuple{getfield(Org, Symbol("#100#106")),Vector{Vector{Int64}}})   # time: 0.0099559
    Base.precompile(Tuple{typeof(consume),Type{InlineSourceBlock},SubString{String}})   # time: 0.009951612
    Base.precompile(Tuple{typeof(consume),Type{FootnoteReference},SubString{String}})   # time: 0.009520893
    isdefined(Org, Symbol("#100#106")) && Base.precompile(Tuple{getfield(Org, Symbol("#100#106")),Vector{Union{Nothing, Vector{Int64}}}})   # time: 0.009133301
    Base.precompile(Tuple{typeof(org),IOBuffer,SourceBlock,Int64})   # time: 0.008511166
    Base.precompile(Tuple{typeof(consume),Type{RegularLink},SubString{String}})   # time: 0.007196862
    Base.precompile(Tuple{typeof(consume),Type{List},SubString{String}})   # time: 0.007170842
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,QuoteBlock,Int64})   # time: 0.00685181
    Base.precompile(Tuple{typeof(consume),Type{Item},SubString{String}})   # time: 0.00668202
    Base.precompile(Tuple{typeof(org),IOContext{IOBuffer},RegularLink})   # time: 0.006290038
    Base.precompile(Tuple{Type{Block},Vector{Union{Nothing, SubString{String}}}})   # time: 0.006034944
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,RegularLink})   # time: 0.005997927
    Base.precompile(Tuple{typeof(consume),Type{GreaterBlock},SubString{String}})   # time: 0.005965764
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,AffiliatedKeywordsWrapper,Int64})   # time: 0.005771555
    Base.precompile(Tuple{Type{Keyword},Vector{Union{Nothing, SubString{String}}}})   # time: 0.005761046
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,CenterBlock,Int64})   # time: 0.005582146
    isdefined(Org, Symbol("#124#125")) && Base.precompile(Tuple{getfield(Org, Symbol("#124#125")),IOBuffer,LaTeXFragment})   # time: 0.005432231
    Base.precompile(Tuple{Type{Heading},Vector{Union{Nothing, SubString{String}}}})   # time: 0.005305904
    isdefined(Org, Symbol("#textobjupto#70")) && Base.precompile(Tuple{getfield(Org, Symbol("#textobjupto#70")),Int64})   # time: 0.005131729
    Base.precompile(Tuple{typeof(org),IOContext{IOBuffer},SourceBlock,Int64})   # time: 0.005061035
    Base.precompile(Tuple{typeof(html),IOBuffer,Table})   # time: 0.005050735
    Base.precompile(Tuple{typeof(html),IOBuffer,UnorderedList})   # time: 0.004805607
    Base.precompile(Tuple{typeof(parse),Type{LinkPath},SubString{String},Bool})   # time: 0.00473084
    Base.precompile(Tuple{typeof(consume),Type{Clock},SubString{String}})   # time: 0.004381719
    Base.precompile(Tuple{typeof(consume),Type{Entity},SubString{String}})   # time: 0.003819155
    Base.precompile(Tuple{typeof(org),IOBuffer,QuoteBlock,Int64})   # time: 0.003732675
    Base.precompile(Tuple{typeof(iterate),OrgIterator,Vector{Tuple}})   # time: 0.003555848
    let fbody = try __lookup_kwbody__(which(forwardsbalenced, (SubString{String},Int64,Int64,))) catch missing end
    if !ismissing(fbody)
        precompile(fbody, (Dict{Char, Char},Vector{Char},Vector{Char},Vector{Char},typeof(forwardsbalenced),SubString{String},Int64,Int64,))
    end
end   # time: 0.003452854
    Base.precompile(Tuple{typeof(org),IOBuffer,ExportBlock,Int64})   # time: 0.003173403
    Base.precompile(Tuple{typeof(html),IOBuffer,TextMarkup{SubString{String}}})   # time: 0.002870525
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,Paragraph,Int64})   # time: 0.002809988
    Base.precompile(Tuple{typeof(org),IOBuffer,Drawer,Int64})   # time: 0.00278488
    Base.precompile(Tuple{typeof(term),IOBuffer,OrgDoc,ExportBlock,Int64})   # time: 0.002739602
    Base.precompile(Tuple{typeof(html_tagpair),String,Pair{String, String}})   # time: 0.002626423
    Base.precompile(Tuple{typeof(consume),Type{ExportSnippet},SubString{String}})   # time: 0.002619359
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,Paragraph,Int64})   # time: 0.002616784
    Base.precompile(Tuple{typeof(org),IOBuffer,LaTeXFragment})   # time: 0.002530007
    Base.precompile(Tuple{typeof(org),IOBuffer,Keyword{SubString{String}},Int64})   # time: 0.002526863
    Base.precompile(Tuple{typeof(org),IOBuffer,TextMarkup{SubString{String}}})   # time: 0.002374013
    Base.precompile(Tuple{typeof(consume),Type{Drawer},SubString{String}})   # time: 0.002340451
    Base.precompile(Tuple{typeof(org),IOBuffer,ExportSnippet})   # time: 0.002330339
    Base.precompile(Tuple{typeof(html),IOBuffer,RegularLink})   # time: 0.002330261
    Base.precompile(Tuple{typeof(consume),Type{NodeProperty},SubString{String}})   # time: 0.002107064
    Base.precompile(Tuple{typeof(term),IOBuffer,RegularLink,Vector{String}})   # time: 0.002088849
    Base.precompile(Tuple{typeof(org),IOBuffer,Comment,Int64})   # time: 0.002087208
    isdefined(Org, Symbol("#65#71")) && Base.precompile(Tuple{getfield(Org, Symbol("#65#71")),Char})   # time: 0.001969018
    Base.precompile(Tuple{typeof(html),IOBuffer,Keyword{SubString{String}}})   # time: 0.001919663
    Base.precompile(Tuple{typeof(org),IOBuffer,ExampleBlock,Int64})   # time: 0.001773046
    Base.precompile(Tuple{typeof(html),IOBuffer,SourceBlock})   # time: 0.001771655
    Base.precompile(Tuple{typeof(org),IOContext{IOBuffer},InlineSourceBlock})   # time: 0.001747723
    Base.precompile(Tuple{typeof(html),IOBuffer,PlainLink})   # time: 0.001667706
    Base.precompile(Tuple{typeof(term),IOBuffer,TextPlain{SubString{String}},Vector{String}})   # time: 0.00163107
    Base.precompile(Tuple{typeof(html),IOBuffer,TextMarkup{Vector{Object}}})   # time: 0.001566183
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,TextPlain{SubString{String}}})   # time: 0.001551615
    Base.precompile(Tuple{typeof(term),IOContext{IOBuffer},OrgDoc,TextPlain{String}})   # time: 0.001542971
    Base.precompile(Tuple{typeof(html),IOBuffer,TextPlain{SubString{String}}})   # time: 0.001469463
    Base.precompile(Tuple{typeof(parse),Type{TableRow},SubString{String}})   # time: 0.00145073
    Base.precompile(Tuple{typeof(html),IOBuffer,ExampleBlock})   # time: 0.001345151
    Base.precompile(Tuple{typeof(parse),Type{Section},SubString{String}})   # time: 0.001341194
    Base.precompile(Tuple{typeof(html),IOBuffer,TextPlain{String}})   # time: 0.001281813
    Base.precompile(Tuple{typeof(org),IOBuffer,TextMarkup{Vector{Object}}})   # time: 0.001265663
    isdefined(Org, Symbol("#124#125")) && Base.precompile(Tuple{getfield(Org, Symbol("#124#125")),IOBuffer,Entity})   # time: 0.001249151
    Base.precompile(Tuple{typeof(html),IOBuffer,SpecialBlock})   # time: 0.001218596
    Base.precompile(Tuple{typeof(html),IOBuffer,LaTeXFragment})   # time: 0.00120709
    Base.precompile(Tuple{typeof(html),IOBuffer,DescriptiveList})   # time: 0.001175334
    Base.precompile(Tuple{typeof(html),IOBuffer,OrderedList})   # time: 0.001161889
    Base.precompile(Tuple{typeof(iterate),Item,Int64})   # time: 0.001062694
    Base.precompile(Tuple{typeof(*),TextPlain{String},TextPlain{SubString{String}}})   # time: 0.001045501
end

_precompile_()
