# The informatio contained in `org-entities'

struct EntityData
    latex::String
    math::Bool
    html::String
    ascii::String
    latin1::String
    utf8::String
end

function Base.show(io::IO, ent::EntityData)
    function rep(field, name, color=:cyan, last=false)
        printstyled(io, getproperty(ent, field); color)
        print(io, ": $name")
        if !last print(io, ", ") end
    end
    if ent.ascii == ent.latin1 == ent.utf8
        rep(:utf8, "Unicode/Latin1/ASCII")
        rep(:latex, "LaTeX", :magenta)
        rep(:html, "HTML", :green, true)
    elseif ent.ascii == ent.latin1 == ent.utf8
        rep(:utf8, "Unicode/Latin1")
        rep(:ascii, "ASCII")
        rep(:latex, "LaTeX")
        rep(:html, "HTML", :green, true)
    else
        rep(:utf8, "Unicode")
        rep(:latin1, "Latin1")
        rep(:ascii, "ASCII")
        rep(:latex, "LaTeX", :magenta)
        rep(:html, "HTML", :green, true)
    end
    if ent.math
        printstyled(io, " (math)", color=:yellow)
    end
end

# (mapconcat
#  (lambda (entity)
#    (if (stringp entity)
#        (concat "# " entity)
#      (setf (caddr entity) (if (caddr entity) "true" "false"))
#      (replace-regexp-in-string "\\$" "\\\\$"
#        (apply #'format "%S => EntityData(%S, %s, %S, %S, %S, %S)" entity))))
#  org-entities "\n")

const Entities = Dict(
    # * Letters
    # ** Latin
    "Agrave" => EntityData("\\`{A}", true, "&Agrave;", "A", "À", "À"),
    "agrave" => EntityData("\\`{a}", true, "&agrave;", "a", "à", "à"),
    "Aacute" => EntityData("\\'{A}", true, "&Aacute;", "A", "Á", "Á"),
    "aacute" => EntityData("\\'{a}", true, "&aacute;", "a", "á", "á"),
    "Acirc" => EntityData("\\^{A}", true, "&Acirc;", "A", "Â", "Â"),
    "acirc" => EntityData("\\^{a}", true, "&acirc;", "a", "â", "â"),
    "Amacr" => EntityData("\\bar{A}", true, "&Amacr;", "A", "Ã", "Ã"),
    "amacr" => EntityData("\\bar{a}", true, "&amacr;", "a", "ã", "ã"),
    "Atilde" => EntityData("\\~{A}", true, "&Atilde;", "A", "Ã", "Ã"),
    "atilde" => EntityData("\\~{a}", true, "&atilde;", "a", "ã", "ã"),
    "Auml" => EntityData("\\\"{A}", true, "&Auml;", "Ae", "Ä", "Ä"),
    "auml" => EntityData("\\\"{a}", true, "&auml;", "ae", "ä", "ä"),
    "Aring" => EntityData("\\AA{}", true, "&Aring;", "A", "Å", "Å"),
    "AA" => EntityData("\\AA{}", true, "&Aring;", "A", "Å", "Å"),
    "aring" => EntityData("\\aa{}", true, "&aring;", "a", "å", "å"),
    "AElig" => EntityData("\\AE{}", true, "&AElig;", "AE", "Æ", "Æ"),
    "aelig" => EntityData("\\ae{}", true, "&aelig;", "ae", "æ", "æ"),
    "Ccedil" => EntityData("\\c{C}", true, "&Ccedil;", "C", "Ç", "Ç"),
    "ccedil" => EntityData("\\c{c}", true, "&ccedil;", "c", "ç", "ç"),
    "Egrave" => EntityData("\\`{E}", true, "&Egrave;", "E", "È", "È"),
    "egrave" => EntityData("\\`{e}", true, "&egrave;", "e", "è", "è"),
    "Eacute" => EntityData("\\'{E}", true, "&Eacute;", "E", "É", "É"),
    "eacute" => EntityData("\\'{e}", true, "&eacute;", "e", "é", "é"),
    "Ecirc" => EntityData("\\^{E}", true, "&Ecirc;", "E", "Ê", "Ê"),
    "ecirc" => EntityData("\\^{e}", true, "&ecirc;", "e", "ê", "ê"),
    "Euml" => EntityData("\\\"{E}", true, "&Euml;", "E", "Ë", "Ë"),
    "euml" => EntityData("\\\"{e}", true, "&euml;", "e", "ë", "ë"),
    "Igrave" => EntityData("\\`{I}", true, "&Igrave;", "I", "Ì", "Ì"),
    "igrave" => EntityData("\\`{i}", true, "&igrave;", "i", "ì", "ì"),
    "Iacute" => EntityData("\\'{I}", true, "&Iacute;", "I", "Í", "Í"),
    "iacute" => EntityData("\\'{i}", true, "&iacute;", "i", "í", "í"),
    "Idot" => EntityData("\\.{I}", true, "&idot;", "I", "İ", "İ"),
    "inodot" => EntityData("\\i", true, "&inodot;", "i", "ı", "ı"),
    "Icirc" => EntityData("\\^{I}", true, "&Icirc;", "I", "Î", "Î"),
    "icirc" => EntityData("\\^{i}", true, "&icirc;", "i", "î", "î"),
    "Iuml" => EntityData("\\\"{I}", true, "&Iuml;", "I", "Ï", "Ï"),
    "iuml" => EntityData("\\\"{i}", true, "&iuml;", "i", "ï", "ï"),
    "Ntilde" => EntityData("\\~{N}", true, "&Ntilde;", "N", "Ñ", "Ñ"),
    "ntilde" => EntityData("\\~{n}", true, "&ntilde;", "n", "ñ", "ñ"),
    "Ograve" => EntityData("\\`{O}", true, "&Ograve;", "O", "Ò", "Ò"),
    "ograve" => EntityData("\\`{o}", true, "&ograve;", "o", "ò", "ò"),
    "Oacute" => EntityData("\\'{O}", true, "&Oacute;", "O", "Ó", "Ó"),
    "oacute" => EntityData("\\'{o}", true, "&oacute;", "o", "ó", "ó"),
    "Ocirc" => EntityData("\\^{O}", true, "&Ocirc;", "O", "Ô", "Ô"),
    "ocirc" => EntityData("\\^{o}", true, "&ocirc;", "o", "ô", "ô"),
    "Otilde" => EntityData("\\~{O}", true, "&Otilde;", "O", "Õ", "Õ"),
    "otilde" => EntityData("\\~{o}", true, "&otilde;", "o", "õ", "õ"),
    "Ouml" => EntityData("\\\"{O}", true, "&Ouml;", "Oe", "Ö", "Ö"),
    "ouml" => EntityData("\\\"{o}", true, "&ouml;", "oe", "ö", "ö"),
    "Oslash" => EntityData("\\O", true, "&Oslash;", "O", "Ø", "Ø"),
    "oslash" => EntityData("\\o{}", true, "&oslash;", "o", "ø", "ø"),
    "OElig" => EntityData("\\OE{}", true, "&OElig;", "OE", "OE", "Œ"),
    "oelig" => EntityData("\\oe{}", true, "&oelig;", "oe", "oe", "œ"),
    "Scaron" => EntityData("\\v{S}", true, "&Scaron;", "S", "S", "Š"),
    "scaron" => EntityData("\\v{s}", true, "&scaron;", "s", "s", "š"),
    "szlig" => EntityData("\\ss{}", true, "&szlig;", "ss", "ß", "ß"),
    "Ugrave" => EntityData("\\`{U}", true, "&Ugrave;", "U", "Ù", "Ù"),
    "ugrave" => EntityData("\\`{u}", true, "&ugrave;", "u", "ù", "ù"),
    "Uacute" => EntityData("\\'{U}", true, "&Uacute;", "U", "Ú", "Ú"),
    "uacute" => EntityData("\\'{u}", true, "&uacute;", "u", "ú", "ú"),
    "Ucirc" => EntityData("\\^{U}", true, "&Ucirc;", "U", "Û", "Û"),
    "ucirc" => EntityData("\\^{u}", true, "&ucirc;", "u", "û", "û"),
    "Uuml" => EntityData("\\\"{U}", true, "&Uuml;", "Ue", "Ü", "Ü"),
    "uuml" => EntityData("\\\"{u}", true, "&uuml;", "ue", "ü", "ü"),
    "Yacute" => EntityData("\\'{Y}", true, "&Yacute;", "Y", "Ý", "Ý"),
    "yacute" => EntityData("\\'{y}", true, "&yacute;", "y", "ý", "ý"),
    "Yuml" => EntityData("\\\"{Y}", true, "&Yuml;", "Y", "Y", "Ÿ"),
    "yuml" => EntityData("\\\"{y}", true, "&yuml;", "y", "ÿ", "ÿ"),
    # ** Latin (special face)
    "fnof" => EntityData("\\textit{f}", true, "&fnof;", "f", "f", "ƒ"),
    "real" => EntityData("\\Re", true, "&real;", "R", "R", "ℜ"),
    "image" => EntityData("\\Im", true, "&image;", "I", "I", "ℑ"),
    "weierp" => EntityData("\\wp", true, "&weierp;", "P", "P", "℘"),
    "ell" => EntityData("\\ell", true, "&ell;", "ell", "ell", "ℓ"),
    "imath" => EntityData("\\imath", true, "&imath;", "[dotless i]", "dotless i", "ı"),
    "jmath" => EntityData("\\jmath", true, "&jmath;", "[dotless j]", "dotless j", "ȷ"),
    # ** Greek
    "Alpha" => EntityData("A", true, "&Alpha;", "Alpha", "Alpha", "Α"),
    "alpha" => EntityData("\\alpha", true, "&alpha;", "alpha", "alpha", "α"),
    "Beta" => EntityData("B", true, "&Beta;", "Beta", "Beta", "Β"),
    "beta" => EntityData("\\beta", true, "&beta;", "beta", "beta", "β"),
    "Gamma" => EntityData("\\Gamma", true, "&Gamma;", "Gamma", "Gamma", "Γ"),
    "gamma" => EntityData("\\gamma", true, "&gamma;", "gamma", "gamma", "γ"),
    "Delta" => EntityData("\\Delta", true, "&Delta;", "Delta", "Delta", "Δ"),
    "delta" => EntityData("\\delta", true, "&delta;", "delta", "delta", "δ"),
    "Epsilon" => EntityData("E", true, "&Epsilon;", "Epsilon", "Epsilon", "Ε"),
    "epsilon" => EntityData("\\epsilon", true, "&epsilon;", "epsilon", "epsilon", "ε"),
    "varepsilon" => EntityData("\\varepsilon", true, "&epsilon;", "varepsilon", "varepsilon", "ε"),
    "Zeta" => EntityData("Z", true, "&Zeta;", "Zeta", "Zeta", "Ζ"),
    "zeta" => EntityData("\\zeta", true, "&zeta;", "zeta", "zeta", "ζ"),
    "Eta" => EntityData("H", true, "&Eta;", "Eta", "Eta", "Η"),
    "eta" => EntityData("\\eta", true, "&eta;", "eta", "eta", "η"),
    "Theta" => EntityData("\\Theta", true, "&Theta;", "Theta", "Theta", "Θ"),
    "theta" => EntityData("\\theta", true, "&theta;", "theta", "theta", "θ"),
    "thetasym" => EntityData("\\vartheta", true, "&thetasym;", "theta", "theta", "ϑ"),
    "vartheta" => EntityData("\\vartheta", true, "&thetasym;", "theta", "theta", "ϑ"),
    "Iota" => EntityData("I", true, "&Iota;", "Iota", "Iota", "Ι"),
    "iota" => EntityData("\\iota", true, "&iota;", "iota", "iota", "ι"),
    "Kappa" => EntityData("K", true, "&Kappa;", "Kappa", "Kappa", "Κ"),
    "kappa" => EntityData("\\kappa", true, "&kappa;", "kappa", "kappa", "κ"),
    "Lambda" => EntityData("\\Lambda", true, "&Lambda;", "Lambda", "Lambda", "Λ"),
    "lambda" => EntityData("\\lambda", true, "&lambda;", "lambda", "lambda", "λ"),
    "Mu" => EntityData("M", true, "&Mu;", "Mu", "Mu", "Μ"),
    "mu" => EntityData("\\mu", true, "&mu;", "mu", "mu", "μ"),
    "nu" => EntityData("\\nu", true, "&nu;", "nu", "nu", "ν"),
    "Nu" => EntityData("N", true, "&Nu;", "Nu", "Nu", "Ν"),
    "Xi" => EntityData("\\Xi", true, "&Xi;", "Xi", "Xi", "Ξ"),
    "xi" => EntityData("\\xi", true, "&xi;", "xi", "xi", "ξ"),
    "Omicron" => EntityData("O", true, "&Omicron;", "Omicron", "Omicron", "Ο"),
    "omicron" => EntityData("\\textit{o}", true, "&omicron;", "omicron", "omicron", "ο"),
    "Pi" => EntityData("\\Pi", true, "&Pi;", "Pi", "Pi", "Π"),
    "pi" => EntityData("\\pi", true, "&pi;", "pi", "pi", "π"),
    "Rho" => EntityData("P", true, "&Rho;", "Rho", "Rho", "Ρ"),
    "rho" => EntityData("\\rho", true, "&rho;", "rho", "rho", "ρ"),
    "Sigma" => EntityData("\\Sigma", true, "&Sigma;", "Sigma", "Sigma", "Σ"),
    "sigma" => EntityData("\\sigma", true, "&sigma;", "sigma", "sigma", "σ"),
    "sigmaf" => EntityData("\\varsigma", true, "&sigmaf;", "sigmaf", "sigmaf", "ς"),
    "varsigma" => EntityData("\\varsigma", true, "&sigmaf;", "varsigma", "varsigma", "ς"),
    "Tau" => EntityData("T", true, "&Tau;", "Tau", "Tau", "Τ"),
    "Upsilon" => EntityData("\\Upsilon", true, "&Upsilon;", "Upsilon", "Upsilon", "Υ"),
    "upsih" => EntityData("\\Upsilon", true, "&upsih;", "upsilon", "upsilon", "ϒ"),
    "upsilon" => EntityData("\\upsilon", true, "&upsilon;", "upsilon", "upsilon", "υ"),
    "Phi" => EntityData("\\Phi", true, "&Phi;", "Phi", "Phi", "Φ"),
    "phi" => EntityData("\\phi", true, "&phi;", "phi", "phi", "ɸ"),
    "varphi" => EntityData("\\varphi", true, "&varphi;", "varphi", "varphi", "φ"),
    "Chi" => EntityData("X", true, "&Chi;", "Chi", "Chi", "Χ"),
    "chi" => EntityData("\\chi", true, "&chi;", "chi", "chi", "χ"),
    "acutex" => EntityData("\\acute x", true, "&acute;x", "'x", "'x", "𝑥́"),
    "Psi" => EntityData("\\Psi", true, "&Psi;", "Psi", "Psi", "Ψ"),
    "psi" => EntityData("\\psi", true, "&psi;", "psi", "psi", "ψ"),
    "tau" => EntityData("\\tau", true, "&tau;", "tau", "tau", "τ"),
    "Omega" => EntityData("\\Omega", true, "&Omega;", "Omega", "Omega", "Ω"),
    "omega" => EntityData("\\omega", true, "&omega;", "omega", "omega", "ω"),
    "piv" => EntityData("\\varpi", true, "&piv;", "omega-pi", "omega-pi", "ϖ"),
    "varpi" => EntityData("\\varpi", true, "&piv;", "omega-pi", "omega-pi", "ϖ"),
    "partial" => EntityData("\\partial", true, "&part;", "[partial differential]", "[partial differential]", "∂"),
    # ** Hebrew
    "alefsym" => EntityData("\\aleph", true, "&alefsym;", "aleph", "aleph", "ℵ"),
    "aleph" => EntityData("\\aleph", true, "&aleph;", "aleph", "aleph", "ℵ"),
    "gimel" => EntityData("\\gimel", true, "&gimel;", "gimel", "gimel", "ℷ"),
    "beth" => EntityData("\\beth", true, "&beth;", "beth", "beth", "ב"),
    "dalet" => EntityData("\\daleth", true, "&daleth;", "dalet", "dalet", "ד"),
    # ** Icelandic
    "ETH" => EntityData("\\DH{}", true, "&ETH;", "D", "Ð", "Ð"),
    "eth" => EntityData("\\dh{}", true, "&eth;", "dh", "ð", "ð"),
    "THORN" => EntityData("\\TH{}", true, "&THORN;", "TH", "Þ", "Þ"),
    "thorn" => EntityData("\\th{}", true, "&thorn;", "th", "þ", "þ"),
    # * Punctuation
    # ** Dots and Marks
    "dots" => EntityData("\\dots{}", true, "&hellip;", "...", "...", "…"),
    "cdots" => EntityData("\\cdots{}", true, "&ctdot;", "...", "...", "⋯"),
    "hellip" => EntityData("\\dots{}", true, "&hellip;", "...", "...", "…"),
    "middot" => EntityData("\\textperiodcentered{}", true, "&middot;", ".", "·", "·"),
    "iexcl" => EntityData("!`", true, "&iexcl;", "!", "¡", "¡"),
    "iquest" => EntityData("?`", true, "&iquest;", "?", "¿", "¿"),
    # ** Dash-like
    "shy" => EntityData("\\-", true, "&shy;", "", "", ""),
    "ndash" => EntityData("--", true, "&ndash;", "-", "-", "–"),
    "mdash" => EntityData("---", true, "&mdash;", "--", "--", "—"),
    # ** Quotations
    "quot" => EntityData("\\textquotedbl{}", true, "&quot;", "\"", "\"", "\""),
    "acute" => EntityData("\\textasciiacute{}", true, "&acute;", "'", "´", "´"),
    "ldquo" => EntityData("\\textquotedblleft{}", true, "&ldquo;", "\"", "\"", "“"),
    "rdquo" => EntityData("\\textquotedblright{}", true, "&rdquo;", "\"", "\"", "”"),
    "bdquo" => EntityData("\\quotedblbase{}", true, "&bdquo;", "\"", "\"", "„"),
    "lsquo" => EntityData("\\textquoteleft{}", true, "&lsquo;", "`", "`", "‘"),
    "rsquo" => EntityData("\\textquoteright{}", true, "&rsquo;", "'", "'", "’"),
    "sbquo" => EntityData("\\quotesinglbase{}", true, "&sbquo;", ",", ",", "‚"),
    "laquo" => EntityData("\\guillemotleft{}", true, "&laquo;", "<<", "«", "«"),
    "raquo" => EntityData("\\guillemotright{}", true, "&raquo;", ">>", "»", "»"),
    "lsaquo" => EntityData("\\guilsinglleft{}", true, "&lsaquo;", "<", "<", "‹"),
    "rsaquo" => EntityData("\\guilsinglright{}", true, "&rsaquo;", ">", ">", "›"),
    # * Other
    # ** Misc. (often used)
    "circ" => EntityData("\\^{}", true, "&circ;", "^", "^", "∘"),
    "vert" => EntityData("\\vert{}", true, "&vert;", "|", "|", "|"),
    "vbar" => EntityData("|", true, "|", "|", "|", "|"),
    "brvbar" => EntityData("\\textbrokenbar{}", true, "&brvbar;", "|", "¦", "¦"),
    "S" => EntityData("\\S", true, "&sect;", "paragraph", "§", "§"),
    "sect" => EntityData("\\S", true, "&sect;", "paragraph", "§", "§"),
    "amp" => EntityData("\\&", true, "&amp;", "&", "&", "&"),
    "lt" => EntityData("\\textless{}", true, "&lt;", "<", "<", "<"),
    "gt" => EntityData("\\textgreater{}", true, "&gt;", ">", ">", ">"),
    "tilde" => EntityData("\\textasciitilde{}", true, "~", "~", "~", "~"),
    "slash" => EntityData("/", true, "/", "/", "/", "/"),
    "plus" => EntityData("+", true, "+", "+", "+", "+"),
    "under" => EntityData("\\_", true, "_", "_", "_", "_"),
    "equal" => EntityData("=", true, "=", "=", "=", "="),
    "asciicirc" => EntityData("\\textasciicircum{}", true, "^", "^", "^", "^"),
    "dagger" => EntityData("\\textdagger{}", true, "&dagger;", "[dagger]", "[dagger]", "†"),
    "dag" => EntityData("\\dag{}", true, "&dagger;", "[dagger]", "[dagger]", "†"),
    "Dagger" => EntityData("\\textdaggerdbl{}", true, "&Dagger;", "[doubledagger]", "[doubledagger]", "‡"),
    "ddag" => EntityData("\\ddag{}", true, "&Dagger;", "[doubledagger]", "[doubledagger]", "‡"),
    # ** Whitespace
    "nbsp" => EntityData("~", true, "&nbsp;", " ", " ", " "),
    "ensp" => EntityData("\\hspace*{.5em}", true, "&ensp;", " ", " ", " "),
    "emsp" => EntityData("\\hspace*{1em}", true, "&emsp;", " ", " ", " "),
    "thinsp" => EntityData("\\hspace*{.2em}", true, "&thinsp;", " ", " ", " "),
    # ** Currency
    "curren" => EntityData("\\textcurrency{}", true, "&curren;", "curr.", "¤", "¤"),
    "cent" => EntityData("\\textcent{}", true, "&cent;", "cent", "¢", "¢"),
    "pound" => EntityData("\\pounds{}", true, "&pound;", "pound", "£", "£"),
    "yen" => EntityData("\\textyen{}", true, "&yen;", "yen", "¥", "¥"),
    "euro" => EntityData("\\texteuro{}", true, "&euro;", "EUR", "EUR", "€"),
    "EUR" => EntityData("\\texteuro{}", true, "&euro;", "EUR", "EUR", "€"),
    "dollar" => EntityData("\\\$", true, "\$", "\$", "\$", "\$"),
    "USD" => EntityData("\\\$", true, "\$", "\$", "\$", "\$"),
    # ** Property Marks
    "copy" => EntityData("\\textcopyright{}", true, "&copy;", "(c)", "©", "©"),
    "reg" => EntityData("\\textregistered{}", true, "&reg;", "(r)", "®", "®"),
    "trade" => EntityData("\\texttrademark{}", true, "&trade;", "TM", "TM", "™"),
    # ** Science et al.
    "minus" => EntityData("\\minus", true, "&minus;", "-", "-", "−"),
    "pm" => EntityData("\\textpm{}", true, "&plusmn;", "+-", "±", "±"),
    "plusmn" => EntityData("\\textpm{}", true, "&plusmn;", "+-", "±", "±"),
    "times" => EntityData("\\texttimes{}", true, "&times;", "*", "×", "×"),
    "frasl" => EntityData("/", true, "&frasl;", "/", "/", "⁄"),
    "colon" => EntityData("\\colon", true, ":", ":", ":", ":"),
    "div" => EntityData("\\textdiv{}", true, "&divide;", "/", "÷", "÷"),
    "frac12" => EntityData("\\textonehalf{}", true, "&frac12;", "1/2", "½", "½"),
    "frac14" => EntityData("\\textonequarter{}", true, "&frac14;", "1/4", "¼", "¼"),
    "frac34" => EntityData("\\textthreequarters{}", true, "&frac34;", "3/4", "¾", "¾"),
    "permil" => EntityData("\\textperthousand{}", true, "&permil;", "per thousand", "per thousand", "‰"),
    "sup1" => EntityData("\\textonesuperior{}", true, "&sup1;", "^1", "¹", "¹"),
    "sup2" => EntityData("\\texttwosuperior{}", true, "&sup2;", "^2", "²", "²"),
    "sup3" => EntityData("\\textthreesuperior{}", true, "&sup3;", "^3", "³", "³"),
    "radic" => EntityData("\\sqrt{\\,}", true, "&radic;", "[square root]", "[square root]", "√"),
    "sum" => EntityData("\\sum", true, "&sum;", "[sum]", "[sum]", "∑"),
    "prod" => EntityData("\\prod", true, "&prod;", "[product]", "[n-ary product]", "∏"),
    "micro" => EntityData("\\textmu{}", true, "&micro;", "micro", "µ", "µ"),
    "macr" => EntityData("\\textasciimacron{}", true, "&macr;", "[macron]", "¯", "¯"),
    "deg" => EntityData("\\textdegree{}", true, "&deg;", "degree", "°", "°"),
    "prime" => EntityData("\\prime", true, "&prime;", "'", "'", "′"),
    "Prime" => EntityData("\\prime{}\\prime", true, "&Prime;", "''", "''", "″"),
    "infin" => EntityData("\\infty", true, "&infin;", "[infinity]", "[infinity]", "∞"),
    "infty" => EntityData("\\infty", true, "&infin;", "[infinity]", "[infinity]", "∞"),
    "prop" => EntityData("\\propto", true, "&prop;", "[proportional to]", "[proportional to]", "∝"),
    "propto" => EntityData("\\propto", true, "&prop;", "[proportional to]", "[proportional to]", "∝"),
    "not" => EntityData("\\textlnot{}", true, "&not;", "[angled dash]", "¬", "¬"),
    "neg" => EntityData("\\neg{}", true, "&not;", "[angled dash]", "¬", "¬"),
    "land" => EntityData("\\land", true, "&and;", "[logical and]", "[logical and]", "∧"),
    "wedge" => EntityData("\\wedge", true, "&and;", "[logical and]", "[logical and]", "∧"),
    "lor" => EntityData("\\lor", true, "&or;", "[logical or]", "[logical or]", "∨"),
    "vee" => EntityData("\\vee", true, "&or;", "[logical or]", "[logical or]", "∨"),
    "cap" => EntityData("\\cap", true, "&cap;", "[intersection]", "[intersection]", "∩"),
    "cup" => EntityData("\\cup", true, "&cup;", "[union]", "[union]", "∪"),
    "smile" => EntityData("\\smile", true, "&smile;", "[cup product]", "[cup product]", "⌣"),
    "frown" => EntityData("\\frown", true, "&frown;", "[Cap product]", "[cap product]", "⌢"),
    "int" => EntityData("\\int", true, "&int;", "[integral]", "[integral]", "∫"),
    "therefore" => EntityData("\\therefore", true, "&there4;", "[therefore]", "[therefore]", "∴"),
    "there4" => EntityData("\\therefore", true, "&there4;", "[therefore]", "[therefore]", "∴"),
    "because" => EntityData("\\because", true, "&because;", "[because]", "[because]", "∵"),
    "sim" => EntityData("\\sim", true, "&sim;", "~", "~", "∼"),
    "cong" => EntityData("\\cong", true, "&cong;", "[approx. equal to]", "[approx. equal to]", "≅"),
    "simeq" => EntityData("\\simeq", true, "&cong;", "[approx. equal to]", "[approx. equal to]", "≅"),
    "asymp" => EntityData("\\asymp", true, "&asymp;", "[almost equal to]", "[almost equal to]", "≈"),
    "approx" => EntityData("\\approx", true, "&asymp;", "[almost equal to]", "[almost equal to]", "≈"),
    "ne" => EntityData("\\ne", true, "&ne;", "[not equal to]", "[not equal to]", "≠"),
    "neq" => EntityData("\\neq", true, "&ne;", "[not equal to]", "[not equal to]", "≠"),
    "equiv" => EntityData("\\equiv", true, "&equiv;", "[identical to]", "[identical to]", "≡"),
    "triangleq" => EntityData("\\triangleq", true, "&triangleq;", "[defined to]", "[defined to]", "≜"),
    "le" => EntityData("\\le", true, "&le;", "<=", "<=", "≤"),
    "leq" => EntityData("\\le", true, "&le;", "<=", "<=", "≤"),
    "ge" => EntityData("\\ge", true, "&ge;", ">=", ">=", "≥"),
    "geq" => EntityData("\\ge", true, "&ge;", ">=", ">=", "≥"),
    "lessgtr" => EntityData("\\lessgtr", true, "&lessgtr;", "[less than or greater than]", "[less than or greater than]", "≶"),
    "lesseqgtr" => EntityData("\\lesseqgtr", true, "&lesseqgtr;", "[less than or equal or greater than or equal]", "[less than or equal or greater than or equal]", "⋚"),
    "ll" => EntityData("\\ll", true, "&Lt;", "<<", "<<", "≪"),
    "Ll" => EntityData("\\lll", true, "&Ll;", "<<<", "<<<", "⋘"),
    "lll" => EntityData("\\lll", true, "&Ll;", "<<<", "<<<", "⋘"),
    "gg" => EntityData("\\gg", true, "&Gt;", ">>", ">>", "≫"),
    "Gg" => EntityData("\\ggg", true, "&Gg;", ">>>", ">>>", "⋙"),
    "ggg" => EntityData("\\ggg", true, "&Gg;", ">>>", ">>>", "⋙"),
    "prec" => EntityData("\\prec", true, "&pr;", "[precedes]", "[precedes]", "≺"),
    "preceq" => EntityData("\\preceq", true, "&prcue;", "[precedes or equal]", "[precedes or equal]", "≼"),
    "preccurlyeq" => EntityData("\\preccurlyeq", true, "&prcue;", "[precedes or equal]", "[precedes or equal]", "≼"),
    "succ" => EntityData("\\succ", true, "&sc;", "[succeeds]", "[succeeds]", "≻"),
    "succeq" => EntityData("\\succeq", true, "&sccue;", "[succeeds or equal]", "[succeeds or equal]", "≽"),
    "succcurlyeq" => EntityData("\\succcurlyeq", true, "&sccue;", "[succeeds or equal]", "[succeeds or equal]", "≽"),
    "sub" => EntityData("\\subset", true, "&sub;", "[subset of]", "[subset of]", "⊂"),
    "subset" => EntityData("\\subset", true, "&sub;", "[subset of]", "[subset of]", "⊂"),
    "sup" => EntityData("\\supset", true, "&sup;", "[superset of]", "[superset of]", "⊃"),
    "supset" => EntityData("\\supset", true, "&sup;", "[superset of]", "[superset of]", "⊃"),
    "nsub" => EntityData("\\not\\subset", true, "&nsub;", "[not a subset of]", "[not a subset of", "⊄"),
    "sube" => EntityData("\\subseteq", true, "&sube;", "[subset of or equal to]", "[subset of or equal to]", "⊆"),
    "nsup" => EntityData("\\not\\supset", true, "&nsup;", "[not a superset of]", "[not a superset of]", "⊅"),
    "supe" => EntityData("\\supseteq", true, "&supe;", "[superset of or equal to]", "[superset of or equal to]", "⊇"),
    "setminus" => EntityData("\\setminus", true, "&setminus;", "\\", " \\", "⧵"),
    "forall" => EntityData("\\forall", true, "&forall;", "[for all]", "[for all]", "∀"),
    "exist" => EntityData("\\exists", true, "&exist;", "[there exists]", "[there exists]", "∃"),
    "exists" => EntityData("\\exists", true, "&exist;", "[there exists]", "[there exists]", "∃"),
    "nexist" => EntityData("\\nexists", true, "&exist;", "[there does not exists]", "[there does not  exists]", "∄"),
    "nexists" => EntityData("\\nexists", true, "&exist;", "[there does not exists]", "[there does not  exists]", "∄"),
    "empty" => EntityData("\\emptyset", true, "&empty;", "[empty set]", "[empty set]", "∅"),
    "emptyset" => EntityData("\\emptyset", true, "&empty;", "[empty set]", "[empty set]", "∅"),
    "isin" => EntityData("\\in", true, "&isin;", "[element of]", "[element of]", "∈"),
    "in" => EntityData("\\in", true, "&isin;", "[element of]", "[element of]", "∈"),
    "notin" => EntityData("\\notin", true, "&notin;", "[not an element of]", "[not an element of]", "∉"),
    "ni" => EntityData("\\ni", true, "&ni;", "[contains as member]", "[contains as member]", "∋"),
    "nabla" => EntityData("\\nabla", true, "&nabla;", "[nabla]", "[nabla]", "∇"),
    "ang" => EntityData("\\angle", true, "&ang;", "[angle]", "[angle]", "∠"),
    "angle" => EntityData("\\angle", true, "&ang;", "[angle]", "[angle]", "∠"),
    "perp" => EntityData("\\perp", true, "&perp;", "[up tack]", "[up tack]", "⊥"),
    "parallel" => EntityData("\\parallel", true, "&parallel;", "||", "||", "∥"),
    "sdot" => EntityData("\\cdot", true, "&sdot;", "[dot]", "[dot]", "⋅"),
    "cdot" => EntityData("\\cdot", true, "&sdot;", "[dot]", "[dot]", "⋅"),
    "lceil" => EntityData("\\lceil", true, "&lceil;", "[left ceiling]", "[left ceiling]", "⌈"),
    "rceil" => EntityData("\\rceil", true, "&rceil;", "[right ceiling]", "[right ceiling]", "⌉"),
    "lfloor" => EntityData("\\lfloor", true, "&lfloor;", "[left floor]", "[left floor]", "⌊"),
    "rfloor" => EntityData("\\rfloor", true, "&rfloor;", "[right floor]", "[right floor]", "⌋"),
    "lang" => EntityData("\\langle", true, "&lang;", "<", "<", "⟨"),
    "rang" => EntityData("\\rangle", true, "&rang;", ">", ">", "⟩"),
    "langle" => EntityData("\\langle", true, "&lang;", "<", "<", "⟨"),
    "rangle" => EntityData("\\rangle", true, "&rang;", ">", ">", "⟩"),
    "hbar" => EntityData("\\hbar", true, "&hbar;", "hbar", "hbar", "ℏ"),
    "mho" => EntityData("\\mho", true, "&mho;", "mho", "mho", "℧"),
    # ** Arrows
    "larr" => EntityData("\\leftarrow", true, "&larr;", "<-", "<-", "←"),
    "leftarrow" => EntityData("\\leftarrow", true, "&larr;", "<-", "<-", "←"),
    "gets" => EntityData("\\gets", true, "&larr;", "<-", "<-", "←"),
    "lArr" => EntityData("\\Leftarrow", true, "&lArr;", "<=", "<=", "⇐"),
    "Leftarrow" => EntityData("\\Leftarrow", true, "&lArr;", "<=", "<=", "⇐"),
    "uarr" => EntityData("\\uparrow", true, "&uarr;", "[uparrow]", "[uparrow]", "↑"),
    "uparrow" => EntityData("\\uparrow", true, "&uarr;", "[uparrow]", "[uparrow]", "↑"),
    "uArr" => EntityData("\\Uparrow", true, "&uArr;", "[dbluparrow]", "[dbluparrow]", "⇑"),
    "Uparrow" => EntityData("\\Uparrow", true, "&uArr;", "[dbluparrow]", "[dbluparrow]", "⇑"),
    "rarr" => EntityData("\\rightarrow", true, "&rarr;", "->", "->", "→"),
    "to" => EntityData("\\to", true, "&rarr;", "->", "->", "→"),
    "rightarrow" => EntityData("\\rightarrow", true, "&rarr;", "->", "->", "→"),
    "rArr" => EntityData("\\Rightarrow", true, "&rArr;", "=>", "=>", "⇒"),
    "Rightarrow" => EntityData("\\Rightarrow", true, "&rArr;", "=>", "=>", "⇒"),
    "darr" => EntityData("\\downarrow", true, "&darr;", "[downarrow]", "[downarrow]", "↓"),
    "downarrow" => EntityData("\\downarrow", true, "&darr;", "[downarrow]", "[downarrow]", "↓"),
    "dArr" => EntityData("\\Downarrow", true, "&dArr;", "[dbldownarrow]", "[dbldownarrow]", "⇓"),
    "Downarrow" => EntityData("\\Downarrow", true, "&dArr;", "[dbldownarrow]", "[dbldownarrow]", "⇓"),
    "harr" => EntityData("\\leftrightarrow", true, "&harr;", "<->", "<->", "↔"),
    "leftrightarrow" => EntityData("\\leftrightarrow", true, "&harr;", "<->", "<->", "↔"),
    "hArr" => EntityData("\\Leftrightarrow", true, "&hArr;", "<=>", "<=>", "⇔"),
    "Leftrightarrow" => EntityData("\\Leftrightarrow", true, "&hArr;", "<=>", "<=>", "⇔"),
    "crarr" => EntityData("\\hookleftarrow", true, "&crarr;", "<-'", "<-'", "↵"),
    "hookleftarrow" => EntityData("\\hookleftarrow", true, "&crarr;", "<-'", "<-'", "↵"),
    # ** Function names
    "arccos" => EntityData("\\arccos", true, "arccos", "arccos", "arccos", "arccos"),
    "arcsin" => EntityData("\\arcsin", true, "arcsin", "arcsin", "arcsin", "arcsin"),
    "arctan" => EntityData("\\arctan", true, "arctan", "arctan", "arctan", "arctan"),
    "arg" => EntityData("\\arg", true, "arg", "arg", "arg", "arg"),
    "cos" => EntityData("\\cos", true, "cos", "cos", "cos", "cos"),
    "cosh" => EntityData("\\cosh", true, "cosh", "cosh", "cosh", "cosh"),
    "cot" => EntityData("\\cot", true, "cot", "cot", "cot", "cot"),
    "coth" => EntityData("\\coth", true, "coth", "coth", "coth", "coth"),
    "csc" => EntityData("\\csc", true, "csc", "csc", "csc", "csc"),
    "deg" => EntityData("\\deg", true, "&deg;", "deg", "deg", "deg"),
    "det" => EntityData("\\det", true, "det", "det", "det", "det"),
    "dim" => EntityData("\\dim", true, "dim", "dim", "dim", "dim"),
    "exp" => EntityData("\\exp", true, "exp", "exp", "exp", "exp"),
    "gcd" => EntityData("\\gcd", true, "gcd", "gcd", "gcd", "gcd"),
    "hom" => EntityData("\\hom", true, "hom", "hom", "hom", "hom"),
    "inf" => EntityData("\\inf", true, "inf", "inf", "inf", "inf"),
    "ker" => EntityData("\\ker", true, "ker", "ker", "ker", "ker"),
    "lg" => EntityData("\\lg", true, "lg", "lg", "lg", "lg"),
    "lim" => EntityData("\\lim", true, "lim", "lim", "lim", "lim"),
    "liminf" => EntityData("\\liminf", true, "liminf", "liminf", "liminf", "liminf"),
    "limsup" => EntityData("\\limsup", true, "limsup", "limsup", "limsup", "limsup"),
    "ln" => EntityData("\\ln", true, "ln", "ln", "ln", "ln"),
    "log" => EntityData("\\log", true, "log", "log", "log", "log"),
    "max" => EntityData("\\max", true, "max", "max", "max", "max"),
    "min" => EntityData("\\min", true, "min", "min", "min", "min"),
    "Pr" => EntityData("\\Pr", true, "Pr", "Pr", "Pr", "Pr"),
    "sec" => EntityData("\\sec", true, "sec", "sec", "sec", "sec"),
    "sin" => EntityData("\\sin", true, "sin", "sin", "sin", "sin"),
    "sinh" => EntityData("\\sinh", true, "sinh", "sinh", "sinh", "sinh"),
    "sup" => EntityData("\\sup", true, "&sup;", "sup", "sup", "sup"),
    "tan" => EntityData("\\tan", true, "tan", "tan", "tan", "tan"),
    "tanh" => EntityData("\\tanh", true, "tanh", "tanh", "tanh", "tanh"),
    # ** Signs & Symbols
    "bull" => EntityData("\\textbullet{}", true, "&bull;", "*", "*", "•"),
    "bullet" => EntityData("\\textbullet{}", true, "&bull;", "*", "*", "•"),
    "star" => EntityData("\\star", true, "*", "*", "*", "⋆"),
    "lowast" => EntityData("\\ast", true, "&lowast;", "*", "*", "∗"),
    "ast" => EntityData("\\ast", true, "&lowast;", "*", "*", "*"),
    "odot" => EntityData("\\odot", true, "o", "[circled dot]", "[circled dot]", "ʘ"),
    "oplus" => EntityData("\\oplus", true, "&oplus;", "[circled plus]", "[circled plus]", "⊕"),
    "otimes" => EntityData("\\otimes", true, "&otimes;", "[circled times]", "[circled times]", "⊗"),
    "check" => EntityData("\\checkmark", true, "&checkmark;", "[checkmark]", "[checkmark]", "✓"),
    "checkmark" => EntityData("\\checkmark", true, "&check;", "[checkmark]", "[checkmark]", "✓"),
    # ** Miscellaneous (seldom used)
    "para" => EntityData("\\P{}", true, "&para;", "[pilcrow]", "¶", "¶"),
    "ordf" => EntityData("\\textordfeminine{}", true, "&ordf;", "_a_", "ª", "ª"),
    "ordm" => EntityData("\\textordmasculine{}", true, "&ordm;", "_o_", "º", "º"),
    "cedil" => EntityData("\\c{}", true, "&cedil;", "[cedilla]", "¸", "¸"),
    "oline" => EntityData("\\overline{~}", true, "&oline;", "[overline]", "¯", "‾"),
    "uml" => EntityData("\\textasciidieresis{}", true, "&uml;", "[diaeresis]", "¨", "¨"),
    "zwnj" => EntityData("\\/{}", true, "&zwnj;", "", "", "‌"),
    "zwj" => EntityData("", true, "&zwj;", "", "", "‍"),
    "lrm" => EntityData("", true, "&lrm;", "", "", "‎"),
    "rlm" => EntityData("", true, "&rlm;", "", "", "‏"),
    # ** Smilies
    "smiley" => EntityData("\\ddot\\smile", true, "&#9786;", ":-)", ":-)", "☺"),
    "blacksmile" => EntityData("\\ddot\\smile", true, "&#9787;", ":-)", ":-)", "☻"),
    "sad" => EntityData("\\ddot\\frown", true, "&#9785;", ":-(", ":-(", "☹"),
    "frowny" => EntityData("\\ddot\\frown", true, "&#9785;", ":-(", ":-(", "☹"),
    # ** Suits
    "clubs" => EntityData("\\clubsuit", true, "&clubs;", "[clubs]", "[clubs]", "♣"),
    "clubsuit" => EntityData("\\clubsuit", true, "&clubs;", "[clubs]", "[clubs]", "♣"),
    "spades" => EntityData("\\spadesuit", true, "&spades;", "[spades]", "[spades]", "♠"),
    "spadesuit" => EntityData("\\spadesuit", true, "&spades;", "[spades]", "[spades]", "♠"),
    "hearts" => EntityData("\\heartsuit", true, "&hearts;", "[hearts]", "[hearts]", "♥"),
    "heartsuit" => EntityData("\\heartsuit", true, "&heartsuit;", "[hearts]", "[hearts]", "♥"),
    "diams" => EntityData("\\diamondsuit", true, "&diams;", "[diamonds]", "[diamonds]", "◆"),
    "diamondsuit" => EntityData("\\diamondsuit", true, "&diams;", "[diamonds]", "[diamonds]", "◆"),
    "diamond" => EntityData("\\diamondsuit", true, "&diamond;", "[diamond]", "[diamond]", "◆"),
    "Diamond" => EntityData("\\diamondsuit", true, "&diamond;", "[diamond]", "[diamond]", "◆"),
    "loz" => EntityData("\\lozenge", true, "&loz;", "[lozenge]", "[lozenge]", "⧫"),
    "_ " => EntityData("\\hspace*{0.5em}", true, "&ensp;", " ", " ", " "),
    "_  " => EntityData("\\hspace*{1.0em}", true, "&ensp;&ensp;", "  ", "  ", "  "),
    "_   " => EntityData("\\hspace*{1.5em}", true, "&ensp;&ensp;&ensp;", "   ", "   ", "   "),
    "_    " => EntityData("\\hspace*{2.0em}", true, "&ensp;&ensp;&ensp;&ensp;", "    ", "    ", "    "),
    "_     " => EntityData("\\hspace*{2.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;", "     ", "     ", "     "),
    "_      " => EntityData("\\hspace*{3.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "      ", "      ", "      "),
    "_       " => EntityData("\\hspace*{3.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "       ", "       ", "       "),
    "_        " => EntityData("\\hspace*{4.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "        ", "        ", "        "),
    "_         " => EntityData("\\hspace*{4.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "         ", "         ", "         "),
    "_          " => EntityData("\\hspace*{5.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "          ", "          ", "          "),
    "_           " => EntityData("\\hspace*{5.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "           ", "           ", "           "),
    "_            " => EntityData("\\hspace*{6.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "            ", "            ", "            "),
    "_             " => EntityData("\\hspace*{6.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "             ", "             ", "             "),
    "_              " => EntityData("\\hspace*{7.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "              ", "              ", "              "),
    "_               " => EntityData("\\hspace*{7.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "               ", "               ", "               "),
    "_                " => EntityData("\\hspace*{8.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "                ", "                ", "                "),
    "_                 " => EntityData("\\hspace*{8.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "                 ", "                 ", "                 "),
    "_                  " => EntityData("\\hspace*{9.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "                  ", "                  ", "                  "),
    "_                   " => EntityData("\\hspace*{9.5em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "                   ", "                   ", "                   "),
    "_                    " => EntityData("\\hspace*{10.0em}", true, "&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;&ensp;", "                    ", "                    ", "                    "),
)
