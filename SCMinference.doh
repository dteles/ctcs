*************************************************
* Charitable Tax Credits Analysis
* SCMinference.doh
* 9/27/2017, version 1
* Dan Teles
*************************************************
* this file performs the synthetic control analysis
* it can be called from CTC_IA.do or CTC_AZ.do
* which, in turn, are called from CharitableTaxCredits.do
**************************************************
di "-------------"
di "Statistical Inference:"
di "Current Version runs the following iterations"
di `iteratemore'
di "-------------"
foreach pass of local iteratemore {
	* Define locals sfx and dropstate
	if "`pass'"=="`set'" {
		local dropstate "" // default is no dropped states
		local sfx ""
		di "Baseline"
	}
	else{
		foreach s of local suffixlist {
			if "`pass'"=="`set'`s'" {
				local dropstate = "" 
				local sfx = "`s'"
			}				
		}
	}
	else {
		foreach st of local statelist { 
			if "`pass'"=="`set'_no`st'" {
				local dropstate = "`st'" 
				local sfx = "_no`dropstate'"
			}				
		}											
	}
	else di "ERROR: pass `pass' not found"
	* define years
	local lastpreyear = `treatyear'-1
	local year1 = `treatyear'-10
	di ""
	di "-------------------"
	di "Statistical Inference for iteration :`pass'"
	if "`pass'"=="`set'" di "`set' Baseline Estimates"
	else {
		di "`set' Robustness Check `sfx'"
	}
	if "`dropstate'"!="" di " `dropstate' removed from sample pool"
	di "Year 1 = `year1', Treatment Year = `treatyear'"
	**************************************************
	* Define sections to run // default is not to run any section
	local runnone="yes"
	foreach outcome in contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC numPC lnnum lnnumPC {
		local run`outcome' ="no"
	}
	* Define local formlist
	local formlist `formlist1'
	* Expand formlist for robustness check of baseline
	if "`pass'"=="`set'" & "`robust'"=="yes" {
		local formlist `formlist2' // formlist2 includes PC, LNPC, ln
	}
	di "Functional forms include: `formlist'"			
	* Define sections to run
	if "`pass'"=="`set'" {
		// log contributions and log number per captia are the baseline
		local runlncontPC="yes"
		local runlnnumPC="yes"
		if "`pass'"=="`set'" & "`robust'"=="yes" {		
			// Add additional functional forms if "robust"
			local runlnsolicitPC="yes"
			local runcontPC="yes"
			local runnumPC="yes"
			local runsolicitPC="yes"
			local runlncont = "yes"
			local runlnsolicit = "yes"
			local runlnnum = "yes"		
		}	
	}
	else if "`pass'"!="`set'" & "`dropstate'"=="" {
		// for robustness checks just run lncontPC and lnnumPC
		local runlncontPC="yes"
		local runlnnumPC="yes"	
	}
	else if "`dropstate'"!="" {
		//determine which states need drop1 robustness checks
		foreach outcome in lncontPC lnnumPC {
			qui  cd "`output'/tempfiles"
			qui use `treatstate'_`set'_`outcome'_donorlist, clear
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
		if "`pass'"=="`set'" di "ERROR  no outcomes selected"
		else di "`dropstate' is never a donor for `set' , no inference performed this pass"
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
			* Generate values PLUS Gov't Funding
			*********************************************************
			if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
				if "`credits'"=="yes" { 
					clear all 
					di "...generating contribution levels plus government funding"
					qui {
						qui cd "`datadir'"
						use `treatstate'_Credits_Awarded
						qui cd "`output'\tempfiles"
						merge 1:m _time using `treatstate'_SCM_`pass'_`outcome'
						drop _merge
						if "`outcome'"=="contPC" {
							gen _Y_expected = _Y_synthetic+creditsPC+grantsPC
						} 
						if "`outcome'"=="lncontPC" {
							gen _Y_expected=ln(exp(_Y_synthetic)+creditsPC+grantsPC)	
						}
						if "`outcome'"=="lncont" {
							gen _Y_expected=ln(exp(_Y_synthetic)+(credits_adj)+(grants_adj))	
						}
						gen NETDIFF=_Y_treated - _Y_expected
						rename _time year
						noi save `treatstate'_NET_`pass'_`outcome', replace
						rename year _rowname
						keep _rowname NETDIFF
						drop if _rowname==.		
						tostring _rowname, replace
						recast str4 _rowname
						noi save `treatstate'_`pass'_DIFF_`outcome'_NET, replace							
					}
				}
			}
			*************************************************************
			* Generate Standard DD Estimators************
			*******************************************************
			clear all
			qui  cd "`output'\tempfiles"
			* Load Diff files (difference between Treat and Synth
			di "Load `treatstate'_`pass'_DIFF_`outcome'"			
			qui  cd "`output'\tempfiles"
			use `treatstate'_`pass'_DIFF_`outcome'
			rename c1 DIFF
			* IF credits=yes merge with file of Differences NET of Gov't funding
			if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
				if "`credits'"=="yes" { 
					di "merge with `treatstate'_`pass'_DIFF_`outcome'_NET"
					qui merge 1:1 _rowname using `treatstate'_`pass'_DIFF_`outcome'_NET
					drop _merge
				}	
			}
			*  merge together file of differences between observation and synth with placebos.
			di "merge with `treatstate'_`pass'_PL_`outcome'"
			qui merge 1:1 _rowname using `treatstate'_`pass'_PL_`outcome'
			drop _merge
			* destring and rename year variable
			qui destring _rowname, replace
			qui rename _rowname year
			save `treatstate'_PL_GRAPH_`pass'_`outcome', replace
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
				if "`credits'"=="yes" { 
					qui sum NETDIFF if year>=`treatyear'
					local DIFF_POST_NET =r(mean)
					gen NETDIFF_2=NETDIFF*NETDIFF
					qui sum NETDIFF_2 if year>=`treatyear'
					local RMSPE_POST_NET=sqrt(r(mean))	
					local DDNET_`outcome'=`DIFF_POST_NET'-`DIFF_PRE'
					di "The NET DD estimator for `pass' `outcome' is:"
					di `DDNET_`outcome''			
					local RRNET_`outcome'=`RMSPE_POST_NET'/`RMSPE_PRE'
					di "The NET RMSPE Ratio for `pass' `outcome'  is:"
					di `RRNET_`outcome''
					drop NETDIFF_2
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
				if "`credits'"=="yes" {
					local NumCntrl=r(k)-4 /*Also subtract for NETDIFF */
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
			matrix `treatstate'_`pass'_DDmat_`outcome' = `DDmat'
			matsave `treatstate'_`pass'_DDmat_`outcome'	, saving replace
			matrix `treatstate'_`pass'_RRmat_`outcome'=`RRmat'
			matsave `treatstate'_`pass'_RRmat_`outcome', saving replace	
			if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
				matrix `treatstate'_`pass'_DDmat_`outcome'2 = `DDmat2'
				matsave `treatstate'_`pass'_DDmat_`outcome'2	, saving replace
				matrix `treatstate'_`pass'_RRmat_`outcome'2=`RRmat2'
				matsave `treatstate'_`pass'_RRmat_`outcome'2, saving replace				
			}
			* Calcualate P Values
			foreach metric in DD RR {
				*  STANDARD P VALUE
				clear all
				use `treatstate'_`pass'_`metric'mat_`outcome'
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
					if "`credits'"=="yes" {
						count if c1==.
						local m=r(N)
						count if c1>``metric'NET_`outcome''
						local count1=r(N)-`m'
						count if c1<``metric'NET_`outcome''
						local count2=r(N)
						di "There are `count1' estimators larger and  `count2' estimators smaller"
						if ``metric'NET_`outcome''>0 {
							local `metric'NET_pval_`outcome'=(`count1'+1)/(`NumCntrl'+1-`m')
						}
						if ``metric'NET_`outcome''<0 {
							local `metric'NET_pval_`outcome'=(`count2'+1)/(`NumCntrl'+1-`m')
						}									
						di "The P-value associated with the `pass' (`outcome') `metric' (NET) estimator is :"
						di ``metric'NET_pval_`outcome''	
					}							
				}
				* P-VALUE FOR FUNDRAISING THROUGH 2007
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					use `treatstate'_`pass'_`metric'mat_`outcome'2, clear
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
			}
			if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
				matrix `outcome'MAT2 = [9999, 9999, 9999, 9999]
			}
		}	
		foreach outcome of local outvars {
			matrix `outcome'MAT = [`DD_`outcome'', `DD_pval_`outcome'', `RR_`outcome'', `RR_pval_`outcome'' ]
			if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
				if "`credits'"=="yes" { 
					matrix `outcome'MATNET = [`DDNET_`outcome'', `DDNET_pval_`outcome'', `RRNET_`outcome'', `RRNET_pval_`outcome'' ]
				}
			}
			if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
				matrix `outcome'MAT2 = [`DD_`outcome'2', `DD_pval_`outcome'2', `RR_`outcome'2', `RR_pval_`outcome'2' ]
			}
		}
		di "test1"
		matrix `treatstate'_estimators_`pass' = [contPCMAT \ lncontMAT \ lncontPCMAT \ contPCMATNET \ lncontMATNET \ lncontPCMATNET \solicitPCMAT \ lnsolicitMAT \ lnsolicitPCMAT \ solicitPCMAT2 \ lnsolicitMAT2 \ lnsolicitPCMAT2 \ numPCMAT \ lnnumMAT \ lnnumPCMAT ]
		matrix rown `treatstate'_estimators_`pass' =  "ContPC" "lnCont" "lnContPC" "ContPC_net" "lnCont_net" "lnContPC_net" "SolicitPC_to12" "lnSolicit_to12" "lnSolicitPC_to12" "SolicitPC_to07" "lnSolicit_to07" "lnSolicitPC_to07" "NumPC" "lnNum" "lnNumPC"
		matrix coln `treatstate'_estimators_`pass' = "DD" "DD_pval" "Ratio" "Ratio_pval"
		matrix list `treatstate'_estimators_`pass'
		di "test2"
		qui matsave `treatstate'_estimators_`pass', saving replace
		clear all
		use `treatstate'_estimators_`pass'
		export excel using "`output'\tables/`treatstate'_estimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
		matrix drop _all
		di "------------------------------------"
		*************************************************************************
		* INFERENCE USING ALTERNATE SYNTHETIC CONTROLS
		*************************************************************************
		if "`pass'" =="`set'" & "`robust'"=="yes" { 
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
				di "create `treatstate'_`pass'_PW_`outcome'"
				clear all
				qui cd "`output'\tempfiles"
				*  count placebos*   (altcrosswalk drops high and low)
				use `project'_`pass'_`fform'_`outcome'_altcrosswalk
				qui sum  stco if stco<99
				local numplacebos = r(max)
				*  merge together placebo weights
				foreach n of numlist 1/`numplacebos' {
					use `treatstate'_`pass'_PW_`outcome'`n', replace
					qui keep if _rowname == "_W_Weight"
					qui save `treatstate'_`pass'_PW_`outcome'`n', replace
				}
				use `treatstate'_`pass'_PW_`outcome'1, replace
				foreach n of numlist 2/`numplacebos' {
					append using `treatstate'_`pass'_PW_`outcome'`n'
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
				save `treatstate'_`pass'_PW_`outcome', replace
				di "Load `project'_`pass'_`fform'"
				use `project'_`pass'_`fform', replace
				* Define variables by fform
				local altvars  `cont' `solicit' `num' `dir_exp' `own_rev' `INCperCAP' unemp top1 
				local synthvars  synth_`cont' synth_`solicit' synth_`num' synth_`dir_exp' synth_`own_rev' synth_`INCperCAP' synth_unemp synth_top1 
				di "Merge in W matrix `treatstate'_`pass'_W_`outcome' and `treatstate'_`pass'_PW_`outcome' "
				qui {
					merge m:1 stco using `treatstate'_`pass'_W_`outcome'
					drop _merge
					sort stco year
					rename weight W_99
					merge m:1 AB using `treatstate'_`pass'_PW_`outcome'
					drop _merge
					save `treatstate'_`pass'_ALTOUT_`outcome'_temp, replace
					noi di "...generating values of alternate outcome variables using W weights"
					foreach st of numlist 99 1/`numstates' {
						use `treatstate'_`pass'_ALTOUT_`outcome'_temp, replace
						capture rename unemploymentrate unemp 
						gen treated=0
						replace treated=1 if stco==`st'
						foreach var of varlist `altvars' {
								gen synth_`var' = `var'*W_`st'
								replace synth_`var'=`var' if treated==1
						}
						collapse (sum) `synthvars', by(treated year)
						if `st'==99 {
							noi save `treatstate'_`pass'_ALTOUT_`outcome', replace
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
							noi save `treatstate'_`pass'_ALTOUT_`outcome'_wide, replace
						}
						else {
							foreach var in `cont' `solicit' `num' {
								preserve
								gen pl`st'= `var'_treated-`var'_synthetic
								keep year pl`st'
								save `treatstate'_`pass'_ALT_`var'w`outcome'_PL`st', replace
								restore
							}
						}
					}
					foreach var in `cont' `solicit' `num' {
						use `treatstate'_`pass'_ALT_`var'w`outcome'_PL1, replace
						foreach st of numlist 2/`numstates' {
							merge 1:1 year using `treatstate'_`pass'_ALT_`var'w`outcome'_PL`st'
							drop _merge
						}
						noi save `treatstate'_`pass'_ALT_`var'w`outcome'_PL, replace
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
				capture rename unemploymentrate unemp 
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
					local altvars contPC lncont lncontPC solicitPC lnsolicit lnsolicitPC INCperCAP lnINCperCAP unemp top1 
					keep `altvars' treated year
					order treated year `altvars'
					*  rename vars to prevent confilict
					foreach var of varlist `altvars' {
						label var `var'
					}	
					collapse (mean) `altvars', by(treated year)
				}
				save `treatstate'_`pass'_ALTOUT_`controlgroup'avg, replace	
				* reformat ALTOUT so that synth and treated are seperate columns
				di "....reformatting"
				qui {
					reshape wide `altvars', i(year) j(treated)
					foreach var in `altvars' {
						rename `var'1 `var'_treated
						rename `var'0 `var'_synthetic
					}
					noi save `treatstate'_`pass'_ALTOUT_`controlgroup'avg_wide, replace
				}
				*end quietly
			}	
			* end loop over neighbor and national		
			* Inference on Alternative Outcomes
			di "Inference on Alternative Controls"
			foreach altoutput in solicit num neighboravg nationalavg {					
				foreach fform of local formlist {
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
					use `treatstate'_`pass'_ALTOUT_`alt'_wide, replace
					rename `cont'_treated _Y_treated
					rename `cont'_synthetic _Y_synthetic
					rename year _time
					keep _Y_treated _Y_synthetic _time
					* merge in Credits data
					qui  cd "`datadir'"
					qui merge 1:1  _time using `treatstate'_Credits_Awarded
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
						merge 1:1 year using `treatstate'_`pass'_ALT_`cont'w`alt'_PL
						drop _merge
					}	
					* Generate DD Estimator and P Value for DONATIONS************
					di "ALTOUT Inference: DD and Ratio for `cont' using `alt' weights"						
					*  Calculate DD Estimator
					qui sum DIFF if year>=`treatyear'
					local DIFF_POST=r(mean)
					qui sum DIFF if year<`treatyear'
					local DIFF_PRE=r(mean)				
					local DD`diff'_`cont'w`alt'=`DIFF_POST'-`DIFF_PRE'
					di "The DD `diff'_`cont'w`alt' estimator is:"
					di `DD`diff'_`cont'w`alt''
					*  Calculate RR Estimator
					qui gen DIFF2 = DIFF*DIFF
					qui sum DIFF2 if year>=`treatyear'
					local RMSPE_POST=sqrt(r(mean))
					qui sum DIFF2 if year<`treatyear'
					local RMSPE_PRE=sqrt(r(mean))							
					local RR`diff'_`cont'w`alt'=`RMSPE_POST'-`RMSPE_PRE'
					di "The RR `diff'_`cont'w`alt' estimator is:"
					di `RR`diff'_`cont'w`alt''		
					drop DIFF2
					* Calcualate P Values for altout w/ solicit and num weights
					if "`altoutput'"=="solicit" | "`altoutput'"=="num" {
						* calculate DD and RMSPE Ratio Estimators for Placebos
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
						matrix `treatstate'_`pass'_DDmat_contw`alt' = `DDmat'
						matsave `treatstate'_`pass'_DDmat_contw`alt'	, saving replace
						matrix `treatstate'_`pass'_RRmat_contw`alt'=`RRmat'
						matsave `treatstate'_`pass'_RRmat_contw`alt', saving replace	
					}
					* Calcualate P Values
					foreach metric in DD RR {
						*  ALTOUT STANDARD P VALUE
						preserve
						clear all
						use `treatstate'_`pass'_`metric'mat_contw`alt'
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
					matrix drop _all
				}
				* end fform loop
			}
			* end loop over alternative outcomes
			foreach fform of local formlist {
				foreach altout in solicit num {
					if "`fform'"=="PC" {
						local cont contPC
						local alt `altout'PC
						local altn `altout'PC
					}	
					if "`fform'"=="LNPC" {
						local cont lncontPC
						local alt ln`altout'PC
						local altn `altout'LNPC
					}
					if "`fform'"=="LN" {
						local cont lncont
						local alt ln`altout'
						local altn `altout'LN
					}						
					matrix ALTEST_`altn'= [`DD_`cont'', `DDGR_`cont'w`alt'' , `DDGR_`cont'w`alt'_pval', `RRGR_`cont'w`alt'_pval', `DDNET_`cont'',  `DDNET_`cont'w`alt'' , `DDNET_`cont'w`alt'_pval', `RRNET_`cont'w`alt'_pval']
					matrix rown ALTEST_`altn' = "`alt'"					
				}
				* end loop over altout variables
				foreach alt in neighboravg nationalavg {
					matrix ALTEST_`alt'`fform'= [`DD_`cont'', `DDGR_`cont'w`alt'' , . , ., `DDNET_`cont'', `DDNET_`cont'w`alt'', . , .]
					matrix rown ALTEST_`alt'`fform' = "`alt'_`fform'"
				}
				matrix dir
				* end loop over neighboravg and nationalavg
				matrix `treatstate'_ALTEST_`pass' = [nullmat(`treatstate'_ALTEST_`pass')\ALTEST_neighboravg`fform' \ ALTEST_nationalavg`fform' \ ALTEST_solicit`fform' \ ALTEST_num`fform']			
			}
			matrix dir
			matrix coln `treatstate'_ALTEST_`pass' = "GROSS" "GROSS_ALT" "GROSS_DD_PVAL" "GROSS_RR_PVAL" "NET" "NET_ALT" "NET_DD_PVAL" "NET_RR_PVAL"
			qui  cd "`output'\tempfiles"
			qui matsave `treatstate'_ALTEST_`pass', saving replace
			clear all
			use `treatstate'_ALTEST_`pass'
			export excel using "`output'\tables/`treatstate'_ALTestimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
			matrix drop _all	
		}		
		* end altout inference							
	}
	* End "run none" loop"
}
* End Loop over Iterations*********