clear all
drop _all
capture log close
set trace off
*************************************************
di "-------------------------"
di "Dan Teles `c(current_date)'"
di "`c(current_time)'"
di "-------------------------"
**************************************************
****************************************************
******Standard Preamble***************************
******************************************************
set more off, perm
local project="IAcredit"
*****Local PC or CCS**********
local ccs="yes"
local myPC="no"
*****Locals: WHICH SECTIONS TO RUN?***********
local logthis="no"
*Section*
local clean="no"
local sumstats="no"
local training="no"
local SCM="no"
local placebo="yes"
local inf="no"
local tables="no"
local graphs="yes"
local DID="no"
local regtables="no"
*****Locals : Iteration Lists*************
local robustclass `" "CF" "'
local primaryclasses `" "CF" "CFwo" "'
local DDclasses `" "DD" "DDwo" "DDD" "DDDwo""'
local bigcatlist `" "ALL" "BIG1" "BIG2" "' /*BIG1 is NTEE cat S and T, BIG2 is cats RSTUVW*/
local spilllist `" "ALLm" "COMP1" "COMP2" "' /*ALLm, COMP1, and COMP2, are ALL, BIG1, and BIG2 without CFs*/
local sumsuffixes `""'
local trainingsuffixes `" `sumsuffixes' "np" "89" "89np" "'
local SCMsuffixes `" "np" "nz" "nst" "'
local neighborstates `" "NE" "SD" "MN" "WI" "IL" "MO" "'
**Locals: Which Iterations to Run***
local primary="yes"
local robust="yes"
local firmlevel="yes"
local bigcat="yes"
local spillover="yes"
**Locals: Other Options**
local besttrainyear=1994
***locals to determine which functional forms to run**********
local formlist =  `" "PC" "lnPC" "'
if "`robust'"=="yes" {
	local formlist = `" `formlist' "ln" "'
}
****Locals to run more in-depth (slower) optimization procedure when using the cluster*******
if "`ccs'"=="yes" {
	local scmopts /*options for more precise optimization: nested 
	                      nested not working*/
}
if "`myPC'"=="yes" {
	local scmopts /*options for faster optimization*/
}
******Cluster directories*****
if "`ccs'"=="yes"{
local projectdir="/econ/dteles/TaxCredits"
local NCCSdir="/econ/dteles/NCCSdata/Clean"
local datadir="/econ/dteles/TaxCredits/data"
local output="/econ/dteles/TaxCredits/output/current"
******Cluster installs*********
ssc install sutex
ssc install estout, replace
ssc install mat2txt
net install outtable, from("http://fmwww.bc.edu/RePEc/bocode/o/") replace
ssc install egenmore, replace
ssc install spmap, replace
ssc install corrtex
ssc install avar, replace
ssc install weakiv, replace
ssc install ivreg2, replace
ssc install xtivreg2, replace
ssc install ranktest, replace
ssc install synth, replace
ssc install matsave
ssc install labutil, replace
ssc install carryforward, replace
ssc install unique, replace
}
*****My PC Directories***********
if "`myPC'"=="yes" {
local projectdir="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\StateTaxIncentives"
local parentdir="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits"
local output="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\StateTaxIncentives\output"
local datadir="D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\StateTaxIncentives\data\"
local NCCSdir= "D:\Documents\Dropbox\Teles Disertation Research\Volunteering and NonProfits\NCCS Data\Clean\"
}

***Log********
if "`logthis'"=="yes"{
qui cd "`projectdir'/dofiles"
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
set maxvar 32767, perm
set scheme s1color, perm
*************************************************
di "-------------------------"
di "`project'"
di "Dan Teles `c(current_date)'"
di ""
di "-------------------------"
**************************************************
********CLEAN DATA****
************************************************
***Define Which iterations to run*****************
if "`primary'"=="yes" {
	local universe `" `primaryclasses' "'
}
if "`bigcat'"=="yes" {
	local universe `" `universe' `bigcatlist' "'
	local COMP `" `bigcatlist' "'
}
if "`spillover'"=="yes" {
	local universe `" `universe' `spilllist' "'
	local COMP `" `COMP' `spilllist' "'
}
if "`firmlevel'"=="yes" {
	local universe `" `universe' "firmCF" "firmALL" "'
}
***Clean****
if  "`clean'"=="yes" {
	foreach uni of local universe {
		clear all
		cd "`NCCSdir'"
		di "Creating dataset for `uni' "
		*locals for comparison groups and bigcatlists
		local comp "no"
		foreach u of local COMP {
			if "`uni'"=="`u'" {
				local comp "yes"
			}
		}
		if "`comp'"=="yes" {
			use NCCS_ntee_state_year
			di "Load ntee by state by year file"
			gen NTEE1=""
			foreach letter in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z {
				replace NTEE1="`letter'" if regexm(nteecc, "^`letter'")
			}
			gen MAJOR=""
			foreach letter in A B Q X Y Z {
				replace MAJOR="`letter'" if NTEE1=="`letter'"
			}
			replace MAJOR = "CD" if NTEE1=="C"
			replace MAJOR = "CD" if NTEE1=="D"
			foreach letter in E F G H  {
				replace MAJOR="Health" if NTEE1=="`letter'"
			}
			foreach letter in I J K L M N O P {
				replace MAJOR="Human" if NTEE1=="`letter'"
			}
			foreach letter in R S T U V W {
				replace MAJOR="Public" if NTEE1=="`letter'"
			}
			*drop CFs
			if "`uni'"=="COMP1" | "`uni'"=="COMP2" |  "`uni'"=="ALLm" {
				drop if nteecc=="T31"
			}
			if "`uni'"=="COMP1" | "`uni'"=="BIG1" {
				keep if NTEE1=="S" | NTEE1=="T"
			}
			if  "`uni'"=="COMP2" | "`uni'"=="BIG2" {
				keep if MAJOR=="Public"			
			}
			collapse (sum) cont-compens nonprofits, by(state fisyr)
		}
		else {
			if "`uni'"=="firmALL" {
				/*Load NCCS Data for firmALL File*/
				use "`NCCSdir'/CombinedNCCS.dta" 
				di "Load Big NCCS file"
			}
			else {
				/*Load Foundations NCCS file*/
				use NCCS_foundations
				di "Load Foundations file"
			}	
			summarize
			drop N-n
			***sum to state year level
			****carryforward state if it is missing
			sort ein fisyr
			bysort ein: carryforward state if state=="", replace
			bysort ein: carryforward state if state=="", replace
			gsort ein - fisyr
			by ein : carryforward state if state=="", replace 
			by ein: carryforward state if state=="", replace
			di "Checking to make sure no state identifiers are missing"
			di "Number missing:"
			count if state==""
			sort ein fisyr
			***generate count of number of foundations
			if "`uni'"!="firmALL" {
				qui gen foundations=1
			}
			if "`uni'"=="firmALL" {
				qui gen CF=0
				qui replace CF=1 if nteecc=="T31"
			}
			****drop outlier*****
			if "`uni'"=="CF"{
				drop if ein==421504843
			}
			if "`uni'"=="CF" |  "`uni'"=="CFwo" {
				******collapse to state level	
				collapse (sum) cont-compens foundations (first) nteecc, by(state fisyr)
			}
		}
		/*SPACE LEFT FOR
			COMPARISON WITH AZCREDIT FILE
		*/
		****Bring in Controls****
		qui cd "`datadir'"
		***rename state and year variables for merge
			rename state AB
			rename fisyr year
		**Merge in controls***
		di "Merging NCCS Data with Control datasets"
		merge m:1 AB year using StateLevelDemographicControls
			keep if _merge==3
			drop _merge
		merge m:1 AB year using StateLevelUnemployment
			keep if _merge==3
			drop _merge	
		merge m:1 FIPS year using CensusOfGovernments_adjusted
			keep if _merge==3
			drop _merge
		rename FIPS fips
		merge m:1 fips year using SEERpopulation
			rename fips FIPS
			keep if _merge==3
			drop _merge
		**Keep only SEER population estimate
			replace POP=pop
			drop pop totalpop
		****Bring in Price Index and Convert to Real 2012 Dollars****
		**Merge in CPI-U (1982-1984 base)***	
		merge m:1 year using cpi83_80_to_2013
			keep if _merge==3
			drop _merge
		*****inflate variables to 2012 Dollars****************
		qui sum cpi83 if year==2012
		local cpi83in2012 = r(max)
		local test = r(min)
		if `cpi83in2012'!=`test' {
			error
		}
		foreach var of varlist cont-compens {
			replace `var'=`var'*`cpi83in2012'/cpi83
		}
		****generate OverHead Variable*****
		replace rentexp=0 if rentexp==.
		replace compens=0 if compens==.
		gen overhead = rentexp + compens		
		**Create Per Capita and Log Form Measures***
		if "`uni'"=="CF" | "`uni'"=="CFwo" {
			gen num=foundations*1000000
			gen lnnum = ln(num)
			gen numPC = num /POP
			gen lnnumPC = ln(num/POP)
			sum num lnnum numPC lnnumPC
		}
		if "`comp'"=="yes" {
			sum
			gen num=nonprofits*1000000
			gen lnnum = ln(num)
			gen numPC = num /POP
			gen lnnumPC = ln(num/POP)
			sum num lnnum numPC lnnumPC
		}
		foreach var of varlist cont progrev totrev solicit overhead own_rev dir_exp {
			gen `var'PC=`var'/POP
			gen ln`var'PC=ln(`var'/POP)
			gen ln`var'=ln(`var') 
			sum `var'PC ln`var'PC ln`var'
		}
		foreach var of varlist progrev totrev solicit overhead own_rev dir_exp {
			replace ln`var'PC=ln((`var'+.01)/POP) if `var'==0
			replace ln`var'= ln(`var'+.01)
			sum `var'PC ln`var'PC
		}
		gen POP_million=POP/1000000
		gen lnPOP=ln(POP)
		gen lnINCperCAP=ln(INCperCAP)
		sum INCperCAP lnINCperCAP POP_million lnPOP
		*******save state foundations file ***********************
		cd "`output'/datasets"
		if "`uni'"=="CF" { 
			save Foundations_state, replace
		}
		if "`uni'"=="CFwo" { 
			save Foundations_state_wo, replace
		}
		if "`comp'"=="yes" {
			save IA_`uni'_state, replace
		}
		***save "raw"  and edited firm level file********
		if "`uni'"=="firmCF" {
			save Foundations_firm, replace
			drop foundations
			sort AB year
			by AB year: gen foundations = _N	
		}
		if "`uni'"=="firmCF" | "`uni'"=="firmALL"  {
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
			qui cd "`output'/datasets"
			*******save unbalanced panel with without outlier***************
			if "`uni'"=="firmCF" {
				save `project'_DDwo, replace	
				drop if ein==421504843
				save `project'_DD, replace	
			}
			if  "`uni'"=="firmALL"  {
				save `project'_DDDwo, replace	
				drop if ein==421504843
				save `project'_DDD, replace				
			}
		}			
	}
	***End loop over datasets********************
}
******End Clean DATA*********************************
***************************************
***Summary Statistics****
***************************************
/*Summary Stats*/
/*classlist is list of main iterations (CF, CF(without outlier) ALLnonprofits )
  iterate is full list of iterations including robustness checks*/
if "`primary'"=="yes" local classlist `" `primaryclasses' "'
if "`bigcat'"=="yes" {
	local classlist `" `classlist' `bigcatlist' "'
	local COMP `" `bigcatlist' "'
}
if "`spillover'"=="yes" {
	local classlist `" `classlist' `spilllist' "'
	local COMP `" `COMP' `spilllist' "'
}
*if "`individualNPs'"=="yes" {
/* Left Blank, No Org SCM for IOWA */
*}
local sumclasslist `" `classlist' "'
if "`robust'"=="yes" {
	foreach class of local robustclass {
		foreach sfx of local sumsuffixes {
			local sumclasslist = `" `sumclasslist' "`class'`sfx'" "'
		}
	}
}
**DD Options**
if "`DID'"=="yes" local sumclasslist `" `sumclasslist' `DDclasses' "'
	/*classlist2 includes "firm"*/

local reglist `" "unbal" "'
foreach year1 in 90 93 96 98 00 {
	foreach year2 in 05 07 09 12 {
		local reglist `" `reglist' "bal`year1'`year2'" "'
	}
}

*******
di "SUMSTATS for : "
di `sumclasslist' 
if "`sumstats'"=="yes" {
	foreach class of local sumclasslist {
		di "-------------------------"
		di "Summary Statistics for `class'"
		di "-------------------------"
		*local for comparison groups
		local comp "no"
		local DDclass "no"
		foreach u of local COMP {
			if "`class'"=="`u'" {
				local comp "yes"
			}
		}	
		foreach u of local DDclasses {
			if "`class'"=="`u'" {
				local DDclass "yes"
			}
		}
		local varlistBASE cont INCperCAP progrev solicit POP_million gini top1
		local varlistLOG lncont lnINCperCAP lnprogrev lnsolicit lnPOP gini top1
		local varlistPC contPC INCperCAP progrevPC solicitPC POP_million gini top1
		local varlistLNPC lncontPC lnINCperCAP lnprogrevPC lnsolicitPC lnPOP gini top1
		local varnames `" "Contributions" "Income" "Program_Revenue" "Fundraising" "Population" "Gini" "Top_1_Percent" "'
		**add num to varlist for complete state aggregate
		if "`class'"=="CF" | "`class'"=="CFwo" {
			local varlistBASE `varlistBASE' foundations
			local varlistLOG `varlistLOG' lnnum
			local varlistPC `varlistPC' numPC
			local varlistLNPC `varlistLNPC' lnnumPC			
			local varnames `" `varnames' "Foundations" "'
		}
		else if "`DDclass'"=="yes" {
			local varlistBASE `varlistBASE' 
			local varlistLOG `varlistLOG' 
			local varlistPC `varlistPC' 
			local varlistLNPC `varlistLNPC' 			
			local varnames `" `varnames' "'		
		}
		else {
			local varlistBASE `varlistBASE' nonprofits
			local varlistLOG `varlistLOG' lnnum
			local varlistPC `varlistPC' numPC
			local varlistLNPC `varlistLNPC' lnnumPC			
			local varnames `" `varnames' "Nonprofits" "'
		}		
		****begin loop over functional form*****************
		foreach fform in BASE LOG PC LNPC {
			clear all
			qui cd "`output'/datasets"
			if "`class'"=="CF"{
				use Foundations_state
			}
			if "`class'"=="CFwo"{
				use Foundations_state_wo
			}
			if "`DDclass'"=="yes"{
				use `project'_`class'
			}
			if "`comp'"=="yes" {
				use IA_`class'_state
			}
			*****reduce to 1993 to 2012**********
			keep if year>1992
			keep if year<2013
			qui cd "`output'/tempfiles"
			********summary statistics for whole country*********			
				di "Summary Statistics for US `class': `fform' variables"
				sum 
				sum `varlist`fform''
				tabstat `varlist`fform'', s(mean sd) save
				matrix C=r(StatTotal)'
				matrix coln C ="US_Mean" "US_Std_deviation"
				matrix rown C = `varnames' 
			********Export data for Summary Graph, Iowa vs. US***********		
			if "`DDclass'"!="yes" {
				preserve
				qui gen IA=0
				qui replace IA=1 if AB=="IA"
				qui gen NOT_IA=1-IA	
				collapse (mean) `varlist`fform'', by(IA NOT_IA year)
				save IA_`class'vsUS_`fform', replace
				restore
				*****Define Sample Pool**********
				di "define sample pool"
				*Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska becuase they have or had similar programs
				drop if AB=="KS" | AB=="KY" | AB=="MI" | AB=="MT" | AB=="ND" | AB=="NE" 
				*Exclude Iowa, big charitable giving credit
				drop if AB=="AZ"
				*Exclude Hawaii and Utah, missing years.
				drop if AB=="HI" | AB=="UT" 
				*Exclude Wyoming and Deleware, years with zero contributions
				drop if AB=="WY" | AB=="DE"
			}
			*******summary statistics for Iowa*********
			sum `varlist`fform'' if AB=="IA"
			tabstat `varlist`fform'' if AB=="IA", s(mean sd) save
			matrix A=r(StatTotal)'
			matrix coln A ="IA_Mean" "IA_Std_deviation"
			matrix rown A = `varnames'
			matrix list A
			*******summary statistics for sample pool or Controls*********
			if "`DDclass'"=="yes" {
				di "Summary Statistics for Control Group `class': `fform' variables"
				local Bcoln `" "Control_Mean" "Control_SD" "'
			}
			else {
				di "Summary Statistics for DONOR STATES `class': `fform' variables"
				local Bcoln `" "Pool_Mean" "Pool_Std_deviation" "'
			}			
				sum `varlist`fform''  if AB!="IA"
				tabstat `varlist`fform''  if AB!="IA", s(mean sd) save
				matrix B=r(StatTotal)'
				matrix coln B = `Bcoln'
				matrix rown B = `varnames' 
			********Collapse data for Summary Graph, Iowa vs. US vs. Sample Pool***********		
			if "`DDclass'"!="yes"{
				drop if AB=="IA"
				gen POOL=1
				collapse (mean) `varlist`fform'' POOL, by(year)
				append using IA_`class'vsUS_`fform'
				save IA_`class'vsUS_`fform', replace
			}
			********Export Summary Statisitcs*******
			matrix IA_sumstats_`class'_`fform'= [A , B , C ]
			matrix list IA_sumstats_`class'_`fform'
			matsave IA_sumstats_`class'_`fform', saving replace
			clear all
			use IA_sumstats_`class'_`fform'
			export excel using "`output'/tables/IA_SUMSTATS.xls", firstrow(variables) sheet("`class'_`fform'") sheetreplace
			matrix drop _all
		}	
		******end loop over functional form***
	}
	****End Loop over sumclasslist
}
***************************************
***Synthetic Control Analysis****
***************************************
*Define locals to determine whether to run program iteratively for robustness check without population variables ***
***Define which classes get full slate of robustness checks***
local suffixlist ""
if "`robust'"=="yes"  {
	foreach class of local robustclass {
		foreach sfx of local trainingsuffixes {
			local trainorders  `" `trainorders' "`class'`sfx'" "'
		}
	}
}
local iterate `" `classlist' `trainorders' "'
di "ADDITIONAL ITERATIONS ADDED FOR ROBUSTNESS"
di "ITERATIONS DEFINED:"
di `iterate'
**************************************
******BEGIN TRAINING LOOP***************
**************************************
if "`SCM'"=="yes" & "`training'"=="yes" {
	*****loop over each type of organization
	foreach pass of local iterate {
		di ""
		di "--------------------------------------------------------"
		di "Begin Training Sections for `pass':"
		***define org and years****
		foreach c of local classlist {
			if "`pass'"=="`c'" {
				local class = "`c'"
				local sfx = ""
				di "Baseline"
			}
			if "`pass'"!="`c'" {
				foreach s of local trainingsuffixes {
					if "`pass'"=="`c'`s'" {
						local class="`c'"
						local sfx="`s'"
						di "`class' Robustness Check: `sfx'"
					}	
				}					
			}
		}
		*local for comparison groups
		local comp "no"
		foreach u of local COMP {
			if "`class'"=="`u'" {
				local comp "yes"
			}
		}		
		if "`sfx'"=="89" local year1 = 1989
		else local year1 = 1990
		local lastyear=1998	
		local doextra "no"
		foreach c of local robustclass {
			if "`class'"=="`c'" local doextra "yes"
		}		
		if "`doextra'"=="yes" & "`robust'"=="yes" {
			local calibyears 1993(1)1995
			di "Calibration using treatment years:"
			foreach yr of numlist `calibyears' {
				di "`yr'"
			}	
		}
		else {
			local calibyears `besttrainyear'
			di "Calibration using treatmentyears: `calibyears'"
		}
		***loop over training treatyear options
		foreach treatyear of numlist `calibyears' {
			local lastpreyear = `treatyear'-1
			foreach n of numlist 2/10 {
				local year`n' = `year1'+`n'-1
			}
			****loop over each functional form*******
			foreach fform of local formlist {	
				di "---------------------------------"
				di "Training Section for `pass' `fform' "
				*define locals for variables of interest*******
				if "`fform'"=="PC"	{
					foreach var in cont progrev totrev solicit num {
						local `var' `var'PC
					}
					local INCperCAP INCperCAP
				}
				if "`fform'"=="ln"	{
					foreach var in cont progrev totrev solicit num INCperCAP{
						local `var' ln`var'
					}				
				}					
				if "`fform'"=="lnPC"	{
					foreach var in cont progrev totrev solicit num {
						local `var' ln`var'PC
					}
					local INCperCAP lnINCperCAP					
				}
				local predvarlist `cont' `progrev' `totrev' `solicit' `num' `INCperCAP' gini top1
				***clear out predvars****
				foreach yr of numlist 1/10 {
					foreach predvar of local predvarlist  {
						local `predvar'`n' ""
					}
				}
				foreach yr of numlist `year1'/`lastpreyear' {
					local n = `yr'-`year1'+1
						foreach predvar of local predvarlist  {
						local `predvar'`n' `predvar'(`yr')
					}
				}
				foreach predvar of local predvarlist {
					local `predvar'L `predvar'(`lastpreyear')
				}
				if "`sfx'"=="np" {
					/*populaiton variable always in log form*/
					local pop = ""
					local pop1 = ""
					local popL = ""
				}
				else {
					/*populaiton variable always in log form*/
					local pop lnPOP
					local pop1 lnPOP(`year1')
					local popL lnPOP(`lastpreyear')
				}
				***define locals for cont predictor variables ************************
				local lagpredictors ``cont'1' ``cont'2'  ``cont'3'  ``cont'4'  ``cont'5'  ``cont'6' 
				local otherpredictors `INCperCAP' `pop' `progrev' `solicit' gini top1 
				local otherpredictors2 `otherpredictors'  ``INCperCAP'1' `pop1' ``progrev'1' ``solicit'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L' ``solicit'L' `giniL' `top1L' 
				local X1 `lagpredictors'
				local X2 `cont' `otherpredictors'
				local X3 ``cont'1' ``cont'L' `cont' `otherpredictors2'
				local X4 `lagpredictors' `otherpredictors'
				local X5 `lagpredictors' `otherpredictors2'
				local X6 `otherpredictors'
				local X7 `otherpredictors2'
				local X8 `cont' `otherpredictors2'
				local X9 ``cont'1' ``cont'L' `cont' `otherpredictors'
				local X10 ``cont'1' ``cont'L' `cont' ``progrev'1' ``progrev'L' `progrev' ``solicit'1' ``solicit'L' `solicit'
				***define locals for solicit predictor variables
				local lagpredictors_fund ``solicit'1' ``solicit'2'  ``solicit'3'  ``solicit'4'  ``solicit'5'  ``solicit'6' 
				local otherpredictors_fund `INCperCAP' `pop' `progrev'  gini top1
				local otherpredictors2_fund `otherpredictors' ``INCperCAP'1' `pop1' ``progrev'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L' `giniL' `top1L' 
				local Y1 `lagpredictors_fund'
				local Y2 `solicit' `otherpredictors_fund'
				local Y3 ``solicit'1' ``solicit'L' `solicit' `otherpredictors2_fund'
				local Y4 `lagpredictors_fund' `otherpredictors_fund'
				local Y5 `lagpredictors_fund' `otherpredictors2_fund'
				local Y6 `otherpredictors_fund'
				local Y7 `otherpredictors2_fund'
				local Y8 `solicit' `otherpredictors2_fund'
				local Y9 ``solicit'1' ``solicit'L' `solicit' `otherpredictors_fund'
				local Y10 ``solicit'1' ``solicit'L' `solicit' ``progrev'1' ``progrev'L' `progrev' 
				***define locals for SCM predictor variables for NUM
				local number="`num'"
				local lagpredictors_num ``num'1' ``num'2'  ``num'3'  ``num'4'  ``num'5'  ``num'6' 
				local Z1 `lagpredictors_num'
				local Z2 `num' `otherpredictors'
				local Z3 ``num'1' ``num'L' `num' `otherpredictors2'
				local Z4 `lagpredictors_num' `otherpredictors'
				local Z5 `lagpredictors_num' `otherpredictors2'
				local Z6 `otherpredictors'
				local Z7 `otherpredictors2'
				local Z8 `num' `otherpredictors2'
				local Z9 ``num'1' ``num'L' `num' `otherpredictors'
				local Z10 ``num'1' ``num'L' `num' ``solicit'1' ``solicit'L' `solicit' ``progrev'1' ``progrev'L' `progrev' 
				****display output*********
				di "`fform' metrics are: `cont' `solicit' `num'"
				di "Pretreatment Period runs `year1' to `lastpreyear'.  Posttreatment Period runs `treatyear' to `lastyear'"
				di "--------------------------------------"
				*****perepare data************************
				clear all
				qui cd "`output'/datasets"
				***For Baseline: load SCMtrainingfile without outlier*******
				if "`class'"=="CF" {
					di "load Foundations_state"
					use Foundations_state
				}
				****Robustness: load SCMtraining file with outlier***
				if "`class'"=="CFwo" {
					di "load Foundations_state_wo'"
					use Foundations_state_wo
				}
				****Comparison: Load comparison group file******
				if "`comp'"=="yes" {
					use IA_`class'_state
				}
				cd "`output'/tempfiles"
				keep if year>1988
				if `year1'==1990 {
					drop if year==1989
				}	
				keep if year<1999
				* remove states with missing years
				di "Removing observations with missing data"
				foreach var of varlist INCperCAP POP progrevPC solicitPC gini top1 contPC numPC lncont lnprogrev lnsolicit {
					drop if `var'==.
				}
				foreach var of varlist INCperCAP POP contPC lncont numPC {
					drop if `var'==0
				}
				sort AB year
				by AB: gen N=_N
				if `year1'==1989 {
					keep if N==10
				}
				if `year1'==1990 {
					keep if N==9
				}
				*generate local for Org-by-State Observations***
				encode AB, gen(stco)
				labmask stco, values(AB)
				qui sum stco
				local Numstates=r(max)
				di "------"
				di "There are `Numstates'  observations in the `pass' to `treatyear' training group"
				di "------"
				forvalues j = 1/10 {
					***begin quietly running iterative SCM	
					di "Predvars: (list `j')"
					di "`X`j''"
					di "`Y`j''"
					di "`Z`j''"
					***define matrix names to save RMSPE and FIT Index*****
					tempname resmat`j'_`cont'
					tempname resmat`j'_`solicit'
					tempname resmat`j'_`num'			
					tempname fitmat`j'_`cont'
					tempname fitmat`j'_`solicit'
					tempname fitmat`j'_`num'	
					tempname fit2mat`j'_`cont'
					tempname fit2mat`j'_`solicit'
					tempname fit2mat`j'_`num'	
					***RUN SCM for contPC***
					*******Begin loop for each state******
					forvalues i = 1/`Numstates' {
						quietly { 
							*define time series set
							tsset stco year
							foreach outcome in `cont' `solicit' `num' {
								**Define Predvars****
								if "`outcome'" == "`cont'" {
									local predictors   `X`j''
								}
								if "`outcome'" == "`solicit'" {
									local predictors  `Y`j''
								}
								if "`outcome'" == "`num'" {
									local predictors `Z`j''
								}						
								*synthetic control command:
								noi capture synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') `scmopts'
								if _rc !=0{ //If error then run without nested option
									noi di "The error message for outcome `outcome', predvarslist `j',  control unit `i' is " _rc
									noi synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') 
								}	
								
								***save matrix of RMSPEs
								matrix DIFF=e(Y_treated)-e(Y_synthetic)
								matrix TREAT = e(Y_treated)
								matrix SYNTH = e(Y_synthetic)
								matrix BASE=.1*e(Y_treated)									
								matrix SSEM = DIFF' * DIFF
								scalar SSE = SSEM[1,1]	
								local yrspost = `lastyear'-`treatyear'+1
								scalar postRMSE = sqrt(SSE/`yrspost')					
								matrix `resmat`j'_`outcome'' = [nullmat(`resmat`j'_`outcome'') \ postRMSE]	
								***back out not-logged in if in log form, logged if not in log form
								if "`fform'"=="lnPC" | "`fform'"=="ln" {
									matrix DIFF_ALT=J(`yrspost',1,0)
									matrix BASE_ALT=J(`yrspost',1,0)
									forvalues n = 1/`yrspost' {
										 matrix DIFF_ALT[`n',1]= exp(TREAT[`n',1])-exp(SYNTH[`n',1])
										 matrix BASE_ALT[`n',1]= exp(TREAT[`n',1])*.1
									}
								}
								if "`fform'"=="PC" {
									matrix DIFF_ALT=J(`yrspost',1,0)
									matrix BASE_ALT=J(`yrspost',1,0)
									forvalues n = 1/`yrspost' {
										 matrix DIFF_ALT[`n',1]= ln(TREAT[`n',1]+.0001)-ln(SYNTH[`n',1]+.0001)
										 matrix BASE_ALT[`n',1]= ln(TREAT[`n',1]+.001)*.1
									}						
								}
								matrix SSEM_ALT =DIFF_ALT' * DIFF_ALT
								matrix BASE2 = BASE' * BASE
								matrix BASE2_ALT = BASE_ALT' * BASE_ALT
								matrix CHECK = [TREAT, SYNTH, DIFF, BASE, DIFF_ALT, BASE_ALT]
								scalar SSE_ALT = SSEM_ALT[1,1]
								scalar SSE_BASE = BASE2[1,1]
								scalar SSE_BASE_ALT = BASE2_ALT[1,1]
								scalar postRMSE_alt=sqrt(SSE_ALT/`yrspost')	
								scalar fitindex=.1*postRMSE/(sqrt(SSE_BASE/`yrspost'))									
								scalar fitindex_alt=.1*postRMSE_alt/(sqrt(SSE_BASE_ALT/6))
								matrix `fitmat`j'_`outcome'' = [nullmat(`fitmat`j'_`outcome'') \ fitindex]	
								matrix `fit2mat`j'_`outcome'' = [nullmat(`fit2mat`j'_`outcome'') \ fitindex_alt]	
								matrix drop DIFF_ALT BASE_ALT SSEM_ALT BASE2 BASE2_ALT CHECK 
								scalar drop SSE_ALT SSE_BASE SSE_BASE_ALT postRMSE_alt fitindex fitindex_alt
								matrix drop DIFF TREAT SYNTH BASE SSEM
								scalar drop postRMSE SSE
							}
							****end loop over outcomes
						}				
						****end quietly							
					}	
					*****end loop for each state
					****generate names for placebos ONLY THE FIRST TIME THROUGH***	
					****generate names for placebos***	
					if `j'==1 {
						local names ""
						forvalues i = 1/`Numstates' {
							local names `" `names' "pl`i'" "'
						}
					}
					***end name generation loop
					****create matrix of RMSPEs
					foreach outcome in `cont' `solicit' `num' {
						matrix RMSPES_`outcome'_`j' = `resmat`j'_`outcome''
						mat colnames RMSPES_`outcome'_`j' = "group`j'"
						matrix FITINDEX_`outcome'_`j' = `fitmat`j'_`outcome''
						mat colnames FITINDEX_`outcome'_`j' = "group`j'"
						matrix FITINDEXA_`outcome'_`j' = `fit2mat`j'_`outcome''
						mat colnames FITINDEXA_`outcome'_`j' = "group`j'"						
					}
					di "end loop `j' for `pass' `fform' training"
					di "--"
				}
				******end loop of 10 sets of predictor variables*********
				*****Export file of RMSPES from each loop*******
				quietly{
					local tyr=`treatyear'-1900
					foreach outcome in `cont' `solicit' `num' {
						matrix IA_`pass'_RMSPES`tyr'_`outcome'=[RMSPES_`outcome'_1, RMSPES_`outcome'_2, RMSPES_`outcome'_3, RMSPES_`outcome'_4, RMSPES_`outcome'_5, RMSPES_`outcome'_6, RMSPES_`outcome'_7, RMSPES_`outcome'_8, RMSPES_`outcome'_9, RMSPES_`outcome'_10]
						mat rownames IA_`pass'_RMSPES`tyr'_`outcome'= `names' 
						matsave IA_`pass'_RMSPES`tyr'_`outcome', saving replace
						matrix IA_`pass'_INDEX`tyr'_`outcome'=[FITINDEX_`outcome'_1, FITINDEX_`outcome'_2, FITINDEX_`outcome'_3, FITINDEX_`outcome'_4, FITINDEX_`outcome'_5, FITINDEX_`outcome'_6, FITINDEX_`outcome'_7, FITINDEX_`outcome'_8, FITINDEX_`outcome'_9, FITINDEX_`outcome'_10]
						mat rownames IA_`pass'_INDEX`tyr'_`outcome'= `names' 
						matsave IA_`pass'_INDEX`tyr'_`outcome', saving replace
						matrix IA_`pass'_INDEXA`tyr'_`outcome'=[FITINDEXA_`outcome'_1, FITINDEXA_`outcome'_2, FITINDEXA_`outcome'_3, FITINDEXA_`outcome'_4, FITINDEXA_`outcome'_5, FITINDEXA_`outcome'_6, FITINDEXA_`outcome'_7, FITINDEXA_`outcome'_8, FITINDEXA_`outcome'_9, FITINDEXA_`outcome'_10]
						mat rownames IA_`pass'_INDEXA`tyr'_`outcome'= `names' 
						matsave IA_`pass'_INDEXA`tyr'_`outcome', saving replace
					}
				}
				di " RMSPE and FIT INDEX Matrices for `pass' `fform' to `treatyear' saved"
				di "------------------------------------------------------"
				matrix drop _all
			}
			************end loop over fform
		}	
		****end training treatyear iteration loop
	}
	************end class iteration loop
}
***end training/calibrate predictor vars loop
************************************
if "`robust'"=="yes"  {
	local classlist `" `classlist' `neighborstates' "'
	foreach class of local robustclass {
		***Additional Robustness checks that don't require their own training group*****
		foreach sfx of local SCMsuffixes {
			local SCMorders  `" `SCMorders' "`class'`sfx'" "'
			local suffixlist `" `suffixlist' "`sfx'" "'
		}
		***Additional Robustness tests using alternative training years**************	
		foreach n of numlist 1(1)10 {
			local SCMorders `" `SCMorders' "`class'p`n'" "'
			local suffixlist `" `suffixlist' "p`n'" "'
		}
	}
}
local iterate `" `classlist' `SCMorders'  "'
di `iterate'
**************************************************	
*******SCM FOR REALS******************************
**************************************************
if "`SCM'"=="yes" {
	di "------------------"
	di "-------------"
	di "Current Version runs the following iterations"
	di `iterate'
	di "------------------"
	******************************************"
	foreach pass of local iterate {
		di ""
		di ""
		di "------------------------------------------"
		di "This is the SCM section for iteration: `pass'"
		***define class and years****
		foreach c of local classlist {
			if "`pass'"=="`c'" {
				local class = "`c'"
				local sfx = ""
				di "Baseline"
			}
			if "`pass'"!="`c'" {
				foreach s of local suffixlist {
					if "`pass'"=="`c'`s'" {
						local class="`c'"
						local sfx="`s'"
						di "Robustness Check `sfx'"
					}	
				}					
			}
			if "`sfx'"=="89"	local year1 = 1989
			else local year1 = 1990
		}
		*local for comparison groups
		local comp "no"
		foreach c of local COMP {
			if "`class'"=="`c'" {
				local comp "yes"
			}
		}
		local treatstate IA
		foreach state of local neighborstates {
			if "`class'"=="`state'" {
				local treatstate `state'
			}	
		}	
		local treatyear = 2003
		local lastpreyear = `treatyear'-1
		local lastyear=2012
		local year1 = `treatyear'-10
		di "Pass: `pass' , Class: `class'"
		di "Year 1 = `year1', Treatment Year = `treatyear'"
		foreach n of numlist 2/10 {
			local year`n' = `year1'+`n'-1
		}
		local doextra "no"
		foreach c of local robustclass {
			if "`pass'"=="`c'" local doextra "yes"
		}
		****loop over each functional form*******
		foreach fform of local formlist {
			di "-----------"
			di "Begin SCM for  `pass' `fform' "
			di "Year 1 = `year1', Treatment Year = `treatyear'"
			di "-------------------------------"
			***define locals for variables of interest*******
			if "`fform'"=="PC"	{
				foreach var in cont progrev totrev solicit num {
					local `var' `var'PC
				}
				local INCperCAP INCperCAP
			}
			if "`fform'"=="ln"	{
				foreach var in cont progrev totrev solicit num INCperCAP{
					local `var' ln`var'
				}				
			}					
			if "`fform'"=="lnPC"	{
				foreach var in cont progrev totrev solicit num {
					local `var' ln`var'PC
				}
				local INCperCAP lnINCperCAP					
			}
			local predvarlist `cont' `progrev' `totrev' `solicit' `num' `INCperCAP' gini top1
			***clear out predvars****
			foreach yr of numlist 1/10 {
				foreach predvar of local predvarlist  {
					local `predvar'`n' ""
				}
			}
			*create predvars
			foreach yr of numlist `year1'/`lastpreyear' {
				local n = `yr'-`year1'+1
				foreach predvar of local predvarlist  {
					local `predvar'`n' `predvar'(`yr')
				}
			}
			foreach predvar of local predvarlist {
				local `predvar'L `predvar'(`lastpreyear')
			}
			if "`sfx'"=="np" | "`sfx'"=="89np"{
				/*populaiton variable always in log form*/
				local pop = ""
				local pop1 = ""
				local popL = ""
			}
			else {
				/*populaiton variable always in log form*/
				local pop lnPOP
				local pop1 lnPOP(`year1')
				local popL lnPOP(`lastpreyear')
			}
			***define locals for cont predictor variables ************************
			local lagpredictors ``cont'1' ``cont'2'  ``cont'3'  ``cont'4'  ``cont'5'  ``cont'6'  ``cont'7' ``cont'7' ``cont'9' ``cont'10'
			local otherpredictors `INCperCAP' `pop'  `progrev' `solicit' gini top1 
			local otherpredictors2 `otherpredictors'  ``INCperCAP'1' `pop1' ``progrev'1' ``solicit'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L' ``solicit'L' `giniL' `top1L' 
			local X1 `lagpredictors'
			local X2 `cont' `otherpredictors'
			local X3 ``cont'1' ``cont'L' `cont' `otherpredictors2'
			local X4 `lagpredictors' `otherpredictors'
			local X5 `lagpredictors' `otherpredictors2'
			local X6 `otherpredictors'
			local X7 `otherpredictors2'
			local X8 `cont' `otherpredictors2'
			local X9 ``cont'1' ``cont'L' `cont' `otherpredictors'
			local X10 ``cont'1' ``cont'L' `cont' ``progrev'1' ``progrev'L' `progrev' ``solicit'1' ``solicit'L' `solicit'
			***define locals for solicit predictor variables
			local lagpredictors_fund ``solicit'1' ``solicit'2'  ``solicit'3'  ``solicit'4'  ``solicit'5'  ``solicit'6'  ``solicit'7'  ``solicit'8'  ``solicit'9'  ``solicit'10'  
			local otherpredictors_fund `INCperCAP' `pop'  `progrev' gini top1
			local otherpredictors2_fund `otherpredictors'  ``INCperCAP'1' `pop1' ``progrev'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L' `giniL' `top1L' 
			local Y1 `lagpredictors_fund'
			local Y2 `solicit' `otherpredictors_fund'
			local Y3 ``solicit'1' ``solicit'L' `solicit' `otherpredictors2_fund'
			local Y4 `lagpredictors_fund' `otherpredictors_fund'
			local Y5 `lagpredictors_fund' `otherpredictors2_fund'
			local Y6 `otherpredictors_fund'
			local Y7 `otherpredictors2_fund'
			local Y8 `solicit' `otherpredictors2_fund'
			local Y9 ``solicit'1' ``solicit'L' `solicit' `otherpredictors_fund'
			local Y10 ``solicit'1' ``solicit'L' `solicit' ``progrev'1' ``progrev'L' `progrev' 
			***define locals for SCM predictor variables for NUM
			local number="`num'"
			local lagpredictors_num ``num'1' ``num'2'  ``num'3'  ``num'4'  ``num'5'  ``num'6'  ``num'7'  ``num'8'  ``num'9'  ``num'10' 
			local Z1 `lagpredictors_num'
			local Z2 `num' `otherpredictors'
			local Z3 ``num'1' ``num'L' `num' `otherpredictors2'
			local Z4 `lagpredictors_num' `otherpredictors'
			local Z5 `lagpredictors_num' `otherpredictors2'
			local Z6 `otherpredictors'
			local Z7 `otherpredictors2'
			local Z8 `num' `otherpredictors2'
			local Z9 ``num'1' ``num'L' `num' `otherpredictors'
			local Z10 ``num'1' ``num'L' `num' ``solicit'1' ``solicit'L' `solicit' ``progrev'1' ``progrev'L' `progrev' 
			*******Determine which Set of Predictor Variables to Use*****
			if "`sfx'"=="p1" | "`sfx'"=="p2" | "`sfx'"=="p3" | "`sfx'"=="p4"  | "`sfx'"=="p5" | "`sfx'"=="p6" | "`sfx'"=="p7"  | "`sfx'"=="p8" | "`sfx'"=="p9" | "`sfx'"=="p10" {
				foreach outcome in `cont' `solicit' `num' {	
					foreach n of numlist 1(1)10 {
						if "`sfx'"=="p`n'" local keepnum_`outcome'_`pass' = `n'
					}
					di "For `pass' predictor set number `keepnum_`outcome'_`pass'' is used for `outcome'"
				}
			}
			else {
				if "`pass'"=="`class'" & "`treatstate'"!="IA" {
					local trainpass CF
				}
				else if "`pass'"=="CFnz" {
					local trainpass CF
				}
				else if "`sfx'"=="nst" {
					local trainpass `class'
				}
				else {
					local trainpass `pass'
				}
				local trainyear =`besttrainyear'-1900
				if "`doextra'"=="yes" & "`robust'"=="yes" {
					local calibyears 93 94 95
				}
				else if "`sfx'"=="89" | "`sfx'"=="np" | "`sfx'"=="89np" {
					local calibyears 93 94 95
				}
				else local calibyears `trainyear'	
				foreach outcome in `cont' `solicit' `num' {		
					****Load RMSPES Files and determine best fit**********
					foreach tyr in `calibyears' {				
						qui cd "`output'/tempfiles"
						use IA_`trainpass'_RMSPES`tyr'_`outcome', clear
						foreach x of numlist 1/10 {
							local y=`x'-1
							qui sum group`x'
							scalar ARMSPE_`x'=r(mean)
							if `x'==1 {
								scalar bestARMSPE=ARMSPE_`x'
								scalar keeper=`x'
							}
							if ARMSPE_`x'<bestARMSPE {
								scalar bestARMSPE=ARMSPE_`x'
								scalar keeper=`x'
							}
						}
						if `tyr'==`trainyear' local keepnum_`outcome'_`pass' = keeper
						**********Export Tables Showing Goodness of fit****************
						if "`trainpass'"=="`pass'" {
							qui cd "`output'/tempfiles"
							foreach fit in INDEX INDEXA {
								use IA_`trainpass'_`fit'`tyr'_`outcome', replace
								foreach x of numlist 1/10 {
									qui sum group`x'
									scalar A`fit'_`x'=r(mean)
								}
							}
							foreach fit in RMSPE INDEX INDEXA {
								matrix IA_AV`fit'`tyr'_`pass'_`outcome' = [A`fit'_1 \  A`fit'_2 \ A`fit'_3 \ A`fit'_4 \ A`fit'_5 \ A`fit'_6 \ A`fit'_7 \ A`fit'_8 \ A`fit'_9 \ A`fit'_10]
								matrix colnames IA_AV`fit'`tyr'_`pass'_`outcome' = "AVG`fit'"
							}
							matrix IA_AVFIT_`pass'`tyr'_`outcome' = [IA_AVRMSPE`tyr'_`pass'_`outcome' , IA_AVINDEX`tyr'_`pass'_`outcome' , IA_AVINDEXA`tyr'_`pass'_`outcome']
							matsave IA_AVFIT_`pass'`tyr'_`outcome' , saving replace
							matrix drop _all
							scalar drop _all
							clear
							use IA_AVFIT_`pass'`tyr'_`outcome' 
							export excel using "`output'/tables/IA_AVRMSPES_`outcome'.xls", firstrow(variables) sheet("`pass'`tyr'") sheetreplace		
							matrix drop _all
						}
					}
					***end loop over trainyears
					di "----------------"
					di "For `pass' the best fit for `outcome' is with predictor set number `keepnum_`outcome'_`pass''"
					di "-----------------"
				}
				********End outcome var loop
			}
			*****End Loop Calculating Best Fit Predictor Variables
			*****perepare data************************
			clear all
			qui cd "`output'/datasets"
			***Load Files******
			if "`class'"=="CF" | "`class'"=="`treatstate'" {
				di "load Foundations_state"
				use Foundations_state
			}
			****Robustness: load SCMtraining file with outlier***
			if "`class'"=="CFwo" {
				di "load Foundations_state_wo'"
				use Foundations_state_wo
			}
			****Comparison: Load all Nonprofits file******
			if "`comp'"=="yes" {
				di "load IA_`class'_state"
				use IA_`class'_state
			}		
			di "limit to sample pool"
			sum
			keep if year>=`year1'
			keep if year<2013
			*Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska becuase they have or had similar programs
			if "`treatstate'"=="NE" {
				drop if AB=="KS" | AB=="KY" | AB=="MI" | AB=="MT" | AB=="ND" 		
			}
			else {
				drop if AB=="KS" | AB=="KY" | AB=="MI" | AB=="MT" | AB=="ND" | AB=="NE" 
			}	
			*Exclude Arizona, big charitable giving credit
			drop if AB=="AZ"
			*Exclude Hawaii and Utah, missing years.
			if "`class'"!="ALL" {
				drop if AB=="HI" | AB=="UT" 
			}
			*Exclude Wyoming and Deleware, years with zero contributions
			if "`sfx'" == "nz"  |  "`fform'"=="lnPC" | "`fform'"=="ln" {
				di "drop states with zeros"
				drop if AB=="WY" | AB=="DE"
			}
			****Robustness using only neighboring states***********
			if "`sfx'"=="nst" {
				gen keepstate=0
				replace keepstate=1 if AB=="IA"
				foreach state of local neighborstates {
					replace keepstate=1 if AB=="`state'"
				}
				keep if keepstate==1
				drop keepstate
			}
			*generate running code variable (FIPS has missing variables)
			encode AB if AB!="`treatstate'", gen(stco)
			replace stco=99 if AB=="`treatstate'"
			labmask stco, values(AB)
			qui cd "`output'/tempfiles"
			save `project'_`pass'_`fform', replace
			*generate local for number of states in sample pool
			qui sum stco if stco<99
			local num_states=r(max)
			di "----"
			di "There are `num_states' potential donors for `pass' (`fform') in the real SCM Group"	
			di "-----"
			***save stco AB crosswalk and define locals
			preserve		
			keep stco AB
			collapse (first) AB, by(stco)
			sort stco
			save `project'_`pass'_`fform'_stcocrosswalk, replace
			forvalues i = 1/ `num_states' {
				local AB`i'= AB[`i']
			}
			restore
			forvalues i = 1/ `num_states' {
				di "local AB`i' is `AB`i''"
			}
			**set option for prediction variables based on lowest prediction RMSPE
			local x = `keepnum_`cont'_`pass''
			local y = `keepnum_`solicit'_`pass''
			local z = `keepnum_`num'_`pass''
			***RUN SCM on Iowa************
			di "--------------------"
			di "Run SCM for `pass' `fform' "
			local outcomelist `cont' `solicit' `num' 
			foreach outcome of local outcomelist {
				if "`outcome'"=="`cont'" {
					local predictors "`X`x'' "
				}
				if "`outcome'"=="`solicit'" {
					local predictors " `Y`y'' "
				}
				if "`outcome'"=="`num'" {
					local predictors " `Z`z'' "
				}				
				******SCM COMMANDS******
				di "---------------------------------------------------"
				di "SCM for `pass' `outcome'"
				di "Predictors Variables are `predictors'"
				di "---------------------------------------------------"
				**define time series set
				tsset stco year
				**run SCM and save output
				capture synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
				resultsperiod(`year1'(1)`lastyear') `scmopts' keep(IA_SCM_`pass'_`outcome', replace)
				if _rc !=0{ //If error then run without nested option
					noi di "The error message for outcome `outcome', pass `pass' is " _rc
					synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
					resultsperiod(`year1'(1)`lastyear') keep(IA_SCM_`pass'_`outcome', replace)
				}				
				**create matrices
				matrix IA_`pass'_DIFF_`outcome'=e(Y_treated)-e(Y_synthetic)
				di "IA_`pass'_DIFF_`outcome' created"
				matrix IA_`pass'_V_`outcome' = vecdiag(e(V_matrix))'
				di "IA_`pass'_V_`outcome' created"
				matrix IA_`pass'_W_`outcome'=e(W_weights)
				local rownum = rowsof(IA_`pass'_W_`outcome') //number of potential control units
				local control_units_rowname: rown IA_`pass'_W_`outcome' // save name of potential control units in local control_units_rowname
				matrix colnames IA_`pass'_W_`outcome'="stco" "weight"
				di "IA_`pass'_W_`outcome' created"					
				matrix balance = e(X_balance)
				**save matrices
				matsave IA_`pass'_DIFF_`outcome', saving replace
				matrix list IA_`pass'_V_`outcome'
				matsave IA_`pass'_V_`outcome', saving replace
				matsave IA_`pass'_W_`outcome', saving replace				
				*******************************
				****Leave 1 Out Tests**********
				*******************************
				if "`robust'"=="yes"  & "`doextra'"=="yes" {
					matrix donors=IA_`pass'_W_`outcome' /* matrix name too long for variable names*/
					svmat donors
					count if !missing(donors2)
					local size_donor_pool = r(N)
					count if donors2>0 & !missing(donors2)
					local donorcount = r(N)
					levelsof donors1 if donors2!=0, local(posi_donors)
					tempname donorlist
					foreach l of local posi_donors {
						di "--------------"
						di "robustness test for `pass' `outcome' dropping donor `AB`l''"
						matrix `donorlist' = [nullmat(`donorlist')\ `l'	]				
						preserve
						drop if stco ==`l'
						save `project'_`pass'_no`AB`l''_`fform', replace
						qui capture synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
						resultsperiod(`year1'(1)`lastyear') `scmopts' keep(IA_SCM_`pass'_no`AB`l''_`outcome', replace)
						** If nested gives problem then run without nested and allopt option
						if _rc !=0{
							noi di "The error code for LOO run `l' is " _rc
							qui synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
							resultsperiod(`year1'(1)`lastyear') keep(IA_SCM_`pass'_no`AB`l''_`outcome', replace)
						}
						matrix IA_`pass'_no`AB`l''_DIFF_`outcome'=e(Y_treated)-e(Y_synthetic)
						matsave IA_`pass'_no`AB`l''_DIFF_`outcome', saving replace
						di "IA_`pass'_no`AB`l''_DIFF_`outcome' created"
						matrix IA_`pass'_no`AB`l''_V_`outcome' =vecdiag(e(V_matrix))'
						di "IA_`pass'_no`AB`l''_V_`outcome'  created"
						matsave IA_`pass'_no`AB`l''_V_`outcome', saving replace
						matrix IA_`pass'_no`AB`l''_W_`outcome' =e(W_weights)
						matrix colnames IA_`pass'_no`AB`l''_W_`outcome' ="stco" "weight"
						matsave IA_`pass'_no`AB`l''_W_`outcome', saving replace
						di "IA_`pass'_no`AB`l''_W_`outcome'  created"		
						restore
						di "----------------"
					}
					drop donors*  /*removed saved matrix values*/
					***create file of donor list / dropped states
					preserve
					clear
					set obs `size_donor_pool'
					gen stco = _n
					gen AB = ""
					foreach l of local posi_donors {
						qui replace AB = "`AB`l''" if stco==`l'
					}
					drop if AB==""
					save IA_`pass'_`outcome'_donorlist, replace
					restore	
				}
				***************************
				****Placebo Tests**********
				***************************
				local placeboruns 0 `posi_donors'
				**loop over baseline and leave-one-out checks***
				foreach l of local placeboruns {
					tempname resmat_`outcome'_`l'
					tempname diffmat_`outcome'_`l'
					tempname Wmat_`outcome'_`l'
					qui cd "`output'/tempfiles"
					save `project'_temp, replace
					di "--------"
					if `l'==0 {
						di "Placebo loop for `pass' `outcome' baseline"
					}
					if `l' !=0 {
						di "Placebo loop for `pass' `outcome' no `AB`l'' "
						drop if stco==`l'
						*regenerate stco to be consecutive numbers
						qui gen AB2=AB
						sort AB2 year
						encode AB2 if AB!="`treatstate'", gen(stco2)
						qui replace stco2=99 if AB=="`treatstate'"
						qui replace stco=stco2
						drop stco2 AB2
					}
					*Renumber state with highest or lowest value of outcome variable (BAD FIT)
					**these states won't be used as placebos**
					sort stco
					gen pre1 = `outcome' if year < `treatyear'
					by stco: egen pre2=mean(pre1)
					egen premax=max(pre2)
					egen premin=min(pre2)
					gen skip=1 if premin==pre2 | premax==pre2 | stco==99
					qui gen AB3=AB if skip!=1
					sort AB3 year
					encode AB3 if skip!=1, gen(stco3)
					replace stco3=stco+100 if skip==1
					replace stco3=stco if stco==99			
					qui replace stco=stco3
					labmask stco, values(AB)
					drop stco3 AB3 pre*	
					**create new crosswalk to be used in altoutput tests***
					preserve
					keep stco AB
					collapse (first) AB, by(stco)
					sort stco
					qui cd "`output'/tempfiles"
					save `project'_`pass'_`fform'_`outcome'_altcrosswalk, replace
					restore
					******Placebo Synth
					qui {
						***generate local for number of controls***
						sum stco if stco<99
						local NumCntrl = r(max)
						noi di "NumCntrl is `NumCntrl'"
						local plnames = ""
						*******Placebo loop
						forvalues i = 1/`NumCntrl' {
							*define time series
							sort stco year
							tsset stco year
							*scm command:
							capture synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`year1'(1)2012) `scmopts'
							** If nested gives problem then run without nested and allopt option
							if _rc !=0{
								noi di "The error code for placebo test `i' (pass: `pass') is " _rc
								synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`year1'(1)2012) 
							}							
							matrix `resmat_`outcome'_`l'' = [nullmat(`resmat_`outcome'_`l'') \ e(RMSPE)]
							matrix DIFF1_`outcome'=e(Y_treated)-e(Y_synthetic)
							matrix DIFF2_`outcome'=DIFF1_`outcome''	
							matrix `diffmat_`outcome'_`l'' = [nullmat(`diffmat_`outcome'_`l'')\ DIFF2_`outcome'	]				
							if `l'==0 {
								matrix IA_`pass'_PW_`outcome'`i'=e(W_weights)'
								matsave IA_`pass'_PW_`outcome'`i' , saving replace
							}	
							local plnames `"`plnames' `"pl`i'"' "'
						}
						*****end placebo loop
					}
					*di "end placebo loop"
					****end quietly
					***display list of placebo names
					*di " placebo names:"
					*di `plnames'
					***Create matrix of differences********	
					if `l'==0 {
						matrix IA_`pass'_PL_`outcome'= `diffmat_`outcome'_`l'''
						mat colnames IA_`pass'_PL_`outcome' = `plnames'
						}
					if `l' !=0 {
						matrix IA_`pass'_no`AB`l''_PL_`outcome'= `diffmat_`outcome'_`l'''
						mat colnames IA_`pass'_no`AB`l''_PL_`outcome' = `plnames'						
					}
					****save IA_`pass'_SCM_PL as a stata file for use in Placebo Graphs			
					if `l'==0 {
						di "Save All Placebos Difference Matrix `outcome'"
						matsave IA_`pass'_PL_`outcome' , saving replace
					}
					if `l' !=0 {
						di "Save All Placebos Difference Matrix `outcome'"
						matsave IA_`pass'_no`AB`l''_PL_`outcome' , saving replace
					}
					matrix drop _all
					use `project'_temp, replace
				}
				***End loop over placebo Tests*****
				***Export W and V Matrixes into Excel
				preserve
				use IA_`pass'_W_`outcome', replace
				export excel using "`output'/tables/IA_W_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
				use IA_`pass'_V_`outcome', replace
				export excel using "`output'/tables/IA_V_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
				if "`robust'"=="yes" & "`doextra'"=="yes" {
				di "..exporting leave one out robustness check tables too"				
					foreach l of local posi_donors {
						use IA_`pass'_no`AB`l''_W_`outcome', replace
						qui export excel using "`output'/tables/IA_W_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
						use IA_`pass'_no`AB`l''_V_`outcome', replace
						qui export excel using "`output'/tables/IA_V_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
					}
				}
				restore
			}
			****End loop over outcomes*********************
		}
		****End Loop over fform*********
	}
	****End Loop over iteration*********
}	
****End SCM Section*******
*****************************************************
******Statistical Inference******************************	
*****************************************************
di `iterate'
local statelist AL AK AR CA CO CT DE DC FL GA HI ID IN IL KS KY LA ME MA MI MD MN MS MO MT NE NV NH NJ NM NY NC ND OH OR OK PA RI SC SD TN TX UT VA VT VI WV WA WI WY 
if "`robust'"=="yes" {
	foreach pass of local robustclass {	
		foreach ST of local statelist {
			local drop1s `" `drop1s' "`pass'_no`ST'"  "'
			di `drop1s'
		}	
	}
}
local iteratemore  `" `iterate' `drop1s' "'
di `iteratemore'
if "`inf'"=="yes" {
	di "-------------"
	di "Statistical Inference:"
	di "Current Version runs the following iterations"
	di `iteratemore'
	di "-------------"
	******loop over each iteration*******************
	foreach pass of local iteratemore {
		********Define family, class, year1, and drop state********
		foreach i of local iterate {
			if "`pass'"=="`i'" {
				local dropstate = ""
				local family = "`i'"
			}
			foreach st of local statelist {		
				if "`pass'"=="`i'_no`st'" {
					local dropstate = "`st'"
					local family = "`i'"
				}
			}
		}
		***end loop defing dropstate, family
		foreach c of local classlist {
			if "`pass'"=="`c'" {
				local class = "`c'"
				local sfx = ""
			}
			else if "`family'"=="`c'" {
				local class = "`c'"
				local sfx = "_no`dropstate'"
			}
			else {
				foreach s of local suffixlist {
					if "`pass'"=="`c'`s'" {
						local class="`c'"
						local sfx="`s'"
					}
					else if "`family'"=="`c'`s'" {
						local class="`c'"
						local sfx="`s'_no`dropstate'"
					}
				}			
			}
		}
		*local for comparison groups
		local comp "no"
		foreach u of local COMP {
			if "`uni'"=="`u'" {
				local comp "yes"
			}
		}		
		***end loop defing class sfx
		local treatstate IA
		foreach state of local neighborstates {
			if "`class'"=="`state'" {
				local treatstate `state'
			}	
		}	
		***define years
		local treatyear = 2003
		local lastpreyear = `treatyear'-1
		local lastyear=2012
		local year1 = `treatyear'-10
		di ""
		di "-------------------"
		di "Statistical Inference for iteration :`pass'"
		if "`pass'"=="`class'" di "`class' Baseline Estimates"
		else {
			di "`class' Robustness Check"
			if "`sfx'"=="np" | "`sfx'"=="np_no`dropstate'" {
				di "No Population Predictor Variable"
			}
			if "`sfx'"=="89" | "`sfx'"=="89_no`dropstate'" {
					di "Uses 1989 Data"
			}
			if "`sfx'"=="nst" | "`sfx'"=="nst_no`dropstate'" {
				di "Limited to Neighboring States"
			}
		}
		**************************************************
		if "`dropstate'"!="" di " `dropstate' removed from sample pool"
		di "Year 1 = `year1', Treatment Year = `treatyear'"
		****Define sections to run**********
		local outcomelist contPC solicitPC lncontPC lnsolicitPC numPC lnnumPC
		if "`robust'"=="yes" {
			local outcomelist `outcomelist' lncont lnsolicit lnnum
		}
		/*default is not to run any section***/
		local runnone="yes"
		foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
			local run`outcome' ="no"
		}
		****BASELINE********
		if "`pass'"=="`family'" {
			local runcontPC="yes"
			local runsolicitPC="yes"
			local runlncontPC="yes"
			local runlnsolicitPC="yes"
			local runnumPC="yes"
			local runlnnumPC="yes"
			if "`robust'"=="yes" {
				local runlncont = "yes"
				local runlnsolicit = "yes"
				local runlnnum = "yes"
			}	
		}			
		***check to see if state is used as robustness check***
		if "`robust'"=="yes" &  "`pass'"!="`family'" {
			foreach outcome of local outcomelist {
				qui  cd "`output'/tempfiles"
				qui use IA_`family'_`outcome'_donorlist, clear
				qui count
				local tempnum = r(N)
				forvalues i = 1/ `tempnum' {
					if AB[`i']=="`dropstate'" {
						local run`outcome' = "yes"
					}
				}
			}
		}
		foreach outcome of local outcomelist {
			if "`run`outcome''"=="yes" {
				local runnone = "no"
			}
		}	
		if "`runnone'"=="yes" {
			if "`pass'"=="`family'" {
				di "ERROR  no outcomes selected"
			}
			di "`dropstate' is never a donor for `family' , no inference performed this pass"
			di "-------------------"
		}
		if "`runnone'"=="no" {
			di "Variables of Interest:"
			foreach outcome of local outcomelist {
				if "`run`outcome''"=="yes" {
					di "`outcome'"
				}				
			}
		}
		***************************************************
		********Generate DD Estimator and P Values*************
		***************************************************
		if "`runnone'"=="no" {
			local outcomelist = `""'
			foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
				if "`run`outcome''"=="yes" {
					local outcomelist  `" `outcomelist' "`outcome'" "'
				}
			}
			if "`dropstate'"=="" { 
				di "running full list of outcomes : "
				di `outcomelist'
				di "--------"
			}
			if "`dropstate'"!="" {
				di "`dropstate' was a donor for outcomes :"
				di `outcomelist'
				di "--------"
			}		
			foreach outcome of local outcomelist {
				di "-----------"
				di "Generate Estimators for `pass' `outcome'  "		
				*********************************************************
				********Generate values of Synthetic Iowa with Gov't Funding******
				/*only for aggregated Community Foundations (CF, CFwo)************/
				if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
					if "`class'"=="CF" | "`class'"=="CFwo" { 
						clear all 
						di "...generating contribution levels net of government funding"
						qui {
							qui cd "`datadir'"
							use IA_Credits_Awarded
							qui cd "`output'/tempfiles"
							merge 1:m _time using IA_SCM_`pass'_`outcome'
							drop _merge
							if "`outcome'"=="contPC" {
								gen _Y_expected = _Y_synthetic+creditsPC+grantsPC
								gen _Y_plusgrants = _Y_synthetic+grantsPC
							} 
							if "`outcome'"=="lncontPC" {
								gen _Y_expected=ln(exp(_Y_synthetic)+creditsPC+grantsPC)	
								gen _Y_plusgrants=ln(exp(_Y_synthetic)+grantsPC)	
							}
							if "`outcome'"=="lncont" {
								gen _Y_expected=ln(exp(_Y_synthetic)+(credits_adj)+(grants_adj))	
								gen _Y_plusgrants=ln(exp(_Y_synthetic)+(grants_adj))	
							}
							gen NETDIFF=_Y_treated - _Y_expected
							gen MIDDIFF = _Y_treated - _Y_plusgrants
							rename _time year
							noi save IA_NET_`pass'_`outcome', replace
							rename year _rowname
							keep _rowname NETDIFF MIDDIFF
							drop if _rowname==.		
							tostring _rowname, replace
							recast str4 _rowname
							noi save IA_`pass'_DIFF_`outcome'_NET, replace							
						}
					}
				}
				*************************************************************
				********Generate Standard DD Estimators************
				*******************************************************
				clear all
				qui  cd "`output'/tempfiles"
				***Load Diff files (difference between Treat and Synth****
				di "Load IA_`pass'_DIFF_`outcome'"			
				qui  cd "`output'/tempfiles"
				use IA_`pass'_DIFF_`outcome'
				rename c1 DIFF
				***For CF, CFwo: merge with file of Differences NET of Gov't funding******
				if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
					if "`class'"=="CF" | "`class'"=="CFwo" { 
						di "merge with IA_`pass'_DIFF_`outcome'_NET"
						qui merge 1:1 _rowname using IA_`pass'_DIFF_`outcome'_NET
						drop _merge
					}	
				}
				**merge together file of differences between observation and synth with placebos.
				di "merge with IA_`pass'_PL_`outcome'"
				qui merge 1:1 _rowname using IA_`pass'_PL_`outcome'
				drop _merge
				***destring and rename year variable
				qui destring _rowname, replace
				qui rename _rowname year
				save IA_PL_GRAPH_`pass'_`outcome', replace
				**Calculate DD and RMSPE Ratio Estimators****				
				di "...calculating DD and RMSPE ratio estimators for `treatstate' Contributions, version `pass' outcome `outcome'"
				qui sum DIFF if year<`treatyear'
				local DIFF_PRE=r(mean)				
				gen DIFF_2=DIFF*DIFF		
				qui sum DIFF_2 if year<`treatyear' 
				local RMSPE_PRE=sqrt(r(mean))	
				qui sum DIFF if year>=`treatyear'
				local DIFF_POST=r(mean)
				qui sum DIFF_2 if year>=`treatyear'
				local RMSPE_POST=sqrt(r(mean))
				local DD_`outcome'=`DIFF_POST'-`DIFF_PRE'
				di "The DD estimator for `pass' `outcome' is:"
				di `DD_`outcome''			
				local RR_`outcome'=`RMSPE_POST'/`RMSPE_PRE'
				di "The RMSPE Ratio for `pass' `outcome'  is:"
				di `RR_`outcome''					
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					if "`class'"=="CF" | "`class'"=="CFwo" {
						foreach a in NET MID {
							qui sum `a'DIFF if year>=`treatyear'
							local DIFF_POST_`a' =r(mean)
							gen `a'DIFF_2=`a'DIFF*`a'DIFF
							qui sum `a'DIFF_2 if year>=`treatyear'
							local RMSPE_POST_`a'=sqrt(r(mean))	
							local DD`a'_`outcome'=`DIFF_POST_`a''-`DIFF_PRE'
							di "The `a' DD estimator for `pass' `outcome' is:"
							di `DD`a'_`outcome''			
							local RR`a'_`outcome'=`RMSPE_POST_`a''/`RMSPE_PRE'
							di "The `a' RMSPE Ratio for `pass' `outcome'  is:"
							di `RR`a'_`outcome''
							drop `a'DIFF_2
						}	
					}
				}			
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					qui sum DIFF if year>=`treatyear' & year<2008
					local DIFF_POST2=r(mean)
					qui sum DIFF_2 if year>=`treatyear' & year<2008
					local RMSPE_POST2=sqrt(r(mean))	
					local DD_`outcome'2=`DIFF_POST2'-`DIFF_PRE'
					di "The DD estimator for `pass' `outcome' cutoff is:"
					di `DD_`outcome'2'			
					local RR_`outcome'2=`RMSPE_POST2'/`RMSPE_PRE'
					di "The RMSPE Ratio for `pass' `outcome' cutoff is:"
					di `RR_`outcome'2'	
				}			
				****calculate DD and RMSPE Ratio Estimators for Placebos*******
				/*I want to exclude DC and Utah from Cont,...maybe other stuff from others*/
				tempname DDmat	
				local DDcount=0
				tempname RRmat	
				local RRcount=0
				tempname DDmat2	
				local DDcount2=0
				tempname RRmat2	
				local RRcount2=0
				qui describe
				local NumCntrl =r(k)-3 /*DIFF, DIFF2, year*/
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					if "`class'"=="CF" | "`class'"=="CFwo" { 
						local NumCntrl=r(k)-5 /*Also subtract for NETDIFF MIDDIFF */
					}
				}		
				forvalues i = 1/`NumCntrl' {
					qui sum pl`i' if year<`treatyear'
					local DIFF_PRE=r(mean)	
					qui sum pl`i' if year>=`treatyear'
					local DIFF_POST=r(mean)
					scalar DD=`DIFF_POST'-`DIFF_PRE'
					matrix `DDmat' = nullmat(`DDmat')\DD					
					gen pl`i'_2=pl`i' * pl`i'
					qui sum pl`i'_2 if year<`treatyear'
					local RMSPE_PRE=sqrt(r(mean))
					qui sum pl`i'_2 if year>=`treatyear'
					local RMSPE_POST=sqrt(r(mean))
					scalar RR=`RMSPE_POST'/`RMSPE_PRE'
					matrix `RRmat' =nullmat(`RRmat')\RR	
					***Second set of estimators for Fund cut off 2008****
					if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
						qui sum pl`i' if year>=`treatyear' & year<2008
						local DIFF_POST2=r(mean)
						qui sum pl`i'_2 if year>=`treatyear' & year<2008
						local RMSPE_POST2=sqrt(r(mean))		
						scalar DD2=`DIFF_POST2'-`DIFF_PRE'
						matrix `DDmat2' = nullmat(`DDmat2')\DD2
						scalar RR2=`RMSPE_POST2'/`RMSPE_PRE'
						matrix `RRmat2' =nullmat(`RRmat2')\RR2
					}				
				}
				***end loop over controls
				matrix IA_`pass'_DDmat_`outcome' = `DDmat'
				matsave IA_`pass'_DDmat_`outcome'	, saving replace
				matrix IA_`pass'_RRmat_`outcome'=`RRmat'
				matsave IA_`pass'_RRmat_`outcome', saving replace	
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					matrix IA_`pass'_DDmat_`outcome'2 = `DDmat2'
					matsave IA_`pass'_DDmat_`outcome'2	, saving replace
					matrix IA_`pass'_RRmat_`outcome'2=`RRmat2'
					matsave IA_`pass'_RRmat_`outcome'2, saving replace				
				}
				******Calcualate P Values****
				foreach metric in DD RR {
					**STANDARD P VALUE********
					clear all
					use IA_`pass'_`metric'mat_`outcome'
					count if c1==.
					local m=r(N)
					count if c1>``metric'_`outcome''
					local count1=r(N)-`m'
					count if c1<``metric'_`outcome''
					local count2=r(N)
					di "There are `count1' estimators larger and  `count2' estimators smaller"
					if ``metric'_`outcome''>0 {
						local `metric'_pval_`outcome'=(`count1'+1)/(`NumCntrl'+1-`m')
					}
					if ``metric'_`outcome''<0 {
						local `metric'_pval_`outcome'=(`count2'+1)/(`NumCntrl'+1-`m')
					}									
					di "The P-value associated with the `pass' (`outcome') `metric' estimator is :"
					di ``metric'_pval_`outcome''
					***P value for NET OF CREDITS (CF ONLY)*
					if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
						if "`class'"=="CF" | "`class'"=="CFwo" {
							foreach a in NET MID {
								count if c1==.
								local m=r(N)
								count if c1>``metric'`a'_`outcome''
								local count1=r(N)-`m'
								count if c1<``metric'`a'_`outcome''
								local count2=r(N)
								di "There are `count1' estimators larger and  `count2' estimators smaller"
								if ``metric'`a'_`outcome''>0 {
									local `metric'`a'_pval_`outcome'=(`count1'+1)/(`NumCntrl'+1-`m')
								}
								if ``metric'`a'_`outcome''<0 {
									local `metric'`a'_pval_`outcome'=(`count2'+1)/(`NumCntrl'+1-`m')
								}									
								di "The P-value associated with the `pass' (`outcome') `metric' (`a') estimator is :"
								di ``metric'`a'_pval_`outcome''	
							}	
						}							
					}
					***P-VALUE FOR FUNDRAISING THROUGH 2007****
					if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
						use IA_`pass'_`metric'mat_`outcome'2, clear
						count if c1==.
						local m=r(N)
						count if c1>``metric'_`outcome'2'
						local count1=r(N)-`m'
						count if c1<``metric'_`outcome'2'
						local count2=r(N)
						di "There are `count1' estimators larger and `count2' estimators smaller"
						if ``metric'_`outcome'2'>0 {
							local `metric'_pval_`outcome'2=(`count1'+1)/(`NumCntrl'+1-`m')
						}
						if ``metric'_`outcome'2'<0 {
							local `metric'_pval_`outcome'2=(`count2'+1)/(`NumCntrl'+1-`m')
						}					
						di "The P-value associated with the `pass' (`outcome') `metric' estimator is :"
						di ``metric'_pval_`outcome'2'		
					}				
					matrix drop _all
				}
				**end loop over DD and RR
			}
			***end loop over outcome list******						
			************************************
			*****Create Estimate Tables*******
			************************************
			***Note: 2 estimators for Fundraising measures****
			foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
				matrix `outcome'MAT = [9999, 9999, 9999, 9999]
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					matrix `outcome'MATNET = [9999, 9999, 9999, 9999]
					matrix `outcome'MATMID = [9999, 9999, 9999, 9999]
				}
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					matrix `outcome'MAT2 = [9999, 9999, 9999, 9999]
				}
			}	
			foreach outcome of local outcomelist {
				matrix `outcome'MAT = [`DD_`outcome'', `DD_pval_`outcome'', `RR_`outcome'', `RR_pval_`outcome'' ]
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					if "`class'"=="CF" | "`class'"=="CFwo" { 
						matrix `outcome'MATNET = [`DDNET_`outcome'', `DDNET_pval_`outcome'', `RRNET_`outcome'', `RRNET_pval_`outcome'' ]
						matrix `outcome'MATMID = [`DDMID_`outcome'', `DDMID_pval_`outcome'', `RRMID_`outcome'', `RRMID_pval_`outcome'' ]
					}
				}
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					matrix `outcome'MAT2 = [`DD_`outcome'2', `DD_pval_`outcome'2', `RR_`outcome'2', `RR_pval_`outcome'2' ]
				}
			}
			matrix IA_estimators_`pass' = [contPCMAT \ lncontMAT \ lncontPCMAT \ contPCMATMID \ lncontMATMID \ lncontPCMATMID \ contPCMATNET \ lncontMATNET \ lncontPCMATNET \solicitPCMAT \ lnsolicitMAT \ lnsolicitPCMAT \ solicitPCMAT2 \ lnsolicitMAT2 \ lnsolicitPCMAT2 \ numPCMAT \ lnnumMAT \ lnnumPCMAT ]
			matrix rown IA_estimators_`pass' =  "ContPC" "lnCont" "lnContPC" "ContPC_mid" "lnCont_mid" "lnContPC_mid" "ContPC_net" "lnCont_net" "lnContPC_net" "SolicitPC_to12" "lnSolicit_to12" "lnSolicitPC_to12" "SolicitPC_to07" "lnSolicit_to07" "lnSolicitPC_to07" "NumPC" "lnNum" "lnNumPC"
			matrix coln IA_estimators_`pass' = "DD" "DD_pval" "Ratio" "Ratio_pval"
			matrix list IA_estimators_`pass'
			qui matsave IA_estimators_`pass', saving replace
			clear all
			use IA_estimators_`pass'
			export excel using "`output'/tables/IA_estimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
			matrix drop _all
			di "------------------------------------"
			*************************************************************************
			******INFERENCE USING ALTERNATE SYNTHETIC CONTROLS******
			*************************************************************************
			if "`pass'" =="CF" { 
				di "----"
				di "ALT OUTPUT FOR Pass:"
				di "`pass'"
				***Generate Synthetic Controls using weights from alternate output varaibles****
				di "SCM was run on:"
				di `" `outcomelist' "'
				foreach outcome of local outcomelist {
					foreach Y in cont solicit num {
						if "`outcome'"=="`Y'PC" {
							local fform = "PC"
							foreach var in cont solicit num dir_exp own_rev {
								local `var' `var'PC
							}
							local INCperCAP INCperCAP
						}
						if "`outcome'"=="ln`Y'" {
							local fform = "ln"
							foreach var in cont solicit num dir_exp own_rev {
								local `var' ln`var'
							}
							local INCperCAP lnINCperCAP
						}
						if "`outcome'"=="ln`Y'PC" {
							local fform = "lnPC"
							foreach var in cont solicit num dir_exp own_rev {
								local `var' ln`var'PC
							}
							local INCperCAP lnINCperCAP
						}
					}
					**Create File of Placebo Weights******
					di "--------------------"
					di "create IA_`pass'_PW_`outcome'"
					clear all
					qui cd "`output'/tempfiles"
					**count placebos** (altcrosswalk drops high and low)
					use `project'_`pass'_`fform'_`outcome'_altcrosswalk
					qui sum  stco if stco<99
					local numplacebos = r(max)
					**merge together placebo weights
					foreach n of numlist 1/`numplacebos' {
						use IA_`pass'_PW_`outcome'`n', replace
						qui keep if _rowname == "_W_Weight"
						qui save IA_`pass'_PW_`outcome'`n', replace
					}
					use IA_`pass'_PW_`outcome'1, replace
					foreach n of numlist 2/`numplacebos' {
						append using IA_`pass'_PW_`outcome'`n'
					}
					**generate AB based on missing columns
					drop _rowname
					qui gen AB = ""
					foreach st of local statelist {
						capture replace AB="`st'" if `st'==.
					}
					**merge in original crosswalk
					merge 1:1 AB using `project'_`pass'_`fform'_stcocrosswalk
					***local numstates local using full list of states
					qui sum  stco if stco<99
					local numstates = r(max)
					gen _varname =""
					foreach st of numlist 1/`numstates' {
						capture replace _varname = "W_`st'" if stco==`st'
					}
					drop if stco==99
					drop AB _merge stco
					xpose, varname clear
					order _varname
					rename _varname AB
					sort AB
					save IA_`pass'_PW_`outcome', replace
					di "Load `project'_`pass'_`fform'"
					use `project'_`pass'_`fform', replace
					****Define variables by fform****
					local altvars  `cont' `solicit' `num' `dir_exp' `own_rev' `INCperCAP' unemploymentrate top1 
					local synthvars  synth_`cont' synth_`solicit' synth_`num' synth_`dir_exp' synth_`own_rev' synth_`INCperCAP' synth_unemploymentrate synth_top1 
					di "Merge in W matrix IA_`pass'_W_`outcome' and IA_`pass'_PW_`outcome' "
					qui {
						merge m:1 stco using IA_`pass'_W_`outcome'
						drop _merge
						sort stco year
						rename weight W_99
						merge m:1 AB using IA_`pass'_PW_`outcome'
						drop _merge
						save IA_`pass'_ALTOUT_`outcome'_temp, replace
						noi di "...generating values of alternate outcome variables using W weights"
						foreach st of numlist 99 1/`numstates' {
							use IA_`pass'_ALTOUT_`outcome'_temp, replace
							gen treated=0
							replace treated=1 if stco==`st'
							foreach var of varlist `altvars' {
									gen synth_`var' = `var'*W_`st'
									replace synth_`var'=`var' if treated==1
							}
							collapse (sum) `synthvars', by(treated year)
							if `st'==99 {
								noi save IA_`pass'_ALTOUT_`outcome', replace
							}
							***reformat ALTOUT so that synth and treated are seperate columns*******
							foreach var of local altvars {
								rename synth_`var' `var'
							}
							keep `altvars' year treated
							reshape wide `altvars' , i(year) j(treated)
							foreach var of local altvars {
								rename `var'1 `var'_treated
								rename `var'0 `var'_synthetic
							}
							if `st'==99 {
							noi save IA_`pass'_ALTOUT_`outcome'_wide, replace
							}
							else {
								foreach var in `cont' `solicit' `num' {
									preserve
									gen pl`st'= `var'_treated-`var'_synthetic
									keep year pl`st'
									save IA_`pass'_ALT_`var'w`outcome'_PL`st', replace
									restore
								}
							}
						}
						foreach var in `cont' `solicit' `num' {
							use IA_`pass'_ALT_`var'w`outcome'_PL1, replace
							foreach st of numlist 2/`numstates' {
								merge 1:1 year using IA_`pass'_ALT_`var'w`outcome'_PL`st'
								drop _merge
							}
							noi save IA_`pass'_ALT_`var'w`outcome'_PL, replace
						}
						***end loop over placebos
					}
					*end quietly
				}	
				***end loop over outcomes*****
				***Generate Synthetic Controls using averages from control groups****
				foreach controlgroup in neighbor national {
					qui cd "`output'/tempfiles"
					di "Load `project'_`pass'_`fform'"
					use `project'_`pass'_`fform', replace
					qui {
						if "`controlgroup'"=="neighbor" {
							noi di "...generating values of alternate outcome variables average of neighbors"
							gen keepstate=0
							replace keepstate=1 if AB=="IA"
							foreach state of local neighborstates {
								replace keepstate=1 if AB=="`state'"
							}
							keep if keepstate==1
							drop keepstate
						}
						else {
							noi di "...generating values of alternate outcome variables national average"
						}
						sort stco year
						gen treated=0
						replace treated=1 if stco==99
						local altvars contPC lncontPC solicitPC lnsolicitPC INCperCAP lnINCperCAP unemploymentrate top1 
						keep `altvars' treated year
						order treated year `altvars'
						**rename vars to prevent confilict
						foreach var of varlist `altvars' {
							label var `var'
						}	
						collapse (mean) `altvars', by(treated year)
					}
					save IA_`pass'_ALTOUT_`controlgroup'avg, replace	
					***reformat ALTOUT so that synth and treated are seperate columns*******
					di "....reformatting"
					qui {
						reshape wide `altvars', i(year) j(treated)
						foreach var in `altvars' {
							rename `var'1 `var'_treated
							rename `var'0 `var'_synthetic
						}
						noi save IA_`pass'_ALTOUT_`controlgroup'avg_wide, replace
					}
					*end quietly
				}	
				****end loop over neighbor and national		
				****Inference on Alternative Outcomes****
				di "Inference on Alternative Controls"
				foreach altoutput in solicit num neighboravg nationalavg {					
					foreach fform in PC lnPC {
						if "`fform'"=="PC" {
							foreach var in cont solicit dir_exp own_rev num  {
								local `var' `var'PC
							}
							local INCperCAP INCperCAP
						}
						if "`fform'"=="ln" {
							foreach var in cont solicit dir_exp own_rev num {
								local `var' ln`var'
							}
							local INCperCAP lnINCperCAP
						}
						if "`fform'"=="lnPC" {
							foreach var in cont solicit dir_exp own_rev num {
								local `var' ln`var'PC
							}
							local INCperCAP lnINCperCAP
						}
						if "`altoutput'"=="solicit" | "`altoutput'"=="num"{
							local alt ``altoutput''
							di "using weights from `alt'"
						}
						else {
							local alt `altoutput'
							di "using `alt'"
						}
						qui  cd "`output'/tempfiles"
						use IA_`pass'_ALTOUT_`alt'_wide, replace
						rename `cont'_treated _Y_treated
						rename `cont'_synthetic _Y_synthetic
						rename year _time
						keep _Y_treated _Y_synthetic _time
						***merge in Credits data****
						qui  cd "`datadir'"
						qui merge 1:1  _time using IA_Credits_Awarded
						drop _merge
						if "`fform'"=="PC" {
							gen _Y_expected = _Y_synthetic+creditsPC+grantsPC
							gen _Y_plusgrants = _Y_synthetic+grantsPC						
						} 
						if "`fform'"=="lnPC" {
							gen _Y_expected=ln(exp(_Y_synthetic)+creditsPC+grantsPC)	
							gen _Y_plusgrants=ln(exp(_Y_synthetic)+grantsPC)	
						}
						gen DIFF = _Y_treated - _Y_synthetic
						gen NETDIFF=_Y_treated - _Y_expected
						gen MIDDIFF = _Y_treated - _Y_plusgrants
						rename _time year
						keep year DIFF NETDIFF MIDDIFF
						drop if year==.
						qui cd "`output'/tempfiles"
						if "`altoutput'"=="solicit" | "`altoutput'"=="num" {
							merge 1:1 year using IA_`pass'_ALT_`cont'w`alt'_PL
							drop _merge
						}	
						********Generate DD Estimator and P Value for DONATIONS************
						di "ALTOUT Inference: DD and Ratio for `cont' using `alt' weights"
						****Loop for DD and Ratio over GR and NET****
						foreach diff in GR MID NET {
							if "`diff'"=="GR" {
								local IA = "DIFF"
							}
							if "`diff'"=="NET" {
								local IA = "NETDIFF"
							}
							if "`diff'"=="MID" {
								local IA = "MIDDIFF"
							}							
							**Calculate DD Estimator****
							qui sum `IA' if year>=`treatyear'
							local DIFF_POST=r(mean)
							qui sum `IA' if year<`treatyear'
							local DIFF_PRE=r(mean)				
							local DD`diff'_`cont'w`alt'=`DIFF_POST'-`DIFF_PRE'
							di "The DD `diff'_`cont'w`alt' estimator is:"
							di `DD`diff'_`cont'w`alt''
							**Calculate RR Estimator
							qui gen `IA'2 = `IA'*`IA'
							qui sum `IA'2 if year>=`treatyear'
							local RMSPE_POST=sqrt(r(mean))
							qui sum `IA'2 if year<`treatyear'
							local RMSPE_PRE=sqrt(r(mean))							
							local RR`diff'_`cont'w`alt'=`RMSPE_POST'-`RMSPE_PRE'
							di "The RR `diff'_`cont'w`alt' estimator is:"
							di `RR`diff'_`cont'w`alt''		
							drop `IA'2
							******Calcualate P Values for altout w/ solicit and num weights****
							if "`altoutput'"=="solicit" | "`altoutput'"=="num" {
								****calculate DD and RMSPE Ratio Estimators for Placebos*******
								if "`diff'"=="GR" {
									tempname DDmat	
									local DDcount=0
									tempname RRmat	
									local RRcount=0
									tempname DDmat2	
									local DDcount2=0
									tempname RRmat2	
									local RRcount2=0
									qui describe
									local NumCntrl =r(k)-4
									forvalues i = 1/`NumCntrl' {
										qui sum pl`i' if year<`treatyear'
										local DIFF_PRE=r(mean)				
										qui sum pl`i' if year>=`treatyear'
										local DIFF_POST=r(mean)
										scalar DD=`DIFF_POST'-`DIFF_PRE'
										matrix `DDmat' = nullmat(`DDmat')\DD					
										gen pl`i'_2=pl`i' * pl`i'
										qui sum pl`i'_2 if year<`treatyear'
										local RMSPE_PRE=sqrt(r(mean))
										qui sum pl`i'_2 if year>=`treatyear'
										local RMSPE_POST=sqrt(r(mean))
										scalar RR=`RMSPE_POST'/`RMSPE_PRE'
										matrix `RRmat' =nullmat(`RRmat')\RR	
										
									}
									***end loop over controls
									matrix IA_`pass'_DDmat_contw`alt' = `DDmat'
									matsave IA_`pass'_DDmat_contw`alt'	, saving replace
									matrix IA_`pass'_RRmat_contw`alt'=`RRmat'
									matsave IA_`pass'_RRmat_contw`alt', saving replace	
								}
								******Calcualate P Values****
								foreach metric in DD RR {
									**ALTOUT STANDARD P VALUE********
									preserve
									clear all
									use IA_`pass'_`metric'mat_contw`alt'
									count if c1==.
									local m=r(N)
									count if c1>``metric'`diff'_`cont'w`alt''
									local count1=r(N)-`m'
									count if c1<``metric'`diff'_`cont'w`alt''
									local count2=r(N)
									di "There are `count1' estimators larger and  `count2' estimators smaller"
									if ``metric'`diff'_`cont'w`alt''>0 {
										local `metric'`diff'_`cont'w`alt'_pval=(`count1'+1)/(`NumCntrl'+1-`m')
									}
									if ``metric'`diff'_`cont'w`alt''<0 {
										local `metric'`diff'_`cont'w`alt'_pval=(`count2'+1)/(`NumCntrl'+1-`m')
									}												
									restore
								}
								***end loop over DD and RR p-val calculations
							}
							matrix drop _all
							***end loop for P-values	
						}
						****end GR vs NET loop
					}
					***end fform loop
				}
				***end loop over alternative outcomes
				foreach fform in PC lnPC {
					foreach altout in solicit num {
						if "`fform'"=="PC" {
							local cont contPC
							local alt `altout'PC
						}	
						if "`fform'"=="lnPC" {
							local cont lncontPC
							local alt ln`altout'PC
						}
/*foreach thing in DD_`cont' DDGR_`cont'w`alt' DDGR_`cont'w`alt'_pval RRGR_`cont'w`alt'_pval DDNET_`cont' DDNET_`cont'w`alt' DDNET_`cont'w`alt'_pval RRNET_`cont'w`alt'_pval {
	di "test A"
	di "`thing'"
	di "``thing''"
	di "test B"
}	*/					
						matrix ALTEST_`alt'= [`DD_`cont'', `DDGR_`cont'w`alt'' , `DDGR_`cont'w`alt'_pval', `RRGR_`cont'w`alt'_pval', `DDNET_`cont'',  `DDNET_`cont'w`alt'' , `DDNET_`cont'w`alt'_pval', `RRNET_`cont'w`alt'_pval']
						matrix rown ALTEST_`alt' = "`alt'"
					}
					***end loop over altout variables
					foreach alt in neighboravg nationalavg {
						matrix ALTEST_`alt'`fform'= [`DD_`cont'', `DDGR_`cont'w`alt'' , . , ., `DDNET_`cont'', `DDNET_`cont'w`alt'', . , .]
						matrix rown ALTEST_`alt'`fform' = "`alt'_`fform'"
					}
					***end loop over neighboravg and nationalavg
				}
				matrix IA_ALTEST_`pass' = [ALTEST_neighboravgPC \ ALTEST_nationalavgPC \ ALTEST_solicitPC \ ALTEST_numPC \ ALTEST_neighboravglnPC \ ALTEST_nationalavglnPC \ ALTEST_lnsolicitPC \ ALTEST_lnnumPC ]
				matrix coln IA_ALTEST_`pass' = "GROSS" "GROSS_ALT" "GROSS_DD_PVAL" "GROSS_RR_PVAL" "NET" "NET_ALT" "NET_DD_PVAL" "NET_RR_PVAL"
				qui  cd "`output'/tempfiles"
				qui matsave IA_ALTEST_`pass', saving replace
				clear all
				use IA_ALTEST_`pass'
				export excel using "`output'/tables/IA_ALTestimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
				matrix drop _all	
			}		
			***end altout inference*****							
		}
		******End "run none" loop"
	}
	****End Loop over Iterations*********
}
****End Organization SCM Section*******	
*********************************
*****Create SCM Graphs***********
*********************************
local ALL ""
if "`bigcat'"=="yes" {
	local ALL ALL
}	

if "`graphs'"=="yes" {
	****SUMMARY GRAPHS**********************
	****graph contributions per capita and without outlier
	clear all
	qui cd "`output'/tempfiles"
	use IA_CFwovsUS_PC
	keep if IA==1
	rename IA IA_wo
	append using IA_CFvsUS_PC
	qui cd "`output'/graphs"
	twoway (scatter contPC year if IA_wo==1, connect(l) ) (scatter contPC year if NOT_IA==1, connect(l) lpattern(dash)) ///
	(scatter contPC year if IA==1, connect(l) lpattern(longdash)) (scatter contPC year if POOL==1, connect(l) lpattern(shortdash)), ///
	xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("Per Capita Contributions") ///
	legend(label(1 "Iowa") label(2 "US, excluding Iowa") label(3 "Iowa, excluding outlier") label(4 "Donor Pool")) xlabel(1993(2)2012)
	**PC Version********
	if "`myPC'"=="yes" {	
		graph export IACF_vs_US_contPC.png, replace
	}
	****CCS Version*******
	if "`ccs'"=="yes" {
		graph export IACF_vs_US_contPC.eps, replace
	}
	****Create Basic SCM Graphs******
	foreach class in CF `ALL' {
		foreach outcome in lncontPC  contPC solicitPC lnsolicitPC numPC lnnumPC{
			****Graph of IA vs Control
			clear all
			di "------"
			di "Creating SCM graphs for `class' `outcome'"
			if "`class'"!="CF" & "`class'"!="CFwo" {	
				qui cd "`output'/tempfiles"
				use IA_SCM_`class'_`outcome'
				if "`outcome'"=="contPC" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("Per Capita Contributions") xlabel(1993(2)2012)
				}
				if "`outcome'"=="lncont" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("ln(Contributions)") xlabel(1993(2)2012)	
				}
				if "`outcome'"=="lncontPC" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("ln(Per Capita Contributions)") xlabel(1993(2)2012)	
				}
			}
			if "`class'"=="CF"  | "`class'"=="CFwo" { 
				clear all
				qui cd "`datadir'"
				use IA_Credits_Awarded
				qui cd "`output'/tempfiles"
				merge 1:m _time using IA_SCM_`class'_`outcome'
				drop _merge
				label var _Y_synthetic "Synthetic Iowa"
				label var _Y_treated "Iowa"
				if "`outcome'"=="contPC" {
					gen _Y_expected = _Y_synthetic+creditsPC
					label var _Y_expected "Expected Iowa"
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)) ///
					(scatter _Y_expected _time if _time>=1998, connect(l) lpattern(dot)) ,  ///
					xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("Per Capita Contributions") xlabel(1993(2)2012)
				}
				if "`outcome'"=="lncont" {
					gen _Y_expected=ln(exp(_Y_synthetic)+(credits_adj))
					label var _Y_expected "Expected Iowa"
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)) ///
					(scatter _Y_expected _time if _time>=1998, connect(l) lpattern(dot)) , ///
					xline(2002.5) xline(2004.5, lp(longdash))xtitle("Year") ytitle("ln(Contributions)") xlabel(1993(2)2012)	
				}
				if "`outcome'"=="lncontPC" {
					gen _Y_expected=ln(exp(_Y_synthetic)+(creditsPC))	
					label var _Y_expected "Expected Iowa"
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)) ///
					(scatter _Y_expected _time if _time>=1998, connect(l) lpattern(dot)) ,  ///
					xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("ln(Per Capita Contributions)") xlabel(1993(2)2012)	
				}
			}
			if "`outcome'"=="solicitPC" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(2002.5) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("Fundraising Expenditures") xlabel(1993(2)2012)
			}
			if "`outcome'"=="lnsolicit" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(2002.5) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("ln(Fundraising Expenditures)") xlabel(1993(2)2012)		
			}
			if "`outcome'"=="lnsolicitPC" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(2002.5) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("ln(Per Capita Fundraising Expenditure)") xlabel(1993(2)2012)
			}			
			if "`outcome'"=="numPC" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("Number of Nonprofits per 100,000") xlabel(1993(2)2012)
			}
			if "`outcome'"=="lnnum" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("ln(Number of Nonprofits)") xlabel(1993(2)2012)		
			}
			if "`outcome'"=="lnnumPC" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("ln(Number of Nonprofits per 100,000)") xlabel(1993(2)2012)
			}					
			qui cd "`output'/graphs"
			**PC Version********
			if "`myPC'"=="yes" {	
				graph export IA_`class'_`outcome'_SCM1.png, replace
			}
			****CCS Version*******
			if "`ccs'"=="yes" {
				graph export IA_`class'_`outcome'_SCM1.eps, replace
			}
			*********************
			****Placebo Graphs Option
			if "`placebo'"=="yes" {
				****Graph of DIFF vs Placebos
				**merge together file of differences between observation and synth with placebos.
				clear all
				qui cd "`output'/tempfiles"
				use IA_`class'_DIFF_`outcome'
				rename c1 IA
				label var IA "Iowa"
				if "`class'"=="CF" {
					if "`outcome'" == "lncontPC" | "`outcome'"=="contPC" {
						merge 1:1 _rowname using IA_`class'_DIFF_`outcome'_NET
						rename NETDIFF IANET	
						drop _merge	
						drop MIDDIFF
					}	
				}				
				merge 1:1 _rowname using IA_`class'_PL_`outcome'
				drop _merge
				***destring and rename year variable
				destring _rowname, replace
				rename _rowname year
				****set NumCntrl local***
				*r(k) gives the number of variables.  Subtract 1 for rowname and 1 for IA
				qui describe
				local NumCntrl=r(k)-3
				di "There are `NumCntrl' `class' controls for `outcome'"
				local call =""
				sum IA
				local top = 4*r(max)
				local bottom = 4*r(min)
				local N_tr=`NumCntrl'+1
				di "`NumCntrl' + 1 = `N_tr'"
				***define Placebo lines****
				forval j = 1/`NumCntrl' {
					local call `call' line pl`j' year if pl`j'<`top' & pl`j'>`bottom', lc(gs10) lw(vvthin) ||
				}			
				***Graph Placebos and overlay
				/*if "class"=="CF" {
					local netgraph line IANET year, lc(black) lp(dash)||
				}
				else {
					local netgraph 
				}*/
				if "`outcome'"=="contPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in Per Capita Contributions") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
				}
				if "`outcome'"=="lncont" {
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Contributions)") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
				}
				if "`outcome'"=="lncontPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Per Capita Contributions)") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
				}	
				if "`outcome'"=="solicitPC" {		
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in Per Capita Fundraising Expenditure") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
				}
				if "`outcome'"=="lnsolicit" {			
					twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) ///
					lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Fundraising Expenditure)") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
				}				
				if "`outcome'"=="lnsolicitPC" {			
					twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) ///
					lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Per Capita Fundraising Expenditure)") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
				}
				if "`class'"=="CF" | "`class'"=="ALL"  {
					if "`outcome'"=="numPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5) xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in Number of Nonprofits per 100,000") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
					}	
					if "`outcome'"=="lnnum" {
						twoway `call' || line IA year, yline(0) xline(2002.5)  xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Number of Nonprofits)") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
					}
					if "`outcome'"=="lnnumPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5)xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Number of Nonprofits per Million)") xtitle("Year") legend(order(`N_tr' "Iowa" 1 "Placebos"))
					}
				}
				*****end Log graph command******
				qui cd "`output'/graphs"
				****export Graph****
				if "`ccs'"=="yes" {
					graph export IA_`class'_`outcome'_SCM2.eps, replace
				}		
				if "`myPC'"=="yes" {
					graph export IA_`class'_`outcome'_SCM2.png, replace
				}							
			}
			*****End Placebo Graphs Option
			****LEAVE ONE OUT GRAPHS
			if "`robust'"=="yes" & "`class'"=="CF" & "`outcome'"=="lncontPC"{
				****Graph of DIFF vs Placebos
				**merge together file of differences between observation and synth with placebos.
				clear all
				qui cd "`output'/tempfiles"
				use IA_`class'_DIFF_`outcome'_NET
				rename NETDIFF IA
				drop MIDDIFF
				foreach st of local statelist {
					capture merge 1:1 _rowname using IA_`class'_no`st'_DIFF_`outcome'_NET
					if _rc==0 {
						drop _merge
						rename NETDIFF `st'
						sum `st'
					}
					else gen `st'=.
				}
				***destring and rename year variable
				destring _rowname, replace
				rename _rowname year
				****set NumCntrl local***
				*r(k) gives the number of variables.  Subtract 1 for rowname and 1 for IA
				qui describe
				local NumCntrl=r(k)-2
				local call =""
				sum IA
				local top = 4*r(max)
				local bottom = 4*r(min)
				***define Placebo lines****
				local q=0
				foreach st of local statelist {
					local call `call' line `st' year, lc(gs10) lw(vvthin) ||
					local q= `q'+1
				}				
				local q= `q'+1
				***Graph Placebos and overlay
				if "`outcome'"=="contPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in Per Capita Contributions")  xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
				}
				if "`outcome'"=="lncont" {
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' )  xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Contributions)") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
				}
				if "`outcome'"=="lncontPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' )  xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Per Capita Contributions)") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
				}	
				if "`outcome'"=="solicitPC" {		
						twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash))xline(2007.5, lp(shortdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in Per Capita Fundraising Expenditure") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
				}
				if "`outcome'"=="lnsolicit" {			
					twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash))xline(2007.5, lp(shortdash)) ///
					lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Fundraising Expenditure)") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
				}				
				if "`outcome'"=="lnsolicitPC" {			
					twoway `call' || line IA year, yline(0) xline(2002.5 `endline' ) xline(2004.5, lp(longdash)) xline(2007.5, lp(shortdash)) ///
					lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Per Capita Fundraising Expenditure)") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
				}
				if "`class'"=="ALL"{
					if "`outcome'"=="numPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5  )  xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in Number of Nonprofits per 100,000") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
					}	
					if "`outcome'"=="lnnum" {
						twoway `call' || line IA year, yline(0) xline(2002.5  )  xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Number of Nonprofits)") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
					}
					if "`outcome'"=="lnnumPC" {
						twoway `call' || line IA year, yline(0) xline(2002.5  )   xline(2004.5, lp(longdash)) ///
						lc(black) xlab(1993(2)2012) ytitle("Gap in ln(Number of Nonprofits per Million)") xtitle("Year") legend(order(`q' "Baseline Estimate" 1 "Robustness Check"))
					}
				}
				*****end Log graph command******
				qui cd "`output'/graphs"
				****export Graph****
				if "`ccs'"=="yes" {
					graph export IA_`class'_`outcome'_L1O.eps, replace
				}		
				if "`myPC'"=="yes" {
					graph export IA_`class'_`outcome'_L1O.png, replace
				}							
			}
			*****End LEAVE ONE OUT Option
		}
		***end loop over outcomes******
	}		
	***end loop over classes
	****ALTOUT GRAPHS, BASELINE ONLY*************************
	di "ALTOUT GRAPHS USING `outcome' WEIGHTS:"
	foreach outcome in contPC lncontPC solicitPC lnsolicitPC {
		foreach Y in cont solicit num {
			if "`outcome'"=="`Y'PC" {
				local fform = "PC"
				foreach var in cont solicit num dir_exp own_rev {
					local `var' `var'PC
				}
				local INCperCAP INCperCAP
			}
			if "`outcome'"=="ln`Y'" {
				local fform = "ln"
				foreach var in cont solicit num dir_exp own_rev {
					local `var' ln`var'
				}
				local INCperCAP lnINCperCAP
			}
			if "`outcome'"=="ln`Y'PC" {
				local fform = "lnPC"
				foreach var in cont solicit num dir_exp own_rev {
					local `var' ln`var'PC
				}
				local INCperCAP lnINCperCAP
			}
		}
		clear all
		local agg CF
		qui cd "`output'/tempfiles"
		use IA_`agg'_ALTOUT_`outcome'
		foreach var in `cont' `solicit' `INCperCAP' `dir_exp' `own_rev' unemploymentrate top1 {
			if "`var'"=="`solicit'" {
				local ytitle_s = "Fundraising Expenditure"
				local xline = "xline(2007.5, lp(dot))"
			}
			if "`var'"=="`cont'" {
				local ytitle_s = "Contributions"
				local xline = ""
			}
			if "`var'"=="`dir_exp'" {
				local ytitle_s = "State and Local Expenditure"
				local xline=""
			}					
			if "`var'"=="`own_rev'" {
				local ytitle_s = "State and Local Revenue"
				local xline=""
			}
			if "`var'"=="`solicit'" | "`var'"=="`cont'" | "`var'"=="`dir_exp'" | "`var'"=="`own_rev'" {
				if "`fform'"=="PC" local ytitle "`ytitle_s' Per Capita"
				if "`fform'"=="lnPC" local ytitle "ln(`ytitle_s' Per Capita)"
				if "`fform'"=="ln" local ytitle "ln(`ytitle_s')"
			}
			if "`var'"=="lnINCperCAP" {
				local ytitle = "ln(Per Capita Income)"
				local xline=""
			}
			if "`var'"=="INCperCAP" {
				local ytitle = "Per Capita Income"
				local xline=""
			}
			if "`var'"=="unemploymentrate" {
				local ytitle = "Unemployment Rate"
				local xline=""
			}
			if "`var'"=="top1" {
				local ytitle = "Top 1 Percent Income Share"
				local xline=""
			}							
			twoway (scatter synth_`var' year if treated==1, connect(l)) (scatter synth_`var' year if treated==0, connect(l) lpattern(dash)), ///
			xline(2002.5) `xline' xtitle("Year") ytitle("`ytitle'") legend(label(1 "Iowa") label(2 "Synthetic Control")) xlabel(1993(2)2012)
			cd "`output'/graphs"
			****CCS Version*******
			if "`ccs'"=="yes" {
				graph export IA_`agg'_ALTOUT_`var'_w_`outcome'.eps, replace
			}	
		}
		****End loop over altoutcomes
		
	}	
	****End loop over SCM outcomes
}

***************************************
*** Firm Level Summary Statistics****
***************************************
if "`regtables'"=="yes" {
	qui cd "`output'/datasets"
	use `project'_DD, replace	
	foreach var of varlist lncont lnsolicit lnprogrev lnINC lnPOP gini top1 {
		drop if `var'==.
	}
	foreach class in unbal bal0005 bal9708 {
		local varlistBASE cont INCperCAP progrev solicit POP_million gini top1
		local varlistLOG lncont lnINCperCAP lnprogrev lnsolicit lnPOP gini top1
		local varnames `" "Contributions" "Income" "Program_Revenue" "Fundraising" "Population" "Gini" "Top_1_Percent" "'
		****begin loop over functional form*****************
		foreach fform in BASE LOG {
			preserve
			di "-----------------------------------"
			if "`class'"=="bal0005" {
				local year1 2000
				local year2 2005
			}
			if "`class'"=="bal9708" {
				local year1 1997
				local year2 2008
			}
			if "`class'"=="unbal" {
				local year1 1993
				local year2 2012
				di "Regs using unbalanced Panel"
				local numyears = 2012-1990 +1
				di "`numyears' years"
			}
			else {
				keep if year >=`year1'
				keep if year <=`year2'
				local numyears = `year2' - `year1' +1
				di "numyears=`numyears'"
				sort ein
				by ein: gen numyears=_N
				keep if numyears==`numyears'
			}
			gen foundPC=foundations/POP_million			
			gen lnINC=ln(INCperCAP)
			gen tr=0
			replace tr=1 if AB=="IA"
			gen post=0
			replace post=1 if year>=2003
			gen tr_post=tr*post
			gen post2=0
			replace post2=1 if year>=2005
			gen tr_post2=tr*post2
			*Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska becuase they have or had similar programs
			drop if AB=="KS" | AB=="KY" | AB=="MI" | AB=="MT" | AB=="ND" | AB=="NE" 
			*Exclude Iowa, big charitable giving credit
			drop if AB=="AZ"
			count	
			local obs = r(N)
			local minobs = `numyears'*30
			sort year
			by year: count
			count if year==2003
			local `pass'_N = r(N)
			xi: reg lncont tr tr_post i.year, vce(cluster AB)
			********summary statistics for whole country*********			
			di "Summary Statistics for US `class': `fform' variables"
			sum 
			sum `varlist`fform''
			tabstat `varlist`fform'', s(mean sd) save
			matrix C=r(StatTotal)'
			matrix coln C ="US_Mean" "US_Std_deviation"
			matrix rown C = `varnames' 
			*******summary statistics for Iowa*********
			di "Summary Statistics for Iowa `class': `fform' variables"
			sum `varlist`fform'' if AB=="IA"
			tabstat `varlist`fform'' if AB=="IA", s(mean sd) save
			matrix A=r(StatTotal)'
			matrix coln A ="IA_Mean" "IA_Std_deviation"
			matrix rown A = `varnames'
			matrix list A
			*******summary statistics for sample pool or Controls*********
			di "Summary Statistics for Control Group `class': `fform' variables"
			local Bcoln `" "Control_Mean" "Control_SD" "'
			sum `varlist`fform''  if AB!="IA"
			tabstat `varlist`fform''  if AB!="IA", s(mean sd) save
			matrix B=r(StatTotal)'
			matrix coln B = `Bcoln'
			matrix rown B = `varnames' 
			********Export Summary Statisitcs*******
			matrix IA_sumstats_`class'_`fform'= [A , B , C ]
			matrix list IA_sumstats_`class'_`fform'
			qui cd "`output'/tempfiles"
			matsave IA_sumstats_`class'_`fform', saving replace
			clear all
			use IA_sumstats_`class'_`fform'
			qui cd "`output'/tables"
			export excel using "IA_FIRM_SUMSTATS.xls", firstrow(variables) sheet("`class'_`fform'") sheetreplace
			matrix drop _all
			restore
		}	
		******end loop over functional form***
	}
	****End Loop over uni
}

***************************************
***Diff-in-Diff regressions for Firm Level****
***************************************
clear all
if "`DID'"=="yes" {
	foreach pass of local reglist {	
		qui cd "`output'/datasets"
		use `project'_DD, replace
		qui cd "`output'/tempfiles"
		di "-----------------------------------"
		local controls lnINC lnPOP gini top1
		foreach var of varlist lncont lnsolicit lnprogrev `controls' {
			drop if `var'==.
			drop if `var'==0
		}
		foreach yr1 in 90 91 92 93 94 95 96 97 98 99 00 {
			foreach yr2 in 05 06 07 08 09 10 11 12 {
				if "`pass'"=="bal`yr1'`yr2'"{
					if `yr1'==00 {
						local year1 2000
					}
					else {
						local year1 19`yr1'
					}
					local year2 20`yr2'
					di "Regs using Balanced Panel from `year1' to `year2' "
					keep if year >=`year1'
					keep if year <=`year2'
					local numyears = `year2' - `year1' +1
					di "numyears=`numyears'"
					by ein: gen numyears=_N
					keep if numyears==`numyears'
				}
			}
		}
		if "`pass'"=="unbal" {
			di "Regs using unbalanced Panel"
			local numyears = 2012-1990 +1
			di "`numyears' years"
		}
		gen foundPC=foundations/POP_million			
		gen lnINC=ln(INCperCAP)
		gen tr=0
		replace tr=1 if AB=="IA"
		gen post=0
		replace post=1 if year>=2003
		gen tr_post=tr*post
		gen post2=0
		replace post2=1 if year>=2005
		gen tr_post2=tr*post2
		*Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska becuase they have or had similar programs
		drop if AB=="KS" | AB=="KY" | AB=="MI" | AB=="MT" | AB=="ND" | AB=="NE" 
		*Exclude Iowa, big charitable giving credit
		drop if AB=="AZ"
		count	
		local obs = r(N)
		local minobs = `numyears'*30
		sort year
		by year: count
		count if year==2003
		local `pass'_N = r(N)
		count if year==2003 & AB=="IA"
		local `pass'_N_IA=r(N)
		if "`pass'"=="bal9807" | "`pass'"=="bal9312"| "`pass'"=="bal0005" | "`pass'"=="unbal" {
			local moreregs = "yes"
		}
		else {
			local moreregs = "no"
		}
		if `obs'>`minobs' {
			****Clustered Base Regressions*********	
			xi: reg lncont tr_post tr i.year, vce(cluster AB)
			est save IA_CF_DD_`pass', replace
			xi: reg lncont tr_post tr i.year `controls' lnsolicit  lnprogrev, vce(cluster AB)
			xi: reg lncont tr_post i.year `controls' lnsolicit  lnprogrev i.state, vce(cluster AB)
			xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(AB) vce(cluster AB)
			est save IA_CF_DD2_`pass', replace
			xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(ein) vce(cluster AB)
			est save IA_CF_full_`pass', replace	
			matrix b=e(b) 
			local lncont_b_`pass'=b[1,1]
			matrix sd=e(V)
			local lncont_sd_`pass'=sd[1,1]			
			****Fundraising as an outcome variable.
			xi: areg lnsolicit tr_post i.year `controls' lnprogrev lncont, absorb(ein) vce(cluster AB)
			est save IA_FUND_full_`pass', replace	
			matrix b=e(b)
			local lnsolicit_b_`pass'=b[1,1]
			matrix sd=e(V)
			local lnsolicit_sd_`pass'=sd[1,1]	
			******sperating treatments
			xi: areg lncont tr_post tr_post2 i.year `controls' lnsolicit  lnprogrev, absorb(ein) vce(cluster AB)
			est save IA_CF_sep_full_`pass', replace	
			xi: areg lnsolicit tr_post tr_post2 `controls' lnprogrev lncont i.year, absorb(ein) vce(cluster AB)
			est save IA_FUND_sep_full_`pass', replace	
			*****additional specifications********
			if "`moreregs'"=="yes" {
				****Alternative Base Regressions*********	
				xi: areg lncont tr_post i.year, absorb(ein) vce(cluster AB)
				est save IA_CF_firmFE_`pass', replace
				xi: areg lncont tr_post i.year `controls', absorb(ein) vce(cluster AB)
				est save IA_CF_controls_`pass', replace
				****Alternative Fundraising as an outcome variable.
				xi: reg lnsolicit tr tr_post i.year, vce(cluster AB)
				est save IA_FUND_DD_`pass', replace
				xi: areg lnsolicit tr_post i.year, absorb(ein) vce(cluster AB)
				est save IA_FUND_firmFE_`pass', replace
				xi: areg lnsolicit tr_post i.year `controls', absorb(ein) vce(cluster AB)
				est save IA_FUND_controls_`pass', replace 
				******sperating treatments
				xi: areg lncont tr_post tr_post2 i.year `controls', absorb(ein) vce(cluster AB)
				est save IA_CF_sep_controls_`pass', replace
				xi: areg lnsolicit tr_post tr_post2 `controls' i.year, absorb(ein) vce(cluster AB)
				est save IA_FUND_sep_controls_`pass', replace	
				*****OLS Regressions*********		
				xi: reg lncont tr tr_post i.year
				est save IA_CF_DD_OLS_`pass', replace
				xi: areg lncont tr_post i.year, absorb(AB)
				est save IA_CF_stateFE_OLS_`pass', replace
				xi: areg lncont tr_post i.year, absorb(ein)
				est save IA_CF_firmFE_OLS_`pass', replace
				xi: areg lncont tr_post i.year `controls', absorb(ein)
				est save IA_CF_controls_OLS_`pass', replace
				xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(ein)
				est save IA_CF_full_OLS_`pass', replace
				*****Robust Base Regressions*********	
				xi: reg lncont tr tr_post i.year, vce(robust)
				est save IA_CF_DD_robust_`pass', replace
				xi: areg lncont tr_post i.year, absorb(ein) vce(robust)
				est save IA_CF_firmFE_robust_`pass', replace
				xi: areg lncont tr_post i.year `controls', absorb(ein) vce(robust)
				est save IA_CF_controls_robust_`pass', replace	
				xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(ein) vce(robust)
				est save IA_CF_full_robust_`pass', replace
				****robustness not log transformed	
				xi: reg cont tr tr_post i.year
				est save IA_CF_DD2_`pass', replace
				xi: areg cont tr_post i.year, absorb(AB)
				est save IA_CF_stateFE2_`pass', replace
				xi: areg cont tr_post i.year, absorb(ein)
				est save IA_CF_firmFE2_`pass', replace
				xi: areg cont tr_post i.year INCperCAP progrev POP_million gini top1, absorb(ein)
				est save IA_CF_controls2_`pass', replace
				xi: areg cont tr_post i.year INCperCAP progrev POP_million gini top1 solicit, absorb(ein)
				est save IA_CF_full2_`pass', replace
				****Seemingly Unrelated Regressions***********
				quietly{
					**FE Model**
					xi: reg lncont tr_post i.year i.ein
					est sto sur_lncont_fe
					xi: reg lnsolicit tr_post i.year i.ein
					est sto sur_lnsolicit_fe
					suest sur_lncont_fe sur_lnsolicit_fe
					est save IA_SUR_firmFE_`pass', replace	
					suest sur_lncont_fe sur_lnsolicit_fe, vce(cluster AB)
					est save IA_SUR_firmFE_cluster_`pass', replace
					suest sur_lncont_fe sur_lnsolicit_fe, vce(robust)
					est save IA_SUR_firmFE_robust_`pass', replace
					**Controls***
					xi: reg lncont tr_post i.year i.ein `controls'
					est sto sur_lncont_controls
					xi: reg lnsolicit tr_post i.year i.ein `controls'
					est sto sur_lnsolicit_controls
					suest sur_lncont_controls sur_lnsolicit_controls
					est save IA_SUR_controls_`pass', replace	
					suest sur_lncont_controls sur_lnsolicit_controls , vce(cluster AB)
					est save IA_SUR_controls_cluster_`pass', replace
					suest sur_lncont_controls sur_lnsolicit_controls, vce(robust)
					est save IA_SUR_controls_robust_`pass', replace
					**FULL**
					xi: reg lncont tr_post i.year i.ein `controls' lnsolicit  lnprogrev
					est sto sur_lncont_full
					suest sur_lncont_full sur_lnsolicit_controls
					est save IA_SUR_full_`pass', replace	
					suest sur_lncont_full sur_lnsolicit_controls , vce(cluster AB)
					est save IA_SUR_full_cluster_`pass', replace
					suest sur_lncont_full sur_lnsolicit_controls, vce(robust)
					est save IA_SUR_full_robust_`pass', replace
				}
				*****Conley Taber******************************************
				di "-----------"
				di "Conley Taber Section"
				foreach Y in lncont lnsolicit {
					encode AB if AB!="IA", gen(stco)
					replace stco=99 if AB=="IA"
					labmask stco, values(AB)
					gen styr=1000*stco+year
					if "`Y'"=="lncont" {
						local Z lnsolicit
					}
					if "`Y'"=="lnsolicit" {
						local Z lncont
					}
					*xi:reg `Y' tr_post i.year `controls' `Z'  lnprogrev i.state,r cluster(stco)
					xi:reg `Y' tr_post i.year `controls' `Z'  lnprogrev i.state,r cluster(styr)
					xi: areg `Y' tr_post i.year `controls' `Z' lnprogrev, absorb(ein) vce(cluster stco)					
					xi: areg `Y' tr_post i.year `controls' `Z' lnprogrev, absorb(ein) vce(cluster styr)
					matrix b=e(b) 
					matrix b=b[1,1]
					quietly {
						/* predict residuals from regression */
						predict eta, res 
						replace eta=eta+_b[tr_post]*tr_post
						/* create d tilde variable*/
						bysort year: egen djttr=mean(tr_post) if tr==1
						bysort year: egen sdjt=sum(djttr) 
						bysort year: egen ndjt=count(djttr) 
						gen djt=sdjt/ndjt
						bysort state: egen meandjt=mean(djt) 
						g dtil=djt-meandjt
						/* obtain difference in differences coefficient*/
						reg eta dtil if tr==1,noc
						matrix alpha=e(b)	
						/* simulations*/
						sum stco
						g k=r(min)
						g stmax=r(max)
						replace stmax=100 if stmax>100 /*saftey valve to prevent endless loop*/
						sum stmax
						while k<=stmax {
							capture {
								reg eta dtil if stco==k & tr!=1, noc
								matrix alpha=alpha\e(b)
							}
								replace k=k+1
						} 
						matrix asim=alpha[2...,1]
						matrix alpha=alpha[1,1]
						/* Confidence intervals */
						svmat alpha 
						svmat asim
						g byte ind=1
						bysort ind: egen alpha=sum(alpha1)
						drop alpha1 ind eta djttr sdjt ndjt djt meandjt dtil k stmax
						g ci=alpha-asim
					}
					/* form confidence intervals */
					unique stco
					local numst=r(sum)-1
					local i025=floor(0.025*(`numst'-1))
					local i975=ceil(0.975*(`numst'-1))
					local i05=floor(0.050*(`numst'-1))
					local i95=ceil(0.950*(`numst'-1))
					quietly sum alpha
					display as text "Difference in Differences coefficient=" as result _newline(2) r(mean)
					local `Y'_CT_`pass'=r(mean)
					sort asim
					if `numst'>40 {
						noi sum ci if _n==`i025'|_n==`i975'
						display as text "95% Confidence interval=" as result _newline(2) r(min) _col(15) r(max)
						local `Y'_CT95L_`pass'=r(min)
						local `Y'_CT95H_`pass'=r(max)
					}
					else {
						local `Y'_CT95L_`pass'=.
						local `Y'_CT95H_`pass'=.
					}
					noi sum ci if _n==`i05'|_n==`i95' 
					display as text "90% Confidence interval=" as result _newline(2) r(min) _col(15) r(max)
					local `Y'_CT90L_`pass'=r(min)
					local `Y'_CT90H_`pass'=r(max)
					drop ci alpha asim stco styr
					di "------------------------"
				}	
			}
		}
		else {
			di "Too few Observations"
			di "`obs' Observations is insufficient for a `numyear' panel"
		}
	}
	foreach pass of local reglist {	
		matrix TOTCFS = [nullmat(TOTCFS) \ ``pass'_N' ]
		matrix IACFS = [nullmat(IACFS) \ ``pass'_N_IA' ]
		foreach Y in lncont lnsolicit {
			capture matrix IA_`Y' = [nullmat(IA_`Y') \ ``Y'_b_`pass'',  ``Y'_sd_`pass'']
			if _rc==111 {
				capture matrix IA_`Y'= [nullmat(IA_`Y' ) \ .,.]
			}
			capture matrix IA_`Y'_CT = [nullmat(IA_`Y'_CT ) \ ``Y'_CT_`pass'',  ``Y'_CT95L_`pass'',  ``Y'_CT95H_`pass'',  ``Y'_CT90L_`pass'' , ``Y'_CT90H_`pass'' ]
			if _rc==111 {
				capture matrix IA_`Y'_CT = [nullmat(IA_`Y'_CT ) \ .,.,.,.,.]
			}			
		}
		local passnames `" `passnames' "`pass'" "'
	}
	matrix IA_NUMCFS=[IACFS, TOTCFS]
	matrix rown IA_NUMCFS = `passnames'
	matrix coln IA_NUMCFS = "IA" "TOTAL"
	matrix list IA_NUMCFS
	matsave IA_NUMCFS, saving replace
	matrix IA_BETAS=[IA_lncont, IA_lnsolicit]
	matrix rown IA_BETAS = `passnames'
	matrix coln IA_BETAS = "lncont" "C_sd" "lnsolicit" "S_sd"
	matrix list IA_BETAS
	matsave IA_BETAS, saving replace
	matrix IA_CTSTATS=[IA_lncont_CT, IA_lnsolicit_CT]
	matrix rown IA_CTSTATS = `passnames'
	matrix coln IA_CTSTATS = "lncont" "C_CT95L" "C_CT95H" "C_CT90L" "C_CT90H" "lnsolicit" "S_CT95L" "S_CT95H" "S_CT90L" "S_CT90H"
	matrix list IA_CTSTATS
	matsave IA_CTSTATS, saving replace
	***save matrices***
	clear all
	use IA_NUMCFS
	qui cd "`output'/tables"
	export excel using "`output'/tables/IA_BETAOUT.xls", firstrow(variables) sheet("numCFs") sheetreplace
	qui cd "`output'/tempfiles"
	use IA_BETAS, replace
	qui cd "`output'/tables"
	export excel using "`output'/tables/IA_BETAOUT.xls", firstrow(variables) sheet("Betas") sheetreplace
	qui cd "`output'/tempfiles"
	use IA_CTSTATS, replace
	qui cd "`output'/tables"
	export excel using "`output'/tables/IA_BETAOUT.xls", firstrow(variables) sheet("CT_Stats") sheetreplace
	matrix drop _all
	
}	
*************************************
******Regression Tables***************
*************************************
if "`DID'"=="yes" & "`regtables'"=="yes" {
	foreach pass of local reglist {
		di "Output Tables for Regressions on `reg' Panel"
		di "Contributions Baseline"
		qui cd "`output'/tempfiles"
		foreach reg in DD firmFE controls full {
			capture est use IA_CF_`reg'_`pass'
			if _rc==0 {
				est store `reg'
				local `reg' `reg'
			}
			else {
			di "Can't Find IA_`reg'_`pass'"
			}			
		}
		qui cd "`output'/tables"
		esttab `DD' `firmFE' `controls' `full' using IA_CF_REGS_`pass'.csv, replace  ///
		unstack se wrap label nonumbers nodepvars nogaps b(3) t(3)  keep(tr_post tr lnsolicit lnprogrev lnINC lnPOP gini top1) ///
		nomtitles prefoot("Year FE & yes & yes & yes & yes  \\ Firm FE & no & yes & yes  & yes \\ ")
		***
		di "Fundraising Expenditure"
		qui cd "`output'/tempfiles"
		foreach reg in FUND_DD FUND_firmFE FUND_controls FUND_full {
			capture est use IA_`reg'_`pass'
			if _rc==0 {
				est store `reg'
				local `reg' `reg'
			}
			else {
			di "Can't Find IA_`reg'_`pass'"
			}
		}
		qui cd "`output'/tables"
		esttab `FUND_DD' `FUND_firmFE' `FUND_controls' `FUND_full' using IA_FUND_REGS_`pass'.csv, replace  ///
		unstack se wrap label nonumbers nodepvars nogaps b(3) t(3)  keep(tr_post tr lncont lnprogrev lnINC lnPOP gini top1) ///
		nomtitles prefoot("Year FE & yes & yes & yes & yes  \\ Firm FE & no & yes & yes  & yes \\ ")
		**
		di "Seperate Treatment Effects"
		qui cd "`output'/tempfiles"
		foreach reg in CF_sep_controls CF_sep_full FUND_sep_controls FUND_sep_full {
			capture est use IA_`reg'_`pass'
			if _rc==0 {
				est store `reg'
				local `reg' `reg'
			}
			else {
			di "Can't Find IA_`reg'_`pass'"
			}			
		}
		qui cd "`output'/tables"
		capture esttab `CF_sep_controls' `CF_sep_full' `FUND_sep_controls' `FUND_sep_full' using IA_TR2_REGS_`pass'.csv, replace  ///
		unstack se wrap label nonumbers nodepvars nogaps b(3) t(3)  keep(tr_post tr_post2 lnsolicit lnprogrev lnINC lnPOP gini top1) ///
		nomtitles prefoot("Year FE & yes & yes & yes & yes \\ \\ Firm FE & yes & yes & yes & yes \\ ")
		if _rc!=0 {
			di "ERROR with IA_TR2_REGS_`pass'"
		}
	}
}
