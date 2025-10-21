{smcl}
{* *! version {{VERSION}} {{STHLP_DATE}}}{...}
{viewerjumpto "Syntax" "registream##syntax"}{...}
{viewerjumpto "Description" "registream##description"}{...}
{viewerjumpto "RegiStream modules" "registream##modules"}{...}
{viewerjumpto "First-run setup" "registream##setup"}{...}
{viewerjumpto "Commands" "registream##commands"}{...}
{viewerjumpto "Configuration" "registream##config"}{...}
{viewerjumpto "Examples" "registream##examples"}{...}
{viewerjumpto "Privacy" "registream##privacy"}{...}
{viewerjumpto "Authors" "registream##authors"}{...}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :{cmd:registream} {hline 2}}Streamline Your Register Data Workflow{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{pstd}
{ul:Configuration & Settings}
{p_end}

{p 8 15 2}
{cmd:registream info}
{p_end}

{p 8 15 2}
{cmd:registream config} [{cmd:,} {it:options}]
{p_end}

{pstd}
{ul:Updates & Maintenance}
{p_end}

{p 8 15 2}
{cmd:registream update} [{cmd:package}|{cmd:dataset}]
{p_end}

{pstd}
{ul:Usage & Statistics}
{p_end}

{p 8 15 2}
{cmd:registream stats}
{p_end}

{pstd}
{ul:Reference & Citation}
{p_end}

{p 8 15 2}
{cmd:registream version}
{p_end}

{p 8 15 2}
{cmd:registream cite}
{p_end}

{marker description}{...}
{title:Description}

{pstd}
{cmd:RegiStream} is a comprehensive package for working with register data. It automates the application of variable and value labels from official sources like Statistics Sweden (SCB), manages metadata, and helps keep your workflow organized.
{p_end}

{pstd}
The {cmd:registream} command provides utilities for managing the package, checking versions, configuring settings, and viewing citation information.
{p_end}

{marker modules}{...}
{title:RegiStream modules}

{pstd}
{help autolabel:autolabel} - Automatically apply variable and value labels for register data
{p_end}

{marker setup}{...}
{title:First-run setup}

{pstd}
When you first run RegiStream or any of its modules, you'll be asked to choose a setup mode:
{p_end}

{phang2}
{bf:1) Offline Mode}
{p_end}
{pmore2}
• No internet connections{break}
• Manual metadata management{break}
• Local usage logging only (stays on your machine)
{p_end}

{phang2}
{bf:2) Standard Mode} (recommended)
{p_end}
{pmore2}
• Automatic metadata downloads{break}
• Automatic update checks (daily){break}
• Local usage logging only{break}
• No online telemetry
{p_end}

{phang2}
{bf:3) Full Mode} (Help improve RegiStream)
{p_end}
{pmore2}
• Everything in Standard Mode, plus:{break}
• Online telemetry: Sends anonymized usage data to help improve RegiStream
{p_end}

{pstd}
You can change these settings at any time using {cmd:registream config}.
{p_end}

{marker commands}{...}
{title:Commands}

{dlgtab:info}

{pstd}
Display current configuration and settings.
{p_end}

{phang2}
{cmd:. registream info}
{p_end}

{pstd}
Shows:
{p_end}

{pmore2}
• Configuration directory location{break}
• Current version{break}
• All active settings (usage_logging, telemetry_enabled, internet_access, auto_update_check){break}
• Citation information
{p_end}

{dlgtab:config}

{pstd}
Update configuration settings. With no options, displays current settings (same as {cmd:registream info}).
{p_end}

{phang2}
{cmd:. registream config}
{p_end}

{phang2}
{cmd:. registream config, telemetry_enabled(false)}
{p_end}

{pstd}
See {help registream##config:Configuration section} below for all available settings and mode presets.
{p_end}

{dlgtab:update}

{pstd}
Check for and install RegiStream package or metadata dataset updates.
{p_end}

{phang2}
{cmd:. registream update} - Check/install package updates (default)
{p_end}

{phang2}
{cmd:. registream update package} - Check/install package updates (same as above)
{p_end}

{phang2}
{cmd:. registream update dataset} - Check/install metadata dataset updates
{p_end}

{pstd}
By default (no argument), checks for package updates and prompts to install if available.
{p_end}

{dlgtab:stats}

{pstd}
View your local usage statistics.
{p_end}

{phang2}
{cmd:. registream stats}
{p_end}

{pstd}
Shows how many times you've used RegiStream and when.
{p_end}

{dlgtab:version}

{pstd}
Display the current version of RegiStream.
{p_end}

{phang2}
{cmd:. registream version}
{p_end}

{pstd}
Output:
{p_end}

{pmore}
RegiStream version {{VERSION}}
{p_end}

{dlgtab:cite}

{pstd}
Display citation information for use in publications.
{p_end}

{phang2}
{cmd:. registream cite}
{p_end}

{pstd}
Shows the recommended citation format along with details about datasets used.
{p_end}

{marker config}{...}
{title:Configuration}

{dlgtab:Available settings}

{pstd}
All settings accept {cmd:true} or {cmd:false}:
{p_end}

{phang}
{opt usage_logging(true|false)} - Local usage logging (default: true){break}
Stores command history in {cmd:~/.registream/usage_stata.csv}
{p_end}

{phang}
{opt telemetry_enabled(true|false)} - Online telemetry (default: false){break}
Sends anonymized usage data to registream.org
{p_end}

{phang}
{opt internet_access(true|false)} - Internet features (default: true){break}
Allows automatic metadata downloads and update checks
{p_end}

{phang}
{opt auto_update_check(true|false)} - Auto-update checks (default: true){break}
Daily background check for package updates
{p_end}

{dlgtab:Mode presets}

{pstd}
{bf:Offline Mode}:
{p_end}

{phang2}
{cmd:. registream config, usage_logging(true) internet_access(false) telemetry_enabled(false) auto_update_check(false)}
{p_end}

{pstd}
{bf:Standard Mode}:
{p_end}

{phang2}
{cmd:. registream config, usage_logging(true) internet_access(true) telemetry_enabled(false) auto_update_check(true)}
{p_end}

{pstd}
{bf:Full Mode}:
{p_end}

{phang2}
{cmd:. registream config, usage_logging(true) internet_access(true) telemetry_enabled(true) auto_update_check(true)}
{p_end}

{pstd}
You can also set individual settings (e.g., {cmd:registream config, telemetry_enabled(false)}).
{p_end}

{dlgtab:Custom directory}

{pstd}
By default, RegiStream stores files in:
{p_end}

{pmore2}
• macOS: {cmd:/Users/username/.registream/}{break}
• Linux: {cmd:/home/username/.registream/}{break}
• Windows: {cmd:C:/Users/username/AppData/Local/registream/}
{p_end}

{pstd}
To use a custom directory, set before first run:
{p_end}

{phang2}
{cmd:. global registream_dir "/your/custom/path"}
{p_end}

{marker examples}{...}
{title:Examples}

{dlgtab:Configuration}

{phang2}
{cmd:. registream info} {it:(view current settings)}
{p_end}

{phang2}
{cmd:. registream config, telemetry_enabled(false)} {it:(disable online telemetry)}
{p_end}

{phang2}
{cmd:. registream info} {it:(verify changes)}
{p_end}

{dlgtab:Updates}

{phang2}
{cmd:. registream update} {it:(check/install package updates)}
{p_end}

{phang2}
{cmd:. registream update dataset} {it:(update metadata datasets)}
{p_end}

{dlgtab:Usage}

{phang2}
{cmd:. registream stats} {it:(view your usage statistics)}
{p_end}

{dlgtab:Reference}

{phang2}
{cmd:. registream version} {it:(show version)}
{p_end}

{phang2}
{cmd:. registream cite} {it:(show citation for publications)}
{p_end}

{marker privacy}{...}
{title:Privacy and Usage Tracking}

{pstd}
RegiStream has two separate tracking systems:
{p_end}

{dlgtab:1. Local Usage Logging (NOT a GDPR issue)}

{pstd}
Stores data {bf:only on your machine} - never transmitted anywhere.
{p_end}

{pmore2}
• Stored in {cmd:~/.registream/usage_stata.csv}{break}
• Like {cmd:.bash_history} for RegiStream commands{break}
• Default: Enabled{break}
• You control: View ({cmd:registream stats}), Delete (rm file), Disable ({cmd:registream config, usage_logging(false)})
{p_end}

{dlgtab:2. Online Telemetry (GDPR compliant)}

{pstd}
Opt-in system that sends {bf:fully anonymous} data to registream.org.
{p_end}

{pmore2}
• Default: Disabled (requires explicit consent){break}
• Anonymous: One-way hash ID - cannot identify individuals{break}
• What's sent: command, timestamp, version, OS (NOT your data or file paths){break}
• Why: Helps improve RegiStream{break}
• Enable: {cmd:registream config, telemetry_enabled(true)}{break}
• Disable: {cmd:registream config, telemetry_enabled(false)}
{p_end}

{pstd}
For server-side data deletion, email support@registream.org with your anonymous ID (from {cmd:registream stats}).
{p_end}

{dlgtab:User control}

{pstd}
You have complete control over both systems:
{p_end}

{pmore2}
{bf:Configuration:}{break}
• View all settings: {cmd:registream info}{break}
• Change any setting: {cmd:registream config, option(value)}
{p_end}

{pmore2}
{bf:Local data:}{break}
• View statistics: {cmd:registream stats}{break}
• Access raw CSV: {cmd:~/.registream/usage_stata.csv}{break}
• Disable: {cmd:registream config, usage_logging(false)}{break}
• Delete: {cmd:rm ~/.registream/usage_stata.csv}
{p_end}

{pmore2}
{bf:Online telemetry:}{break}
• Disable: {cmd:registream config, telemetry_enabled(false)}{break}
• Request server deletion: Email support@registream.org with anonymous ID
{p_end}

{marker authors}{...}
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
To cite the {cmd:RegiStream} package in publications:
{p_end}

{pstd}
Clark, J. & Wen, J. (2024–). {it:RegiStream: Streamline Your Register Data Workflow} (Version {{VERSION}}). Available at: {browse "https://registream.org"}.
{p_end}

{pstd}
For dataset-specific citations, use {cmd:registream cite} to see recommended format.
{p_end}

{marker support}{...}
{title:Support}

{pstd}
• Documentation: {browse "https://registream.org/docs"}{break}
• Issues & feedback: {browse "https://github.com/registream/registream/issues"}{break}
• Website: {browse "https://registream.org"}
{p_end}
