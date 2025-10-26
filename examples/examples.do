/*==============================================================================
  Examples for Stata Journal: autolabel command

  Purpose: Reproduce examples from the paper
  Authors: Jeffrey Clark & Jie Wen
  Date: October 2025

  This do-file demonstrates all key features of autolabel using synthetic
  SCB data. Examples correspond to those shown in the paper.

  Note: This version uses local metadata files (no downloads required)
==============================================================================*/

capture log close
log using "../logs/examples.log", replace text

clear all
set more off
version 16.0

di as text _n(2) "{hline 78}"
di as result "  Stata Journal Examples: autolabel command"
di as text "{hline 78}" _n

*------------------------------------------------------------------------------
* Setup: Use local code files (if conflicting with installed version)
*------------------------------------------------------------------------------
* Prepend local code directory to adopath
adopath ++ "../code"
di as text "Added ../code to adopath (using local submission version)"

*------------------------------------------------------------------------------
* Setup: Tell autolabel to use local metadata
*------------------------------------------------------------------------------
* Set path to local metadata directory (no downloads needed)
* autolabel expects metadata in autolabel_keys/ subdirectory
global registream_dir "../data"

di as text "Setup: Using local metadata from: " as result "$registream_dir/autolabel_keys"
di as text "       (No internet connection required - all files included)"
di as text "{hline 78}" _n

*------------------------------------------------------------------------------
* Step 1: Load the dataset - what do we have?
*------------------------------------------------------------------------------
di as result _n "Step 1: Load unlabeled data" _n
use "../data/synthetic_scb_data.dta", clear

di as text "What variables do we have?"
describe

di as text _n "What does the data look like?"
list in 1/5, separator(0) abbrev(12)

di as text _n "Problem: We don't know what these variables mean!"

*------------------------------------------------------------------------------
* Step 2: Add variable labels - now we understand what each variable is
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 2: Label variables with autolabel"
di as text "{hline 78}" _n

autolabel variables, domain(scb) lang(eng)

di as text _n "Now we can see what each variable represents:"
describe

*------------------------------------------------------------------------------
* Step 3: Look at categorical variables - what do the codes mean?
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 3: What do these category codes mean?"
di as text "{hline 78}" _n

di as text "Industry codes (astsni2007):"
tab astsni2007 in 1/100, sort

di as text _n "Problem: Codes like '85201' and '56100' are meaningless!"

*------------------------------------------------------------------------------
* Step 4: Add value labels - now we understand the categories
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 4: Label values with autolabel"
di as text "{hline 78}" _n

autolabel values, domain(scb) lang(eng)

di as text _n "Now the codes have meaning:"
tab astsni2007 in 1/100, sort

di as text _n "Education levels are also labeled:"
tab sun2000niva, sort

*------------------------------------------------------------------------------
* Step 5: Selective labeling with exclude() option
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 5: Selective labeling with exclude()"
di as text "{hline 78}" _n

di as text "Reload fresh data:"
use "../data/synthetic_scb_data.dta", clear

di as text _n "Apply labels but EXCLUDE identifier variables (lopnr):"
autolabel variables, domain(scb) lang(eng) exclude(lopnr)

di as text _n "Check results - lopnr should remain unlabeled:"
describe lopnr kommun kon

di as text _n "lopnr is unlabeled (as intended for ID variables)"
di as text "kommun and kon are labeled"

*------------------------------------------------------------------------------
* Step 6: Non-destructive labeling with suffix() option
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 6: Non-destructive labeling with suffix()"
di as text "{hline 78}" _n

di as text "Reload fresh data:"
use "../data/synthetic_scb_data.dta", clear

di as text _n "Create labeled COPIES with _lab suffix (preserving originals):"
autolabel variables kommun kon, domain(scb) lang(eng) suffix(_lab)

di as text _n "Now we have both original and labeled versions:"
describe kommun kommun_lab kon kon_lab

di as text _n "Compare side-by-side:"
list kommun kommun_lab kon kon_lab in 1/5

*------------------------------------------------------------------------------
* Step 7: Multilingual support - instant language switching
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 7: Demonstrate multilingual support"
di as text "{hline 78}" _n

di as text "Reload fresh data to demonstrate multilingual support:"
use "../data/synthetic_scb_data.dta", clear

di as text _n "First, apply English labels to the original data..." _n

* Apply English labels
autolabel variables kommun kon, domain(scb) lang(eng)
autolabel values kommun kon, domain(scb) lang(eng)

di as text _n "English labeled data:"
tab kommun in 1/50, sort

di as text _n "Now reload and apply Swedish labels for comparison..." _n
use "../data/synthetic_scb_data.dta", clear

* Apply Swedish labels
autolabel variables kommun kon, domain(scb) lang(swe)
autolabel values kommun kon, domain(scb) lang(swe)

di as text _n "Same data in Swedish:"
tab kommun in 1/50, sort

di as text _n "This demonstrates instant language switching:"
di as text "Same data, same codes - different languages!"

*------------------------------------------------------------------------------
* Step 8: Lookup mode - inspect metadata without modifying data
*------------------------------------------------------------------------------
di as result _n(2) "{hline 78}"
di as result "Step 8: Use lookup mode to explore metadata"
di as text "{hline 78}" _n

* Reload fresh data to show lookup doesn't modify
use "../data/synthetic_scb_data.dta", clear

di as text "Lookup provides detailed information about variables:"
autolabel lookup dispink04 astsni2007, domain(scb) lang(eng)


log close
