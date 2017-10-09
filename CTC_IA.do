*************************************************
* Charitable Tax Credits Analysis
* CTC_IA.do
* 9/27/2017, version 3
* Dan Teles
*************************************************
* this file contains the analysis for Endow Iowa
* it can be called from CharitableTaxCredits.do
**************************************************
* Directories
**************************************************
local projectdir="D:\Users\dteles\Box Sync\DTeles\CharitableTaxCredits"
local datadir="D:\NCCSdata"
local output="`projectdir'\output"
local project="IA"
**************************************************
* Locals to define which sections to run
**************************************************
local sumstats="n"
local training="yes"
local SCM="n"
local INF="n"
**************************************************
* Locals Iteration Lists
**************************************************
local setlist `" "CF" "'
**************************************************
* Locals More Lists
**************************************************
local statelist AL AK AR CA CO CT DE DC FL GA HI ID IN IL IA KS KY LA ME MA MI MD MN MS MO MT NE NV NH NJ NM NY NC ND OH OR OK PA RI SC SD TN TX UT VA VT VI WV WA WI WY 
**************************************************
* Begin Cycle through Analyses
**************************************************
foreach set of local setlist {
	**************************************************
	* Analaysis Specific Locals 
	**************************************************
	if "`set'"=="CF" {
		local robust "yes"
		local dataset CF
		local credits "yes" // credit expenditure data available
		local treatyear 2003
		local firstyear 1993
		local lastyear 2012
		local besttrainyear=1994
		local set CF
		local treatstate IA
		local neighborstates  `" "NE" "SD" "MN" "WI" "IL" "MO" "'
		local baseform LNPC
		local otherforms PC LN
		local notcontrol `" "KS" "KY" "MI" "MT" "ND" "NE" "AZ" "HI" "UT" "WY" "DE" "'
		/* 	Exclude Kentucky, Montana, North Dakota, Michigan, Kansas and Nebraska 
			becuase they have or had similar programs
			Exclude Arizona, big charitable giving credit
			Exclude Hawaii and Utah, missing years.
			Exclude Wyoming and Deleware, years with zero contributions */
	}	
	***************************************
	* Summary Statistics 
	***************************************
	if "`sumstats'"=="yes" {
		* define functional forms over which to run		* 
		local formlist BASE `baseform'
		* run sumstats code
		include "`projectdir'\ctcs_dofiles\sumstats.doh"
	}
	**************************************************
	* Synthetic Control Analysis
	**************************************************
	* add robustness checks that require training loop
	local iterate " "`set'" "
	* Add iterations for robustness checks
	if "`robust'"=="yes" {
		foreach sfx of local robustchecks1 {
			local iterate `" `iterate' "`set'`sfx'" "'
			local suffixlist `" `suffixlist' "`sfx'" "'
		}	
	}
	* define functional forms over which to run synthetic control analysis
	local formlist1 `baseform'
	local formlist2 `otherforms'
	* Training loop uses the pre-intervention period 
	if "`training'"=="yes" {
		* run SCM training code
		include "`projectdir'\ctcs_dofiles\SCMtraining.doh"
	}
	* Add iterations for robustness checks 
	if "`robust'"=="yes" {
		* Robustness using the baseline predictor variables
		foreach sfx of local robustchecks2 {
			local iterate `" `iterate' "`set'`sfx'" "'
			local suffixlist `" `suffixlist' "`sfx'" "'
		}
		* Robustness checks of predictor variables
		foreach n of numlist 1(1)10 {
			local iterate  `" `iterate' "`set'p`n'" "'
			local suffixlist `" `suffixlist' "p`n'" "'
		}	
	}
	* SCM analysis loop
	if "`SCM'"=="yes" {
		* run SCM analysis code
		include "`projectdir'\ctcs_dofiles\SCManalysis.doh"
	}
	*Add dropstate robustness checks
	if "`robust'"=="yes" {	
		foreach ST of local statelist {
			if "`ST'"!="`treatstate'" {
				local drop1s `" `drop1s' "`pass'_no`ST'"  "'
				di `drop1s'
			}	
		}	
	}
	local iteratemore  `" `iterate' `drop1s' "'	
	* SCM inference loop
	if "`INF'"=="yes" {
		* run SCM inference code
		include "`projectdir'\ctcs_dofiles\SCMinference.doh"
	}
}
* End Loop over set list 




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
