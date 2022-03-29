import Base.diff

# Because diff is already documented in markdown, we should just use MD documentation
"""
    diff(A::OrgDoc, B::OrgDoc)
    diff(A::Component, B::Component)
    diff(A::Vector{<:Component}, B::Vector{<:Component})
Compare two different Org components or ASTs.

The diff method can detect insertions, deletions, and reshuffling of
immediate decendents of a component.
"""
function diff(A::OrgDoc, B::OrgDoc)
    if A == B
        print(stdout, "Identical\n")
    else
        diff(A.contents, B.contents, [])
    end
    nothing
end

function printbreadcrums(path, prefix=nothing, prefixcolor=:default, postfix='\n')
    # Path is a vector of (component, counter, color) tuples
    # counter can be an integer or a (value, bold?, color) tuple
    if length(path) > 0
        isnothing(prefix) || printstyled(prefix, ' ', color=prefixcolor)
        for (component, counter, color) in path
            (component, counter, color) == first(path) ||
                printstyled(" > ", bold=true)
            printstyled(component; color)
            if counter isa Integer
                printstyled('#', counter, bold=true, color=:light_black)
            elseif counter isa Tuple
                printstyled('#', counter[1], bold=counter[2], color=counter[3])
            end
        end
        print(postfix)
    end
end

function printdiffheader(message, aval, bval)
    printstyled("  × ", bold=true, color=:magenta)
    printstyled(message, '\n', color=:magenta)
    if isnothing(aval)
    elseif aval isa Component
        printstyled("    A (Org representation):\n", color=:red)
        org(stdout, aval, 7)
        print('\n')
    else
        printstyled("    A: ", color=:red)
        print(aval, '\n')
    end
    if isnothing(bval)
    elseif bval isa Component
        printstyled("    B (Org representation):\n", color=:green)
        org(stdout, bval, 7)
        print('\n')
    else
        printstyled("    B: ", color=:green)
        print(bval, '\n')
    end
end

function diff(A::Component, B::Component, path::Vector=[], counter=1)
    pathA = vcat(path, (nameof(typeof(A)), counter, :yellow))
    if A == B
    elseif nameof(typeof(A)) != nameof(typeof(B))
        printbreadcrums(pathA)
        printdiffheader("Component type mismatch", typeof(A), typeof(B))
    else
        props = fieldnames(typeof(A))
        for prop in props
            ap, bp = getproperty(A, prop), getproperty(B, prop)
            if ap != bp
                if (ap isa Component && bp isa Component) ||
                    (ap isa Vector{<:Component} && ap isa Vector{<:Component})
                    diff(ap, bp, pathA, 1)
                elseif ap isa Component || ap isa Vector{<:Component}
                    printbreadcrums(pathA)
                    printdiffheader("$(nameof(typeof(A))) $prop type mismatch", typeof(ap), typeof(bp))
                else
                    printbreadcrums(pathA)
                    printdiffheader("$(nameof(typeof(A))) $prop mismatch", string(ap), string(bp))
                end
            end
        end
    end
    nothing
end

function diff(As::Vector{<:Component}, Bs::Vector{<:Component}, path::Vector=[], counter=0)
    # Detect reorderings
    diffmat = [A == B for A in As, B in Bs]
    reorderings = []
    while maximum(diffmat) > 0
        a, b = Tuple(argmax(diffmat))
        if a != b && a > b
            push!(reorderings, (a, b))
        end
        diffmat[a, :] .= 0
        diffmat[:, b] .= 0
    end
    for (a, b) in reorderings
        printbreadcrums(vcat(path, (nameof(typeof(As[a])), (a, false, :red), :yellow)), "swapped", :blue, "")
        printstyled(" <-> ", color=:blue)
        printbreadcrums([(nameof(typeof(Bs[b])), (b, false, :green), :yellow)])
    end
    reordered = reorderings |> Iterators.flatten |> collect
    # Remaining differences
    if As == Bs
    elseif length(As) == length(Bs)
        for i in setdiff(1:length(As), reordered)
            diff(As[i], Bs[i], path, i)
        end
    else
        minlen = min(length(As), length(Bs))
        for i in setdiff(1:minlen, reordered)
            diff(As[i], Bs[i], path, i)
        end
        printdiffheader("Missing components", "$(length(As)) components", "$(length(Bs)) components")
        if length(As) > length(Bs)
            for i in (minlen+1):length(As)
                printbreadcrums(vcat(path, (nameof(typeof(As[i])), i, :red)), "    !", :red)
            end
        else
            for i in (minlen+1):length(Bs)
                printbreadcrums(vcat(path, (nameof(typeof(Bs[i])), i, :green)), "    !", :green)
            end
        end
    end
    nothing
end
