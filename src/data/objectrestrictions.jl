const OrgObjectRestrictions =
    let minimalset = [TextPlain, TextMarkup, Entity, LaTeXFragment, Script]
        completeset = [Citation, CitationReference, Entity, ExportSnippet,
    FootnoteReference, InlineBabelCall, InlineSourceBlock, LaTeXFragment,
    LineBreak, RadioLink, PlainLink, AngleLink, RegularLink, Macro, RadioTarget,
    Script, StatisticsCookie, TableCell, Target, TextMarkup, TextPlain, Timestamp]
        standardset = filter(o -> o ∉ (CitationReference, TableCell), completeset)
        standardsetnolinebreak = filter(o -> o != LineBreak, standardset)

        Dict(TextMarkup => standardset,
             Citation => [CitationReference],
             CitationReference => minimalset,
             FootnoteReference => standardset,
             Heading => standardsetnolinebreak,
             InlineTask => standardsetnolinebreak,
             Item => standardsetnolinebreak,
             Keyword => filter(o -> o != FootnoteReference, standardset),
             RegularLink => minimalset ∪
                 (ExportSnippet, InlineBabelCall, InlineSourceBlock, Macro, StatisticsCookie),
             Paragraph => standardset,
             RadioTarget => minimalset,
             Script => standardset,
             TableCell => minimalset ∪
                 (Citation, ExportSnippet, FootnoteReference, RadioLink,
    PlainLink, AngleLink, RegularLink, Macro, RadioTarget, Target, Timestamp),
             TableRow => [TableCell])
    end
