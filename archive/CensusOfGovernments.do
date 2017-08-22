clear all
drop _all
capture log close   

****************************************************
******Standard Preamble***************************
******************************************************
/*
******Cluster directories*****
local projectdir="/econ/dteles/"
local datadir="/econ/dteles/"
local output="/econ/dteles/"
local project=""to
*/
*****My PC Directories************
local projectdir="D:\Documents\Dropbox\Teles_Disertation_Research\Volunteering_and_NonProfits\Controls and Instruments"
local datadir="`projectdir'\Census\censusofgovernments"
local output="D:\Documents\Dropbox\Teles_Disertation_Research\Volunteering_and_NonProfits\Controls and Instruments\statafiles"
local project="CensusOfGovernments"

***Log********
local logthis="yes"
if "`logthis'"=="yes"{
cd "`projectdir'\dofiles"
capture log close
local time : di %tcCCYYNNDD!_HHMMSS clock("`c(current_date)'`c(current_time)'","DMYhms")
capture shell mv `project'_*.do ./archive/
capture cp `project'_.do "`project'_`time'.do"
capture shell mv `project'_*.log ./archive/
log using `project'__`time'.log, replace text
pwd
display "$S_DATE $S_TIME"
}

* verify packages installed
* capture adoupdate, update

set mem 12g
*set matsize 11000
set linesize 120
set maxvar 5000
set scheme s1color, perm
*************************************************
*CensusOfGovernments.do
*Dan Teles May 2015
***************************************************
set more off
***********************************************************
********Convert GOVS to FIPS code Crosswalk to Stata*******
***********************************************************
clear all
cd "`projectdir'\Census"
insheet using "GOVS_to_FIPS_State_Crosswalk.csv", comma
rename v1 GOVS
rename v2 state
rename v3 FIPS
save GOVS_to_FIPS_State_Crosswalk.dta, replace
************
***********************************************************
***note: Years Ending in 2 or 7 are survey years, no CV****
***********************************************************
********Import Data from Microsoft Access Database*********
***********************************************************
***1972, 1977-2008***
clear all
insheet using "D:\Documents\Dropbox\Teles_Disertation_Research\Volunteering_and_NonProfits\Controls and Instruments\Census\censusofgovernments\historical\RexDac-extractQQ01.csv", comma
rename state stco
rename type gov_lvl
rename year4 year
drop sort_code 
cd "`datadir'"
save RexDaxExtract_72and77to08.dta, replace
***********************************************************
********Import Data from Public Use Files******************
***********************************************************
***1993 and 1994 Public Use File***
foreach yr in 93 94 {
	cd "`datadir'"
	clear all
	**load***
	if `yr'==93 {
		insheet using "`yr'stlest_edited.txt", comma 
		/*Edited coding error for New York changed "33-2, 33-2" to "33-1, 33-2" */
	}
	if `yr'==94{
	insheet using "`yr'stlest.txt", comma
	}
	**for 1993, drop first column and update column names***
	if `yr'==93{
		drop v1
		forval i =2/158 {
			local h = `i'-1
			rename v`i' v`h'
		}	
	}
	**save item names***
	qui count
	local N=r(N)
	forval i = 1/`N' {
		local label`i' =v1[`i']
	}
	drop v1
	**transpose and return item variable names
	if `yr'==93 {
		sxpose, clear
		drop _var1
		rename _var2 year
		rename _var3 code
		forval i = 5/`N' {
			rename _var`i' amount`label`i''
		}
	}	
	if `yr'==94 {
		xpose, varname clear
		forval i = 1/`N' {
			rename v`i' amount`label`i''
		}
	}
	**edit observation names for 1993
	if `yr'==93 {		
		drop _var4
		split code, p(-)
		rename code1 stco
		rename code2 gov_lvl
		drop code
		qui destring year stco gov_lvl amount*, replace
		order stco gov_lvl year
		replace year = 1993 
	}	
	**edit observation names for 1994
	if `yr'==94 {
		qui count
		local M=r(N)+1
		local Z = r(N)/3
		forval i = 1/`M' {
			qui replace _varname ="" if _varname=="v`i'"
		}
		replace _varname =_varname[_n-1] if _varname==""
		rename _varname state
		gen gov_lvl = _n
		forval i=1/`Z' {
			local m =`i'*3
			local l = `m'-1
			local k = `m'-2
			qui replace gov_lvl=1 if gov_lvl==`k'
			qui replace gov_lvl=2 if gov_lvl==`l'
			qui replace gov_lvl=3 if gov_lvl==`m'		
		}
		replace state="_US" if state=="ustotals"
		replace state="districtofcolumbia" if state=="dc"
		sort state
		egen stco = group(state)
		replace stco = stco - 1
		gen year = 1994
		order state stco gov_lvl year
		} 
	drop amountPOP
	save `yr'statetypepu.dta, replace
}
***1992 and 1997 Public Use Files*****
foreach yr in 92 97 {
	clear all
	infix stco 1-2 gov_lvl 3 str item 15-17 amount 18-29 using "`yr'CensusStateTypePU.txt"
	gen cv=.
	gen year=`yr'
	save `yr'statetypepu.dta, replace
}
***1995-96, 1998-2012 Public Use Files***
foreach yr in 95 96 {
	clear all
	infix stco 1-2 gov_lvl 3 str item 15-17 amount 18-29 using "FIN`yr'EST.txt"
	gen cv=.
	gen year=`yr'
	save `yr'statetypepu.dta, replace
}
***1998-2000,2002 Public Use Files***
clear all
infix stco 1-2 gov_lvl 3 str item 5-7 amount 9-20 cv 21-32 year 34-35 using "98statetypepu_0701.txt"
save 98statetypepu.dta, replace
clear all
infix stco 1-2 gov_lvl 3 str item 5-7 amount 9-20 cv 21-32 year 34-35 using "99statetypepu_0402.txt"
save 99statetypepu.dta, replace
clear all
infix stco 1-2 gov_lvl 3 str item 5-7 amount 9-20 cv 21-32 year 34-35 using "00statetypepu_1108.txt"
save 00statetypepu.dta, replace
clear all
infix stco 1-2 gov_lvl 3 str item 15-17 amount 19-29 using "2002State_By_type_Summaries24.txt"
gen cv=.
gen year=02 
save 02statetypepu.dta, replace
****2001 and 2003-2012 Public Use Files**
foreach yr in 01 03 04 05 06 07 08 09 10 11 12 {
	clear all
	infix stco 1-2 gov_lvl 3 str item 5-7 amount 9-20 cv 21-32 year 34-35 using "`yr'statetypepu.txt"
	save `yr'statetypepu.dta, replace
}
*******************************************************
***Merge PU Files from 1992 and 1995-2012 and Reshape**
*******************************************************
clear all
use 92statetypepu.dta
foreach yr in 95 96 97 98 99 00 01 02 03 04 05 06 07 08 09 10 11 12 {
	append using `yr'statetypepu
}
***convert year to 4 digits
replace year = year + 1900 if year>75	
replace year = year + 2000 if year<75
**reshape 
reshape wide amount cv, i(stco gov_lvl year) j(item) string
**********************************************
*****Append with 1993 and 1994 Data***************
**********************************************
append using 93statetypepu
append using 94statetypepu
save PUfiles_temp, replace 
clear all
cd "`datadir'" 
use PUfiles_temp
**********************************************
*******Generate Aggregates of Interest********
**********************************************
gen tax_rev=0
foreach code in 01 09 10 11 12 13 14 15 16 19 20 21 22 23 24 25 27 28 29 40 41 50 51 53 99 {
	replace amountT`code'=0 if amountT`code'==.
	replace tax_rev = tax_rev + amountT`code'
}
gen gen_chgs=0
foreach code in 01 03 06 09 10 12 14 16 18 21 36 44 45 50 54 56 59 60 61 80 81 87 89 {	
	replace amountA`code'=0 if amountA`code'==.
	replace gen_chgs = gen_chgs + amountA`code'
}
gen misc_rev=0
foreach code in 01 10 11 20 21 30 40 41 50 95 99 {	
	replace amountU`code'=0 if amountU`code'==.
	replace misc_rev = misc_rev + amountU`code'
}
gen util_rev=0
foreach code in 91 92 93 94 {
	replace amountA`code'=0 if amountA`code'==.
	replace util_rev = util_rev + amountA`code'
}
gen liqr_rev=0
	replace amountA90=0 if amountA90==.
	replace liqr_rev=amountA90
gen trust_rev = 0
foreach code in X01 X02 X04 X05 Y01 Y02 Y04 Y11 Y12 Y51 Y52 {
	replace amount`code'=0 if amount`code'==.
	replace trust_rev = trust_rev + amount`code'
}		
gen own_rev = tax_rev + misc_rev + gen_chgs
gen ops_exp=0
foreach code in 01 03 04 05 12 16 18 21 22 23 24 25 26 29 31 32 36 44 45 50 52 55 56 59 60 61 62 66 74 75 77 79 80 81 85 87 89 90 91 92 93 94 {
	replace amountE`code'=0 if amountE`code'==.
	replace ops_exp = ops_exp + amountE`code'
}	
gen cap_exp=0
foreach code in F01 F03 F04 F05 F12 F16 F18 F21 F22 F23 F24 F25 F26 F29 F31 F32 F36 F44 F45 F50 F52 F55 F56 F59 F91 F92 F93 F94 G01 G03 G04 G05 G12 G16 G18 G21 G22 G23 G24 G25 G26 G29 G31 G32 G36 G44 G45 G50 G52 G55 G56 G59 G60 G61 G62 G66 G77 G79 G80 G81 G85 G87 G89 G90 G91 G92 G93 G94 {
	replace amount`code'=0 if amount`code'==.
	replace cap_exp = cap_exp + amount`code'
}	
gen misc_exp=0
foreach code in X11 X12 Y05 Y06 Y14 Y53 J19 J67 J68 J85 I89 I91 I92 I93 I94 {
	replace amount`code'=0 if amount`code'==.
	replace misc_exp = misc_exp + amount`code'
}	
gen dir_exp = ops_exp + cap_exp + misc_exp
***Carry Forward State Names from 1994 file*******
gsort + stco - state
by stco: carryforward state, replace
order state stco year gov_lvl
sort stco year gov_lvl
*******************************************************
***Merge PU Files with database extract****************
*******************************************************
merge 1:1 stco year gov_lvl using RexDaxExtract_72and77to08.dta
drop _merge
***Carry Forward State Names*******
gsort + stco - state
by stco: carryforward state, replace
***Carry Forward state/level name***
sort stco gov_lvl
by stco gov_lvl: carryforward name, replace
***use database extract for data up to 2006, PU files thereafter***
/*I may want to change this later*/
local yr = 2006
replace tax_rev = totaltaxes if year<=`yr'
replace gen_chgs = totalgeneralcharges if year<=`yr'
replace misc_rev = miscgeneralrevenue if year<=`yr'
replace own_rev = genrevownsources if year<=`yr'
replace ops_exp = totalcurrentoper  if year<=`yr'
replace cap_exp =totalcapitaloutlays if year<=`yr'
replace misc_exp =  totalinterestondebt + totalinsurtrustben + totassistsubsidies  if year<=`yr'
replace dir_exp = directexpenditure if year<=`yr'
**keep only state, local, and state/local total**
keep if gov_lvl<=3
**clean 
keep stco gov_lvl name year own_rev tax_rev gen_chgs misc_rev dir_exp ops_exp cap_exp misc_exp
order name stco gov_lvl year own_rev tax_rev gen_chgs misc_rev dir_exp ops_exp cap_exp misc_exp
sort stco year gov_lvl
rename stco GOVS
***************************************
********merge in FIPS codes************
***************************************
cd "`projectdir'\Census"
merge m:1 GOVS using GOVS_to_FIPS_State_Crosswalk.dta
drop _merge
**drop US Aggregates
drop if GOVS==0 | GOVS==52
order state name GOVS FIPS gov_lvl year own_rev tax_rev gen_chgs misc_rev dir_exp ops_exp cap_exp misc_exp
***************************************
****************save*******************
***************************************
cd "`output'"
save CensusOfGovernments, replace
********************************
**impute aggregates for 2001 and 2003 and roll up to aggregate level**
**generate missing observations
gen id=GOVS*10 + gov_lvl
tsset id year
tsfill
drop if year>1972 & year<1977
**fill state and gov_lvl***
sort id year
bysort id: carryforward state name GOVS FIPS gov_lvl, replace
drop id name
***reshape**
reshape wide own_rev-misc_exp, i(state GOVS FIPS year) j(gov_lvl)
***impute****
gen negyear=3000-year
foreach var in own_rev tax_rev gen_chgs misc_rev dir_exp ops_exp cap_exp misc_exp {
gen ratio=`var'1/`var'2
sort GOVS year
bysort GOVS: carryforward ratio, gen(ratiolag)
sort GOVS negyear
bysort GOVS: carryforward ratio, gen(ratiolead) back
replace ratio = (ratiolag + ratiolead)/2 if ratio==.
replace `var'1= `var'2*ratio if year==2001 | year==2003
replace `var'3=`var'1-`var'2 if year==2001 | year==2003
drop ratio ratiolag ratiolead
}
drop negyear
***reshape back***
reshape long own_rev tax_rev gen_chgs misc_rev dir_exp ops_exp cap_exp misc_exp, i(state GOVS FIPS year) j(gov_lvl)
***keep aggregate
keep if gov_lvl==1
save CensusOfGovernments_adjusted, replace
