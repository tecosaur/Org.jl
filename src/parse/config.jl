const org_archive_tag = "ARCHIVE"
const org_comment_string = "COMMENT"

const org_keyword_translations =
    Dict("data" => "name",
         "label" => "name",
         "resname" => "name",
         "source" => "name",
         "srcname" => "name",
         "tblname" => "name",
         "result" => "results",
         "headers" => "header")

const org_affilated_keywords =
    ("caption", "header", "name", "plot", "results")

const org_affiliable_elements =
    (Drawer, DynamicBlock, FootnoteDefinition,
     GreaterBlock, List, Table, BabelCall,
     Block, DiarySexp, FixedWidth, HorizontalRule,
     Keyword, LaTeXEnvironment, Paragraph, TableHrule)

const org_dual_keywords = ("caption", "results")
const org_multiple_keywords = ("caption", "header")
const org_parsed_keywords = ("caption")

const org_secondary_values =
    Dict(Citation => (:globalprefix, :globalsuffix),
         CitationReference => (:prefix, :suffix),
         Heading => (:title,),
         InlineTask => (:title,),
         Item => (:tag,))

const org_object_restrictions =
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

const org_markup_formatting =
    Dict('*' => :bold,
         '/' => :italic,
         '+' => :strikethrough,
         '_' => :underline,
         '=' => :verbatim,
         '~' => :code)
