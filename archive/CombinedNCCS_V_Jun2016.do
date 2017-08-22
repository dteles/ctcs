*************************************************
*CombinedNCCS.do
*Dan Teles October 2015
***************************************************
clear all
drop _all
capture log close
****************************************************
******Standard Preamble***************************
******************************************************
******Cluster directories*****
local projectdir="/econ/dteles/NCCSdata"
local datadir="/econ/dteles/NCCSdata/Extracts"
local output="/econ/dteles/NCCSdata/Clean"
local project="CombinedNCCS"
*****Locals: WHICH SECTIONS TO RUN?***********
local logthis="yes"
local mergeNCCS="yes"
local cleanNCCS="yes"
local hospital="yes"
local univ="yes"
local FP="yes" /*Food Pantries*/
local CF="yes" /*Community Foundations*/
local nteebystate="yes"
local statefile="yes"

***Log********
local logthis="yes"
if "`logthis'"=="yes"{
cd "`projectdir'/dofiles"
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
set more off, perm


ssc install carryforward
*********************************************
********Combine NCCS Extracts:********************
*********************************************
if "`mergeNCCS'"=="yes" {
****Create 1989-2009 temp files*This Code works for CorePC files for 1989-2009*****
	foreach num of numlist 1989/2009 {
		clear all
		cd "`datadir'"
		use CorePC`num'
		if `num'==1990 {
			keep ein fisyr name-zip5 cont dues invinc totrev solicit ass_boy-liab_eoy fundfees compens
				gen progrev=0
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
		**Edit Program Revenue Variable for consistancy in measurement across years**
			replace progrev=progrev+dues
			drop dues	
		****destring for help with merge and sort.
			destring ein fisyr , replace force
			recast long ein
		****generate a variable for which version the data came from
			gen yr_filed = `num'
		***save stemp file***
		cd "`datadir'"
		save CorePC`num'_temp, replace
	}
	clear all
	****Create 2010 temp file****
	use CorePC2010
	keep ein fisyr name-zip5 cont progrev dues invinc totrev solicit ass_boy-liab_eoy fundfees direxp rentexp compens
		**Edit Program Revenue Variable for consistancy in measurement across years**
		replace progrev=progrev+dues
		drop dues
		***Edit Fundraising Expenses for consistancy after change in 990 Form
		replace solicit=fundfees+direxp if fundfees+direxp>solicit & fundfees!=. & direxp!=.
		replace solicit=fundfees+direxp if solicit==0 | solicit==.
		****destring for help with merge and sort.
		destring ein fisyr , replace
		recast long ein
		****generate a variable for which version the data came from
		gen yr_filed = 2010
	***Save 2010 temp file***
	save CorePC2010_temp, replace
	clear all
	****Create 2011 temp file****
	use CorePC2011
	keep ein fisyr name-zip5 cont progrev invinc totrev ass_boy-liab_eoy fundfees lessdirf lessdirg rentexp compens
		***Edit Fundraising Expenses for consistancy after change in 990 Form
		gen solicit=fundfees+lessdirf+lessdirg
		****destring for help with merge and sort.
		destring ein fisyr , replace
		recast long ein
		****generate a variable for which version the data came from
		gen yr_filed = 2011
	***Save 2011 temp file***
	save CorePC2011_temp, replace
	clear all
	****Create 2012 temp file****
	use CorePC2012
	keep ein fisyr name-zip5 cont progrev invinc totrev ass_boy-liab_eoy lessdirf fundfees lessdirf lessdirg rentexp compens
		***Edit Fundraising Expenses for consistancy after change in 990 Form
		gen solicit=fundfees+lessdirf+lessdirg	
		****destring for help with merge and sort.
		destring ein fisyr , replace
		recast long ein
		****generate a variable for which version the data came from
		gen yr_filed = 2012
	***Save 2012temp file***
	save CorePC2012_temp, replace
	clear all
****Merge Temp files into a Master file*****************
	cd "`datadir'"
	use CorePC1989_temp
	foreach num of numlist 1990/2012 {
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
		count
		***Save Combined Project File**********
	cd "`output'"
	save `project', replace
}

************************************************
*********Univiersities File********************
*************************************************
if "`univ'"=="yes" {
	clear all
	cd "`output'"
	use `project'
	keep if nteecc=="B43" | nteecc=="B42" | nteecc=="B41"
	***create dummies for University, College, and 2 year/Community C0llege.
		gen UNIV=0
		gen COLL=0
		gen CC=0
		replace UNIV=1 if nteecc=="B43"
		replace COLL=1 if nteecc=="B42"
		replace CC=1 if nteecc=="B41"
	sort ein fisyr
	save NCCS_universities, replace
}
************************************************
*********Food Pantries File********************
*************************************************
if "`FP'"=="yes" {
	clear all
	cd "`output'"
	use `project'
	keep if nteecc=="K31"
	sort ein fisyr
	save NCCS_foodpantries, replace
}
************************************************
*********Community Foundations File********************
*************************************************
if "`FP'"=="yes" {
	clear all
	cd "`output'"
	use `project'
	keep if nteecc=="T31"
	sort ein fisyr
	save NCCS_foundations, replace
}
************************************************
*********NTEE by State File********************
*************************************************
if "`nteebystate'"=="yes" {

	clear all
	cd "`output'"
	use `project'
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
	****Save File****
	cd "`output'"
	save NCCS_ntee_state_year, replace	
}
************************************************
*********State File********************
*************************************************
if "`statefile'"=="yes" {
	clear all
	cd "`output'"
	use NCCS_ntee_state_year
	***Collapse to Statby Year
	sort state fisyr nteecc 
	collapse (sum) cont-compens nonprofits, by(state fisyr)
	****Save File****
	cd "`output'"
	save NCCS_state_year, replace	
}


