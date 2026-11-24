%% miloscv.cls -- ATS-first single-column class for the milosvasic.ru career
%% documents (CV and cover letter).
%%
%% Design constraints, each paid for by a measurement rather than a taste:
%%
%%   * LIGATURES ARE OFF (`Ligatures=NoCommon`).  A PDF whose text layer holds
%%     U+FB00 instead of "ff" fails keyword matching in real ATS parsers.  The
%%     glyph looks right and the parser sees one character that no recruiter
%%     will ever search for.
%%   * NO ICON FONTS ANYWHERE.  A FontAwesome glyph in the contact line
%%     extracts as a private-use codepoint or nothing at all, so the phone
%%     number silently loses its label.
%%   * ONE COLUMN, RAGGED RIGHT.  Two-column layouts extract out of reading
%%     order, and justification drives the word spacing apart in the narrow
%%     measure a CV actually uses.
%%   * DIGITS NEVER COME FROM A CJK FONT.  Noto Sans CJK maps ASCII digits to
%%     FULLWIDTH forms (U+FF11...), which is invisible on screen and fatal to a
%%     parser looking for "2020".  Latin is therefore always the PRIMARY font
%%     and CJK is the FALLBACK, so digits shape from Noto Sans.
%%   * BYTE-REPRODUCIBLE.  `\pdfvariable suppressoptionalinfo 512` removes the
%%     `/ID` array, which is the only thing making two otherwise identical
%%     LuaLaTeX runs differ.  Measured: 512/768/1023 work, 0/32/64/96/256 do
%%     not.  The build also pins SOURCE_DATE_EPOCH.
%%
%% Engine: LuaLaTeX only.  Measured, not assumed: LuaHBTeX 1.22.0 extracts
%% Devanagari correctly in 6/6 pdftotext mode/font combinations where XeLaTeX
%% scores 1/6 and corrupts logical order (`वर्षों` -> `वर्षंो`).  Arabic and
%% Persian are NOT rendered here -- bidi.sty and luabidi.sty are absent on this
%% host, and LuaTeX's own RTL output extracts as Arabic PRESENTATION FORMS
%% (U+FExx) in visual order, so those two locales go through render/html.py
%% (WeasyPrint/Pango), measured to extract as base codepoints in logical order.

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{miloscv}[2026/11/19 v1.0 ATS-first career document]

% ---------------------------------------------------------------------------
% Options
% ---------------------------------------------------------------------------
% 11pt is a NATIVE article size.  10.5pt is not -- `article` silently ignores
% it and falls back to 10pt, which is how a font-size change becomes a no-op
% that nobody notices.  At 11pt with 26mm sides the measure is ~86 characters,
% inside the 75--85 readability band that the type research measured.
\LoadClass[11pt,a4paper]{article}

% The renderer sets these three BEFORE \documentclass, e.g.
%   \def\milosscript{cjk}\def\milosaccent{1F6FEB}
%   \documentclass[cover]{miloscv}
% No key=value class options: LaTeX's own option loop does not expose
% \CurrentOption to \DeclareOption*, and hand-rolling that parse is a bug farm
% for no benefit.
\providecommand{\milosscript}{latin}
\providecommand{\milosaccent}{1F6FEB}
\providecommand{\miloslang}{en}

\newif\ifmilos@cover
\milos@coverfalse
\DeclareOption{cover}{\milos@covertrue}
\DeclareOption*{\ClassWarning{miloscv}{ignoring unknown option \CurrentOption}}
\ProcessOptions\relax

% \edef, not \def: the \ifx tests below compare MACRO BODIES, and \def would make
% \milos@script the one-token body \milosscript -- never equal to 'deva'/'cjk', so
% every non-Latin locale silently loaded the Latin font (the U+FFFD root cause).
\edef\milos@script{\milosscript}
\def\milos@accent{\milosaccent}
\edef\milos@lang{\miloslang}

% ---------------------------------------------------------------------------
% Reproducibility: strip the /ID array so two builds are byte-identical.
% ---------------------------------------------------------------------------
\pdfvariable suppressoptionalinfo 512

% ---------------------------------------------------------------------------
% Page geometry.  16mm side margins keep the text block wide enough that a
% parser reading line by line never has to guess at continuation.
% ---------------------------------------------------------------------------
% 24mm side margins measured: they give ~96 characters per line at 10.5pt in
% Noto Sans, which sits at the top of the 75--85 readability band and is the
% narrowest margin that still looks deliberate rather than cramped.  16mm gave
% 107 characters, which is measurably too wide to scan.
\RequirePackage[a4paper,top=12mm,bottom=12mm,left=26mm,right=26mm]{geometry}
\RequirePackage{fontspec}
\RequirePackage{xcolor}
\RequirePackage{titlesec}
\RequirePackage{enumitem}
\RequirePackage{tabularx}
\RequirePackage{array}
\RequirePackage{ragged2e}
\RequirePackage{microtype}
\RequirePackage{needspace}
\RequirePackage{lastpage}
\RequirePackage{fancyhdr}
\RequirePackage[hidelinks,unicode]{hyperref}
\RequirePackage{etoolbox}

% Tagged build (\DocumentMetadata{tagging=on} is emitted by the renderer).
% tagpdf otherwise rewrites every line-end hyphen to U+00AD in the text layer;
% measured: that soft hyphen is forbidden by gates._NO_ARTIFACT_RANGES because
% an ATS reads "communi<U+00AD>cation" as two words.  Off, the hyphen extracts
% as the ASCII "-" it always did.
\ifdefined\tagpdfsetup\tagpdfsetup{activate/softhyphen=false}\fi
% Window title shows the document title, not the file name (G-22).
\hypersetup{pdfdisplaydoctitle=true}
\ifdefined\tagpdfsetup
  % Under tagging the kernel list code ignores \setlist (measured: \itemsep
  % stays 4.5pt, one extra line per bullet), so restate the geometry where the
  % kernel reads it.
  \def\@listi{\leftmargin=4.0mm \topsep=0.5pt \itemsep=0.2pt \parsep=0pt
    \partopsep=0pt \labelsep=2.0mm \labelwidth=2.0mm}
  \let\@listI\@listi
\fi

\definecolor{milosaccent}{HTML}{\milos@accent}
\definecolor{milosink}{HTML}{111418}
\definecolor{milosmuted}{HTML}{4A5361}
\definecolor{milosrule}{HTML}{D8DEE7}

% ---------------------------------------------------------------------------
% Fonts, per script.  `Noto Sans` measured to cover ASCII + all West European
% accents + Serbian/Croatian carons + full Russian, Belarusian and Kazakh
% Cyrillic with ZERO missing codepoints, so one family serves 12 locales.
% ---------------------------------------------------------------------------
% Measured with fontTools: NotoSans-Regular.ttf has NO U+2192 (->), U+2190,
% U+2194, U+2264, U+2265 or U+2713.  DejaVu Sans has all of them.  Without this
% fallback LaTeX prints "Missing character" and drops the glyph from the text
% layer, so a bullet that says "Proposal -> Critique" extracts as "Proposal
% Critique".  Appended to every script chain rather than replacing anything.
% Fallbacks are addressed by FAMILY NAME ("Noto Sans CJK JP:mode=node;"); the
% earlier file-name form "NotoSansCJK-Regular.ttc:mode=node;" is not resolvable
% as a fallback entry (measured: it emitted nothing, so CJK came out U+FFFD).
% The renderer verifies with fc-list that every family named here exists and
% exits 2 otherwise -- never a silent tofu build.
\def\milos@cjkfamily{Noto Sans CJK JP}
\def\milos@tmp{zh}\ifx\milos@lang\milos@tmp \def\milos@cjkfamily{Noto Sans CJK SC}\fi
\def\milos@tmp{ko}\ifx\milos@lang\milos@tmp \def\milos@cjkfamily{Noto Sans CJK KR}\fi
\directlua{
  luaotfload.add_fallback("milossym", {"DejaVu Sans:mode=node;"})
  luaotfload.add_fallback("miloscjk", {"\luaescapestring{\milos@cjkfamily}:mode=node;",
                                       "DejaVu Sans:mode=node;"})
  luaotfload.add_fallback("milosdeva", {"Noto Sans Devanagari:mode=node;",
                                        "Noto Sans:mode=node;",
                                        "DejaVu Sans:mode=node;"})
}

\def\milos@loadlatin{%
  \setmainfont{NotoSans-Regular.ttf}[
    BoldFont=NotoSans-Bold.ttf,
    ItalicFont=NotoSans-Italic.ttf,
    BoldItalicFont=NotoSans-BoldItalic.ttf,
    Ligatures=NoCommon,
    RawFeature={fallback=milossym},
  ]%
  \setsansfont{NotoSans-Regular.ttf}[
    BoldFont=NotoSans-Bold.ttf,
    ItalicFont=NotoSans-Italic.ttf,
    Ligatures=NoCommon,
    RawFeature={fallback=milossym},
  ]%
  \setmonofont{DejaVuSansMono.ttf}[Ligatures=NoCommon]%
}

\def\milos@loadcjk{%
  \setmainfont{NotoSans-Regular.ttf}[
    BoldFont=NotoSans-Bold.ttf,
    ItalicFont=NotoSans-Italic.ttf,
    Ligatures=NoCommon,
    RawFeature={fallback=miloscjk},
  ]%
  \setsansfont{NotoSans-Regular.ttf}[
    BoldFont=NotoSans-Bold.ttf,
    RawFeature={fallback=miloscjk},
  ]%
  \setmonofont{DejaVuSansMono.ttf}[Ligatures=NoCommon]%
}

% Devanagari is PRIMARY here, because HarfBuzz shaping of conjuncts and matra
% reordering has to run against the font that actually owns the glyphs.
% Measured: extracting `वर्षों क्षेत्र दृष्टि` gives correct logical order with
% Noto Sans Devanagari primary + Latin fallback, identical to FreeSans primary.
\def\milos@loaddeva{%
  \setmainfont{NotoSansDevanagari-Regular.ttf}[
    BoldFont=NotoSansDevanagari-Bold.ttf,
    Ligatures=NoCommon,
    RawFeature={fallback=milosdeva},
  ]%
  \setsansfont{NotoSansDevanagari-Regular.ttf}[
    BoldFont=NotoSansDevanagari-Bold.ttf,
    RawFeature={fallback=milosdeva},
  ]%
  \newfontfamily\miloslatin{NotoSans-Regular.ttf}[
    BoldFont=NotoSans-Bold.ttf,
    ItalicFont=NotoSans-Italic.ttf,
    Ligatures=NoCommon,
    RawFeature={fallback=milossym},
  ]%
}

\def\milos@setupfonts{%
  \def\milos@tmp{latin}%
  \ifx\milos@script\milos@tmp \milos@loadlatin
  \else
    \def\milos@tmp{deva}%
    \ifx\milos@script\milos@tmp \milos@loaddeva
    \else
      \def\milos@tmp{cjk}%
      \ifx\milos@script\milos@tmp \milos@loadcjk
      \else \milos@loadlatin
      \fi
    \fi
  \fi
}
\milos@setupfonts

% Latin fallback helper exists for every script so the renderer can wrap a
% tech token (Kotlin, Go, Kubernetes) without branching.
\providecommand{\miloslatin}{}

% ---------------------------------------------------------------------------
% Global typography
% ---------------------------------------------------------------------------
\color{milosink}
\pagestyle{fancy}
\fancyhf{}
\renewcommand{\headrulewidth}{0pt}
\renewcommand{\footrulewidth}{0pt}
\fancyfoot[L]{\footnotesize\color{milosmuted}\milos@doclabel}
\fancyfoot[R]{\footnotesize\color{milosmuted}\thepage\,/\,\pageref*{LastPage}}
\AtEndDocument{\label{LastPage}}
\setlength{\parindent}{0pt}
\setlength{\parskip}{1.4pt}
\linespread{1.0}
\RaggedRight
\setlength{\emergencystretch}{2em}
\hyphenpenalty=10000 % JSK-T178: never break a word by automatic hyphenation (extractors keep the stray "-" and a space; "Post-greSQL" is not "PostgreSQL")
% Contact URLs must never be split by hyphenation ("gitlab.com/milos85va-/sic"
% is not a URL a parser or a human can use).  Use inside a group that ends
% with \par so the penalties are in force when the paragraph is broken.
\newcommand{\milosnohyphens}{\hyphenpenalty=10000 \exhyphenpenalty=10000 }
\clubpenalty=10000
\widowpenalty=10000
\raggedbottom

\setlist[itemize]{%
  leftmargin=4.0mm, topsep=0.5pt, itemsep=0.2pt, parsep=0pt,
  label={\textbullet}, labelsep=2.0mm,
}

% ---------------------------------------------------------------------------
% Section headings: a coloured rule plus a bold label.  No \MakeUppercase --
% uppercasing is wrong for Turkish (i/İ) and for every non-Latin script, and a
% parser sees the same words either way.
% ---------------------------------------------------------------------------
% Vertical rhythm is a page budget, measured not guessed: the first draft of
% this block (5.2 + 1.6 + 2.4 pt around every rule) cost ~40 line-equivalents
% across eight sections and pushed a 2-page CV onto a third page.  These are
% the values that fit while still reading as deliberate separation.
\newcommand{\milossection}[1]{%
  \par\needspace{2\baselineskip}%
  \vspace{3.4pt}%
  {\color{milosaccent}\rule{\linewidth}{0.9pt}}\par\nobreak
  \vspace{1.0pt}%
  {\large\bfseries\color{milosaccent}#1}\par\nobreak
  \vspace{1.4pt}%
}

% Entry header: role (bold) . employer . location, right-aligned period.
% Everything stays on one line where it fits so a line-by-line parser keeps the
% four facts together; \sloppy prevents an ugly overflow when it does not.
% All four facts on ONE line, in the order every ATS guide recommends
% (title, employer, location, dates), separated by a middle dot.
%
% MEASURED, and the reason it is not right-aligned: any gap wider than a few
% millimetres -- \hfill, 4mm, 8mm all tested -- makes pdftotext treat the dates
% as a separate text block, so the extracted order becomes role / date /
% employer and a line-by-line parser attaches the dates to the wrong record.
% The pretty version costs parseability, so the date is inline.
\newcommand{\milosentry}[4]{%
  \par\needspace{2\baselineskip}%
  \vspace{1.8pt}%
  \noindent
  {\bfseries #1}%
  \if\relax\detokenize{#2}\relax\else{\color{milosmuted},\ #2}\fi
  \if\relax\detokenize{#3}\relax\else{\color{milosmuted}\ \textperiodcentered\ #3}\fi
  \if\relax\detokenize{#4}\relax\else{\small\color{milosmuted}\ \textperiodcentered\ #4}\fi
  \par\nobreak\vspace{0.8pt}%
}

\newcommand{\milosproject}[3]{%
  \par\needspace{1.6\baselineskip}%
  \vspace{1.2pt}%
  \noindent{\bfseries #1}\if\relax\detokenize{#3}\relax\else{\small\color{milosmuted}\ \textperiodcentered\ #3}\fi\par\nobreak
  \if\relax\detokenize{#2}\relax\else{\small #2\par\nobreak}\fi
  \vspace{0.2pt}%
}

\newcommand{\miloskv}[2]{%
  {\bfseries #1}\if\relax\detokenize{#2}\relax\else{\color{milosmuted}\ \textperiodcentered\ #2}\fi\par
}

% Tag line under an entry (the technology list).  Kept as plain text: a
% chip/pill design would be prettier and would extract as scattered fragments.
\newcommand{\milostags}[1]{%
  \par\vspace{0.6pt}{\small\color{milosmuted}#1}\par\nobreak\vspace{0.4pt}%
}

% ---------------------------------------------------------------------------
% Cover letter blocks
% ---------------------------------------------------------------------------
\newcommand{\milosletterhead}[2]{%
  {\Huge\bfseries #1}\par\vspace{1.2pt}%
  {\small\color{milosmuted}\milosnohyphens #2\par}%
  \vspace{3.6pt}{\color{milosaccent}\rule{\linewidth}{1.4pt}}\par\vspace{6pt}%
}

\newcommand{\milosaddressee}[1]{%
  \par\vspace{2pt}{\color{milosmuted}#1}\par\vspace{5pt}%
}

\newcommand{\milossubject}[1]{%
  \par\vspace{2pt}{\bfseries #1}\par\vspace{4pt}%
}

\newcommand{\milossalutation}[1]{\par #1\par\vspace{3pt}}

\newcommand{\milosclosing}[1]{\par\vspace{5pt}#1\par}

% ---------------------------------------------------------------------------
% Document metadata and the document label used in the footer.
% ---------------------------------------------------------------------------
\newcommand{\milos@doclabel}{}
\newcommand{\milosdoclabel}[1]{\renewcommand{\milos@doclabel}{#1}}
\newcommand{\milosdoctitle}[1]{\hypersetup{pdftitle={#1}}}
\newcommand{\milosdocsubject}[1]{\hypersetup{pdfsubject={#1}}}
\newcommand{\milosdockeywords}[1]{\hypersetup{pdfkeywords={#1}}}
\newcommand{\milosdocauthor}[1]{\hypersetup{pdfauthor={#1}}}
% pdfmark language tag.  Helps screen readers pick the right voice and helps a
% parser know which dictionary to use; costs one line.
\newcommand{\milospdflang}[1]{\hypersetup{pdflang={#1}}}

% ---------------------------------------------------------------------------
% Bullets.  The renderer hands over already-escaped text.
% ---------------------------------------------------------------------------
\newenvironment{milosbullets}{\begin{itemize}}{\end{itemize}}

