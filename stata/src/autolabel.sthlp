{smcl}
{* *! version {{VERSION}} {{STHLP_DATE}}}{...}

{vieweralsosee "" "--"}{...}
{vieweralsosee "registream" "help registream"}{...}
{viewerjumpto "Syntax" "autolabel##syntax"}{...}
{viewerjumpto "Description" "autolabel##description"}{...}
{viewerjumpto "Options" "autolabel##options"}{...}
{viewerjumpto "Examples" "autolabel##examples"}{...}
{viewerjumpto "Important Limitations" "autolabel##limitations"}{...}
{viewerjumpto "See also" "autolabel##seealso"}{...}
{viewerjumpto "Authors" "autolabel##authors"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:autolabel} {hline 2}}Automatically apply variable and value labels for register data{p_end}
{p2colreset}{...}

{pstd}
This is a program within the {help registream:RegiStream} package, designed to streamline register data workflows.
{p_end}

{marker syntax}{...}
{title:Syntax}

{pstd}
Automatically label variables:
{p_end}

{p 8 15 2} {cmd:autolabel variables} {it:varlist} [{cmd:,} {opth domain(string)} {opth lang(string)} {opth exclude(varlist)} {opth suffix(string)}]{p_end}

{pstd}
Automatically label value labels:
{p_end}

{p 8 15 2} {cmd:autolabel values} {it:varlist} [{cmd:,} {opth domain(string)} {opth lang(string)} {opth exclude(varlist)} {opth suffix(string)}]{p_end}

{pstd}
Look up any variables in a domain:
{p_end}

{p 8 15 2} {cmd:autolabel lookup} {it:varlist} [{cmd:,} {opth domain(string)} {opth lang(string)}]{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:autolabel} is designed to streamline the workflow of applying predefined labels to variables and values based on a domain. It currently supports SCB (Statistics Sweden) and is extensible to other domains.
{p_end}

{pstd}
{bf:First-run setup:} When you first use {cmd:autolabel}, RegiStream will ask you to choose a setup mode (Offline, Standard, or Full Mode). This determines whether metadata is downloaded automatically and whether usage data is collected. You can change these settings later using {cmd:registream config}. See {help registream:registream} for details.
{p_end}

{pstd}
The three main functions are:
{p_end}

{phang2}
{cmd:variables} - Apply labels to variables from the specified domain
{p_end}

{phang2}
{cmd:values} - Apply value labels to variables from the specified domain
{p_end}

{phang2}
{cmd:lookup} - Look up and display labels for specified variables
{p_end}

{marker options}{...}
{title:Options}

{phang}
{opt domain(string)}  
Specify the domain for labeling. This argument is required. Currently, only {cmd:scb} (Statistics Sweden) is supported.
{p_end}

{phang}
{opt lang(string)}  
Specify the language for labels. This argument is required. Options are {cmd:swe} or {cmd:eng}.
{p_end}

{phang}
{opt exclude(varlist)}  
Specify a list of variables to exclude from labeling.
{p_end}

{phang}
{opt suffix(string)}
Specify a suffix to append to the new variable names. When using {cmd:autolabel values} on string categorical variables, the original string codes are permanently replaced with sequential numeric codes. Use {opt suffix()} to preserve the original variable and create a new labeled version instead. See {bf:Important Limitations} below.
{p_end}

{marker examples}{...}
{title:Examples}


{pstd}
1. Label all variables
{p_end}

{phang2}{cmd:. autolabel variables, domain(scb) lang(eng) }{p_end}

{pstd}
This command labels all variables, using the SCB domain in English.
{p_end}



{pstd}
2. Set all value labels
{p_end}

{phang2}{cmd:. autolabel values, domain(scb) lang(swe) }{p_end}

{pstd}
This command sets value labels to all variables, using the SCB domain in Swedish.
{p_end}



{pstd}
3. Label specified variables
{p_end}

{phang2}{cmd:. autolabel variables ku*ink yrkarbtyp, domain(scb) lang(eng) exclude(ku3ink) }{p_end}

{pstd}
This command labels the specified variables (using wildcard asterisk to get all ku*ink variables), excluding {cmd:ku3ink}, using the SCB domain in English.
{p_end}



{pstd}
4. Label specified variables (with suffix)
{p_end}

{phang2}{cmd:. autolabel variables ku*ink yrkarbtyp, domain(scb) lang(eng) exclude(ku3ink) suffix("_lbl") }{p_end}

{pstd}
This command labels the variables as in example 3, however the result is stored in new variables with suffix "_lbl"
{p_end}



{pstd}
5. Set specified value labels
{p_end}

{phang2}{cmd:. autolabel values kon, domain(scb) lang(eng) }{p_end}

{pstd}
This command applies value labels to the kon variable, using the SCB domain in English.
{p_end}



{pstd}
6. Lookup variable in the domain data
{p_end}

{phang2}{cmd:. autolabel lookup carb random_var yrkarbtyp kaross, domain(scb) lang(eng)}{p_end}

{pstd}
This displays the labels, definitions, and value labels (if applicable) for the variables {cmd:carb}, {cmd:yrkarbtyp}, and {cmd:kaross} from the SCB domain in English. The variable {cmd:random_var} does not exist in the domain, so a warning is returned at the end.
{p_end}


{marker limitations}{...}
{title:Important Limitations}

{pstd}
{bf:⚠️ String Categorical Variables Lose Original Data}
{p_end}

{pstd}
When using {cmd:autolabel values} on {bf:string categorical variables}, the original string codes are permanently replaced with sequential numeric codes (1, 2, 3...). This means:
{p_end}

{phang2}
• Original string codes cannot be recovered after encoding{break}
• You cannot filter by original string values after labeling{break}
• Re-running {cmd:autolabel values} requires reloading original data
{p_end}

{pstd}
{bf:Numeric categorical variables} do not have this limitation - they preserve original numeric codes when labels are applied.
{p_end}

{pstd}
{ul:Solution}: Use the {opt suffix()} option to preserve original data:
{p_end}

{phang2}{cmd:. autolabel values astsni2007, domain(scb) lang(eng) suffix("_lbl")}{p_end}

{pstd}
This keeps the original {cmd:astsni2007} variable unchanged and creates a new labeled variable {cmd:astsni2007_lbl}.
{p_end}


{marker seealso}{...}
{title:See also}

{pstd}
{help registream:registream} - RegiStream package management and configuration
{p_end}

{pmore2}
• View configuration: {cmd:registream info}{break}
• Change settings: {cmd:registream config, option(value)}{break}
• Check updates: {cmd:registream update}{break}
• View usage stats: {cmd:registream stats}
{p_end}

{marker contact}{...}
{title:Authors}

{pstd}Jeffrey Clark{break}
Stockholm University{break}
Email: {browse "mailto:jeffrey.clark@su.se":jeffrey.clark@su.se}
{p_end}

{pstd}Jie Wen{break}
Swedish House of Finance{break}
Email: {browse "mailto:jie.wen@hhs.se":jie.wen@hhs.se}
{p_end}

{marker citation}{...}
{title:Citing RegiStream}

{pstd}
{cmd:autolabel} is a program within the {help registream:RegiStream}  package. When citing {cmd:autolabel}, or any other individual program from the package, we request that you cite the {cmd:RegiStream} package as a whole. Please use the following format:
{p_end}

{pstd}
Clark, J. & Wen, J. (2024–). {it:RegiStream: Streamline Your Register Data Workflow} (Version {{VERSION}}). Available at: {browse "https://registream.org"}.
{p_end}

