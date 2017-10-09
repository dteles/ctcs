*************************************************
* Charitable Tax Credits Analysis
* SCMtraining.doh
* 9/27/2017, version 1
* Dan Teles
*************************************************
* this file calculates summary statistics
* it can be called from CTC_IA.do or CTC_AZ.do
* which, in turn, are called from CharitableTaxCredits.do
**************************************************
di ""
di "------------------------------------------------------"
di "Calibration to determine predictor variables for "
di "  the following iterations"
di `iterate'
di "-----------------------------------------------------"
foreach pass of local iterate {
	di ""
	di "--------------------------------------------------------"
	di "Begin Training Sections for `pass':"	
	* Define local formlist
	local formlist `formlist1'
	* Expand formlist for robustness check of baseline
	if "`pass'"=="`set'" & "`robust'"=="yes" {
		local formlist `formlist2' // formlist2 includes PC, LNPC, ln
	}
	di "Functional forms include: `formlist'"	
	* Define Treatment Years
	local year1 = 1990
	local lasttrainyear = 1998
	local calibyears `besttrainyear'
	* Display calibration year
	di "Calibration using treatmentyears: `calibyears'"
	* loop over training trainyear options
	foreach trainyear of numlist `calibyears' {
		local lastpreyear = `trainyear'-1
		foreach n of numlist 2/10 {
			local year`n' = `year1'+`n'-1
		}
		* loop over functional form
		foreach fform of local formlist {
			di "---------------------------------"
			di "Training Section for `pass' `fform' "	
			di "Year 1 = `year1', Training Period Treatment Year = `trainyear'"
			di "-------------------------------"	
			***********************
			* Define Locals using synth_setup.doh
			include "`projectdir'\ctcs_dofiles\synth_setup.doh"
			***********************
			* Load and prepare data
			clear all
			qui cd "`datadir'"		
			use "`dataset'"
			cd "`output'\tempfiles"
			* Keep Years Needed
			keep if year>=`year1'
			keep if year<=`lasttrainyear'
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
			scalar nyrs = `lasttrainyear'-`year1'+1
			keep if N==nyrs		
			* Generate local for Org-by-State Observations
			encode AB, gen(stco)
			labmask stco, values(AB)
			qui sum stco
			local Numstates=r(max)
			di "------"
			di "There are `Numstates'  observations in the `pass' to `trainyear' training group"
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
				if "`pass'"=="`set'" & "`robust'"=="yes" {
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
							di "`trainyear' to `lasttrainyear'"
							noi capture synth `outcome' `predictors', trunit(`i') trperiod(`trainyear') resultsperiod(`trainyear'(1)`lasttrainyear') `scmopts'
							if _rc !=0 { //If error then run without nested option
								noi di "The error message for outcome `outcome', predvarslist `j',  control unit `i' is " _rc
								noi synth `outcome' `predictors', trunit(`i') trperiod(`trainyear') resultsperiod(`trainyear'(1)`lasttrainyear') 
							}								
							* save matrix of RMSPEs
							matrix DIFF=e(Y_treated)-e(Y_synthetic)
							matrix TREAT = e(Y_treated)
							matrix SYNTH = e(Y_synthetic)
							matrix BASE=.1*e(Y_treated)									
							matrix SSEM = DIFF' * DIFF
							scalar SSE = SSEM[1,1]	
							local yrspost = `lasttrainyear'-`trainyear'+1
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
				local tyr=`trainyear'-1900
				foreach outcome of local outvars {
					matrix `treatstate'_`pass'_RMSPES`tyr'_`outcome'=[RMSPES_`outcome'_1, RMSPES_`outcome'_2, RMSPES_`outcome'_3, RMSPES_`outcome'_4, RMSPES_`outcome'_5, RMSPES_`outcome'_6, RMSPES_`outcome'_7, RMSPES_`outcome'_8, RMSPES_`outcome'_9, RMSPES_`outcome'_10]
					mat rownames `treatstate'_`pass'_RMSPES`tyr'_`outcome'= `names' 
					matsave `treatstate'_`pass'_RMSPES`tyr'_`outcome', saving replace
					matrix `treatstate'_`pass'_INDEX`tyr'_`outcome'=[FITINDEX_`outcome'_1, FITINDEX_`outcome'_2, FITINDEX_`outcome'_3, FITINDEX_`outcome'_4, FITINDEX_`outcome'_5, FITINDEX_`outcome'_6, FITINDEX_`outcome'_7, FITINDEX_`outcome'_8, FITINDEX_`outcome'_9, FITINDEX_`outcome'_10]
					mat rownames `treatstate'_`pass'_INDEX`tyr'_`outcome'= `names' 
					matsave `treatstate'_`pass'_INDEX`tyr'_`outcome', saving replace
					matrix `treatstate'_`pass'_INDEXA`tyr'_`outcome'=[FITINDEXA_`outcome'_1, FITINDEXA_`outcome'_2, FITINDEXA_`outcome'_3, FITINDEXA_`outcome'_4, FITINDEXA_`outcome'_5, FITINDEXA_`outcome'_6, FITINDEXA_`outcome'_7, FITINDEXA_`outcome'_8, FITINDEXA_`outcome'_9, FITINDEXA_`outcome'_10]
					mat rownames `treatstate'_`pass'_INDEXA`tyr'_`outcome'= `names' 
					matsave `treatstate'_`pass'_INDEXA`tyr'_`outcome', saving replace
				}
			}
			di " RMSPE and FIT INDEX Matrices for `pass' `fform' to `trainyear' saved"
			di "------------------------------------------------------"
			matrix drop _all	
		}
		* end loop over functional form
	}
	* end loop over training trainyear options
}
* end loop over each analysis
