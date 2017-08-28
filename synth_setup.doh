*************************************************
* Charitable Tax Credits Analysis
* synth_setup.do
* 8/28/2017, version 1
* Dan Teles
*************************************************
* this file contains setup for CTC synth commands
* it can be called from CTC_IA.do or CTC_AZ.do
* which, in turn, are called from CharitableTaxCredits.do
**************************************************
* define locals for variables of interest
if "`fform'"=="PC"	{
	foreach var in cont progrev totrev solicit num {
		local `var' `var'PC
	}
	local INCperCAP INCperCAP
}
if "`fform'"=="LN"	{
	foreach var in cont progrev totrev solicit num INCperCAP {
		local `var' ln`var'
	}				
}					
if "`fform'"=="LNPC"	{
	foreach var in cont progrev totrev solicit num {
		local `var' ln`var'PC
	}
	local INCperCAP lnINCperCAP					
}
* define predictor variable list
local predvarlist `cont' `progrev' `totrev' `solicit' `num' `INCperCAP' gini top1
* clear out predvaryear locals
foreach yr of numlist 1/10 {
	foreach predvar of local predvarlist  {
		local `predvar'`n' ""
	}
}
* define predvar year locals 
foreach yr of numlist `year1'/`lastpreyear' {
	local n = `yr'-`year1'+1
		foreach predvar of local predvarlist  {
		local `predvar'`n' `predvar'(`yr')
	}
}
foreach predvar of local predvarlist {
	local `predvar'L `predvar'(`lastpreyear')
}
* Define locals for robustness check excluding population
if "`pass'"=="`prime_agg'xp" {
	local pop = ""
	local pop1 = ""
	local popL = ""
}
* Define locals for baseline with population
else {
	local pop lnPOP 
	local pop1 lnPOP(`year1')
	local popL lnPOP(`lastpreyear')
}	// populaiton variable always in log form
* Define local for which outcome variables are of interest
local outvars `cont' `num'  //Contributions and Number of Nonprofits
if "`pass'"==`prime_agg' {
local outvars `cont' `num' `solicit' 
}
* Define locals for cont predictor variables 
local lagpredictors ``cont'1' ``cont'2'  ``cont'3'  ``cont'4'  ``cont'5'  ``cont'6' 
local otherpredictors `INCperCAP' `pop' `progrev' `solicit' gini top1 
local otherpredictors2 `otherpredictors'  ``INCperCAP'1' `pop1' ``progrev'1' ``solicit'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L' ``solicit'L' `giniL' `top1L' 
local C1 `lagpredictors'
local C2 `cont' `otherpredictors'
local C3 ``cont'1' ``cont'L' `cont' `otherpredictors2'
local C4 `lagpredictors' `otherpredictors'
local C5 `lagpredictors' `otherpredictors2'
local C6 `otherpredictors'
local C7 `otherpredictors2'
local C8 `cont' `otherpredictors2'
local C9 ``cont'1' ``cont'L' `cont' `otherpredictors'
local C10 ``cont'1' ``cont'L' `cont' ``progrev'1' ``progrev'L' `progrev' ``solicit'1' ``solicit'L' `solicit'
* Define locals for SCM predictor variables for NUM
local number="`num'"
local lagpredictors_num ``num'1' ``num'2'  ``num'3'  ``num'4'  ``num'5'  ``num'6' 
local N1 `lagpredictors_num'
local N2 `num' `otherpredictors'
local N3 ``num'1' ``num'L' `num' `otherpredictors2'
local N4 `lagpredictors_num' `otherpredictors'
local N5 `lagpredictors_num' `otherpredictors2'
local N6 `otherpredictors'
local N7 `otherpredictors2'
local N8 `num' `otherpredictors2'
local N9 ``num'1' ``num'L' `num' `otherpredictors'
local N10 ``num'1' ``num'L' `num' ``solicit'1' ``solicit'L' `solicit' ``progrev'1' ``progrev'L' `progrev' 
* Define locals for solicit predictor variables
local lagpredictors_fund ``solicit'1' ``solicit'2'  ``solicit'3'  ``solicit'4'  ``solicit'5'  ``solicit'6' 
local otherpredictors_fund `INCperCAP' `pop' `progrev'  gini top1
local otherpredictors2_fund `otherpredictors' ``INCperCAP'1' `pop1' ``progrev'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L' `giniL' `top1L' 
local S1 `lagpredictors_fund'
local S2 `solicit' `otherpredictors_fund'
local S3 ``solicit'1' ``solicit'L' `solicit' `otherpredictors2_fund'
local S4 `lagpredictors_fund' `otherpredictors_fund'
local S5 `lagpredictors_fund' `otherpredictors2_fund'
local S6 `otherpredictors_fund'
local S7 `otherpredictors2_fund'
local S8 `solicit' `otherpredictors2_fund'
local S9 ``solicit'1' ``solicit'L' `solicit' `otherpredictors_fund'
local S10 ``solicit'1' ``solicit'L' `solicit' ``progrev'1' ``progrev'L' `progrev' 
* Display output
di "`fform' metrics are: `outvars'"
di "Pretreatment Period runs `year1' to `lastpreyear'.  Posttreatment Period runs `treatyear' to `lastyear'"
di "--------------------------------------"		

* end dofile				