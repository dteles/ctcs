*************************************************
* Charitable Tax Credits Analysis
* CTC_makedata.do
* 8/21/2017, version 1
* Dan Teles
*************************************************
* this file creates datasets 
* it can be called from CharitableTaxCredits.do
**************************************************
* Directories
**************************************************
local projectdir="D:\Users\dteles\Box Sync\DTeles\CharitableTaxCredits"
local datadir="`projectdir'\data"
local output="`projectdir'\output"
local project="CharitableTaxCredits"
**************************************************
* Locals to define which sections to run
**************************************************
local mergeNCCS="no"
local statefiles="yes"
**************************************************
* Save Time-stamped copy of this .do file
**************************************************
if "$makecopy"=="yes"{
	local time : di %tcCCYYNNDD!_HHMMSS clock("`c(current_date)'`c(current_time)'","DMYhms")
	copy CTC_makedata.do "CTC_makedata_`time'.do"
}
**************************************************
* Create Datasets
**************************************************
*Create 1989-2009 temp files
**************************
if "`mergeNCCS'"=="yes" {
	foreach num of numlist 1989/2009 {
		cd "`datadir'\NCCSextracts"
		use CorePC`num', replace
		if `num'==1990 {
			*keep variables of interest
			keep ein fisyr name-zip5 cont dues invinc totrev solicit ass_boy-liab_eoy fundfees compens
			gen progrev=0  // generate program revenue variable
		}
		if `num'==2008 | `num'==2009 {
			keep ein fisyr name-zip5 cont progrev dues invinc totrev solicit ass_boy-liab_eoy fundfees direxp rentexp compens
			***Edit Fundraising Expenses for consistancy after change in 990 Form
			replace solicit=fundfees+direxp if fundfees+direxp>solicit & fundfees!=. & direxp!=.
			replace solicit=fundfees+direxp if solicit==0 | solicit==.
		}			
		if `num'!=1990 & `num'!=2008 & `num'!=2009 {
			keep ein fisyr name-zip5 cont progrev dues invinc totrev solicit ass_boy-liab_eoy fundfees rentexp compens
		}
		*Edit Program Revenue Variable for consistancy in measurement across years**
		replace progrev=progrev+dues
		drop dues	
		*destring for help with merge and sort.
		destring ein fisyr , replace force
		recast long ein
		*generate a variable for which version the data came from
		gen yr_filed = `num'
		*save temp file*
		cd "`datadir'\temp"
		save CorePC`num'_temp, replace
	}
	**************************
	*Create 2010 temp file
	**************************
	cd "`datadir'\NCCSextracts"
	use CorePC2010, replace
	keep ein fisyr name-zip5 cont progrev dues invinc totrev solicit ass_boy-liab_eoy fundfees direxp rentexp compens
	*Edit Program Revenue Variable for consistancy in measurement across years**
	replace progrev=progrev+dues
	drop dues
	*Edit Fundraising Expenses for consistancy after change in 990 Form
	replace solicit=fundfees+direxp if fundfees+direxp>solicit & fundfees!=. & direxp!=.
	replace solicit=fundfees+direxp if solicit==0 | solicit==.
	*destring for help with merge and sort.
	destring ein fisyr , replace
	recast long ein
	*generate a variable for which version the data came from
	gen yr_filed = 2010
	cd "`datadir'\temp"
	save CorePC2010_temp, replace
	**************************
	*Create 2011 temp file
	**************************
	cd "`datadir'\NCCSextracts"
	use CorePC2011, replace
	keep ein fisyr name-zip5 cont progrev invinc totrev ass_boy-liab_eoy fundfees lessdirf lessdirg rentexp compens
	***Edit Fundraising Expenses for consistancy after change in 990 Form
	gen solicit=fundfees+lessdirf+lessdirg
	****destring for help with merge and sort.
	destring ein fisyr , replace
	recast long ein
	****generate a variable for which version the data came from
	gen yr_filed = 2011
	cd "`datadir'\temp"
	save CorePC2011_temp, replace
	*******************************************
	*Create 2012 and 2013 temp files
	*******************************************
	foreach num of numlist 2012/2013 {
		cd "`datadir'\NCCSextracts"	
		use CorePC`num', replace
		keep ein fisyr name-zip5 cont progrev invinc totrev ass_boy-liab_eoy lessdirf fundfees lessdirf lessdirg rentexp compens
			***Edit Fundraising Expenses for consistancy after change in 990 Form
			gen solicit=fundfees+lessdirf+lessdirg	
			****destring for help with merge and sort.
			destring ein fisyr , replace
			recast long ein
			****generate a variable for which version the data came from
			gen yr_filed = 2012
		***Save 2012temp file***
		cd "`datadir'\temp"
		save CorePC`num'_temp, replace
	}
	*********************************************
	*Merge Temp files into a Master file and Clean Data
	*********************************************
	use CorePC1989_temp, replace
	foreach num of numlist 1990/2013 {
		cd "`datadir'\temp"
		append using CorePC`num'_temp
	}
	**remove duplicates*****
	***first, if duplicate entries exist within the same fiscal year and filing year, take the larger values of financial variables
	sort ein fisyr yr_filed
	order ein fisyr yr_filed
	collapse  (first) name-zip5 (max) cont-compens, by(ein fisyr yr_filed)
	***second treat duplicates from filings in seperate years as ammended files.
	sort ein fisyr yr_filed /*sorts by year filed*/
	by ein fisyr: gen N=_N
	by ein fisyr: gen n=_n
	count
	**Keeps only the last filing***
	keep if N==n
	drop N n
	count
	*clean string data
	foreach var of varlist name state city {
		replace `var'=upper(`var')
		replace `var' = subinstr(`var', "&", " AND ",.)
		replace `var' = subinstr(`var', "-", " ",.)
		replace `var' = subinstr(`var', "/", " ",.)
		replace `var' = subinstr(`var', ",", " ",.)
		replace `var' = subinstr(`var', "INCORPORATED", "INC.",.)
		replace `var' = subinstr(`var', "CORPORRN", "CORP.",.)
		replace `var' = subinstr(`var', "  ", " ",.)
		replace `var' = subinstr(`var', "  ", " ",.)
		egen `var'2=sieve(`var'), keep(alphabetic numeric space)
		replace `var'=`var'2
		drop `var'2
		replace `var'=trim(`var')
		replace `var'=trim(`var')
	}	
	***Save Combined Project File**********
	cd "`datadir'"
	save CombinedNCCS, replace
}	
*********************************************
*Create State-by-NTEECC and State Aggregate Files
*********************************************
if "`statefiles'"=="yes" {
	* load data *
	if "`mergeNCCS'"=="no" {
		cd "`datadir'"
		use CombinedNCCS, replace
	}	
	**Gen Number Variable
	gen nonprofits=1
	***fill in state variable if missing
	sort ein fisyr
		bysort ein: carryforward state if state=="", replace
		bysort ein: carryforward state if state=="", replace
		gsort ein - fisyr
		by ein : carryforward state if state=="", replace 
		by ein: carryforward state if state=="", replace
		count if state==""
	***Collapse to State by NCCS by Year	
	sort state nteecc ein fisyr
	collapse (sum) cont-compens nonprofits, by(state nteecc fisyr)
	****Save State-by-NTEECC File****
	cd "`datadir'"
	save NCCS_ntee_state_year, replace	
	***Collapse to State by Year
	sort state fisyr nteecc 
	collapse (sum) cont-compens nonprofits, by(state fisyr)
	****Save State Aggregate File****
	cd "`datadir'"
	save NCCS_state_year, replace	
}
