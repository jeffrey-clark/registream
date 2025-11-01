* =============================================================================
* RegiStream Development Setup
* Quick setup file for testing local changes to RegiStream
* =============================================================================

clear all
discard
adopath ++ "/Users/jeffrey/Github/registream/stata/src"

* Verify the path was added
di as result ""
di as result "RegiStream development environment loaded"
di as result "Source directory: /Users/jeffrey/Github/registream/stata/src"
di as result ""
di as text "You can now test RegiStream commands using the local source code"
di as text ""
di as text "Example commands:"
di as text "  . autolabel update datasets"
di as text "  . autolabel update datasets, domain(scb) lang(eng) version(20251014)"
di as text "  . autolabel variables, domain(scb) lang(eng)"
di as text ""
