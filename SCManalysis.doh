*************************************************
* Charitable Tax Credits Analysis
* SCManalysis.doh
* 9/27/2017, version 1
* Dan Teles
*************************************************
* this file performs the synthetic control analysis
* it can be called from CTC_IA.do or CTC_AZ.do
* which, in turn, are called from CharitableTaxCredits.do
**************************************************
di ""
di "------------------------------------------------------"
di "Synthetic Control Analysis for the following iterations"
di `iterate'
di "-----------------------------------------------------"
foreach pass of local iterate {
	di ""
	di "------------------------------------------"
	di "This is the SCM section for iteration: `pass'"
	* Define suffix, and years
	if "`pass'"=="`set'" {
		local sfx = ""
		di "Baseline"
	}
	if "`pass'"!="`set'" {
		foreach s of local suffixlist {
			if "`pass'"=="`set'`s'" {
				local sfx="`s'"
				di "Robustness Check `sfx'"
			}	
		}					
	}
	* Define local formlist
	local formlist `formlist1'
	* Expand formlist for robustness check of baseline
	if "`pass'"=="`set'" & "`robust'"=="yes" {
		local formlist `formlist1' `formlist2' // formlist2 includes PC, LNPC, ln
	}
	di "Functional forms include: `formlist'"		
	* Define Treatment Years
	local lastpreyear = `treatyear'-1
	local lastyear = 2012
	local year1 = `treatyear'-10
	* Display Pass, first year, treatment year
	di "Pass: `pass' "
	di "Year 1 = `year1', Treatment Year = `treatyear'"
	foreach n of numlist 2/10 {
		local year`n' = `year1'+`n'-1
	}
	* loop over functional form
	di "test `formlist'"
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
			if "`sfx'"=="nst" {
				local trainpass `set'
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
			local calibyears `trainyear'	
			foreach outcome of local outvars {	
				* Load RMSPES Files and determine best fit
				foreach tyr in `calibyears' {				
					qui cd "`output'\tempfiles"
					use `treatstate'_`trainpass'_RMSPES`tyr'_`outcome', clear
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
							use `treatstate'_`trainpass'_`fit'`tyr'_`outcome', replace
							foreach x of numlist 1/10 {
								qui sum group`x'
								scalar A`fit'_`x'=r(mean)
							}
						}
						foreach fit in RMSPE INDEX INDEXA {
							matrix `treatstate'_AV`fit'`tyr'_`pass'_`outcome' = [A`fit'_1 \  A`fit'_2 \ A`fit'_3 \ A`fit'_4 \ A`fit'_5 \ A`fit'_6 \ A`fit'_7 \ A`fit'_8 \ A`fit'_9 \ A`fit'_10]
							matrix colnames `treatstate'_AV`fit'`tyr'_`pass'_`outcome' = "AVG`fit'"
						}
						matrix `treatstate'_AVFIT_`pass'`tyr'_`outcome' = [`treatstate'_AVRMSPE`tyr'_`pass'_`outcome' , `treatstate'_AVINDEX`tyr'_`pass'_`outcome' , `treatstate'_AVINDEXA`tyr'_`pass'_`outcome']
						matsave `treatstate'_AVFIT_`pass'`tyr'_`outcome' , saving replace
						matrix drop _all
						scalar drop _all
						clear
						use `treatstate'_AVFIT_`pass'`tyr'_`outcome' 
						export excel using "`output'\tables/`treatstate'_AVRMSPES_`outcome'.xls", firstrow(variables) sheet("`pass'`tyr'") sheetreplace		
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
		use `dataset'	
		di "limit to sample pool"
		sum
		keep if year>=`year1'
		keep if year<=`lastyear'
		foreach st of local notcontrol {
			drop if AB=="`st'"
		}
		* Robustness using only neighboring states***********
		if "`sfx'"=="nst" {
			gen keepstate=0
			replace keepstate=1 if AB=="`treatstate'"
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
		* RUN SCM 
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
			resultsperiod(`year1'(1)`lastyear') `scmopts' keep(`treatstate'_SCM_`pass'_`outcome', replace)
			if _rc !=0{ //If error then run without nested option
				noi di "The error message for outcome `outcome', pass `pass' is " _rc
				synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
				resultsperiod(`year1'(1)`lastyear') keep(`treatstate'_SCM_`pass'_`outcome', replace)
			}				
			*  create matrices
			matrix `treatstate'_`pass'_DIFF_`outcome'=e(Y_treated)-e(Y_synthetic)
			di "`treatstate'_`pass'_DIFF_`outcome' created"
			matrix `treatstate'_`pass'_V_`outcome' = vecdiag(e(V_matrix))'
			di "`treatstate'_`pass'_V_`outcome' created"
			matrix `treatstate'_`pass'_W_`outcome'=e(W_weights)
			local rownum = rowsof(`treatstate'_`pass'_W_`outcome') //number of potential control units
			local control_units_rowname: rown `treatstate'_`pass'_W_`outcome' // save name of potential control units in local control_units_rowname
			matrix colnames `treatstate'_`pass'_W_`outcome'="stco" "weight"
			di "`treatstate'_`pass'_W_`outcome' created"					
			matrix balance = e(X_balance)
			*  save matrices
			matsave `treatstate'_`pass'_DIFF_`outcome', saving replace
			matrix list `treatstate'_`pass'_V_`outcome'
			matsave `treatstate'_`pass'_V_`outcome', saving replace
			matsave `treatstate'_`pass'_W_`outcome', saving replace				
			*******************************
			* Leave 1 Out Tests**********
			*******************************
			if "`robust'"=="yes" & "`pass'"=="`set'" {
				matrix donors=`treatstate'_`pass'_W_`outcome' /* matrix name too long for variable names*/
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
						resultsperiod(`year1'(1)`lastyear') keep(`treatstate'_SCM_`pass'_no`AB`l''_`outcome', replace)
					}
					matrix `treatstate'_`pass'_no`AB`l''_DIFF_`outcome'=e(Y_treated)-e(Y_synthetic)
					matsave `treatstate'_`pass'_no`AB`l''_DIFF_`outcome', saving replace
					di "`treatstate'_`pass'_no`AB`l''_DIFF_`outcome' created"
					matrix `treatstate'_`pass'_no`AB`l''_V_`outcome' =vecdiag(e(V_matrix))'
					di "`treatstate'_`pass'_no`AB`l''_V_`outcome'  created"
					matsave `treatstate'_`pass'_no`AB`l''_V_`outcome', saving replace
					matrix `treatstate'_`pass'_no`AB`l''_W_`outcome' =e(W_weights)
					matrix colnames `treatstate'_`pass'_no`AB`l''_W_`outcome' ="stco" "weight"
					matsave `treatstate'_`pass'_no`AB`l''_W_`outcome', saving replace
					di "`treatstate'_`pass'_no`AB`l''_W_`outcome'  created"		
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
				save `treatstate'_`pass'_`outcome'_donorlist, replace
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
							matrix `treatstate'_`pass'_PW_`outcome'`i'=e(W_weights)'
							matsave `treatstate'_`pass'_PW_`outcome'`i' , saving replace
						}	
						local plnames `"`plnames' `"pl`i'"' "'
					}
					* end placebo loop
				}
				* di "end placebo loop"
				* end quietly
				* Create matrix of differences	
				if `l'==0 {
					matrix `treatstate'_`pass'_PL_`outcome'= `diffmat_`outcome'_`l'''
					mat colnames `treatstate'_`pass'_PL_`outcome' = `plnames'
					}
				if `l' !=0 {
					matrix `treatstate'_`pass'_no`AB`l''_PL_`outcome'= `diffmat_`outcome'_`l'''
					mat colnames `treatstate'_`pass'_no`AB`l''_PL_`outcome' = `plnames'						
				}
				* save `treatstate'_`pass'_SCM_PL as a stata file for use in Placebo Graphs			
				if `l'==0 {
					di "Save All Placebos Difference Matrix `outcome'"
					matsave `treatstate'_`pass'_PL_`outcome' , saving replace
				}
				if `l' !=0 {
					di "Save All Placebos Difference Matrix `outcome'"
					matsave `treatstate'_`pass'_no`AB`l''_PL_`outcome' , saving replace
				}
				matrix drop _all
				use `project'_temp, replace
			}
			* End loop over placebo Tests
			* Export W and V Matrixes into Excel
			preserve
			use `treatstate'_`pass'_W_`outcome', replace
			export excel using "`output'\tables/`treatstate'_W_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
			use `treatstate'_`pass'_V_`outcome', replace
			export excel using "`output'\tables/`treatstate'_V_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
			if "`robust'"=="yes" & "`doextra'"=="yes" {
			di "..exporting leave one out robustness check tables too"				
				foreach l of local posi_donors {
					use `treatstate'_`pass'_no`AB`l''_W_`outcome', replace
					qui export excel using "`output'\tables/`treatstate'_W_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
					use `treatstate'_`pass'_no`AB`l''_V_`outcome', replace
					qui export excel using "`output'\tables/`treatstate'_V_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
				}
			}
			restore
		}
		* End loop over outcomes*********************
	}
	* End Loop over fform*********
}
* End Loop over iteration*********
	