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
local projectdir="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\Controls and Instruments"
local output="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\Controls and Instruments\statafiles"
local project="StateLevelDemographicControls"

***Log********
local logthis="no"
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
*StateLevelDemographicControls.do
*Dan Teles Mar 2014
***************************************************
set more off
************

************Import BEA Data:*******************
clear all
cd "`projectdir'\Bureau of Economic Analysis"
import excel percapitaIncome_state_1980to2012_edited, firstrow
*****Drop Notes*******
drop if LineCode==.
*****Reshape from State,Variable x Year to State,Year x Variable*****
reshape long y, i(Fips LineCode) j(year)
drop Description
/* LineCode1== Personal Income
   LineCode2==Population
   LineCode3==PerCapita Personal Income */
   
reshape wide y, i(Fips year) j(LineCode)
**********************************
destring Fips, replace
rename Fips FIPS
replace FIPS=FIPS/1000
rename y1 INCOME
rename y2 POP
rename y3 INCperCAP
label var INCOME "Income"
label var POP "Population (BEA)"
label var INCperCAP "Income per capita"
order FIPS Area year
***********************
*merge with state crosswalk
**************************
cd "`output'"
merge m:1 FIPS using StateCrosswalk
keep if _merge==3
sort FIPS year
drop _merge
******SAVING***************
cd "`output'"
save `project'_temp, replace


***************************************************
************Import Census Data:********************
***************************************************
clear all
*** Import   2000-2009********
cd "`projectdir'\Census"
insheet using ST-EST00INT-AGESEX.csv
rename state fips
rename name state
drop region division estimatesbase2000 census2010pop
foreach num of numlist 2000/2010{
rename popestimate`num' pop`num'
}
**Drop US****
drop if fips==0
**reshape
reshape long pop, i(fips state age sex) j(year)
reshape wide pop, i(fips state age year) j(sex)
rename pop0 pop
rename pop1 popm
rename pop2 popf
drop if year==2010 /*use 2010 populations from 2010-2012 file*/
********SAVING************
cd "`output'"
save `project'_temp2, replace
clear all
*** Import  2010-2012********
cd "`projectdir'\Census"
insheet using PEP_2012_PEPSYASEX_with_ann.csv
rename geoid2 fips
rename geodisplaylabel state
drop if fips==. /*drops US totals*/
drop if fips==72 /*drops Puerto Rico*/
***Keep variables of interest***
/*population variables are labeled est7yyyysex[s]_age[age]
I drop all variables with other conventions
these include census values and estimates base */
drop cen* est4* geoid est72010sex0_medage-est72012sex2_medage
**RESHAPE DATA***
foreach y in 0 1 2{
foreach s in 0 1 2{
rename est7201`y'sex`s'_age85plus est7201`y'sex`s'_age85
/*drop the word plus so 85 can be numeric*/
}
}
local stubs1 est72010sex0_age est72010sex1_age est72010sex2_age est72011sex0_age est72011sex1_age est72011sex2_age est72012sex0_age est72012sex1_age est72012sex2_age 
reshape long `stubs1', i(fips) j(age)
foreach y in 0 1 2{
foreach s in 0 1 2{
rename est7201`y'sex`s'_age est7201`y'sex`s'
/*drop _age so sex can be numeric j*/
}
}
local stubs2 est72010sex est72011sex est72012sex
reshape long `stubs2', i(fips age) j(sex)
foreach y in 0 1 2 {
rename est7201`y'sex pop201`y'
/*drops sex so year is numeric,
also rename to pop for later merge*/
}
reshape long pop, i (fips age sex) j(year)
reshape wide pop, i(fips state age year) j(sex)
rename pop0 pop
rename pop1 popm
rename pop2 popf

****Append with 2000-2010****
cd "`output'"
append using `project'_temp2
*****Import 1980-1999 from NBER********
cd "`projectdir'\NBER"
append using pop80s
append using pop90s
*****Drop Male and Female Pops, Retain total pop****
drop popm popf
****Calc Percent under 18 and over 65********
drop if age==999 /*drops total for 2000s, total not available for 80s, 90s*/
sort fips year
by fips year: egen totalpop=total(pop)
reshape wide pop, i(fips state year) j(age)
gen popu18 = pop0
foreach var of varlist pop1-pop17{
replace popu18 =popu18 + `var'
}
gen popo65 = pop66
foreach var of varlist pop66-pop85{
replace popo65 =popo65 + `var'
}

gen pctpopu18 = popu18 / totalpop
gen pctpopo65 = popo65 / totalpop
label var pctpopu18 "Percent of population under 18"
label var pctpopo65 "Percent of population over 65"
****Keep only variables of interest and fips*******
keep fips year pctpopu18 pctpopo65 totalpop
label var year "Year"
label var totalpop "Population (Census)"
rename fips FIPS /*for merge*/

***Merge with BEA data********
cd "`output'"
merge 1:1 FIPS year using `project'_temp
drop _merge

***Merge with Mark Frank Inequality Data*****
cd "`output'"
rename NAME state
drop Area
merge 1:1 state year using Frank_Inequality_Aug2014
keep if _merge==3
drop _merge
rename state NAME
******SAVING***************
cd "`output'"
save `project', replace
