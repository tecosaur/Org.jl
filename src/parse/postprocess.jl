function postprocess!(doc::Org)
    # Radio Links
    radios = filter(c -> c isa RadioTarget, doc.components)
    if length(radios) > 0
        paragraphs = filter(c -> c isa Paragraph, doc.components)
        footnoterefs = filter(c -> c isa FootnoteReference{<:Any, Vector{Object}}, doc.components)
        markups = filter(c -> c isa TextMarkup{Vector{Object}}, doc.components)
        for radio in radios
            for heading in doc.headings
                heading.title = radio_replace(heading.title, radio)
            end
            for paragraph in paragraphs
                paragraph.contents = radio_replace(paragraph.contents, radio)
            end
            for markup in markups
                markup.contents = radio_replace(markup.contents, radio)
            end
            for fnref in footnoterefs
                fnref.definition = radio_replace(fnref.definition, radio)
            end
        end
    end
end

function radio_replace(objs::Vector{Object}, radio::RadioTarget)
    if length(radio.contents) == 1 && radio.contents[1] isa TextPlain
        radio_replace_singular(objs, radio)
    else
        needles = radio.contents
        function radioat(i)
            (objs[i] == needles[1] || # 1 matches, or
             (objs[i] isa TextPlain && needles[1] isa TextPlain &&
              endswith(objs[i].text, needles[1].text))) && # 1 ends with needles[1]
                objs[i+1:i+length(needles)-2] == needles[2:end-1] && # 2-(end-1) matches
                (objs[i+length(needles)-1] == needles[end] || # end matches, or
                 (objs[i+length(needles)-1] isa TextPlain && needles[end] isa TextPlain &&
                  startswith(objs[i+length(needles)-1].text, needles[end].text))) # end start with radio[end]
        end
        newobjs = Object[]
        i = 1
        while i <= length(objs)
            if radioat(i)
                if needles[1] isa TextPlain &&
                    objs[i] != needles[1]
                    # objs[1] must be a TextPlain that ends in needles[1]
                    push!(newobjs, TextPlain(@inbounds @view objs[i].text[1:end-ncodeunits(needles[1].text)]))
                end
                push!(newobjs, RadioLink(radio))
                i += length(needles)-1
                if needles[end] isa TextPlain &&
                    objs[i-1] != needles[end]
                    push!(newobjs, TextPlain(@inbounds @view objs[i-1].text[ncodeunits(needles[end].text):end]))
                end
            else
                push!(newobjs, objs[i])
            end
            i += 1
        end
        newobjs
    end
end

function radio_replace_singular(objs::Vector, radio::RadioTarget)
    @assert length(radio.contents) == 1 && radio.contents[1] isa TextPlain
    needle = radio.contents[1].text
    alphnum(c::Char) = c in 'A':'Z' || c in 'a':'z' || c in '0':'9'
    newobjs = Object[]
    for obj in objs
        if obj isa TextPlain && occursin(needle, obj.text)
            occurances = findall(needle, obj.text)
            point = 1
            for occ in occurances
                if (occ.start == 1 || !alphnum(obj.text[prevind(obj.text, occ.start)])) &&
                   (occ.stop == length(obj.text) || !alphnum(obj.text[nextind(obj.text, occ.stop)]))
                    push!(newobjs, TextPlain(@inbounds @view obj.text[point:occ.start-1]))
                    push!(newobjs, RadioLink(radio))
                    point = occ.stop + 1
                end
            end
            if point <= lastindex(obj.text)
                push!(newobjs, TextPlain(@inbounds @view obj.text[point:end]))
            end
        else
            push!(newobjs, obj)
        end
    end
    newobjs
end
