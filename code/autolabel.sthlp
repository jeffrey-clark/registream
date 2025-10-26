{smcl}
{* *! version 1.0.0  24oct2025}{...}

{viewerjumpto "Syntax" "autolabel##syntax"}{...}
{viewerjumpto "Description" "autolabel##description"}{...}
{viewerjumpto "Options" "autolabel##options"}{...}
{viewerjumpto "Examples" "autolabel##examples"}{...}
{viewerjumpto "Important Limitations" "autolabel##limitations"}{...}
{viewerjumpto "Stored results" "autolabel##results"}{...}
{viewerjumpto "Authors" "autolabel##authors"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:autolabel} {hline 2}}Automatically apply variable and value labels for register data{p_end}
{p2colreset}{...}

{pstd}
{bf:Note:} This is a stripped-down Stata Journal submission version of the autolabel module from RegiStream v2.0.0, containing only core labeling functionality without usage logging, update checking, or configuration management.
{p_end}


{marker syntax}{...}
{title:Syntax}

{pstd}
Automatically label variables:
{p_end}

{p 8 15 2} {cmd:autolabel variables} [{it:varlist}] {cmd:,} {opth domain(string)} {opth lang(string)} [{opth exclude(varlist)} {opth suffix(string)}]{p_end}

{pstd}
Automatically label value labels:
{p_end}

{p 8 15 2} {cmd:autolabel values} [{it:varlist}] {cmd:,} {opth domain(string)} {opth lang(string)} [{opth exclude(varlist)} {opth suffix(string)}]{p_end}

{pstd}
Look up variables in metadata:
{p_end}

{p 8 15 2} {cmd:autolabel lookup} {it:varlist} {cmd:,} {opth domain(string)} {opth lang(string)}{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:autolabel} automates the application of variable labels and value labels to register data using structured metadata files. It is designed to streamline data preparation workflows by eliminating manual labeling.
{p_end}

{pstd}
The command works with CSV metadata files that define variable labels, definitions, and value label mappings. Metadata files can be created for any domain (e.g., Statistics Sweden, custom surveys, administrative registers).
{p_end}

{pstd}
The three main functions are:
{p_end}

{phang2}
{cmd:variables} - Apply descriptive labels to variables based on metadata
{p_end}

{phang2}
{cmd:values} - Apply value labels to categorical variables
{p_end}

{phang2}
{cmd:lookup} - Display metadata for specified variables without modifying the dataset
{p_end}

{pstd}
{bf:Metadata location:} By default, {cmd:autolabel} looks for metadata files in {cmd:~/.registream/autolabel_keys/}. You can override this by setting the global macro {cmd:$registream_dir} to point to a custom directory.
{p_end}

{pstd}
{bf:Metadata files:} For each domain and language, two files are required:
{p_end}

{phang2}
• {cmd:{it:domain}_variables_{it:lang}.dta} - Variable metadata (labels, definitions, types)
{p_end}

{phang2}
• {cmd:{it:domain}_value_labels_{it:lang}.dta} - Value label mappings
{p_end}

{pstd}
{bf:Downloading metadata:} If metadata files are missing, {cmd:autolabel} will prompt to download them from https://registream.org (for SCB domain only). You can decline the download and provide your own metadata files instead.
{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt domain(string)}
Specify the domain for labeling. This argument is required. Example: {cmd:scb} (Statistics Sweden).
{p_end}

{phang}
{opt lang(string)}
Specify the language for labels. This argument is required. Options include {cmd:eng} (English) or {cmd:swe} (Swedish), depending on available metadata.
{p_end}

{phang}
{opt exclude(varlist)}
Exclude specified variables from labeling. Useful for preserving unlabeled identifiers or variables that should not be modified.
{p_end}

{phang}
{opt suffix(string)}
Append a suffix to create new labeled variables while preserving the originals. This is particularly important for string categorical variables (see {bf:Important Limitations} below). Example: {opt suffix(_lab)} creates {cmd:kon_lab} while keeping {cmd:kon} unchanged.
{p_end}

{marker examples}{...}
{title:Examples}

{pstd}
{bf:Example 1: Label all variables}
{p_end}

{phang2}{cmd:. use mydata, clear}{p_end}
{phang2}{cmd:. autolabel variables, domain(scb) lang(eng)}{p_end}

{pstd}
Labels all variables in the dataset using SCB metadata in English.
{p_end}


{pstd}
{bf:Example 2: Label all values}
{p_end}

{phang2}{cmd:. autolabel values, domain(scb) lang(eng)}{p_end}

{pstd}
Applies value labels to all categorical variables using SCB metadata in English.
{p_end}


{pstd}
{bf:Example 3: Label specific variables with wildcard}
{p_end}

{phang2}{cmd:. autolabel variables ku*ink yrkarbtyp, domain(scb) lang(eng) exclude(ku3ink)}{p_end}

{pstd}
Labels variables matching {cmd:ku*ink} and {cmd:yrkarbtyp}, excluding {cmd:ku3ink}.
{p_end}


{pstd}
{bf:Example 4: Create labeled copies (preserving originals)}
{p_end}

{phang2}{cmd:. autolabel variables kon astsni2007, domain(scb) lang(eng) suffix(_lab)}{p_end}

{pstd}
Creates new variables {cmd:kon_lab} and {cmd:astsni2007_lab} with labels applied, while keeping the original variables unchanged.
{p_end}


{pstd}
{bf:Example 5: Label specific values}
{p_end}

{phang2}{cmd:. autolabel values kon sun2000niva, domain(scb) lang(swe)}{p_end}

{pstd}
Applies Swedish value labels to {cmd:kon} and {cmd:sun2000niva}.
{p_end}


{pstd}
{bf:Example 6: Lookup mode (inspect metadata without modifying data)}
{p_end}

{phang2}{cmd:. autolabel lookup dispink04 astsni2007, domain(scb) lang(eng)}{p_end}

{pstd}
Displays variable labels, definitions, and value labels for the specified variables without modifying the dataset.
{p_end}


{marker limitations}{...}
{title:Important Limitations}

{pstd}
{bf:⚠️ String Categorical Variables Lose Original Data}
{p_end}

{pstd}
When using {cmd:autolabel values} on {bf:string categorical variables}, the original string codes are permanently replaced with sequential numeric codes (1, 2, 3...). This is a limitation of Stata's value label system, which only works with numeric variables.
{p_end}

{pstd}
This means:
{p_end}

{phang2}
• Original string codes cannot be recovered after encoding{break}
• You cannot filter by original string values after labeling{break}
• Re-running {cmd:autolabel values} requires reloading the original data
{p_end}

{pstd}
{bf:Numeric categorical variables} do not have this limitation - they preserve original numeric codes when labels are applied.
{p_end}

{pstd}
{ul:Solution}: Use the {opt suffix()} option to preserve original variables:
{p_end}

{phang2}{cmd:. autolabel values astsni2007, domain(scb) lang(eng) suffix(_lab)}{p_end}

{pstd}
This keeps the original {cmd:astsni2007} variable unchanged and creates a new labeled variable {cmd:astsni2007_lab}.
{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:autolabel} stores the following in {cmd:r()}:
{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(status)}}0 if successful, 1 if error{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(dir)}}Directory where metadata files are located{p_end}


{marker authors}{...}
{title:Authors}

{pstd}Jeffrey Clark{break}
Stockholm University{break}
Email: {browse "mailto:jeffrey.clark@su.se":jeffrey.clark@su.se}
{p_end}

{pstd}Jie Wen{break}
Stockholm School of Economics{break}
Email: {browse "mailto:jie.wen@hhs.se":jie.wen@hhs.se}
{p_end}

