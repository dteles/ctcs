*************************************************
* Charitable Tax Credits Analysis
* sumstats.doh
* 9/27/2017, version 1
* Dan Teles
*************************************************
* this file calculates summary statistics
* it can be called from CTC_IA.do or CTC_AZ.do
* which, in turn, are called from CharitableTaxCredits.do
**************************************************
di "-------------------------"
di "Summary Statistics for `set'"
di "-------------------------"
* Define Variables
local varlistBASE cont INCperCAP progrev solicit POP_million gini top1 nonprofits
local varlistLN lncont lnINCperCAP lnprogrev lnsolicit lnPOP gini top1 lnnum
local varlistPC contPC INCperCAP progrevPC solicitPC POP_million gini top1 numPC
local varlistLNPC lncontPC lnINCperCAP lnprogrevPC lnsolicitPC lnPOP gini top1 lnnumPC 
local varnames `" "Contributions" "Income" "Program_Revenue" "Fundraising" "Population" "Gini" "Top_1_Percent" "Nonprofits" "'
* Load Datasets
clear all
cd "`datadir'"
di "load `dataset'"	
use `dataset', replace
* Reduce to years of interest
keep if year>=`firstyear'
keep if year<=`lastyear'
qui cd "`output'\tempfiles"
* Summarize
sum
* Begin loop over functional form
foreach fform of local formlist {	
	* summary statistics for whole country		
	di "Summary Statistics for US `set': `fform' variables"
	di "`varlist`fform''"
	sum
	tabstat `varlist`fform'', s(mean sd) save
	matrix C=r(StatTotal)'
	matrix coln C ="US_Mean" "US_Std_deviation"
	matrix rown C = `varnames' 
	* Export data for Summary Graph, treatstate vs. US
	preserve
	qui gen `treatstate'=0
	qui replace `treatstate'=1 if AB=="`treatstate'"
	qui gen NOT_IA=1-`treatstate'	
	collapse (mean) `varlist`fform'', by(`treatstate' NOT_IA year)
	save `treatstate'_`set'vsUS_`fform', replace
	restore
	* Define Sample Pool
	preserve
	di "define sample pool"
	foreach st of local notcontrol {
		drop if AB=="`st'"
	}
	* Summary statistics for Iowa
	sum `varlist`fform'' if AB=="`treatstate'"
	tabstat `varlist`fform'' if AB=="`treatstate'", s(mean sd) save
	matrix A=r(StatTotal)'
	matrix coln A ="`treatstate'_mean" "`treatstate'_std_dev"
	matrix rown A = `varnames'
	matrix list A
	* Summary statistics for sample pool or Controls
	di "Summary Statistics for Control (Donor) Group `set': `fform' variables"
	sum `varlist`fform''  if AB!="`treatstate'"
	tabstat `varlist`fform''  if AB!="`treatstate'", s(mean sd) save
	matrix B=r(StatTotal)'
	matrix coln B =  "Control_Mean" "Control_SD" 
	matrix rown B = `varnames' 
	* Collapse data for Summary Graph, treatstate vs. US vs. Sample Pool
	drop if AB=="`treatstate'"
	gen POOL=1
	collapse (mean) `varlist`fform'' POOL, by(year)
	append using `treatstate'_`set'vsUS_`fform'
	save `treatstate'_`set'vsUS_`fform', replace
	restore
	* Export Summary Statisitcs
	matrix sumstats_`treatstate'_`set'_`fform'= [A , B , C ]
	matrix list sumstats_`treatstate'_`set'_`fform'
	matsave sumstats_`treatstate'_`set'_`fform', saving replace
	preserve
	use sumstats_`treatstate'_`set'_`fform', replace
	export excel using "`output'\tables\SUMSTATS.xls", firstrow(variables) sheet("`treatstate'_`set'_`fform'") sheetreplace
	matrix drop _all
	restore
}	
* end loop over functional form


