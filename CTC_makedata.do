*************************************************
* Charitable Tax Credits Analysis
* CTC_makedata.do
* 8/23/2017, version 1
* Dan Teles
*************************************************
* this file creates datasets 
* it can be called from CharitableTaxCredits.do
**************************************************
* Directories
**************************************************
local projectdir="D:\Users\dteles\Box Sync\DTeles\CharitableTaxCredits"
local controldir "D:\Users\dteles\Box Sync\DTeles\MyControls"
local datadir="`projectdir'\data"
local output="`projectdir'\output"
local project="CharitableTaxCredits"
**************************************************
* Locals to define which sections to run
**************************************************
local mergeNCCS="yes"
local makecntrl="yes"
local masterfile="yes"
local statefiles="yes"
local CF="yes"
local subsector="yes"
local diffndiff="yes"
**************************************************
* Locals to define which subsets to create
**************************************************
local BIG `" "ALL" "PUB" "ST" "'
local CFSPILL `" "ALLmCF" "PUBmCF" "STmCF" "'
local DDfiles	`" "DD" "DDD" "'
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
	* Keeps only the last filing***
	keep if N==n
	drop N n
	count
	* clean string data
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
	* carryforward state if it is missing
	sort ein fisyr
	bysort ein (fisyr): carryforward state if state=="", replace
	bysort ein (fisyr): carryforward state if state=="", replace
	bysort ein (fisyr): carryforward state if state=="", replace
	gsort ein - fisyr
	bysort ein (fisyr): carryforward state if state=="", replace 
	bysort ein (fisyr): carryforward state if state=="", replace
	di "Checking to make sure no state identifiers are missing"
	di "Number missing:"
	count if state==""
	sort ein fisyr	
	drop if state==""
	***Save Combined Project File**********
	cd "`datadir'"
	save CombinedNCCS, replace
}
************************************************
* State-by-year Controls Files
************************************************
if "`makecntrl'"=="yes" {
	* Load census government finance data
	cd "`controldir'\Census\governments"
	use CensusStateGov
	* keep State and Local Aggregate
	keep if gov_lvl==1
	drop gov_lvl
	sum year
	* Merge in SEER Population data
	cd "`controldir'\SEER_population"
	merge 1:1 FIPS year using SEERpopulation_state
	keep if _merge==3
	drop _merge	
	sum year
	* Merge in BEA personal Income data
	cd "`controldir'\BEA"
	merge 1:1 FIPS year using BEA_PersonalIncome_state
	keep if _merge==3
	drop _merge
	sum year
	*drop BEA population in favor of SEER population
	drop POP 
	* merge in Frank Ineqaulity data
	rename year Year
	drop State
	rename GeoName State
	cd "`controldir'\Frank_inequality"
	merge 1:1 State Year using Frank_WTID_2013
	drop st // Frank state code
	keep if _merge==3
	drop _merge
	merge 1:1 State Year using Frank_Gini_2013
	drop st // Frank state code	
	keep if _merge==3
	drop _merge
	rename Year year
	sum year
	* merge in unemployment data
	cd "`controldir'\BLS"
	merge 1:1 FIPS year using BLS_unemployment_state
	keep if _merge==3
	drop _merge	
	sum year
	* Merge in CPI-U (1982-1984 base)
	rename year Year
	merge m:1 Year using CPIU
	rename Annual CPIU
	rename Year year
	keep if _merge==3
	drop _merge
	cd "`datadir'"
	* rename and adjust inequality controls
	rename Gini gini
	rename Top1_adj top1
	replace top1=top1/100
	* Keep Variables of Interest
	keep FIPS year own_rev tax_rev dir_exp state pop INCOME INCperCAP top1 gini unemp CPIU 
	order state FIPS year 
	save allcontrols, replace
	summarize
}
************************************************
* Create Master File
************************************************
if "`masterfile'"=="yes" {
	clear all
	cd "`datadir'"
	use CombinedNCCS
	* Create "MAJOR" classification
	gen MAJOR=.
	replace MAJOR = 1 if ntee1=="A"
	replace MAJOR = 2 if ntee1=="B"
	replace MAJOR = 3 if ntee1=="C" | ntee1=="D"
	foreach letter in E F G H  {
		replace MAJOR=4 if ntee1=="`letter'"
	}
	foreach letter in I J K L M N O P {
		replace MAJOR=5 if ntee1=="`letter'"
	}
	foreach letter in R S T U V W {
		replace MAJOR=6 if ntee1=="`letter'"
	}
	replace MAJOR=7 if ntee1=="X"
	replace MAJOR=8 if ntee1=="Y"
	replace MAJOR=10 if ntee1=="Z"	
	* Merge in Controls
	rename fisyr year
	merge m:1 state year using allcontrols
	drop _merge
	* Inflate to 2012 Dollars
	qui sum CPIU if year==2012
	local cpi83in2012 = r(max)
	local test = r(min)
	if `cpi83in2012'!=`test' {
		error
	}
	qui foreach var of varlist cont-compens {
		replace `var'=`var'*`cpi83in2012'/CPIU
	}
	* generate OverHead Variable
	replace rentexp=0 if rentexp==.
	replace compens=0 if compens==.
	gen overhead = rentexp + compens		
	* save masterfile
	cd "`datadir'"
	save NonprofitsMaster, replace
}	
*********************************************
*Create State-by-NTEECC and State Aggregate Files
*********************************************
if "`statefiles'"=="yes" {
	* load data *
	if "`mergeNCCS'"=="no" {
		cd "`datadir'"
		use NonprofitsMaster, replace
	}	
	**Gen Number Variable
	gen nonprofits=1
	***Collapse to State by NCCS by Year	
	sort state nteecc ein year
	order state nteecc ntee1 MAJOR
	sum
	collapse (first) MAJOR ntee1 FIPS-CPIU (sum) cont-compens overhead nonprofits, by(state nteecc year)	
	****Save State-by-NTEECC File****
	cd "`datadir'"
	save NCCS_ntee_state_year, replace	
	sum
	***Collapse to State by Year
	sort state year nteecc 
	collapse (first) MAJOR ntee1 FIPS-CPIU (sum) cont-compens overhead nonprofits, by(state year)
	****Save State Aggregate File****
	cd "`datadir'"
	save NCCS_state_year, replace	
	sum
}
************************************************
* Community Foundations Files
************************************************
if "`CF'"=="yes" {
	clear all
	cd "`datadir'"
	use NonprofitsMaster
	**Gen Number Variable
	gen nonprofits=1
	preserve
	* keep only community foundations
	keep if nteecc=="T31"
	sort ein year
	save NCCS_foundations, replace
	restore
	* drop only community foundations // used for spillover estimates
	drop if nteecc=="T31"
	save NCCS_mCF, replace
}

************************************************
* Save Subsector Files
************************************************
if "`subsector'"=="yes" {
	*define files of interest
	local sectorfiles `" "CF" "CFwo" `BIG' `CFSPILL' "'
	* create sector-level files
	foreach set of local sectorfiles {
		di "..."
		di "creating `set'"
		clear all
		cd "`datadir'"
		* load primary dataset
		foreach i of local BIG {
			if "`set'"=="`i'" {
				use NCCS_ntee_state_year
				di "NCCS_ntee_state_year loaded"
			}
		}
		* load community foundations file
		if "`set'"=="CF" | "`set'"=="CFwo" {
			use NCCS_foundations
			di "NCCS_foundations loaded"
		}
		* load mCF dataset for IA spillover estimates
		foreach i of local CFSPILL {
			if "`set'"=="`i'" {
				use NCCS_mCF
				di "NCCS_mCF loaded"
			}
		}
		* Reduce to Public and Societal Benefit Organizations
		if  "`set'"=="PUBmCF" | "`set'"=="PUB" {
			keep if MAJOR==6	
		}
		* Reduce to ntee1 S&T Organizations
		if "`set'"=="STmCF" | "`set'"=="ST" {
			keep if ntee1=="S" | ntee1=="T"
		}
		* Drop CBCBF (outlier) from main CF file 
		if "`set'"=="CF" {
			drop if ein==421504843
		}
		sort state year
		order state year MAJOR ntee1
		collapse (first) MAJOR ntee1 FIPS-CPIU (sum) cont-compens overhead nonprofits, by(state year)
		* generate additional variables and functional forms
		gen num = nonprofits
		label var num "Number of Nonprofits"
		gen lnnum = ln(num)
		gen numPC = num * 1000000 / pop
		label var numPC "Nonprofits per Million people" 
		gen lnnumPC = ln(num * 1000000 / pop)
		foreach var of varlist cont progrev totrev solicit overhead own_rev dir_exp {
			gen `var'PC=`var'/pop
			gen ln`var'PC=ln(`var'/pop)
			gen ln`var'=ln(`var') 
			sum `var'PC ln`var'PC ln`var'
		}		
		foreach var of varlist cont progrev totrev solicit overhead own_rev dir_exp {
			replace ln`var'PC=ln((`var'+.01)/pop) if `var'==0
			replace ln`var'= ln(`var'+.01)
			sum `var'PC ln`var'PC
		}		
		gen POP_million=pop / 1000000
		gen lnPOP=ln(pop)
		gen lnINCperCAP=ln(INCperCAP)
		sum INCperCAP lnINCperCAP POP_million lnPOP		
		rename state AB
		* In CF File: rename "nonprofits" "foundations"
		if "`set'"=="CF" | "`set'"=="CFwo" {
			rename nonprofits foundations
		}
		summarize
		* save sector level file
		cd "`datadir'"
		save `set', replace		
	}
	* end creation of sector-level files
}
************************************************
* Save Files for Diff-in-Diff
************************************************
if "`diffndiff'"=="yes" {
	foreach set of local DDfiles {
		di "..."
		di "creating `set' and `set'wo"
		clear all
		cd "`datadir'"
		* load primary dataset
		if "`set'"=="DDD" use NonprofitsMaster
		else if "`set'"=="DD" use NCCS_foundations
		* Generate Community Foundations Dummy
		gen CF=0
		replace CF=1 if nteecc=="T31"
		foreach var of varlist cont progrev totrev solicit overhead own_rev dir_exp {
			gen ln`var'= ln(`var'+.01)
		}		
		gen POP_million=pop/1000000
		gen lnPOP=ln(pop)
		gen lnINCperCAP=ln(INCperCAP)
		sum INCperCAP lnINCperCAP POP_million lnPOP	
		rename state AB
		***limit firm level file to sample pool****
		keep if year>1992
		*Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska becuase they have or had similar programs
		drop if AB=="KY" | AB=="MT" | AB=="ND" | AB=="MI" | AB=="NE" | AB=="KS"
		*Exclude Arizona, big charitable giving credit
		drop if AB=="AZ" 
		***limit to Nonprofits w/ at least 3 pre and 3 post years
		sort ein year
		foreach var of varlist lncont lnprogrev lnsolicit {
			gen `var'_temp=0
			foreach yr of numlist 1993/2002 {
				gen `var'_`yr'=0
				replace `var'_`yr'=1 if year==`yr' & `var'!=.
				replace `var'_temp=`var'_temp+`var'_`yr'
			}
			by ein: egen `var'_yrspre=total(`var'_temp)
			drop `var'_temp-`var'_2002
			gen `var'_temp=0
			foreach yr of numlist 2003/2012 {
				gen `var'_`yr'=0
				replace `var'_`yr'=1 if year==`yr' & `var'!=.
				replace `var'_temp=`var'_temp+`var'_`yr'
			}
			by ein: egen `var'_yrspost=total(`var'_temp)
			drop `var'_temp-`var'_2012	
			keep if `var'_yrspre>2 & `var'_yrspost>2
		}
		* end foreach loop
		* Save Dataset with outlier
		save IA_`set'wo, replace
		* Drop CBCBF (outlier) from main CF file 
		drop if ein==421504843
		* Save Datast without outlier
		save IA_`set', replace
	}
	***End loop over datasets********************
}




