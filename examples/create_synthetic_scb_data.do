/*==============================================================================
  Create Synthetic SCB Dataset for Stata Journal Submission

  Purpose: Generate synthetic data for autolabel demonstration
  Authors: Jeffrey Clark & Jie Wen
  Date: October 2025

  This creates synthetic data with realistic value ranges for demonstrating
  autolabel functionality with SCB metadata.

  No real data is used. All values are randomly generated for demonstration.
==============================================================================*/

capture log close
log using "../logs/create_synthetic_scb_data.log", replace text

clear all
set seed 20251013  // Reproducible synthetic data
version 16.0

* Set number of observations (keeping it reasonable for examples)
set obs 1000

di as text _n "Creating synthetic SCB dataset with 1,000 observations..."

*------------------------------------------------------------------------------
* 1. Personal ID (lopnr) - Synthetic sequential IDs
*------------------------------------------------------------------------------
gen lopnr = _n + 1000

*------------------------------------------------------------------------------
* 2. Sex (kon) - Binary variable (1=male, 2=female)
*------------------------------------------------------------------------------
gen kon = cond(runiform() < 0.49, 1, 2)  // Roughly 49% male, 51% female

*------------------------------------------------------------------------------
* 3. Municipality (kommun) - Swedish kommun codes (string with leading zeros)
*------------------------------------------------------------------------------
* Use actual Swedish kommun codes with realistic distribution
* Stockholm region codes: "0114", "0115", "0120", "0125", "0126", "0180"
gen rand = runiform()
gen kommun = "0114" if rand < 0.12        // Upplands Väsby
replace kommun = "0115" if rand >= 0.12 & rand < 0.24   // Vallentuna
replace kommun = "0120" if rand >= 0.24 & rand < 0.40   // Värmdö
replace kommun = "0125" if rand >= 0.40 & rand < 0.55   // Ekerö
replace kommun = "0126" if rand >= 0.55 & rand < 0.75   // Huddinge
replace kommun = "0180" if rand >= 0.75                  // Stockholm
drop rand

*------------------------------------------------------------------------------
* 4. Education level (sun2000niva) - SUN 2000 classification (string)
*------------------------------------------------------------------------------
* Create realistic education distribution using valid codes
gen rand = runiform()
gen sun2000niva = "000" if rand < 0.03          // Preschool education
replace sun2000niva = "100" if rand >= 0.03 & rand < 0.08   // Elementary < 9 years
replace sun2000niva = "106" if rand >= 0.08 & rand < 0.15   // Public school
replace sun2000niva = "200" if rand >= 0.15 & rand < 0.25   // Pre-secondary 9 years
replace sun2000niva = "204" if rand >= 0.25 & rand < 0.50   // Secondary school
replace sun2000niva = "310" if rand >= 0.50 & rand < 0.65   // Upper secondary < 2 years
replace sun2000niva = "410" if rand >= 0.65 & rand < 0.82   // Post-secondary < 2 years
replace sun2000niva = "620" if rand >= 0.82                 // Licentiate education
drop rand

*------------------------------------------------------------------------------
* 5. Occupation code (ssyk3) - SSYK classification (string)
*------------------------------------------------------------------------------
gen rand = runiform()
gen ssyk3 = "***" if rand < 0.08       // Missing/not applicable
replace ssyk3 = "011" if rand >= 0.08 & rand < 0.12
replace ssyk3 = "111" if rand >= 0.12 & rand < 0.17
replace ssyk3 = "121" if rand >= 0.17 & rand < 0.25
replace ssyk3 = "211" if rand >= 0.25 & rand < 0.35
replace ssyk3 = "233" if rand >= 0.35 & rand < 0.45
replace ssyk3 = "322" if rand >= 0.45 & rand < 0.60
replace ssyk3 = "411" if rand >= 0.60 & rand < 0.72
replace ssyk3 = "511" if rand >= 0.72 & rand < 0.85
replace ssyk3 = "911" if rand >= 0.85
drop rand

*------------------------------------------------------------------------------
* 6. Industry code (astsni2007) - SNI 2007 classification (string)
*------------------------------------------------------------------------------
* Using industry codes that appear in the paper examples
gen rand = runiform()
gen astsni2007 = "00000" if rand < 0.10       // Missing
replace astsni2007 = "41200" if rand >= 0.10 & rand < 0.17  // Construction
replace astsni2007 = "47112" if rand >= 0.17 & rand < 0.24  // Grocery stores
replace astsni2007 = "49410" if rand >= 0.24 & rand < 0.30  // Freight
replace astsni2007 = "56100" if rand >= 0.30 & rand < 0.40  // Restaurants
replace astsni2007 = "78200" if rand >= 0.40 & rand < 0.46  // Staffing
replace astsni2007 = "85100" if rand >= 0.46 & rand < 0.56  // Preschools
replace astsni2007 = "85201" if rand >= 0.56 & rand < 0.72  // Primary schools
replace astsni2007 = "86102" if rand >= 0.72 & rand < 0.86  // Inpatient clinics
replace astsni2007 = "87301" if rand >= 0.86 & rand < 0.93  // Elderly facilities
replace astsni2007 = "88101" if rand >= 0.93                 // Home care
drop rand

*------------------------------------------------------------------------------
* 7. Labor income (loneink) - In hundreds of SEK
*    Based on summary: min=0, max=78094, mean=1790
*------------------------------------------------------------------------------
gen rand = runiform()
gen loneink = 0 if rand < 0.12  // 12% with no labor income
replace loneink = floor(rnormal(1790, 1400)) if rand >= 0.12 & missing(loneink)
replace loneink = max(0, min(loneink, 78094))  // Constrain to range
drop rand

*------------------------------------------------------------------------------
* 8. Disposable income (dispink04) - In hundreds of SEK
*    Based on summary: min=-7578, max=234090, mean=2209
*------------------------------------------------------------------------------
gen dispink04 = loneink + floor(rnormal(400, 700))
replace dispink04 = max(-7578, min(dispink04, 234090))

*------------------------------------------------------------------------------
* 9. Number of employees (antans)
*    Based on summary: min=0, max=10, mean=1
*------------------------------------------------------------------------------
gen rand = runiform()
gen antans = 0 if rand < 0.55      // 55% no employees
replace antans = 1 if rand >= 0.55 & rand < 0.82
replace antans = 2 if rand >= 0.82 & rand < 0.90
replace antans = floor(runiform(3, 11)) if rand >= 0.90
replace antans = max(0, min(antans, 10))
drop rand

*------------------------------------------------------------------------------
* 10. Study support (stud) - In hundreds of SEK
*     Based on summary: min=0, max=1860, mean=47
*------------------------------------------------------------------------------
gen rand = runiform()
gen stud = 0 if rand < 0.78  // 78% no study support
replace stud = floor(rnormal(250, 200)) if rand >= 0.78 & missing(stud)
replace stud = max(0, min(stud, 1860))
drop rand

*------------------------------------------------------------------------------
* Order variables logically
*------------------------------------------------------------------------------
order lopnr kon kommun sun2000niva ssyk3 astsni2007 ///
      loneink dispink04 antans stud

*------------------------------------------------------------------------------
* Display summary
*------------------------------------------------------------------------------
di as text _n(2) "{hline 78}"
di as text "Summary of created variables:"
di as text "{hline 78}"

describe, short
di as text _n "Numeric variables:"
summarize loneink dispink04 antans stud, separator(0)

di as text _n "Categorical variables (string):"
tab sun2000niva
tab ssyk3
tab astsni2007, sort

di as text _n "Binary variables:"
tab kon
tab kommun

*------------------------------------------------------------------------------
* Save dataset
*------------------------------------------------------------------------------
compress

* Save in submission data folder
save "../data/synthetic_scb_data.dta", replace

di as text _n(2) "{hline 78}"
di as result "SUCCESS: Synthetic SCB dataset created"
di as text "{hline 78}"
di as text "Location: ../data/synthetic_scb_data.dta"
di as text "Observations: " as result _N
di as text "Variables: " as result r(k)
di as text _n "This synthetic dataset is ready for autolabel demonstration."
di as text "{hline 78}" _n

log close
