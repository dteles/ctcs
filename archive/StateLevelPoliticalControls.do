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
local project=""
*/
*****My PC Directories************
local projectdir="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\Controls and Instruments"
local output="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\Controls and Instruments\statafiles"
local project="StateLevelPoliticalControls"

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
set matsize 11000
set linesize 120
set maxvar 5000
set scheme s1color, perm
*************************************************
*StateLevelPolitcalControls.do
*Dan Teles Mar 2014
***************************************************
set more off
************
************Import ICPSR Data:********************
clear all
cd "`projectdir'\ICPSR Congressional Roster"
use ICPSR_congress
***********
keep id-name state party yrleft yrenter firstcong-totalsens_s
*Recode Years*
foreach var in firstelect lastyr firstelect_h lastyr_h firstelect_s lastyr_s{
replace `var' =`var'+1000
replace `var'=. if `var'==1000
}
***** **
gen FirstYrSess=.
gen LastYrSess=.
replace FirstYrSess=1787+congress*2
replace LastYrSess=FirstYrSess+2
****Gen Chamber****
gen Chamber="S"
replace Chamber="H" if seat==3
***Variables for members of each party and experience***
sort state_id congress Chamber
by state_id congress: gen members=_N
by state_id congress Chamber: gen members_S=_N if Chamber=="S"
by state_id congress Chamber: gen members_H=_N if Chamber=="H"
*Party Headcount:
gen dem=1 if partyB==1
gen gop=1 if partyB==2
by state_id congress: egen dems=total(dem==1) 
by state_id congress: egen gops=total(gop==1)
gen pctD=dems/members
by state_id congress Chamber: egen dems_S=total(dem==1) if Chamber=="S"
by state_id congress Chamber: egen dems_H=total(dem==1) if Chamber=="H"
by state_id congress Chamber: egen gops_S=total(gop==1) if Chamber=="S"
by state_id congress Chamber: egen gops_H=total(gop==1) if Chamber=="H"
gen pctD_S=dems_S/members_S
gen pctD_H=dems_H/members_H
/*Years Experience by party and Chamber*/
gen xper=.
replace xper=FirstYrSess-firstelect_s if seat!=3
replace xper=FirstYrSess-firstelect_h if seat==3
gen rxper=xper if gop==1
gen dxper=xper if dem==1
by state_id congress: egen gopxper=total(rxper) 
by state_id congress: egen demxper=total(dxper)
by state_id congress Chamber: egen gopxper_H=total(rxper) if Chamber=="H"
by state_id congress Chamber: egen demxper_H=total(dxper) if Chamber=="H"
*Collapse to state, congress level
collapse (first) state FirstYrSess LastYrSess (mean) dems gops dems_H gops_H members members_H pctD pctD_H gopxper demxper gopxper_H demxper_H, by (state_id congress)

keep if congress>98
*relabel to prepare for merge***
rename congress Congress
rename state_id StateCode
rename state State
cd "`output'"
save ICPSR_stateyear, replace

************
************Import Stewart and Woon Data:********************
clear all
cd "`projectdir'\StewartWoon"
**House Data*****
import excel using house_data , firstrow
keep cong-Notes
keep if office==3 /*keeps members only, drops delegates*/
gen FirstYrSess=.
gen LastYrSess=.
replace FirstYrSess=1787+cong*2
replace LastYrSess=FirstYrSess+2
***Variables for members of each party and experience***
sort state_ic cong
by state_ic cong: gen members=_N
*Party Headcount:
gen dem=1 if party_txt=="D"
gen gop=1 if party_txt=="R"
by state_ic cong: egen dems=total(dem==1) 
by state_ic cong: egen gops=total(gop==1)
gen pctD=dems/members
/*Years Experience by party*/
gen xper=(ch_senior-1)*2
gen rxper=xper if gop==1
gen dxper=xper if dem==1
by state_ic cong: egen gopxper=total(rxper) 
by state_ic cong: egen demxper=total(dxper)
*Collapse to state, congress level
collapse (first) state_po FirstYrSess LastYrSess (mean) dems gops members pctD gopxper demxper, by (state_ic cong)
*relabel to prepare for merge***
rename cong Congress
rename state_ic StateCode
rename state_po State
****Gen Chamber********
gen Chamber="H"
foreach var of  varlist dems gops members gopxper demxper{
gen `var'_H=`var'
}

*****Save******
cd "`output'"
save StateYearHouseData, replace
***********
clear all
cd "`projectdir'\StewartWoon"
******************
**Senate Data*****
******************
import excel using senate_data , firstrow
keep Congress-Notes
gen FirstYrSess=.
gen LastYrSess=.
replace FirstYrSess=1787+Congress*2
replace LastYrSess=FirstYrSess+2
***Variables for members of each party and experience***
sort StateCode Congress
by StateCode Congress: gen members=_N
*Party Headcount:
gen dem=1 if Party=="D"
gen gop=1 if Party=="R"
by StateCode Congress: egen dems=total(dem==1) 
by StateCode Congress: egen gops=total(gop==1)
gen pctD=dems/members
/*Years Experience by party*/
gen xper=ChamberSeniority-1
gen rxper=xper if gop==1
gen dxper=xper if dem==1
by StateCode Congress: egen gopxper=total(rxper) 
by StateCode Congress: egen demxper=total(dxper)
*Collapse to state, congress level
collapse (first) State FirstYrSess LastYrSess (mean) dems gops members pctD gopxper demxper, by (StateCode Congress)
****Gen Chamber********
gen Chamber="S"
****Saving*********
cd "`output'"
save StateYearSenateData, replace

*****************************************
********MERGE****************
*****************************************
append using StateYearHouseData
***Full Congress Stats from Stewart and Woon***
sort StateCode Congress
collapse (first) State FirstYrSess LastYrSess (sum) dems gops members gopxper demxper dems_H gops_H members_H gopxper_H demxper_H, by (StateCode Congress)
**drop 103rd and 104th cong*****
/*Stewart and Woon data doesnt adjust seniority for midterm changes*/
keep if Congress>104
***add ICPSR****
append using ICPSR_stateyear
*****Calculate Control Metrics
replace pctD=dems/members
replace pctD_H=dems_H/members_H
**experience gap
gen xpergap_D =demxper-gopxper
gen xpergap_R =gopxper-demxper
gen xpergap_D_H =demxper_H-gopxper_H
gen xpergap_R_H =gopxper_H-demxper_H
**split into years instead of congresses****
sort StateCode Congress
expand 2
sort StateCode Congress
by StateCode Congress: gen ab=_n
gen year=FirstYrSess+ab-1
drop ab
order year
******************************
*****Majority Xper - Minority Xper***
*************************************
/*Senate and House, based on majority in state*/
gen str1 majority1=""
replace majority1="D" if pctD>=.5
replace majority1="R" if pctD<.5
gen xpergap1 = xpergap_D if majority1=="D"
replace xpergap1 = xpergap_R if majority1=="R"
/*Senate and House, based on majority in state*/
gen str1 majority2=""
replace majority2="D" if pctD>.5
replace majority2="R" if pctD<=.5
gen xpergap2 = xpergap_D if majority2=="D"
replace xpergap2 = xpergap_R if majority2=="R"
/*House, based on majority in state*/
gen str1 majority3=""
replace majority3="D" if pctD_H>.5
replace majority3="R" if pctD_H<=.5
gen xpergap3 = xpergap_D_H if majority3=="D"
replace xpergap3 = xpergap_R_H if majority3=="R"
/*House, based on majority in state*/
gen str1 majority4=""
replace majority4="D" if pctD_H>=.5
replace majority4="R" if pctD_H<.5
gen xpergap4 = xpergap_D_H if majority4=="D"
replace xpergap4 = xpergap_R_H if majority4=="R"
***Save
save `project', replace

***************************
***Party of Governor from Klarner Politics
*********************************************
clear all
cd "`projectdir'\Klarner Politics"
import excel using Partisan_Balance_For_Use2011_06_09b, firstrow
keep year state govparty_c fips
rename govparty_c GovParty
rename fips FIPS
gen GovD=0
gen GovR=0
replace GovD=1 if GovParty==1
replace GovR=1 if GovParty==0
keep if year>1984
keep if year<2013
rename state State
********************
*Merge with Congressional Data
*****************************
cd "`projectdir'"
merge m:1 FIPS using StateCrosswalk
keep if _merge==3
keep year-GovR STICPSR
rename State State_Full 
rename STICPSR StateCode
cd "`output'"
merge 1:1 StateCode year using `project'
drop _merge
******SAVING***************
cd "`output'"
save `project', replace
*******************************
***Medicaid and Medicare Data***
*******************************
clear all
cd "`projectdir'\CMS"
insheet using MEDICARE_AGGREGATE09.csv
gen program=1
save temp, replace
clear all
insheet using MEDICAID_AGGREGATE09.csv
gen program=2
append using temp
**drop unneeded data**
drop group item region_number region_name average_annual_percent_growth
rename state_name state
drop if state=="" /*drops regional and national data*/
**change codes to cover both programs uniquely
replace code=program*1000+code
drop program
***reshape**
reshape long y, i(state code) j(year)
rename y spending
reshape wide spending, i(state year) j(code)

**generate total medicare and medicaid spending by state year***
gen medicare = 0
gen medicaid = 0
label var medicare "Annual Spending on Medicare"
label var medicaid "Annual Spending on Medicaid"
foreach n in 01 02 03 04 05 06 07 09 10 11{
replace medicare=medicare+spending10`n'
replace medicaid=medicaid+spending20`n'
}
replace medicare=medicare+spending1008 /*no item 8 for medicaid*/
keep state year medicare medicaid
***Drop 1980-1984*******
keep if year>1984
****merge*******
cd "`output'"
rename state State_Full
merge 1:1 State_Full year using `project'
order FIPS StateCode State State_Full 
drop _merge
***Drop DC********
drop if FIPS==.
******SAVING***************
cd "`output'"
save `project', replace
log close
