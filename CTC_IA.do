*************************************************
* Charitable Tax Credits Analysis
* CTC_IA.do
* 8/28/2017, version 2
* Dan Teles
*************************************************
* this file contains the analysis for Endow Iowa
* it can be called from CharitableTaxCredits.do
**************************************************
* Directories
**************************************************
local projectdir="D:\Users\dteles\Box Sync\DTeles\CharitableTaxCredits"
local datadir="D:\Users\dteles\Documents\CharitableTaxCredits\data"
local output="`projectdir'\output"
local project="IA"
**************************************************
* Locals to define which sections to run
**************************************************
local sumstats="no"
local training="yes"
local robust="no"
local more_aggs="no"
local SCM="yes"
local placebo="no"
local inf="no"
local tables="no"
local graphs="no"
local DID="no"
local regtables="no"
**************************************************
* Locals Iteration Lists
**************************************************
local prime_agg `" "CF" "' // robustness checks run for this iteration
local robustchecks1 `" "wo" "xp" "' //robustness checks that require training loop
local robustchecks2 `" "nst" "' //robustness checks that don't require training loop
local robust_sumstats `" "wo" "nst" "' //robustness checks for which sumstats are tabulated
/* 	wo - with outlier - CBCBF not dropped
	xp - excluding population - population not included as a predictor variable
	nst - neighborstates - donor pool restricted to neighboring states
*/
local neighborstates `" "NE" "SD" "MN" "WI" "IL" "MO" "'
local big_aggs `" "ALL" "PUB" "ST" "' /*PUB is NTEE cats RSTUVW, ST is cats ST*/
local spill_aggs `" "ALLmCF" "PUBmCF" "STmCF" "' /*ALLmCF, PUBmCF, and STmCF, are ALL, PUB, and ST without CFs*/
local DDsets `" "DD" "DDwo" "DDD" "DDDwo""'
local reglist `" "unbal" "'
local reglist `" `reglist' "bal9807" "'
* Locals: Other Options
local besttrainyear=1994
* locals to determine which functional forms to run
local formlist1 LNPC
local formlist2 LNPC LN PC
***************************************
* Summary Statistics 
***************************************
* Define Datasets for which Summary Statistics are calculated
local sum_sets `" `prime_agg' "' //primary dataset
* Add "big" and "spillover" datasets
if "`more_aggs'"=="yes" {
	local sum_sets `" `sum_sets' `big_aggs' `spill_aggs' "'
}
* Add datasets used in robustness checks
if "`robust'"=="yes" {
	foreach agg of local prime_agg {
		foreach sfx of local robust_sumstats {
			local robust_sets `" `robust_sets' "`agg'`sfx'" "'
		}
	}	
}
local sum_sets `" `sum_sets' `robust_sets' "'
di `sum_sets'
*if "`individualNPs'"=="yes" {
/* Left Blank, No Org SCM for IOWA */
*}
* Define Datasets for Diff-in-Diff Analysis
if "`DID'"=="yes" local sum_sets `" `sum_sets' `DDsets' "'
* List Datesets
di "SUMSTATS for : "
di `sum_sets'
if "`sumstats'"=="yes" {
	foreach set of local sum_sets {
		di "-------------------------"
		di "Summary Statistics for `set'"
		di "-------------------------"
		foreach u of local DDsets {
			if "`set'"=="`u'" {
				local DDset "yes"
			}
		}
		* Define Variables
		local varlistBASE cont INCperCAP progrev solicit POP_million gini top1
		local varlistLN lncont lnINCperCAP lnprogrev lnsolicit lnPOP gini top1
		local varlistPC contPC INCperCAP progrevPC solicitPC POP_million gini top1
		local varlistLNPC lncontPC lnINCperCAP lnprogrevPC lnsolicitPC lnPOP gini top1
		local varnames `" "Contributions" "Income" "Program_Revenue" "Fundraising" "Population" "Gini" "Top_1_Percent" "'
		* Add number of foundations to varlist baseline
		if "`set'"=="CF" | "`set'"=="CFwo" | "`set'"=="CFnst" {
			local varlistBASE `varlistBASE' foundations
			local varlistLN `varlistLN' lnnum
			local varlistPC `varlistPC' numPC
			local varlistLNPC `varlistLNPC' lnnumPC			
			local varnames `" `varnames' "Foundations" "'
		}
		else if "`DDset'"=="yes" {
			local varlistBASE `varlistBASE' 
			local varlistLN `varlistLN' 
			local varlistPC `varlistPC' 
			local varlistLNPC `varlistLNPC' 			
			local varnames `" `varnames' "'		
		}
		else {
			local varlistBASE `varlistBASE' nonprofits
			local varlistLN `varlistLN' lnnum
			local varlistPC `varlistPC' numPC
			local varlistLNPC `varlistLNPC' lnnumPC			
			local varnames `" `varnames' "Nonprofits" "'
		}
		* Define which functional forms to summarize
		if "`set'"==`prime_agg' {
			local formlist BASE `formlist2' // formlist2 includes PC, LNPC, ln
		}
		di "`formlist'"
		else if "`DDset'"=="yes" {
			local formlist BASE LN
		}
		else local formlist PC
		* Load Datasets
		clear all
		qui cd "`datadir'"
		if "`set'"=="CF" | "`set'"=="CFnst" {
			use CF
			di "load CF"			
		}
		else if "`set'"=="CFwo" {
			use CFwo
			di "load CFwo"
		}
		else if "`DDset'"=="yes"{
			use IA_`set'
			di "load IA_`set'"
		}
		else {
			use `set'
			di "load `set'"
		}
		* Reduce to 1993 to 2012
		keep if year>1992
		keep if year<2013
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
			* Neighbor State Sample Only: Reduce to panel of neighboring states
			if "`set'"=="CFnst" {
				gen keeper=0
				replace keeper=1 if AB=="IA"
				foreach ST of local neighborstates {
					replace keeper=1 if AB=="`ST'"
				}
				keep if keeper==1
				drop keeper
			}
			* Begin Commands that do not apply to DD sets
			if "`DDset'"!="yes" {
				* Export data for Summary Graph, Iowa vs. US
				preserve
				qui gen IA=0
				qui replace IA=1 if AB=="IA"
				qui gen NOT_IA=1-IA	
				collapse (mean) `varlist`fform'', by(IA NOT_IA year)
				save IA_`set'vsUS_`fform', replace
				restore
				preserve
				* Define Sample Pool
				di "define sample pool"
				* Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska becuase they have or had similar programs
				drop if AB=="KS" | AB=="KY" | AB=="MI" | AB=="MT" | AB=="ND" | AB=="NE" 
				* Exclude Iowa, big charitable giving credit
				drop if AB=="AZ"
				* Exclude Hawaii and Utah, missing years.
				drop if AB=="HI" | AB=="UT" 
				* Exclude Wyoming and Deleware, years with zero contributions
				drop if AB=="WY" | AB=="DE"
			}
			* end commands that do not apply to DD sets
			* Summary statistics for Iowa
			sum `varlist`fform'' if AB=="IA"
			tabstat `varlist`fform'' if AB=="IA", s(mean sd) save
			matrix A=r(StatTotal)'
			matrix coln A ="IA_Mean" "IA_Std_deviation"
			matrix rown A = `varnames'
			matrix list A
			* Summary statistics for sample pool or Controls
			if "`DDset'"=="yes" {
				di "Summary Statistics for Control Group `set': `fform' variables"
				local Bcoln `" "Control_Mean" "Control_SD" "'
			}
			else {
				di "Summary Statistics for DONOR STATES `set': `fform' variables"
				local Bcoln `" "Pool_Mean" "Pool_Std_deviation" "'
			}			
				sum `varlist`fform''  if AB!="IA"
				tabstat `varlist`fform''  if AB!="IA", s(mean sd) save
				matrix B=r(StatTotal)'
				matrix coln B = `Bcoln'
				matrix rown B = `varnames' 
			* Collapse data for Summary Graph, Iowa vs. US vs. Sample Pool
			if "`DDset'"!="yes"{
				drop if AB=="IA"
				gen POOL=1
				collapse (mean) `varlist`fform'' POOL, by(year)
				append using IA_`set'vsUS_`fform'
				save IA_`set'vsUS_`fform', replace
				restore
			}
			* Export Summary Statisitcs
			matrix IA_sumstats_`set'_`fform'= [A , B , C ]
			matrix list IA_sumstats_`set'_`fform'
			matsave IA_sumstats_`set'_`fform', saving replace
			preserve
			use IA_sumstats_`set'_`fform', replace
			export excel using "`output'\tables\IA_SUMSTATS.xls", firstrow(variables) sheet("`set'_`fform'") sheetreplace
			matrix drop _all
			restore
		}	
		* end loop over functional form
	}
	* End Loop over sum_sets
}
**************************************************
* Synthetic Control Analysis
**************************************************
* Define which iterations to run
local agglist `" `prime_agg' "' //primary dataset
if "`more_aggs'"=="yes" {
	local agglist `" `agglist' `big_aggs' `spill_aggs' "'
}
local iterate `" `agglist' "'
* Add iterations for robustness checks
if "`robust'"=="yes" {
	foreach agg of local prime_agg {
		foreach sfx of local robustchecks1 {
			local iterate `" `iterate' "`agg'`sfx'" "'
			local suffixlist `" `suffixlist' "`sfx'" "'
		}
	}	
}
di ""
di "------------------------------------------------------"
di "Calibration to determine predictor variables for "
di "  the following iterations"
di `iterate'
di "-----------------------------------------------------"
**************************************************
* Begin Training Loop
**************************************************
* Training loop uses the pre-intervention period 
if "`training'"=="yes" {
	* loop over each analysis
	foreach pass of local iterate {
		di ""
		di "--------------------------------------------------------"
		di "Begin Training Sections for `pass':"		
		* Define local formlist
		local formlist `formlist1'
		* Expand formlist for robustness check of baseline
		if "`pass'"==`prime_agg' {
			local formlist `formlist2' // formlist2 includes PC, LNPC, ln
		}
		di "Functional forms include: `formlist'"		
		* Define Treatment Years
		local year1 = 1990
		local lastyear = 1998
		local calibyears `besttrainyear'
		* Display calibration year
		di "Calibration using treatmentyears: `calibyears'"
		* loop over training treatyear options
		foreach treatyear of numlist `calibyears' {
			local lastpreyear = `treatyear'-1
			foreach n of numlist 2/10 {
				local year`n' = `year1'+`n'-1
			}
			* loop over functional form
			foreach fform of local formlist {
				di "---------------------------------"
				di "Training Section for `pass' `fform' "	
				di "Year 1 = `year1', Treatment Year = `treatyear'"
				di "-------------------------------"	
				***********************
				* Define Locals using synth_setup.doh
				include "`projectdir'\ctcs_dofiles\synth_setup.doh"
				***********************
				* Load and prepare data
				clear all
				qui cd "`datadir'"		
				if "`pass'"=="CFxp" {
					use CF
					di "load CF"
				}
				else {
					use `pass'
					di "load `pass'"
				}	
				cd "`output'\tempfiles"
				* Keep Years Needed
				keep if year>1988
				if `year1'==1990 {
					drop if year==1989
				}	
				keep if year<1999
				* Remove states with missing years
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
				* Generate local for Org-by-State Observations
				encode AB, gen(stco)
				labmask stco, values(AB)
				qui sum stco
				local Numstates=r(max)
				di "------"
				di "There are `Numstates'  observations in the `pass' to `treatyear' training group"
				di "------"
				***********************************
				* Synthetic Control Training Loop
				***********************************
				* Begin loop over Predvar Sets
				forvalues j = 1/10 {
					* begin quietly running iterative SCM	
					di "Predvars: (list `j')"
					di "`C`j''"	
					tempname resmat`j'_`cont'
					tempname fitmat`j'_`cont'
					tempname fit2mat`j'_`cont'
					di "`N`j''"
					tempname resmat`j'_`num'			
					tempname fitmat`j'_`num'	
					tempname fit2mat`j'_`num'	
					if "`pass'"==`prime_agg' {
						di "`S`j''"
						tempname resmat`j'_`solicit'			
						tempname fitmat`j'_`solicit'	
						tempname fit2mat`j'_`solicit'					
					}
					* Begin loop over each state 
					forvalues i = 1/`Numstates' {
						qui { 
							*define time series set
							tsset stco year
							foreach outcome of local outvars {
								*  Define Predvars
								if "`outcome'" == "`cont'" {
									local predictors   `C`j''
								}
								if "`outcome'" == "`solicit'" {
									local predictors  `S`j''
								}
								if "`outcome'" == "`num'" {
									local predictors `N`j''
								}						
								* synthetic control command:
								noi capture synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') `scmopts'
								if _rc !=0 { //If error then run without nested option
									noi di "The error message for outcome `outcome', predvarslist `j',  control unit `i' is " _rc
									noi synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') 
								}								
								* save matrix of RMSPEs
								matrix DIFF=e(Y_treated)-e(Y_synthetic)
								matrix TREAT = e(Y_treated)
								matrix SYNTH = e(Y_synthetic)
								matrix BASE=.1*e(Y_treated)									
								matrix SSEM = DIFF' * DIFF
								scalar SSE = SSEM[1,1]	
								local yrspost = `lastyear'-`treatyear'+1
								scalar postRMSE = sqrt(SSE/`yrspost')					
								matrix `resmat`j'_`outcome'' = [nullmat(`resmat`j'_`outcome'') \ postRMSE]	
								* back out not-logged in if in log form, logged if not in log form
								if "`fform'"=="LNPC" | "`fform'"=="LN" {
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
							* end loop over outcomes
						}				
						* end quietly							
					}				
					* end loop over each state
					* Generate names for placebos (only the first time through)
					if `j'==1 {
						local names ""
						forvalues i = 1/`Numstates' {
							local names `" `names' "pl`i'" "'
						}
					}	
					* Create matrix of RMSPEs 
					foreach outcome of local outvars {
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
				* end loop over Predvar Sets
				* Export file of RMSPES from each loop
				quietly{
					local tyr=`treatyear'-1900
					foreach outcome of local outvars {
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
			* end loop over functional form
		}
		* end loop over training treatyear options
	}
	* end loop over each analysis
}
* end training section
**************************************************	
* SCM FOR REALS******************************
**************************************************
* Add iterations for robustness checks 
if "`robust'"=="yes" {
	foreach agg of local prime_agg {
		* Robustness using the baseline predictor variables
		foreach sfx of local robustchecks2 {
			local iterate `" `iterate' "`agg'`sfx'" "'
			local suffixlist `" `suffixlist' "`sfx'" "'
		}
		* Robustness checks of predictor variables
		foreach n of numlist 1(1)10 {
			local iterate  `" `iterate' "`agg'p`n'" "'
			local suffixlist `" `suffixlist' "p`n'" "'
		}	
	}
	* Spillover estimates for neighboring states
	local iterate `" `iterate' `neighborstates'  "'
}	
di ""
di "------------------------------------------------------"
di "Synthetic Control Analysis for the following iterations"
di `iterate'
di "-----------------------------------------------------"
**************************************************	
* Begin SCM Analysis Loop
************************************************** 
if "`SCM'"=="yes" {
	di "------------------"
	di "-------------"
	di "Current Version runs the following iterations"
	di `iterate'
	di "------------------"
	* Begin Loop over each SCM Analysis
	foreach pass of local iterate {
		di ""
		di "------------------------------------------"
		di "This is the SCM section for iteration: `pass'"
		* Define aggregate, suffix, and years
		foreach a of local agglist {
			if "`pass'"=="`a'" {
				local agg = "`a'"
				local sfx = ""
				di "Baseline"
			}
			if "`pass'"!="`a'" {
				foreach s of local suffixlist {
					if "`pass'"=="`a'`s'" {
						local agg="`a'"
						local sfx="`s'"
						di "Robustness Check `sfx'"
					}	
				}					
			}
		}
		* Define doextra=yes for prime_agg, creates leave-1-out tests
		local doextra "no"
		if "`pass'"==`prime_agg' {
			local doextra "yes"
		}
		* Define local formlist
		local formlist `formlist1'
		* Expand formlist for robustness check of baseline
		if "`pass'"==`prime_agg' {
			local formlist `formlist2' // formlist2 includes PC, LNPC, ln
		}
		di "Functional forms include: `formlist'"		
		* Define Treated State
		local treatstate IA
		foreach state of local neighborstates {
			if "`a'"=="`state'" {
				local treatstate `state'
			}	
		}
		* Define Treatment Years
		local treatyear = 2003
		local lastpreyear = `treatyear'-1
		local lastyear = 2012
		local year1 = `treatyear'-10
		* Display Pass, aggregate, first year, treatment year
		di "Pass: `pass' , Aggregate: `agg'"
		di "Year 1 = `year1', Treatment Year = `treatyear'"
		foreach n of numlist 2/10 {
			local year`n' = `year1'+`n'-1
		}
		* loop over functional form
		foreach fform of local formlist {
			di "-----------"
			di "Begin SCM for  `pass' `fform' "
			di "Year 1 = `year1', Treatment Year = `treatyear'"
			di "-------------------------------"
			***********************
			* Define Locals using synth_setup
			include "`projectdir'\ctcs_dofiles\synth_setup.doh"
			***********************
			* Determine which Set of Predictor Variables to Use
			if "`sfx'"=="p1" | "`sfx'"=="p2" | "`sfx'"=="p3" | "`sfx'"=="p4"  | "`sfx'"=="p5" | "`sfx'"=="p6" | "`sfx'"=="p7"  | "`sfx'"=="p8" | "`sfx'"=="p9" | "`sfx'"=="p10" {
				foreach outcome in `cont' `solicit' `num' {	
					foreach n of numlist 1(1)10 {
						if "`sfx'"=="p`n'" local keepnum_`outcome'_`pass' = `n'
					}
					di "For `pass' predictor set number `keepnum_`outcome'_`pass'' is used for `outcome'"
				}
			}
			else {
				if "`pass'"=="`agg'" & "`treatstate'"!="IA" {
					local trainpass CF
				}
				else if "`pass'"=="CFnz" {
					local trainpass CF
				}
				else if "`sfx'"=="nst" {
					local trainpass `agg'
				}
				else {
					local trainpass `pass'
				}
				local trainyear =`besttrainyear'-1900
				/* Current version doesn't do robustness on calibyear
				if "`doextra'"=="yes" & "`robust'"=="yes" {
					local calibyears 93 94 95
				}
				*/
				else local calibyears `trainyear'	
				foreach outcome of local outvars {		
					* Load RMSPES Files and determine best fit
					foreach tyr in `calibyears' {				
						qui cd "`output'\tempfiles"
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
						* Export Tables Showing Goodness of fit
						if "`trainpass'"=="`pass'" {
							qui cd "`output'\tempfiles"
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
							export excel using "`output'\tables/IA_AVRMSPES_`outcome'.xls", firstrow(variables) sheet("`pass'`tyr'") sheetreplace		
							matrix drop _all
						}
					}
					* end loop over trainyears
					di "----------------"
					di "For `pass' the best fit for `outcome' is with predictor set number `keepnum_`outcome'_`pass''"
					di "-----------------"
				}
				* End outcome var loop
			}
			* End Loop Calculating Best Fit Predictor Variables
			* perepare data************************
			clear all
			qui cd "`datadir'"
			* Load Files
			if "`agg'"=="CF" | "`agg'"=="`treatstate'" {
				di "load CF"
				use CF
			}
			* Robustness: load SCMtraining file with outlier
			else if "`agg'"=="CFwo" {
				di "load CFwo'"
				use CFwo
			}
			* Load BIG/Spillover files
			else  {
				di "load `agg'"
				use `agg'
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
			if "`agg'"!="ALL" {
				drop if AB=="HI" | AB=="UT" 
			}
			*Exclude Wyoming and Deleware, years with zero contributions
			if "`sfx'" == "nz"  |  "`fform'"=="LNPC" | "`fform'"=="LN" {
				di "drop states with zeros"
				drop if AB=="WY" | AB=="DE"
			}
			* Robustness using only neighboring states***********
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
			qui cd "`output'\tempfiles"
			save `project'_`pass'_`fform', replace
			*generate local for number of states in sample pool
			qui sum stco if stco<99
			local num_states=r(max)
			di "----"
			di "There are `num_states' potential donors for `pass' (`fform') in the real SCM Group"	
			di "-----"
			* save stco AB crosswalk and define locals
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
			*  set option for prediction variables based on lowest prediction RMSPE
			local x  `keepnum_`cont'_`pass''
			local y  `keepnum_`solicit'_`pass''
			local z  `keepnum_`num'_`pass''
			* RUN SCM on Iowa************
			di "--------------------"
			di "Run SCM for `pass' `fform' "
			foreach outcome of local outvars {
				if "`outcome'"=="`cont'" {
					local predictors "`C`x'' "
				}
				if "`outcome'"=="`solicit'" {
					local predictors " `S`y'' "
				}
				if "`outcome'"=="`num'" {
					local predictors " `N`z'' "
				}				
				* SCM COMMANDS
				di "---------------------------------------------------"
				di "SCM for `pass' `outcome'"
				di "Predictors Variables are `predictors'"
				di "---------------------------------------------------"
				*  define time series set
				tsset stco year
				*  run SCM and save output
				capture synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
				resultsperiod(`year1'(1)`lastyear') `scmopts' keep(IA_SCM_`pass'_`outcome', replace)
				if _rc !=0{ //If error then run without nested option
					noi di "The error message for outcome `outcome', pass `pass' is " _rc
					synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
					resultsperiod(`year1'(1)`lastyear') keep(IA_SCM_`pass'_`outcome', replace)
				}				
				*  create matrices
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
				*  save matrices
				matsave IA_`pass'_DIFF_`outcome', saving replace
				matrix list IA_`pass'_V_`outcome'
				matsave IA_`pass'_V_`outcome', saving replace
				matsave IA_`pass'_W_`outcome', saving replace				
				*******************************
				* Leave 1 Out Tests**********
				*******************************
				if "`robust'"=="yes" & "`doextra'"=="yes" {
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
						*   If nested gives problem then run without nested and allopt option
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
					* create file of donor list / dropped states
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
				* Placebo Tests**********
				***************************
				local placeboruns 0 `posi_donors'
				*  loop over baseline and leave-one-out checks
				foreach l of local placeboruns {
					tempname resmat_`outcome'_`l'
					tempname diffmat_`outcome'_`l'
					tempname Wmat_`outcome'_`l'
					qui cd "`output'\tempfiles"
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
					* Renumber state with highest or lowest value of outcome variable (BAD FIT)
					//these states won't be used as placebos
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
					*  create new crosswalk to be used in altoutput tests
					preserve
					keep stco AB
					collapse (first) AB, by(stco)
					sort stco
					qui cd "`output'\tempfiles"
					save `project'_`pass'_`fform'_`outcome'_altcrosswalk, replace
					restore
					* Placebo Synth
					qui {
						* generate local for number of controls
						sum stco if stco<99
						local NumCntrl = r(max)
						noi di "NumCntrl is `NumCntrl'"
						local plnames = ""
						* Placebo loop
						forvalues i = 1/`NumCntrl' {
							*define time series
							sort stco year
							tsset stco year
							*scm command:
							capture synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`year1'(1)2012) `scmopts'
							*   If nested gives problem then run without nested and allopt option
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
						* end placebo loop
					}
					* di "end placebo loop"
					* end quietly
					* Create matrix of differences	
					if `l'==0 {
						matrix IA_`pass'_PL_`outcome'= `diffmat_`outcome'_`l'''
						mat colnames IA_`pass'_PL_`outcome' = `plnames'
						}
					if `l' !=0 {
						matrix IA_`pass'_no`AB`l''_PL_`outcome'= `diffmat_`outcome'_`l'''
						mat colnames IA_`pass'_no`AB`l''_PL_`outcome' = `plnames'						
					}
					* save IA_`pass'_SCM_PL as a stata file for use in Placebo Graphs			
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
				* End loop over placebo Tests
				* Export W and V Matrixes into Excel
				preserve
				use IA_`pass'_W_`outcome', replace
				export excel using "`output'\tables/IA_W_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
				use IA_`pass'_V_`outcome', replace
				export excel using "`output'\tables/IA_V_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
				if "`robust'"=="yes" & "`doextra'"=="yes" {
				di "..exporting leave one out robustness check tables too"				
					foreach l of local posi_donors {
						use IA_`pass'_no`AB`l''_W_`outcome', replace
						qui export excel using "`output'\tables/IA_W_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
						use IA_`pass'_no`AB`l''_V_`outcome', replace
						qui export excel using "`output'\tables/IA_V_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
					}
				}
				restore
			}
			* End loop over outcomes*********************
		}
		* End Loop over fform*********
	}
	* End Loop over iteration*********
}	
* End SCM Section
*****************************************************
* Statistical Inference******************************	
*****************************************************
di `iterate'
*define dropstate robustness checks
local statelist AL AK AR CA CO CT DE DC FL GA HI ID IN IL KS KY LA ME MA MI MD MN MS MO MT NE NV NH NJ NM NY NC ND OH OR OK PA RI SC SD TN TX UT VA VT VI WV WA WI WY 
if "`robust'"=="yes" {
	foreach pass of local prime_agg {	
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
	* loop over each iteration 
	foreach pass of local iteratemore {
		* Define locals agg set sfx and dropstate
		foreach i of local iterate {
			* Define locals for passes without states dropped
			if "`pass'"=="`i'" {
				local dropstate = "" // default is no dropped states
				local set = "`i'"
				* Define locals for orginial set of aggregates
				foreach a of local agglist {
					if "`pass'"=="`a'" {
						local agg = "`a'"
						local sfx = ""
					}				
				}			
			}
			* defines local when states are dropped
			else {
				foreach st of local statelist {		
					if "`pass'"=="`i'_no`st'" {
						local dropstate = "`st'" 
						local set = "`i'"
						foreach a of local agglist {
							if "`pass'"=="`a'" {
								local agg = "`a'"
								local sfx = "_no`dropstate'"
							}				
						}											
					}
					else di "ERROR: pass `pass' not found"
				}
			}
		}
		* end loop defining locals agg set sfx and dropstate
		local treatstate IA
		foreach state of local neighborstates {
			if "`agg'"=="`state'" {
				local treatstate `state'
			}	
		}	
		* define years
		local treatyear = 2003
		local lastpreyear = `treatyear'-1
		local lastyear=2012
		local year1 = `treatyear'-10
		di ""
		di "-------------------"
		di "Statistical Inference for iteration :`pass'"
		if "`pass'"=="`agg'" di "`agg' Baseline Estimates"
		else {
			di "`agg' Robustness Check"
			if "`sfx'"=="xp" | "`sfx'"=="xp_no`dropstate'" {
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
		* Define sections to run // default is not to run any section
		local runnone="yes"
		foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
			local run`outcome' ="no"
		}
		* Define sections to run if not a drop 1 robustness check
		if "`pass'"=="`set'" {
			// log contributions and log number per captia are the baseline
			local runlncontPC="yes"
			local runlnnumPC="yes"
			if "`pass'"==`prime_agg' {
				// Add log fundraising per capita if Baseline CF
				local runlnsolicitPC="yes"
				if "`robust'"=="yes" {		
					// Add additional functional forms if Baseline CF and "robust"
					local runcontPC="yes"
					local runnumPC="yes"
					local runsolicitPC="yes"
					local runlncont = "yes"
					local runlnsolicit = "yes"
					local runlnnum = "yes"		
				}	
			}					
		}
		if "`robust'"=="yes" &  "`pass'"!="`set'" {
			foreach outcome in lncontPC lnsolicitPC {
				qui  cd "`output'/tempfiles"
				qui use IA_`set'_`outcome'_donorlist, clear
				qui count
				local tempnum = r(N)
				forvalues i = 1/ `tempnum' {
					if AB[`i']=="`dropstate'" {
						local run`outcome' = "yes"
					}
				}
			}
		}					
		foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
			if "`run`outcome''"=="yes" {
				local runnone = "no"
			}
		}
		if "`runnone'"=="yes" {
			if "`pass'"=="`set'" {
				di "ERROR  no outcomes selected"
			}
			di "`dropstate' is never a donor for `set' , no inference performed this pass"
			di "-------------------"
		}
		if "`runnone'"=="no" {
			di "Variables of Interest:"
			foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
				if "`run`outcome''"=="yes" {
					di "`outcome'"
				}				
			}
		}
		***************************************************
		* Generate DD Estimator and P Values*************
		***************************************************
		if "`runnone'"=="no" {
			local outvars = `""'
			foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
				if "`run`outcome''"=="yes" {
					local outvars  `" `outvars' "`outcome'" "'
				}
			}
			if "`dropstate'"=="" { 
				di "running full list of outcomes : "
				di `outvars'
				di "--------"
			}
			if "`dropstate'"!="" {
				di "`dropstate' was a donor for outcomes :"
				di `outvars'
				di "--------"
			}		
			foreach outcome of local outvars {
				di "-----------"
				di "Generate Estimators for `pass' `outcome'  "		
				*********************************************************
				* Generate values of Synthetic Iowa with Gov't Funding
				/*only for aggregated Community Foundations (CF, CFwo)************/
				if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
					if "`agg'"=="CF" | "`agg'"=="CFwo" { 
						clear all 
						di "...generating contribution levels net of government funding"
						qui {
							qui cd "`datadir'"
							use IA_Credits_Awarded
							qui cd "`output'\tempfiles"
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
				* Generate Standard DD Estimators************
				*******************************************************
				clear all
				qui  cd "`output'\tempfiles"
				* Load Diff files (difference between Treat and Synth
				di "Load IA_`pass'_DIFF_`outcome'"			
				qui  cd "`output'\tempfiles"
				use IA_`pass'_DIFF_`outcome'
				rename c1 DIFF
				* For CF, CFwo: merge with file of Differences NET of Gov't funding
				if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
					if "`agg'"=="CF" | "`agg'"=="CFwo" { 
						di "merge with IA_`pass'_DIFF_`outcome'_NET"
						qui merge 1:1 _rowname using IA_`pass'_DIFF_`outcome'_NET
						drop _merge
					}	
				}
				*  merge together file of differences between observation and synth with placebos.
				di "merge with IA_`pass'_PL_`outcome'"
				qui merge 1:1 _rowname using IA_`pass'_PL_`outcome'
				drop _merge
				* destring and rename year variable
				qui destring _rowname, replace
				qui rename _rowname year
				save IA_PL_GRAPH_`pass'_`outcome', replace
				* Calculate DD and RMSPE Ratio Estimators				
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
					if "`agg'"=="CF" | "`agg'"=="CFwo" {
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
				* calculate DD and RMSPE Ratio Estimators for Placebos
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
					if "`agg'"=="CF" | "`agg'"=="CFwo" { 
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
					* Second set of estimators for Fund cut off 2008
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
				* end loop over controls
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
				* Calcualate P Values
				foreach metric in DD RR {
					*  STANDARD P VALUE
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
					* P value for NET OF CREDITS (CF ONLY)*
					if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
						if "`agg'"=="CF" | "`agg'"=="CFwo" {
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
					* P-VALUE FOR FUNDRAISING THROUGH 2007
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
				*  end loop over DD and RR
			}
			* end loop over outcome list						
			************************************
			* Create Estimate Tables
			************************************
			* Note: 2 estimators for Fundraising measures
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
			foreach outcome of local outvars {
				matrix `outcome'MAT = [`DD_`outcome'', `DD_pval_`outcome'', `RR_`outcome'', `RR_pval_`outcome'' ]
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					if "`agg'"=="CF" | "`agg'"=="CFwo" { 
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
			export excel using "`output'\tables/IA_estimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
			matrix drop _all
			di "------------------------------------"
			*************************************************************************
			* INFERENCE USING ALTERNATE SYNTHETIC CONTROLS
			*************************************************************************
			if "`pass'" =="CF" { 
				di "----"
				di "ALT OUTPUT FOR Pass:"
				di "`pass'"
				* Generate Synthetic Controls using weights from alternate output varaibles
				di "SCM was run on:"
				di `" `outvars' "'
				foreach outcome of local outvars {
					foreach Y in cont solicit num {
						if "`outcome'"=="`Y'PC" {
							local fform = "PC"
							foreach var in cont solicit num dir_exp own_rev {
								local `var' `var'PC
							}
							local INCperCAP INCperCAP
						}
						if "`outcome'"=="ln`Y'" {
							local fform = "LN"
							foreach var in cont solicit num dir_exp own_rev {
								local `var' ln`var'
							}
							local INCperCAP lnINCperCAP
						}
						if "`outcome'"=="ln`Y'PC" {
							local fform = "LNPC"
							foreach var in cont solicit num dir_exp own_rev {
								local `var' ln`var'PC
							}
							local INCperCAP lnINCperCAP
						}
					}
					*  Create File of Placebo Weights
					di "--------------------"
					di "create IA_`pass'_PW_`outcome'"
					clear all
					qui cd "`output'\tempfiles"
					*  count placebos*   (altcrosswalk drops high and low)
					use `project'_`pass'_`fform'_`outcome'_altcrosswalk
					qui sum  stco if stco<99
					local numplacebos = r(max)
					*  merge together placebo weights
					foreach n of numlist 1/`numplacebos' {
						use IA_`pass'_PW_`outcome'`n', replace
						qui keep if _rowname == "_W_Weight"
						qui save IA_`pass'_PW_`outcome'`n', replace
					}
					use IA_`pass'_PW_`outcome'1, replace
					foreach n of numlist 2/`numplacebos' {
						append using IA_`pass'_PW_`outcome'`n'
					}
					*  generate AB based on missing columns
					drop _rowname
					qui gen AB = ""
					foreach st of local statelist {
						capture replace AB="`st'" if `st'==.
					}
					*  merge in original crosswalk
					merge 1:1 AB using `project'_`pass'_`fform'_stcocrosswalk
					* local numstates local using full list of states
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
					* Define variables by fform
					local altvars  `cont' `solicit' `num' `dir_exp' `own_rev' `INCperCAP' unemp top1 
					local synthvars  synth_`cont' synth_`solicit' synth_`num' synth_`dir_exp' synth_`own_rev' synth_`INCperCAP' synth_unemp synth_top1 
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
							* reformat ALTOUT so that synth and treated are seperate columns
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
						* end loop over placebos
					}
					*end quietly
				}	
				* end loop over outcomes
				* Generate Synthetic Controls using averages from control groups
				foreach controlgroup in neighbor national {
					qui cd "`output'\tempfiles"
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
						local altvars contPC lncontPC solicitPC lnsolicitPC INCperCAP lnINCperCAP unemp top1 
						keep `altvars' treated year
						order treated year `altvars'
						*  rename vars to prevent confilict
						foreach var of varlist `altvars' {
							label var `var'
						}	
						collapse (mean) `altvars', by(treated year)
					}
					save IA_`pass'_ALTOUT_`controlgroup'avg, replace	
					* reformat ALTOUT so that synth and treated are seperate columns
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
				* end loop over neighbor and national		
				* Inference on Alternative Outcomes
				di "Inference on Alternative Controls"
				foreach altoutput in solicit num neighboravg nationalavg {					
					foreach fform in PC LNPC {
						if "`fform'"=="PC" {
							foreach var in cont solicit dir_exp own_rev num  {
								local `var' `var'PC
							}
							local INCperCAP INCperCAP
						}
						if "`fform'"=="LN" {
							foreach var in cont solicit dir_exp own_rev num {
								local `var' ln`var'
							}
							local INCperCAP lnINCperCAP
						}
						if "`fform'"=="LNPC" {
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
						qui  cd "`output'\tempfiles"
						use IA_`pass'_ALTOUT_`alt'_wide, replace
						rename `cont'_treated _Y_treated
						rename `cont'_synthetic _Y_synthetic
						rename year _time
						keep _Y_treated _Y_synthetic _time
						* merge in Credits data
						qui  cd "`datadir'"
						qui merge 1:1  _time using IA_Credits_Awarded
						drop _merge
						if "`fform'"=="PC" {
							gen _Y_expected = _Y_synthetic+creditsPC+grantsPC
							gen _Y_plusgrants = _Y_synthetic+grantsPC						
						} 
						if "`fform'"=="LNPC" {
							gen _Y_expected=ln(exp(_Y_synthetic)+creditsPC+grantsPC)	
							gen _Y_plusgrants=ln(exp(_Y_synthetic)+grantsPC)	
						}
						gen DIFF = _Y_treated - _Y_synthetic
						gen NETDIFF=_Y_treated - _Y_expected
						gen MIDDIFF = _Y_treated - _Y_plusgrants
						rename _time year
						keep year DIFF NETDIFF MIDDIFF
						drop if year==.
						qui cd "`output'\tempfiles"
						if "`altoutput'"=="solicit" | "`altoutput'"=="num" {
							merge 1:1 year using IA_`pass'_ALT_`cont'w`alt'_PL
							drop _merge
						}	
						* Generate DD Estimator and P Value for DONATIONS************
						di "ALTOUT Inference: DD and Ratio for `cont' using `alt' weights"
						* Loop for DD and Ratio over GR and NET
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
							*  Calculate DD Estimator
							qui sum `IA' if year>=`treatyear'
							local DIFF_POST=r(mean)
							qui sum `IA' if year<`treatyear'
							local DIFF_PRE=r(mean)				
							local DD`diff'_`cont'w`alt'=`DIFF_POST'-`DIFF_PRE'
							di "The DD `diff'_`cont'w`alt' estimator is:"
							di `DD`diff'_`cont'w`alt''
							*  Calculate RR Estimator
							qui gen `IA'2 = `IA'*`IA'
							qui sum `IA'2 if year>=`treatyear'
							local RMSPE_POST=sqrt(r(mean))
							qui sum `IA'2 if year<`treatyear'
							local RMSPE_PRE=sqrt(r(mean))							
							local RR`diff'_`cont'w`alt'=`RMSPE_POST'-`RMSPE_PRE'
							di "The RR `diff'_`cont'w`alt' estimator is:"
							di `RR`diff'_`cont'w`alt''		
							drop `IA'2
							* Calcualate P Values for altout w/ solicit and num weights
							if "`altoutput'"=="solicit" | "`altoutput'"=="num" {
								* calculate DD and RMSPE Ratio Estimators for Placebos
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
									* end loop over controls
									matrix IA_`pass'_DDmat_contw`alt' = `DDmat'
									matsave IA_`pass'_DDmat_contw`alt'	, saving replace
									matrix IA_`pass'_RRmat_contw`alt'=`RRmat'
									matsave IA_`pass'_RRmat_contw`alt', saving replace	
								}
								* Calcualate P Values
								foreach metric in DD RR {
									*  ALTOUT STANDARD P VALUE
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
								* end loop over DD and RR p-val calculations
							}
							matrix drop _all
							* end loop for P-values	
						}
						* end GR vs NET loop
					}
					* end fform loop
				}
				* end loop over alternative outcomes
				foreach fform in PC LNPC {
					foreach altout in solicit num {
						if "`fform'"=="PC" {
							local cont contPC
							local alt `altout'PC
						}	
						if "`fform'"=="LNPC" {
							local cont lncontPC
							local alt ln`altout'PC
						}			
						matrix ALTEST_`alt'= [`DD_`cont'', `DDGR_`cont'w`alt'' , `DDGR_`cont'w`alt'_pval', `RRGR_`cont'w`alt'_pval', `DDNET_`cont'',  `DDNET_`cont'w`alt'' , `DDNET_`cont'w`alt'_pval', `RRNET_`cont'w`alt'_pval']
						matrix rown ALTEST_`alt' = "`alt'"
					}
					* end loop over altout variables
					foreach alt in neighboravg nationalavg {
						matrix ALTEST_`alt'`fform'= [`DD_`cont'', `DDGR_`cont'w`alt'' , . , ., `DDNET_`cont'', `DDNET_`cont'w`alt'', . , .]
						matrix rown ALTEST_`alt'`fform' = "`alt'_`fform'"
					}
					* end loop over neighboravg and nationalavg
				}
				matrix IA_ALTEST_`pass' = [ALTEST_neighboravgPC \ ALTEST_nationalavgPC \ ALTEST_solicitPC \ ALTEST_numPC \ ALTEST_neighboravgLNPC \ ALTEST_nationalavgLNPC \ ALTEST_lnsolicitPC \ ALTEST_lnnumPC ]
				matrix coln IA_ALTEST_`pass' = "GROSS" "GROSS_ALT" "GROSS_DD_PVAL" "GROSS_RR_PVAL" "NET" "NET_ALT" "NET_DD_PVAL" "NET_RR_PVAL"
				qui  cd "`output'\tempfiles"
				qui matsave IA_ALTEST_`pass', saving replace
				clear all
				use IA_ALTEST_`pass'
				export excel using "`output'\tables/IA_ALTestimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
				matrix drop _all	
			}		
			* end altout inference							
		}
		* End "run none" loop"
	}
	* End Loop over Iterations*********
}
* End Organization SCM Section	
*********************************
* Create SCM Graphs
*********************************
local ALL ""
if "`bigcat'"=="yes" {
	local ALL ALL
}	

if "`graphs'"=="yes" {
	* SUMMARY GRAPHS
	* graph contributions per capita and without outlier
	clear all
	qui cd "`output'\tempfiles"
	use IA_CFwovsUS_PC
	keep if IA==1
	rename IA IA_wo
	append using IA_CFvsUS_PC
	qui cd "`output'\graphs"
	twoway (scatter contPC year if IA_wo==1, connect(l) ) (scatter contPC year if NOT_IA==1, connect(l) lpattern(dash)) ///
	(scatter contPC year if IA==1, connect(l) lpattern(longdash)) (scatter contPC year if POOL==1, connect(l) lpattern(shortdash)), ///
	xline(2002.5) xline(2004.5, lp(longdash)) xtitle("Year") ytitle("Per Capita Contributions") ///
	legend(label(1 "Iowa") label(2 "US, excluding Iowa") label(3 "Iowa, excluding outlier") label(4 "Donor Pool")) xlabel(1993(2)2012)
	graph export IACF_vs_US_contPC.png, replace
	* Create Basic SCM Graphs
	foreach agg in CF `ALL' {
		foreach outcome in lncontPC  contPC solicitPC lnsolicitPC numPC lnnumPC{
			* Graph of IA vs Control
			clear all
			di "------"
			di "Creating SCM graphs for `agg' `outcome'"
			if "`agg'"!="CF" & "`agg'"!="CFwo" {	
				qui cd "`output'\tempfiles"
				use IA_SCM_`agg'_`outcome'
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
			if "`agg'"=="CF"  | "`agg'"=="CFwo" { 
				clear all
				qui cd "`datadir'"
				use IA_Credits_Awarded
				qui cd "`output'\tempfiles"
				merge 1:m _time using IA_SCM_`agg'_`outcome'
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
			qui cd "`output'\graphs"
			graph export IA_`agg'_`outcome'_SCM1.png, replace
			*********************
			* Placebo Graphs Option
			if "`placebo'"=="yes" {
				* Graph of DIFF vs Placebos
				*  merge together file of differences between observation and synth with placebos.
				clear all
				qui cd "`output'\tempfiles"
				use IA_`agg'_DIFF_`outcome'
				rename c1 IA
				label var IA "Iowa"
				if "`agg'"=="CF" {
					if "`outcome'" == "lncontPC" | "`outcome'"=="contPC" {
						merge 1:1 _rowname using IA_`agg'_DIFF_`outcome'_NET
						rename NETDIFF IANET	
						drop _merge	
						drop MIDDIFF
					}	
				}				
				merge 1:1 _rowname using IA_`agg'_PL_`outcome'
				drop _merge
				* destring and rename year variable
				destring _rowname, replace
				rename _rowname year
				* set NumCntrl local
				// r(k) gives the number of variables.  Subtract 1 for rowname and 1 for IA
				qui describe
				local NumCntrl=r(k)-3
				di "There are `NumCntrl' `agg' controls for `outcome'"
				local call =""
				sum IA
				local top = 4*r(max)
				local bottom = 4*r(min)
				local N_tr=`NumCntrl'+1
				di "`NumCntrl' + 1 = `N_tr'"
				* define Placebo lines
				forval j = 1/`NumCntrl' {
					local call `call' line pl`j' year if pl`j'<`top' & pl`j'>`bottom', lc(gs10) lw(vvthin) ||
				}			
				* Graph Placebos and overlay
				/*if "agg"=="CF" {
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
				if "`agg'"=="CF" | "`agg'"=="ALL"  {
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
				* end Log graph command
				qui cd "`output'\graphs"
				* export Graph
				graph export IA_`agg'_`outcome'_SCM2.png, replace
			}
			* End Placebo Graphs Option
			* LEAVE ONE OUT GRAPHS
			if "`robust'"=="yes" & "`agg'"=="CF" & "`outcome'"=="lncontPC"{
				* Graph of DIFF vs Placebos
				*  merge together file of differences between observation and synth with placebos.
				clear all
				qui cd "`output'\tempfiles"
				use IA_`agg'_DIFF_`outcome'_NET
				rename NETDIFF IA
				drop MIDDIFF
				foreach st of local statelist {
					capture merge 1:1 _rowname using IA_`agg'_no`st'_DIFF_`outcome'_NET
					if _rc==0 {
						drop _merge
						rename NETDIFF `st'
						sum `st'
					}
					else gen `st'=.
				}
				* destring and rename year variable
				destring _rowname, replace
				rename _rowname year
				* set NumCntrl local
				// r(k) gives the number of variables.  Subtract 1 for rowname and 1 for IA
				qui describe
				local NumCntrl=r(k)-2
				local call =""
				sum IA
				local top = 4*r(max)
				local bottom = 4*r(min)
				* define Placebo lines
				local q=0
				foreach st of local statelist {
					local call `call' line `st' year, lc(gs10) lw(vvthin) ||
					local q= `q'+1
				}				
				local q= `q'+1
				* Graph Placebos and overlay
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
				if "`agg'"=="ALL"{
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
				* end Log graph command
				qui cd "`output'\graphs"
				* export Graph
				graph export IA_`agg'_`outcome'_L1O.png, replace
			}
			* End LEAVE ONE OUT Option
		}
		* end loop over outcomes
	}		
	* end loop over aggregates
	* ALTOUT GRAPHS, BASELINE ONLY*************************
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
				local fform = "LN"
				foreach var in cont solicit num dir_exp own_rev {
					local `var' ln`var'
				}
				local INCperCAP lnINCperCAP
			}
			if "`outcome'"=="ln`Y'PC" {
				local fform = "LNPC"
				foreach var in cont solicit num dir_exp own_rev {
					local `var' ln`var'PC
				}
				local INCperCAP lnINCperCAP
			}
		}
		clear all
		local agg CF
		qui cd "`output'\tempfiles"
		use IA_`agg'_ALTOUT_`outcome'
		foreach var in `cont' `solicit' `INCperCAP' `dir_exp' `own_rev' unemp top1 {
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
				if "`fform'"=="LNPC" local ytitle "ln(`ytitle_s' Per Capita)"
				if "`fform'"=="LN" local ytitle "ln(`ytitle_s')"
			}
			if "`var'"=="lnINCperCAP" {
				local ytitle = "ln(Per Capita Income)"
				local xline=""
			}
			if "`var'"=="INCperCAP" {
				local ytitle = "Per Capita Income"
				local xline=""
			}
			if "`var'"=="unemp" {
				local ytitle = "Unemployment Rate"
				local xline=""
			}
			if "`var'"=="top1" {
				local ytitle = "Top 1 Percent Income Share"
				local xline=""
			}							
			twoway (scatter synth_`var' year if treated==1, connect(l)) (scatter synth_`var' year if treated==0, connect(l) lpattern(dash)), ///
			xline(2002.5) `xline' xtitle("Year") ytitle("`ytitle'") legend(label(1 "Iowa") label(2 "Synthetic Control")) xlabel(1993(2)2012)
			cd "`output'\graphs"
			graph export IA_`agg'_ALTOUT_`var'_w_`outcome'.png, replace
		}
		* End loop over altoutcomes
		
	}	
	* End loop over SCM outcomes
}

***************************************
* Diff-in-Diff regressions for Firm Level
***************************************
clear all
if "`DID'"=="yes" {
	foreach pass of local reglist {	
		qui cd "`datadir'"
		use `project'_DD, replace
		qui cd "`output'\tempfiles"
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
		gen foundPC=nonprofits/POP_million			
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
			* Clustered Base Regressions*********	
			xi: reg lncont tr_post tr i.year, vce(cluster AB)
			est save IA_CF_DD_`pass', replace
			xi: reg lncont tr_post tr i.year `controls' lnsolicit  lnprogrev, vce(cluster AB)
			xi: reg lncont tr_post i.year `controls' lnsolicit  lnprogrev i.AB, vce(cluster AB)
			xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(AB) vce(cluster AB)
			est save IA_CF_DD2_`pass', replace
			xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(ein) vce(cluster AB)
			est save IA_CF_full_`pass', replace	
			matrix b=e(b) 
			local lncont_b_`pass'=b[1,1]
			matrix sd=e(V)
			local lncont_sd_`pass'=sd[1,1]			
			* Fundraising as an outcome variable.
			xi: areg lnsolicit tr_post i.year `controls' lnprogrev lncont, absorb(ein) vce(cluster AB)
			est save IA_FUND_full_`pass', replace	
			matrix b=e(b)
			local lnsolicit_b_`pass'=b[1,1]
			matrix sd=e(V)
			local lnsolicit_sd_`pass'=sd[1,1]	
			* sperating treatments
			xi: areg lncont tr_post tr_post2 i.year `controls' lnsolicit  lnprogrev, absorb(ein) vce(cluster AB)
			est save IA_CF_sep_full_`pass', replace	
			xi: areg lnsolicit tr_post tr_post2 `controls' lnprogrev lncont i.year, absorb(ein) vce(cluster AB)
			est save IA_FUND_sep_full_`pass', replace	
			* additional specifications
			if "`moreregs'"=="yes" {
				* Alternative Base Regressions*********	
				xi: areg lncont tr_post i.year, absorb(ein) vce(cluster AB)
				est save IA_CF_firmFE_`pass', replace
				xi: areg lncont tr_post i.year `controls', absorb(ein) vce(cluster AB)
				est save IA_CF_controls_`pass', replace
				* Alternative Fundraising as an outcome variable.
				xi: reg lnsolicit tr tr_post i.year, vce(cluster AB)
				est save IA_FUND_DD_`pass', replace
				xi: areg lnsolicit tr_post i.year, absorb(ein) vce(cluster AB)
				est save IA_FUND_firmFE_`pass', replace
				xi: areg lnsolicit tr_post i.year `controls', absorb(ein) vce(cluster AB)
				est save IA_FUND_controls_`pass', replace 
				* sperating treatments
				xi: areg lncont tr_post tr_post2 i.year `controls', absorb(ein) vce(cluster AB)
				est save IA_CF_sep_controls_`pass', replace
				xi: areg lnsolicit tr_post tr_post2 `controls' i.year, absorb(ein) vce(cluster AB)
				est save IA_FUND_sep_controls_`pass', replace	
				* OLS Regressions*********		
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
				* Robust Base Regressions*********	
				xi: reg lncont tr tr_post i.year, vce(robust)
				est save IA_CF_DD_robust_`pass', replace
				xi: areg lncont tr_post i.year, absorb(ein) vce(robust)
				est save IA_CF_firmFE_robust_`pass', replace
				xi: areg lncont tr_post i.year `controls', absorb(ein) vce(robust)
				est save IA_CF_controls_robust_`pass', replace	
				xi: areg lncont tr_post i.year `controls' lnsolicit  lnprogrev, absorb(ein) vce(robust)
				est save IA_CF_full_robust_`pass', replace
				* robustness not log transformed	
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
				* Seemingly Unrelated Regressions***********
				quietly{
					*  FE Model
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
					*  Controls* 
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
					*  FULL
					xi: reg lncont tr_post i.year i.ein `controls' lnsolicit  lnprogrev
					est sto sur_lncont_full
					suest sur_lncont_full sur_lnsolicit_controls
					est save IA_SUR_full_`pass', replace	
					suest sur_lncont_full sur_lnsolicit_controls , vce(cluster AB)
					est save IA_SUR_full_cluster_`pass', replace
					suest sur_lncont_full sur_lnsolicit_controls, vce(robust)
					est save IA_SUR_full_robust_`pass', replace
				}
				* Conley Taber******************************************
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
					*xi:reg `Y' tr_post i.year `controls' `Z'  lnprogrev i.AB,r cluster(stco)
					xi:reg `Y' tr_post i.year `controls' `Z'  lnprogrev i.AB,r cluster(styr)
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
						bysort AB: egen meandjt=mean(djt) 
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
	* save matrices
	clear all
	use IA_NUMCFS
	qui cd "`output'\tables"
	export excel using "`output'\tables/IA_BETAOUT.xls", firstrow(variables) sheet("numCFs") sheetreplace
	qui cd "`output'\tempfiles"
	use IA_BETAS, replace
	qui cd "`output'\tables"
	export excel using "`output'\tables/IA_BETAOUT.xls", firstrow(variables) sheet("Betas") sheetreplace
	qui cd "`output'\tempfiles"
	use IA_CTSTATS, replace
	qui cd "`output'\tables"
	export excel using "`output'\tables/IA_BETAOUT.xls", firstrow(variables) sheet("CT_Stats") sheetreplace
	matrix drop _all
	
}	
*************************************
* Regression Tables***************
*************************************
if "`DID'"=="yes" & "`regtables'"=="yes" {
	foreach pass of local reglist {
		di "Output Tables for Regressions on `reg' Panel"
		di "Contributions Baseline"
		qui cd "`output'\tempfiles"
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
		qui cd "`output'\tables"
		esttab `DD' `firmFE' `controls' `full' using IA_CF_REGS_`pass'.csv, replace  ///
		unstack se wrap label nonumbers nodepvars nogaps b(3) t(3)  keep(tr_post tr lnsolicit lnprogrev lnINC lnPOP gini top1) ///
		nomtitles prefoot("Year FE & yes & yes & yes & yes  \\ Firm FE & no & yes & yes  & yes \\ ")
		***
		di "Fundraising Expenditure"
		qui cd "`output'\tempfiles"
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
		qui cd "`output'\tables"
		esttab `FUND_DD' `FUND_firmFE' `FUND_controls' `FUND_full' using IA_FUND_REGS_`pass'.csv, replace  ///
		unstack se wrap label nonumbers nodepvars nogaps b(3) t(3)  keep(tr_post tr lncont lnprogrev lnINC lnPOP gini top1) ///
		nomtitles prefoot("Year FE & yes & yes & yes & yes  \\ Firm FE & no & yes & yes  & yes \\ ")
		**
		di "Seperate Treatment Effects"
		qui cd "`output'\tempfiles"
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
		qui cd "`output'\tables"
		capture esttab `CF_sep_controls' `CF_sep_full' `FUND_sep_controls' `FUND_sep_full' using IA_TR2_REGS_`pass'.csv, replace  ///
		unstack se wrap label nonumbers nodepvars nogaps b(3) t(3)  keep(tr_post tr_post2 lnsolicit lnprogrev lnINC lnPOP gini top1) ///
		nomtitles prefoot("Year FE & yes & yes & yes & yes \\ \\ Firm FE & yes & yes & yes & yes \\ ")
		if _rc!=0 {
			di "ERROR with IA_TR2_REGS_`pass'"
		}
	}
}
