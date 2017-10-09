*************************************************
* Charitable Tax Credits Analysis
* CTC_IA.do
* 8/21/2017, version 1
* Dan Teles
*************************************************
* this file contains the analysis for Endow Iowa
* it can be called from CharitableTaxCredits.do
**************************************************
* Directories
**************************************************
local projectdir="D:\Users\dteles\Box Sync\DTeles\CharitableTaxCredits"
local datadir="`projectdir'\data"
local output="`projectdir'\output"
local project="IA"
**************************************************
* Locals to define which sections to run
**************************************************
local clean="no"
local sumstats="no"
local training="no"
local SCM="no"
local placebo="yes"
local inf="no"
local tables="no"
local graphs="yes"
**************************************************
* Locals Iteration Lists
**************************************************
local robustclass `" "TOP" "'
local primaryclasses `" "TOP" "'
local NPlist `" "UW" "SVDP" "HFH" "GW" "BGC" "BBBS" "'
local bigcatlist `" "ALL" "ITT" "' /*ITT is NTEE cat JLOPT (includes TOP)*/ 
local spilllist `" "ALLm" "' /* ALLm is ALL minus ITT*/
local sumsuffixes `" "89" "'
local trainingsuffixes `" `sumsuffixes' "np" "89np" "'
local SCMsuffixes `" `trainingsuffixes' "nst" "'
local neighborstates `" "CA" "NV" "UT" "CO" "NM" "'
**Locals: Which Iterations to Run***
local primary="yes"
local robust="yes"
local individualNPs="yes"
local bigcat="yes"
local spillover="yes"
**Locals: Other Options**
local besttrainyear=1994
***locals to determine which functional forms to run**********
local formlist =  `" "PC" "lnPC" "'
if "`robust'"=="yes" {
	local formlist = `" `formlist' "ln" "'
}
***********************************
****Locals to run more in-depth (slower) optimization procedure when using the cluster*******
if "`ccs'"=="yes" {
	local scmopts /*options for more precise optimization*/
}
if "`myPC'"=="yes" {
	local scmopts /*options for faster optimization*/
}
**************************************************
********CLEAN DATA****
************************************************
***Define Which iterations to run*****************
if "`primary'"=="yes" {
	local universe `" "org" "'
}
if "`bigcat'"=="yes" {
	local universe `" `universe' `bigcatlist' "'
	local COMP `" `bigcatlist' "'
}
if "`spillover'"=="yes" {
	local universe `" `universe' `spilllist' "'
	local COMP `" `COMP' `spilllist' "'
}
/* No Firmlevel DID dataset */ 

****Clean****
if "`clean'"=="yes" {
	foreach uni of local universe {
		clear all
		cd "`NCCSdir'"
		di "Creating dataset for `uni' "
		*local for comparison groups
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
			gen ITT = 0 /*Broad, Intent to Treat Category*/
			foreach cat in J L O P T {
			*Employment, Housing and Shelter, Youth, Human Services, Philanthropy*
				replace ITT=1 if NTEE1=="`cat'"
			}			
			*keep ITT
			if "`uni'"=="ITT" {
				keep if ITT==1
			}
			*drop ITT
			if "`uni'"=="ALLm" {
				drop if ITT==1
			}
			**ALL keeps everything
			collapse (sum) cont-compens nonprofits, by(state fisyr)
		}
		if "`uni'"=="org" {
			di "load NCCS firm level file"
			/*Load NCCS Data and create Top Nonprofits File*/
			use "`NCCSdir'CombinedNCCS.dta" 
			summarize
			***drop counting variables
			drop N n
			****Clean String Data****
			if "`uni'"=="org"{
				foreach var of varlist name state city {
					replace `var'=upper(`var')
					replace `var' = subinstr(`var', "&", " AND ",.)
					replace `var' = subinstr(`var', "-", " ",.)
					replace `var' = subinstr(`var', "/", " ",.)
					replace `var' = subinstr(`var', ",", " ",.)
					replace `var' = subinstr(`var', "INCORPORATED", "INC.",.)
					replace `var' = subinstr(`var', "CORPORRN", "CORP.",.)
					replace `var' = subinstr(`var', "  ", " ",.)
					replace `var' = subinstr(`var', "  ", " ",.)
					egen `var'2=sieve(`var'), keep(alphabetic numeric space)
					replace `var'=`var'2
					drop `var'2
					replace `var'=trim(`var')
					replace `var'=trim(`var')
				}
				/*Generate Variables for each of the top 20 orgs with national scope*/
				/* Note that Insufficient data is available for Catholic Charities and Disabled American Veterans */
				gen UW=1 if regexm(name, "UNITED WAY") | regexm(name, "UNITEDWAY")
				label var UW "United Way"
				gen SVDP=1 if regexm(name, "VINCENT DE PAUL") | regexm(name, "VINCENT DEPAUL")
				label var SVDP "St. Vincent De Paul Society"
				gen HFH=1 if regexm(name,"HABITAT FOR HUMANITY") 
				replace HFH=1 if regexm(name,"HFH") & nteecc=="L20"
				label var HFH "Habitat for Humanity"
				gen GW=1 if regexm(name, "GOODWILL INDUSTRIES") | regexm(name, "GOODWILL INDUSTRY")
				label var GW "Goodwill Industries"
				gen BGC=1 if regexm(name,"BOYS AND GIRLS CLUB")
				label var BGC "Boys and Girls Clubs"
				gen CC=1 if regexm(name,"CATHOLIC CHARITIES")
				label var CC "Catholic Charities"
				gen DAV=1 if regexm(name,"DISABLED AMERICAN VETERANS")
				label var DAV "Disabled American Veterans"
				gen BBBS=1 if regexm(name,"BIG BROTHERS BIG SISTERS")
				replace BBBS=1 if regexm(name,"BIG BROTHERS") & regexm(name, "BIG SISTERS")
				label var BBBS "Big Brotheres Big Sisters"
				foreach var of varlist UW-BBBS {
					count if `var'==1
				}
				gen keep=0
				foreach var of varlist UW-BBBS {
					replace keep=1 if `var'==1
				}
				keep if keep==1
				****Collapse to state level**********
				collapse (sum) cont-compens, by(fisyr state UW SVDP HFH GW BGC CC DAV BBBS)
			}
		}	
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
			sum `var'PC ln`var'PC
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
		*****reduce to 1989 to 2012**********
		keep if year>1988
		keep if year<2013
		*******save statelevel nonprofits file***************
		qui cd "`output'\datasets"
		if "`comp'"=="yes" {
			save AZ_`uni'_state, replace
		}
		if "`uni'"=="org" {
			save TopNonprofits, replace
			************************************
			*******aggregate Top Nonprofits*****
			************************************
			/* Note that Insufficient data is available for Catholic Charities and Disabled American Veterans in Arizona
				data is not available for all years, as such they are dropped before aggregation                        */
			drop if DAV==1 | CC==1
			******sum cont, progrev, totrev, collapse state-level controls
			collapse (sum) cont progrev totrev solicit contPC progrevPC totrevPC solicitPC (mean) POP POP_million INCperCAP gini top1 own_rev dir_exp own_revPC dir_expPC unemploymentrate, by(year AB NAME)
			**Convert the aggregated data to log form***
			foreach var of varlist cont progrev totrev solicit POP INCperCAP dir_exp own_rev {
				gen ln`var'=ln(`var'+.01)
			}
			**Convert aggregated Per Capita Data to Log***
			foreach var of varlist cont progrev totrev solicit dir_exp own_rev {
				gen ln`var'PC=ln(((`var'+.01)/POP))
			}
			**save aggregate file
			save TopNonprofits_aggregate, replace
		}
	}
}
******End Clean DATA*********************************






























***************************************
***Summary Statistics****
***************************************
/*Summary Stats*/
	/*classlist is list of main iterations (TOP Group, 6 Individual, ALL nonprofits)
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
if "`individualNPs'"=="yes" {
	local classlist `" `classlist' `NPlist' "'
}
local sumclasslist `" `classlist' "'
if "`robust'"=="yes" {
	foreach class of local robustclass {
		foreach sfx of local sumsuffixes {
			local sumclasslist = `" `sumclasslist' "`class'`sfx'" "'
		}
	}
}
/*Left Blank, No DD for Arizona











*/  
*******
di "SUMSTATS for : "
di `sumclasslist' 
if "`sumstats'"=="yes" {
	*****loop over each of the organizations and/or aggregates
	foreach class of local sumclasslist {
		di "-------------------------"
		di "Summary Statistics for `class'"
		di "-------------------------"
		*local for comparison groups
		local comp "no"
		foreach u of local COMP {
			if "`class'"=="`u'"{
				local comp "yes"
			}
		}
		local varlistBASE cont INCperCAP progrev solicit POP_million gini top1
		local varlistLOG lncont lnINCperCAP lnprogrev lnsolicit lnPOP gini top1
		local varlistPC contPC INCperCAP progrevPC solicitPC POP_million gini top1
		local varlistLNPC lncontPC lnINCperCAP lnprogrevPC lnsolicitPC lnPOP gini top1
		local varnames `" "Contributions" "Income" "Program_Revenue" "Fundraising" "Population" "Gini" "Top_1_Percent" "'
		**add num to varlist for complete state aggregate
		if "`class'"=="ALL" | "`class'"=="ALLm" | "`class'"=="ITT" {
			local varlistBASE `varlistBASE' nonprofits
			local varlistLOG `varlistLOG' lnnum
			local varlistPC `varlistPC' numPC
			local varlistLNPC `varlistLNPC' lnnumPC			
			local varnames `" `varnames' "Nonprofits" "'
		}
		****begin loop over functional form*****************
		foreach fform in BASE LOG PC LNPC {
			clear all
			qui cd "`output'\datasets"
			if "`class'"=="TOP" | "`class'"=="TOP89" {
				use TopNonprofits_aggregate
			}
			else if "`comp'"=="yes" {
				use AZ_`class'_state
			}
			else {
				use TopNonprofits
				keep if `class'==1
			}			
			keep if year>=1989 
			if "`class'"!="TOP89" {
				keep if year >=1990
			}	
			keep if year<=2012
			qui cd "`output'\tempfiles"
			********summary statistics for whole country*********			
				di "Summary Statistics for US `class': `fform' variables"
				sum `varlist`fform'' 
				tabstat `varlist`fform'',  s(mean sd) save
				matrix C=r(StatTotal)'
				matrix coln C ="US_Mean" "US_Std_deviation"
				matrix rown C = `varnames' 
			********Export data for Summary Graph, AZ vs. US***********		
			preserve
			gen AZ=0
			replace AZ=1 if AB=="AZ"
			gen NOT_AZ=1-AZ
			collapse (mean) `varlist`fform'' , by(AZ NOT_AZ year)
			save AZ_`class'vsUS_`fform', replace
			restore
			*******Define sample pool*********
			*Exclude Kansas, Michigan, Missouri, North Carolina, Virginia, West Virigina because they have or had similar programs
			drop if AB=="KS" | AB=="MI" | AB=="MO" | AB=="NC" | AB=="VA" | AB=="WV"
			*******summary statistics for Arizona*********
				di "Summary Statistics for Arizona `class': `fform' variables"
				sum `varlist`fform''  if AB=="AZ" 
				tabstat `varlist`fform''  if AB=="AZ" , s(mean sd) save
				matrix A=r(StatTotal)'
				matrix coln A ="AZ_Mean" "AZ_Std_deviation"
				matrix rown A = `varnames' 
			******summary statistics for sample pool*********
				di "Summary Statistics for DONOR STATES `class': `fform' variables"
				sum `varlist`fform''  if AB!="AZ" 
				tabstat `varlist`fform''  if AB!="AZ", s(mean sd) save
				matrix B=r(StatTotal)'
				matrix coln B ="Pool_Mean" "Pool_Std_deviation"
				matrix rown B = `varnames' 
			********Collapse data for Summary Graph, AZ vs. US vs. Sample Pool***********		
			drop if AB=="AZ"
			gen POOL=1
			collapse (mean) `varlist`fform'' POOL, by(year)
			*********Export Data for  Graph of AZ vs US vs Sample Pool********************	
			append using AZ_`class'vsUS_`fform'
			save AZ_`class'vsUS_`fform', replace			
			********Export Summary Statisitcs*******
			matrix  AZ_sumstats_`class'_`fform' = [A , B , C ]
			matrix list AZ_sumstats_`class'_`fform' 
			matsave AZ_sumstats_`class'_`fform', saving replace
			clear all
			use AZ_sumstats_`class'_`fform'
			qui cd "`output'\tables"
			export excel using "`output'\tables/AZ_SUMSTATS.xls", firstrow(variables) sheet("`class'_`fform'") sheetreplace
			matrix drop _all
		}
		******end loop over functional form***
	}
	***end loop over sumclasslist
}
*****End sumstats
*





































***************************************"
***Synthetic Control Analysis ****
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
***locals to determine which functional forms to run**********
local formlist =  `" "PC" "lnPC" "'
if "`robust'"=="yes" {
	local formlist = `" `formlist' "ln" "'
}
local iterate `" `classlist' `trainorders' "'
di "ADDITIONAL ITERATIONS ADDED FOR RUBISTNESS"
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
						di " `class' Robustness Check: `sfx'"
					}	
				}					
			}
		}	
		if "`sfx'"=="89"  local year1 = 1989
		else local year1 = 1990
		local lastyear=1997	
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
				di "Training Section for `pass' `fform'"
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
				if "`class'"=="ALL" | "`class'"=="ITT" {
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
				}
				if "`class'"!="ALL" & "`class'"!="ITT" {
					local number = ""
					local num = ""
				}
				****display output*********
				di "`fform' metrics are: `cont' `solicit' `num'"
				di "Pretreatment Period runs `year1' to `lastpreyear'.  Posttreatment Period runs `treatyear' to `lastyear'"
				di "--------------------------------------"
				*****perepare data************************
				clear all
				qui cd "`output'\datasets"
				***limit to class of interest***
				local comp "no"
					foreach u of local COMP {
						if "`class'"=="`u'"{
							local comp "yes"
						}
				}
				if "`class'"=="TOP" | "`class'"=="TOP89" {
					use TopNonprofits_aggregate
				}
				else if "`comp'"=="yes" {
					use AZ_`class'_state
				}
				else {
					use TopNonprofits
					keep if `class'==1
				}
				cd "`output'\tempfiles"
				keep if year>1988
				if `year1'==1990 {
					drop if year==1989
				}	
				keep if year<1998
				* remove states with missing years
				foreach var of varlist INCperCAP POP progrevPC solicitPC gini top1 contPC lncont lnprogrev lnsolicit{
					drop if `var'==.
				}
				foreach var of varlist INCperCAP POP contPC lncont {
					drop if `var'==0
				}
				 if "`class'"=="ALL" | "`class'"=="ITT" {
					drop if numPC==0
				}
				sort AB year
				by AB: gen N=_N
				if `year1'==1989 {
					keep if N==9
				}
				if `year1'==1990 {
					keep if N==8
				}	
				*generate local for Org-by-State Observations***
				encode AB, gen(stco)
				labmask stco, values(AB)
				qui sum stco
				local Numstates=r(max)
				di "------"
				di "There are `Numstates'  observations in the `pass' to `treatyear' training group"
				di "------"
				******begin loop for each of the predictors***********
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
								/*for now, not running nested on training*/									
									synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') 
								/*	capture synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') `scmopts'
								if _rc !=0{ //If error then run without nested option
									noi di "The error message for outcome `outcome', predvarslist `j',  control unit `i' is " _rc
									synth `outcome' `predictors', trunit(`i') trperiod(`treatyear') resultsperiod(`treatyear'(1)`lastyear') 
								}*/
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
				*****Export file of RMSPEs from each loop*******
				quietly{
					local tyr=`treatyear'-1900
					foreach outcome in `cont' `solicit' `num' {
						matrix AZ_`pass'_RMSPES`tyr'_`outcome'=[RMSPES_`outcome'_1, RMSPES_`outcome'_2, RMSPES_`outcome'_3, RMSPES_`outcome'_4, RMSPES_`outcome'_5, RMSPES_`outcome'_6, RMSPES_`outcome'_7, RMSPES_`outcome'_8, RMSPES_`outcome'_9, RMSPES_`outcome'_10]
						mat rownames AZ_`pass'_RMSPES`tyr'_`outcome'= `names' 
						matsave AZ_`pass'_RMSPES`tyr'_`outcome', saving replace
						matrix AZ_`pass'_INDEX`tyr'_`outcome'=[FITINDEX_`outcome'_1, FITINDEX_`outcome'_2, FITINDEX_`outcome'_3, FITINDEX_`outcome'_4, FITINDEX_`outcome'_5, FITINDEX_`outcome'_6, FITINDEX_`outcome'_7, FITINDEX_`outcome'_8, FITINDEX_`outcome'_9, FITINDEX_`outcome'_10]
						mat rownames AZ_`pass'_INDEX`tyr'_`outcome'= `names' 
						matsave AZ_`pass'_INDEX`tyr'_`outcome', saving replace
						matrix AZ_`pass'_INDEXA`tyr'_`outcome'=[FITINDEXA_`outcome'_1, FITINDEXA_`outcome'_2, FITINDEXA_`outcome'_3, FITINDEXA_`outcome'_4, FITINDEXA_`outcome'_5, FITINDEXA_`outcome'_6, FITINDEXA_`outcome'_7, FITINDEXA_`outcome'_8, FITINDEXA_`outcome'_9, FITINDEXA_`outcome'_10]
						mat rownames AZ_`pass'_INDEXA`tyr'_`outcome'= `names' 
						matsave AZ_`pass'_INDEXA`tyr'_`outcome', saving replace
					}
				}
				di " RMSPE and FIT INDEX Matrices for `pass' `fform' saved"
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
local iterate `" `classlist' `SCMorders' "'
di `iterate'
**************************************************	
*******SCM  FOR REALS******************************
**************************************************
if "`SCM'"=="yes" {
	di "-------------"
	di "-------------"
	di "Current Version runs the following iterations"
	di `iterate'
	di "-------------"
	***define class and years****
	foreach pass of local iterate {
		di ""
		di "---------------------------------------------"
		di "This is the SCM section for iteration: `pass'"
		****Define class and Years
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
			if "`sfx'"=="89"   local year1 = 1989
			else local year1 = 1990
		}
		local treatstate AZ
		foreach state of local neighborstates {
			if "`class'"=="`state'" {
				local treatstate `state'
			}	
		}	
		local treatyear=1998
		local lastpreyear=`treatyear'-1
		local lastyear=2012
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
				foreach var in  cont progrev totrev solicit num {
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
			local lagpredictors ``cont'1' ``cont'2'  ``cont'3'  ``cont'4'  ``cont'5'  ``cont'6'  ``cont'7' ``cont'8' ``cont'9' ``cont'10'
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
			local otherpredictors_fund `INCperCAP' `pop' `progrev' gini top1
			local otherpredictors2_fund `otherpredictors' ``INCperCAP'1' `pop1' ``progrev'1' `gini1' `top11'  ``INCperCAP'L' `popL' ``progrev'L'  `giniL' `top1L' 
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
			if "`class'"=="ALL" | "`class'"=="ITT" {
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
			}
			else {
				local number = ""
				local num = ""
			}
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
				if "`pass'"=="`class'" & "`treatstate'"!="AZ" {
					local trainpass TOP
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
						qui cd "`output'\tempfiles"
						use AZ_`trainpass'_RMSPES`tyr'_`outcome', clear
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
						if `tyr'==`trainyear' 	local keepnum_`outcome'_`pass' = keeper
						**********Export Tables Showing Goodness of fit****************
						if "`trainpass'"=="`pass'" {
							qui cd "`output'\tempfiles"
							foreach fit in INDEX INDEXA {
								use AZ_`trainpass'_`fit'`tyr'_`outcome', replace
								foreach x of numlist 1/10 {
									qui sum group`x'
									scalar A`fit'_`x'=r(mean)
								}
							}
							foreach fit in RMSPE INDEX INDEXA {
								matrix `fit'`tyr'_`pass'_`outcome' = [A`fit'_1 \  A`fit'_2 \ A`fit'_3 \ A`fit'_4 \ A`fit'_5 \ A`fit'_6 \ A`fit'_7 \ A`fit'_8 \ A`fit'_9 \ A`fit'_10]
								matrix colnames `fit'`tyr'_`pass'_`outcome' = "AVG`fit'"
							}
							matrix AZ_AVFIT_`pass'`tyr'_`outcome' = [RMSPE`tyr'_`pass'_`outcome' , INDEX`tyr'_`pass'_`outcome' , INDEXA`tyr'_`pass'_`outcome']
							matsave AZ_AVFIT_`pass'`tyr'_`outcome' , saving replace
							matrix drop _all
							scalar drop _all
							clear
							use AZ_AVFIT_`pass'`tyr'_`outcome' 
							qui cd "`output'\tables"
							export excel using "`output'\tables/AZ_AVRMSPES_`outcome'.xls", firstrow(variables) sheet("`pass'`tyr'") sheetreplace		
							matrix drop _all
						}
					}
					***end loop over trainyears
					di "----------------"
					di "For `pass' the best fit for `outcome' is with predictor set number `keepnum_`outcome'_`pass''"
				}
				********End outcome var loop
			}	
			*****End Loop Calculating Best Fit Predictor Variables
			*****perepare data************************
			clear all
			qui cd "`output'\datasets"
			***limit to class of interest***
			local comp "no"
				foreach u of local COMP {
					if "`class'"=="`u'"{
						local comp "yes"
					}
			}
			if "`class'"=="TOP" | "`class'"=="TOP89" | "`class'"=="`treatstate'" {
				use TopNonprofits_aggregate
			}
			else if "`comp'"=="yes" {
				use AZ_`class'_state
			}
			else {
				use TopNonprofits
				keep if `class'==1
			}
			qui cd "`output'\tempfiles"			
			keep if year>1988
			if `year1'==1990 {
				drop if year == 1989
			}	
			keep if year<2013
			*Exclude Kansas, Michigan, Missouri, North Carolina, Virginia, West Virigina because they have or had similar programs
			drop if AB=="KS" | AB=="MI" | AB=="MO" | AB=="NC" | AB=="VA" | AB=="WV"			
			****Robustness using only neighboring states***********
			if "`sfx'"=="nst" {
				gen keepstate=0
				replace keepstate=1 if AB=="AZ"
				foreach state of local neighborstates {
					replace keepstate=1 if AB=="`state'"
				}
				keep if keepstate==1
				drop keepstate
			}
			* remove states with missing years
			
			if "`class'" != "ALL" {			
				foreach var of varlist INCperCAP POP gini top1 `cont' {
					drop if `var'==.
				}
				foreach var of varlist INCperCAP POP `cont'{
					drop if `var'==0
				}
				foreach var of varlist `progrev' `solicit' {
					if "`fform'"=="ln" | "`fform'"=="lnPC" {
						qui sum `var'
						local `var'min=r(min)
						replace `var'=``var'min' if `var'==.
					}
					else {
						replace `var'=0 if `var'==.
					}	
				}
				sort AB year
				by AB: gen N=_N
				if `year1'==1989 {
					keep if N==24
				}
				if `year1'==1990 {
					keep if N==23
				}
			}
			*generate running code variable  for each state(FIPS has missing variables)
			encode AB if AB!="`treatstate'", gen(stco)
			replace stco=99 if AB=="`treatstate'"
			labmask stco, values(AB)
			save `project'_`pass'_`fform', replace
			*generate local for number of states in sample pool
			qui sum stco if stco!=99
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
			if "`class'" == "ALL" {
				local z = `keepnum_`num'_`pass''
			}
			***RUN SCM on Arizona************
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
				resultsperiod(`year1'(1)`lastyear') `scmopts' keep(AZ_SCM_`pass'_`outcome', replace)
				if _rc !=0{ //If error then run without nested option
					noi di "The error message for outcome `outcome', pass `pass' is " _rc
					synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
					resultsperiod(`year1'(1)`lastyear') keep(AZ_SCM_`pass'_`outcome', replace)
				}					
				**create matrices
				matrix AZ_`pass'_DIFF_`outcome'=e(Y_treated)-e(Y_synthetic)
				di "AZ_`pass'_DIFF_`outcome' created"
				matrix AZ_`pass'_V_`outcome' = vecdiag(e(V_matrix))'
				di "AZ_`pass'_V_`outcome' created"
				matrix AZ_`pass'_W_`outcome'=e(W_weights)
				local rownum = rowsof(AZ_`pass'_W_`outcome') //number of potential control units
				local control_units_rowname: rown AZ_`pass'_W_`outcome' // save name of potential control units in local control_units_rowname
				matrix colnames AZ_`pass'_W_`outcome'="stco" "weight"
				di "AZ_`pass'_W_`outcome' created"					
				matrix balance = e(X_balance)
				**save matrices
				matsave AZ_`pass'_DIFF_`outcome', saving replace
				matrix list AZ_`pass'_V_`outcome'
				matsave AZ_`pass'_V_`outcome', saving replace				
				matsave AZ_`pass'_W_`outcome', saving replace
				*******************************
				****Leave 1 Out Tests**********
				*******************************
				if "`robust'"=="yes"  & "`doextra'"=="yes" {
					matrix donors=AZ_`pass'_W_`outcome' /* matrix name too long for variable names*/
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
						resultsperiod(`year1'(1)`lastyear') `scmopts' keep(AZ_SCM_`pass'_no`AB`l''_`outcome', replace)
						** If nested gives problem then run without nested and allopt option
						if _rc !=0{
							noi di "The error code for LOO run `l' is " _rc
							qui synth `outcome' `predictors', trunit(99) trperiod(`treatyear')  ///
							resultsperiod(`year1'(1)`lastyear') keep(AZ_SCM_`pass'_no`AB`l''_`outcome', replace)
						}
						matrix AZ_`pass'_no`AB`l''_DIFF_`outcome'=e(Y_treated)-e(Y_synthetic)
						matsave AZ_`pass'_no`AB`l''_DIFF_`outcome', saving replace
						di "AZ_`pass'_no`AB`l''_DIFF_`outcome' created"
						matrix AZ_`pass'_no`AB`l''_V_`outcome' =vecdiag(e(V_matrix))'
						di "AZ_`pass'_no`AB`l''_V_`outcome'  created"
						matsave AZ_`pass'_no`AB`l''_V_`outcome', saving replace
						matrix AZ_`pass'_no`AB`l''_W_`outcome' =e(W_weights)
						matrix colnames AZ_`pass'_no`AB`l''_W_`outcome' ="stco" "weight"
						matsave AZ_`pass'_no`AB`l''_W_`outcome', saving replace
						di "AZ_`pass'_no`AB`l''_W_`outcome'  created"		
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
					save AZ_`pass'_`outcome'_donorlist, replace
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
					cd "`output'\tempfiles"
					save `project'_temp, replace
					di "--------"
					if `l'==0 {
						di "Placebo loop for `pass' `outcome' baseline"
					}
					if `l' !=0 {
						di "Placebo loop for `pass' `outcome' no `AB`l'' "
						drop if stco==`l'
						di "dropped `AB`l'' stco `l'"
						*regenerate stco to be consecutive numbers
						qui gen AB2=AB
						sort AB2 year
						encode AB2 if AB!="`treatstate'", gen(stco2)
						qui replace stco2=99 if AB=="`treatstate'"
						qui replace stco=stco2
						labmask stco, values(NAME)
						qui sum stco
						qui drop stco2 AB2
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
					qui cd "`output'\tempfiles"
					save `project'_`pass'_`fform'_`outcome'_altcrosswalk, replace
					restore
					*****Placebo Synth
					qui {
						***generate local for number of controls***
						sum stco if stco<99
						local NumCntrl = r(max)
						di "NumCntrl is `NumCntrl'"
						local plnames = ""
						*******Placebo loop
						forvalues i = 1/`NumCntrl' {
							*define time series
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
								matrix AZ_`pass'_PW_`outcome'`i'=e(W_weights)'
								matsave AZ_`pass'_PW_`outcome'`i' , saving replace
							}	
							local plnames `"`plnames' `"pl`i'"' "'
						}
						*****end placebo loop
						*di "end placebo loop"
						****end quietly
						***display list of placebo names
						*di " placebo names:"
						*di `plnames'
						***Create matrix of differences********	
						if `l'==0 {
							matrix AZ_`pass'_PL_`outcome'= `diffmat_`outcome'_`l'''
							mat colnames AZ_`pass'_PL_`outcome' = `plnames'
						}
						if `l' !=0 {
							matrix AZ_`pass'_no`AB`l''_PL_`outcome'= `diffmat_`outcome'_`l'''
							mat colnames AZ_`pass'_no`AB`l''_PL_`outcome' = `plnames'								
						}
						****save AZ_`pass'_SCM_PL as a stata file for use in Placebo Graphs			
						if `l'==0 {
							*di "Save All Placebos Difference Matrix `outcome'"
							matsave AZ_`pass'_PL_`outcome' , saving replace
						}
						if `l' !=0 {
							*di "Save All Placebos Difference Matrix `outcome'"
							matsave AZ_`pass'_no`AB`l''_PL_`outcome' , saving replace
						}
						matrix drop _all
					}
					**End Quitely
					use `project'_temp, replace
				}
				***End loop over placebo Tests*****
				***Export W and V Matrixes into Excel
				preserve
				qui cd "`output'\tempfiles"			
				use AZ_`pass'_W_`outcome', replace
				export excel using "`output'\tables/AZ_W_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
				use AZ_`pass'_V_`outcome', replace
				export excel using "`output'\tables/AZ_V_`outcome'.xls", firstrow(variables) sheet("`pass'") sheetreplace
				if "`robust'"=="yes" & "`doextra'"=="yes" {
					di "..exporting leave one out robustness check tables too"
					foreach l of local posi_donors {
						use AZ_`pass'_no`AB`l''_W_`outcome', replace
						qui export excel using "`output'\tables/AZ_W_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
						use AZ_`pass'_no`AB`l''_V_`outcome', replace
						qui export excel using "`output'\tables/AZ_V_`outcome'.xls", firstrow(variables) sheet("`pass'_no`AB`l''") sheetreplace
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
******Statistical Inference ***************	
*****************************************************
di `iterate'
local statelist AL AK AR CA CO CT DE DC FL GA HI ID IN IL IA KS KY LA ME MA MI MD MN MS MO MT NE NV NH NJ NM NY NC ND OH OR OK PA RI SC SD TN TX UT VT VI WV WA WI WY 
if "`robust'"=="yes" {
	foreach pass of local robustclass {	
		foreach ST of local statelist {
			local drop1s `" `drop1s' "`pass'_no`ST'"  "'
		}	
	}
}
local iteratemore  `" `iterate' `drop1s' "'
if  "`inf'"=="yes" {
	**robustness checks for leave one out analysis***\
	di "-----------------------"
	di "Statistical Inference:"
	di "Current Version runs the following iterations"
	di `iteratemore'
	di "-------------"
	*****loop over each iteration*******************
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
		***end loop defing class sfx
		local treatstate AZ
		foreach state of local neighborstates {
			if "`class'"=="`state'" {
				local treatstate `state'
			}	
		}	
		***define years
		local treatyear=1998
		local lastpreyear=`treatyear'-1
		if "`sfx'"=="89" local year1 = 1989
		else local year1 = 1990
		local lastyear=2012
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
		if "`sfx'"=="93" | "`sfx'"=="93_no`dropstate'" {
			di "Training Period uses treatment year 1993"
		}
		else if "`sfx'"=="95" | "`sfx'"=="95_no`dropstate'" {
			di "Training Period uses treatment year 1995"
		}
		else if "`sfx'"=="9095" | "`sfx'"=="9095_no`dropstate'" {
			di "Training Period uses treatment year 1995"
		}
		else di "Training Period uses treatment year 1994"
		**************************************************
		if "`dropstate'"!="" di " `dropstate' removed from sample pool" 
		di "Year 1 = `year1', Treatment Year = `treatyear'"
		****Define sections to run**********
		local outcomelist = `" "contPC" "solicitPC" "lncontPC" "lnsolicitPC" "'
		if "`robust'"=="yes" {
			local outcomelist =`" `outcomelist' "lncont" "lnsolicit" "'
		}
		if "`class'"=="ALL" {
			local outcomelist = `" `outcomelist' "numPC" "lnnumPC" "'
			if "`robust'"=="yes" {
				local outcomelist = `" `outcomelist' "lnnum" "'
			}				
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
			if "`robust'"=="yes" {
				local runlncont = "yes"
				local runlnsolicit = "yes"
			}
			if "`class'"=="ALL" {
				local runnumPC="yes"
				local runlnnumPC="yes"
				if "`robust'"=="yes" {
					local runlnnum = "yes"
				}				
			}	
		}	
		***check to see if state is used as robustness check***
		if "`robust'"=="yes" & "`pass'"!="`family'" {
			foreach outcome of local outcomelist {
				qui cd "`output'\tempfiles"
				qui use AZ_`family'_`outcome'_donorlist, clear
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
		/*if "`runnone'"=="yes" {
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
		}	*/
		***************************************************
		********Generate DD Estimator and P Value*************
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
				********Generate values of Synthetic Arizona with Gov't Funding******
				/*only for aggregated Top6 Group and Total Aggregate (ALL)************/
				if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
					if "`class'"=="TOP" | "`class'"== "ITT" | "`class'"=="ALL" { 
						clear all 
						di "...generating contribution levels net of government funding"
						*qui {
							qui cd "`datadir'"
							if "`class'"== "ITT" | "`class'"=="ALL" {
								use AZ_Credits_Awarded
							}
							else if "`class'"=="TOP" {
								use AZTOP_Credits_Awarded
							}
							qui cd "`output'\tempfiles"
							merge 1:m _time using AZ_SCM_`pass'_`outcome'
							drop _merge
							if "`outcome'"=="contPC" {
								gen _Y_expected = _Y_synthetic+creditsPC
							} 
							if "`outcome'"=="lncontPC" {
								gen _Y_expected=ln(exp(_Y_synthetic)+(creditsPC))	
							}
							if "`outcome'"=="lncont" {
								gen _Y_expected=ln(exp(_Y_synthetic)+(credits_adj))	
							}
							gen NETDIFF=_Y_treated - _Y_expected
							rename _time year
							noi save AZ_NET_`pass'_`outcome', replace
							rename year _rowname
							keep _rowname NETDIFF
							drop if _rowname==.		
							tostring _rowname, replace
							recast str4 _rowname
							noi save AZ_`pass'_DIFF_`outcome'_NET, replace
						*}
					}
				}
				***************************************************************
				********Generate DD Estimators and P Values************
				clear all
				***Load Diff files (difference between Treat and Synth****
				di "Load AZ_`pass'_DIFF_`outcome'"			
				qui cd "`output'\tempfiles"
				use AZ_`pass'_DIFF_`outcome'
				rename c1 DIFF
				***For TOP, CONT: merge with file of Differences net of Gov't funding******
				if "`outcome'"=="lncont"  | "`outcome'"=="contPC"  | "`outcome'"=="lncontPC"   {		
					if "`class'"=="TOP" | "`class'"=="ALL" | "`class'"=="ITT" { 
						di "merge with AZ_`pass'_DIFF_`outcome'_NET"
						qui merge 1:1 _rowname using AZ_`pass'_DIFF_`outcome'_NET
						drop _merge
					}
				}
				**merge together file of differences between observation and synth with placebos.
				di "merge with AZ_`pass'_PL`suffix'_`fform'"
				qui merge 1:1 _rowname using AZ_`pass'_PL_`outcome'
				drop _merge
				***destring and rename year variable
				qui destring _rowname, replace
				qui rename _rowname year
				save AZ_PL_GRAPH_`pass'_`outcome', replace
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
					if "`class'"=="TOP" | "`class'"== "ITT" | "`class'"=="ALL" {
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
				****calculate DD and RMSPE Ratio Estimators for Placebos*******
				tempname DDmat	
				local DDcount=0
				tempname RRmat	
				local RRcount=0
				tempname DDmat2	
				local DDcount2=0
				tempname RRmat2	
				local RRcount2=0
				qui describe
				local NumCntrl =r(k)-3
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					if "`class'"=="TOP" | "`class'"=="ALL" | "`class'"=="ITT" {	
						local NumCntrl=r(k)-4
						/*TOP has an extra variables NET DIFF */
					}
				}			
				forvalues i = 1/`NumCntrl' {
					qui sum pl`i' if year<`treatyear'
					local DIFF_PRE=r(mean)				
					qui sum pl`i' if year>=`treatyear'
					local DIFF_POST=r(mean)
					scalar DD=`DIFF_POST'-`DIFF_PRE'
					matrix `DDmat' = nullmat(`DDmat')\DD					
					qui gen pl`i'_2=pl`i' * pl`i'
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
				if "`pass'"=="`family'" {
					di "..calculating and saving the DD estimators for the placebo tests on `pass' (`outcome') are:"
					matrix AZ_`pass'_DDmat_`outcome' = `DDmat'
					matsave AZ_`pass'_DDmat_`outcome'	, saving replace
					di "..calculating and saving the RMSPE Ratio estimators for the placebo tests on `pass' (`outcome') are:"
					matrix AZ_`pass'_RRmat_`outcome'=`RRmat'
					matsave AZ_`pass'_RRmat_`outcome', saving replace	
					if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC"{		
						di "..calculating and saving the DD estimators for the placebo tests on `pass' (`outcome') with cutoff are:"
						matrix AZ_`pass'_DDmat_`outcome'2 = `DDmat2'
						matsave AZ_`pass'_DDmat_`outcome'2, saving replace
						di "..calculating and saving the RMSPE Ratio estimators for the placebo tests on `pass' (`outcome') with cutoff  are:"
						matrix AZ_`pass'_RRmat_`outcome'2=`RRmat2'
						matsave AZ_`pass'_RRmat_`outcome'2, saving replace				
					}
				}
				if "`pass'"!="`family'" {
					di "..calculating and saving the DD estimators for the placebo tests on `pass' (`outcome') are:"
					matrix AZ_`pass'_DDM_`outcome' = `DDmat'
					matsave AZ_`pass'_DDM_`outcome'	, saving replace
					di "..calculating and saving the RMSPE Ratio estimators for the placebo tests on `pass' (`outcome') are:"
					matrix AZ_`pass'_RRM_`outcome'=`RRmat'
					matsave AZ_`pass'_RRM_`outcome', saving replace	
					if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC"{		
						di "..calculating and saving the DD estimators for the placebo tests on `pass' (`outcome') with cutoff are:"
						matrix AZ_`pass'_DDM_`outcome'2 = `DDmat2'
						matsave AZ_`pass'_DDM_`outcome'2, saving replace
						di "..calculating and saving the RMSPE Ratio estimators for the placebo tests on `pass' (`outcome') with cutoff  are:"
						matrix AZ_`pass'_RRM_`outcome'2=`RRmat2'
						matsave AZ_`pass'_RRM_`outcome'2, saving replace				
					}
				}
				******Calcualate P Values****
				foreach metric in DD RR {
					**STANDARD P VALUE********
					clear all
					if "`pass'"=="`family'" {
						use AZ_`pass'_`metric'mat_`outcome'
					}	
					if "`pass'"!="`family'" {
						use AZ_`pass'_`metric'M_`outcome'
					}
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
					***P value for NET OF CREDITS (TOP ONLY)*
					if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
						if "`class'"=="TOP" | "`class'"=="ALL" {
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
					***P-VALUE FOR FUNDRAISING THROUGH 2007****
					if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
						if "`pass'"=="`family'" {
							use AZ_`pass'_`metric'mat_`outcome'2, clear
						}	
						if "`pass'"!="`family'" {
							use AZ_`pass'_`metric'M_`outcome'2, clear
						}
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
				}
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					matrix `outcome'MAT2 = [9999, 9999, 9999, 9999]
				}
			}	
			foreach outcome of local outcomelist {
				matrix `outcome'MAT = [`DD_`outcome'', `DD_pval_`outcome'', `RR_`outcome'', `RR_pval_`outcome'' ]
				if "`outcome'"=="lncont" | "`outcome'"=="contPC" | "`outcome'"=="lncontPC" {		
					if "`class'"=="TOP" | "`class'"== "ITT" | "`class'"=="ALL" {
						matrix `outcome'MATNET = [`DDNET_`outcome'', `DDNET_pval_`outcome'', `RRNET_`outcome'', `RRNET_pval_`outcome'' ]
					}
				}
				if "`outcome'"=="lnsolicit" | "`outcome'"=="solicitPC" | "`outcome'"=="lnsolicitPC" {		
					matrix `outcome'MAT2 = [`DD_`outcome'2', `DD_pval_`outcome'2', `RR_`outcome'2', `RR_pval_`outcome'2' ]
				}
			}
			matrix AZ_estimators_`pass' = [contPCMAT \ lncontMAT \ lncontPCMAT \ contPCMATNET \ lncontMATNET \ lncontPCMATNET \solicitPCMAT \ lnsolicitMAT \ lnsolicitPCMAT \ solicitPCMAT2 \ lnsolicitMAT2 \ lnsolicitPCMAT2 \ numPCMAT \ lnnumMAT \ lnnumPCMAT ]
			matrix rown AZ_estimators_`pass' =  "ContPC" "lnCont" "lnContPC" "ContPC_net" "lnCont_net" "lnContPC_net" "SolicitPC_to12" "lnSolicit_to12" "lnSolicitPC_to12" "SolicitPC_to07" "lnSolicit_to07" "lnSolicitPC_to07" "NumPC" "lnNum" "lnNumPC"
			matrix coln AZ_estimators_`pass' = "DD" "DD_pval" "Ratio" "Ratio_pval"
			qui matsave AZ_estimators_`pass', saving replace
			clear all
			use AZ_estimators_`pass'
			export excel using "`output'\tables/AZ_estimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
			matrix drop _all
			di "------------------------------------"
			*************************************************************************
			******INFERENCE USING ALTERNATE SYNTHETIC CONTROLS******
			*************************************************************************
			if "`pass'" =="`class'" { 
				di "----"
				di "ALT OUTPUT FOR Pass:"
				di "`pass'"
				***Generate Synthetic Controls using weights from alternate output varaibles****
				di "SCM was run on:"
				di `" `outcomelist' "'
				local allYs cont solicit dir_exp own_rev
				if "`pass'"=="ALL" {
					local allYs `allYs' num
				}
				foreach outcome of local outcomelist {
					foreach Y in cont solicit num {
						if "`outcome'"=="`Y'PC" {
							local fform = "PC"
							foreach var in  `allYs' {
								local `var' `var'PC
							}
							local INCperCAP INCperCAP
						}
						if "`outcome'"=="ln`Y'" {
							local fform = "ln"
							foreach var in `allYs'  {
								local `var' ln`var'
							}
							local INCperCAP lnINCperCAP
						}
						if "`outcome'"=="ln`Y'PC" {
							local fform = "lnPC"
							foreach var in `allYs'  {
								local `var' ln`var'PC
							}
							local INCperCAP lnINCperCAP
						}
					}
					**Create File of Placebo Weights******
					di "--------------------"
					di "create AZ_`pass'_PW_`outcome'"
					clear all
					qui cd "`output'\tempfiles"
					**count placebos** (altcrosswalk drops high and low)
					use `project'_`pass'_`fform'_`outcome'_altcrosswalk
					qui sum  stco if stco<99
					local numplacebos = r(max)
					**merge together placebo weights
					foreach n of numlist 1/`numplacebos' {
						use AZ_`pass'_PW_`outcome'`n', replace
						qui keep if _rowname == "_W_Weight"
						qui save AZ_`pass'_PW_`outcome'`n', replace
					}
					use AZ_`pass'_PW_`outcome'1, replace
					foreach n of numlist 2/`numplacebos' {
						append using AZ_`pass'_PW_`outcome'`n'
					}
					**generate AB based on missing columns
					drop _rowname
					qui gen AB = ""
					foreach st of local statelist {
						capture replace AB="`st'" if `st'==.
						if "`pass'"=="`st'" {
							replace AB="AZ" if AZ==.
							qui count
							local numstates=r(N)
						}
					}
					merge 1:1 AB using AZcredit_`pass'_`fform'_stcocrosswalk
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
					save AZ_`pass'_PW_`outcome', replace
					di "Load `project'_`pass'_`fform'"
					use `project'_`pass'_`fform', replace
					****Define variables by fform****
					local altvars  `cont' `solicit' `dir_exp' `own_rev' `INCperCAP' unemploymentrate top1 
					local synthvars  synth_`cont' synth_`solicit' synth_`dir_exp' synth_`own_rev' synth_`INCperCAP' synth_unemploymentrate synth_top1 
					di "Merge in W matrix AZ_`pass'_W_`outcome' and AZ_`pass'_PW_`outcome' "
					qui {
						merge m:1 stco using AZ_`pass'_W_`outcome'
						drop _merge
						sort stco year
						rename weight W_99
						merge m:1 AB using AZ_`pass'_PW_`outcome'
						drop _merge
						save AZ_`pass'_ALTOUT_`outcome'_temp, replace
						noi di "...generating values of alternate outcome variables using W weights"
						foreach st of numlist 99 1/`numstates' {
							use AZ_`pass'_ALTOUT_`outcome'_temp, replace
							gen treated=0
							replace treated=1 if stco==`st'
							foreach var of varlist `altvars' {
									gen synth_`var' = `var'*W_`st'
									replace synth_`var'=`var' if treated==1
							}
							collapse (sum) `synthvars', by(treated year)
							if `st'==99 {
								noi save AZ_`pass'_ALTOUT_`outcome', replace
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
							noi save AZ_`pass'_ALTOUT_`outcome'_wide, replace
							}
							else {
								foreach var in `cont' `solicit' {
									preserve
									gen pl`st'= `var'_treated-`var'_synthetic
									keep year pl`st'
									save AZ_`pass'_ALT_`var'w`outcome'_PL`st', replace
									restore
								}
							}
						}
						foreach var in `cont' `solicit' {
							use AZ_`pass'_ALT_`var'w`outcome'_PL1, replace
							foreach st of numlist 2/`numstates' {
								merge 1:1 year using AZ_`pass'_ALT_`var'w`outcome'_PL`st'
								drop _merge
							}
							noi save AZ_`pass'_ALT_`var'w`outcome'_PL, replace
						}
						***end loop over placebos
					}
					*end quietly
				}	
				***end loop over outcomes*****
				***Generate Synthetic Controls using averages from control groups****
				foreach controlgroup in neighbor national {
					qui cd "`output'\tempfiles"
					di "Load `project'_`pass'_`fform'"
					use `project'_`pass'_`fform', replace
					qui {
						if "`controlgroup'"=="neighbor" {
							noi di "...generating values of alternate outcome variables average of neighbors"
							gen keepstate=0
							replace keepstate=1 if AB=="AZ"
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
					save AZ_`pass'_ALTOUT_`controlgroup'avg, replace	
					***reformat ALTOUT so that synth and treated are seperate columns*******
					di "....reformatting"
					qui {
						reshape wide `altvars', i(year) j(treated)
						foreach var in `altvars' {
							rename `var'1 `var'_treated
							rename `var'0 `var'_synthetic
						}
						noi save AZ_`pass'_ALTOUT_`controlgroup'avg_wide, replace
					}
					*end quietly
				}	
				****end loop over neighbor and national		
				****Inference on Alternative Outcomes****
				if "`pass'"=="TOP" | "`pass'"=="ALL" {
					di "Inference on Alternative Controls"
					foreach altoutput in solicit neighboravg nationalavg {					
						foreach fform in PC lnPC {
							if "`fform'"=="PC" {
								foreach var in cont solicit dir_exp own_rev  {
									local `var' `var'PC
								}
								local INCperCAP INCperCAP
							}
							if "`fform'"=="ln" {
								foreach var in cont solicit dir_exp own_rev {
									local `var' ln`var'
								}
								local INCperCAP lnINCperCAP
							}
							if "`fform'"=="lnPC" {
								foreach var in cont solicit dir_exp own_rev {
									local `var' ln`var'PC
								}
								local INCperCAP lnINCperCAP
							}
							if "`altoutput'"=="solicit" {
								local alt ``altoutput''
								di "using weights from `alt'"
							}
							else {
								local alt `altoutput'
								di "using `alt'"
							}	
							qui cd "`output'\tempfiles"
							use AZ_`pass'_ALTOUT_`alt'_wide, replace
							rename `cont'_treated _Y_treated
							rename `cont'_synthetic _Y_synthetic
							rename year _time
							keep _Y_treated _Y_synthetic _time
							***merge in Credits data****
							qui cd "`datadir'"
							if "`pass'"=="TOP" {
								qui merge 1:1  _time using AZTOP_Credits_Awarded
								drop _merge 
							}		
							if "`pass'"=="ALL" {
								qui merge 1:1  _time using AZ_Credits_Awarded
								drop _merge
							}	
							if "`fform'"=="PC" {
								gen _Y_expected = _Y_synthetic+creditsPC
							} 
							if "`fform'"=="lnPC" {
								gen _Y_expected=ln(exp(_Y_synthetic)+creditsPC)
							}
							gen DIFF = _Y_treated - _Y_synthetic
							gen NETDIFF=_Y_treated - _Y_expected
							rename _time year
							keep year DIFF NETDIFF
							drop if year==.
							qui cd "`output'\tempfiles"
							if "`altoutput'"=="solicit" {
								merge 1:1 year using AZ_`pass'_ALT_`cont'w`alt'_PL
								drop _merge
							}								
							********Generate DD Estimator and P Value for DONATIONS************
							di "ALTOUT Inference: DD and Ratio for `cont' using `alt' weights"
							****Loop for DD and Ratio over GR and NET****
							foreach diff in GR NET {
								if "`diff'"=="GR" {
									local AZ = "DIFF"
								}
								if "`diff'"=="NET" {
									local AZ = "NETDIFF"
								}
								**Calculate DD Estimator****
								qui sum `AZ' if year>=`treatyear'
								local DIFF_POST=r(mean)
								qui sum `AZ' if year<`treatyear'
								local DIFF_PRE=r(mean)				
								local DD`diff'_`cont'w`alt'=`DIFF_POST'-`DIFF_PRE'
								di "The DD `diff'_`cont'w`alt' estimator is:"
								di `DD`diff'_`cont'w`alt''
								**Calculate RR Estimator
								qui gen `AZ'2 = `AZ'*`AZ'
								qui sum `AZ'2 if year>=`treatyear'
								local RMSPE_POST=sqrt(r(mean))
								qui sum `AZ'2 if year<`treatyear'
								local RMSPE_PRE=sqrt(r(mean))							
								local RR`diff'_`cont'w`alt'=`RMSPE_POST'-`RMSPE_PRE'
								di "The RR `diff'_`cont'w`alt' estimator is:"
								di `RR`diff'_`cont'w`alt''		
								drop `AZ'2	
								******Calcualate P Values for altout w/ solicit weights****
								if "`altoutput'"=="solicit" {
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
										local NumCntrl =r(k)-3
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
										matrix AZ_`pass'_DDmat_contw`alt' = `DDmat'
										matsave AZ_`pass'_DDmat_contw`alt'	, saving replace
										matrix AZ_`pass'_RRmat_contw`alt'=`RRmat'
										matsave AZ_`pass'_RRmat_contw`alt', saving replace	
									}
									******Calcualate P Values****
									foreach metric in DD RR {
										**ALTOUT STANDARD P VALUE********
										preserve
										clear all
										use AZ_`pass'_`metric'mat_contw`alt'
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
						****end fform loop
					}
					***end loop over alternative outcomes
					foreach fform in PC lnPC {
						foreach altout in solicit {
							if "`fform'"=="PC" {
								local cont contPC
								local alt `altout'PC
							}	
							if "`fform'"=="lnPC" {
								local cont lncontPC
								local alt ln`altout'PC
							}
/* foreach thing in DD_`cont' DDGR_`cont'w`alt' DDGR_`cont'w`alt'_pval RRGR_`cont'w`alt'_pval DDNET_`cont' DDNET_`cont'w`alt' DDNET_`cont'w`alt'_pval RRNET_`cont'w`alt'_pval {
	di "test F"
	di "`thing'"
	di "``thing''"
	di "test G"
} */
							matrix ALTEST_`alt'= [`DD_`cont'', `DDGR_`cont'w`alt'' , `DDGR_`cont'w`alt'_pval', `RRGR_`cont'w`alt'_pval', `DDNET_`cont'',  `DDNET_`cont'w`alt'' , `DDNET_`cont'w`alt'_pval', `RRNET_`cont'w`alt'_pval']
							matrix rown ALTEST_`alt' = "`alt'"
						}
						***end loop over altout variables
						foreach alt in neighboravg nationalavg {
							matrix ALTEST_`alt'`fform'= [`DD_`cont'', `DDGR_`cont'w`alt'' , . , ., `DDNET_`cont'', `DDNET_`cont'w`alt'', . , . ]
							matrix rown ALTEST_`alt'`fform' = "`alt'_`fform'"
						}
						***end loop over neighboravg and nationalavg
					}
					matrix AZ_ALTEST_`pass' = [ALTEST_neighboravgPC \ ALTEST_nationalavgPC \ ALTEST_solicitPC \ ALTEST_neighboravglnPC \ ALTEST_nationalavglnPC \ ALTEST_lnsolicitPC ]
					matrix coln AZ_ALTEST_`pass' = "GROSS" "GROSS_ALT" "GROSS_DD_PVAL" "GROSS_RR_PVAL" "NET" "NET_ALT" "NET_DD_PVAL" "NET_RR_PVAL"
					qui cd "`output'\tempfiles"
					qui matsave AZ_ALTEST_`pass', saving replace
					clear all
					use AZ_ALTEST_`pass'
					export excel using "`output'\tables/AZ_ALTestimators.xls", firstrow(varlabels) sheet("`pass'") sheetreplace		
					matrix drop _all	
				}		
				***end altout inference*****				
			}
			***end altout*****					
		}
		******End "not run none" loop"
	}
	****End Loop over Iterations*********
}
****End Organization SCM Section*******	
*********************************
*****Create SCM Graphs***********
*********************************
if "`graphs'"=="yes" {
	****SUMMARY GRAPHS**********************
	****graph contributions and without outlier
	clear all
	qui cd "`output'\tempfiles"
	use AZ_TOPvsUS_PC
	sort year AZ NOT_AZ POOL
	qui cd "`output'\graphs"
	*****contPC*******	
	twoway (scatter contPC year if AZ==1, connect(l) ) (scatter contPC year if NOT_AZ==1, connect(l) lpattern(dash)) ///
	(scatter contPC year if POOL==1, connect(l) lpattern(shortdash)), ///
	xline(1997.5) xtitle("Year") ytitle("Per Capita Contributions") ///
	legend(label(1 "Arizona") label(2 "US, excluding Arizona") label(3 "Donor Pool")) xlabel(1989(2)2012)
	**PC Version********
	if "`myPC'"=="yes" {	
		graph export AZTOP_vs_US_contPC.png, replace
	}
	****CCS Version*******
	if "`ccs'"=="yes" {
		graph export AZTOP_vs_US_contPC.eps, replace
	}
	*****loop over each type of organization
	foreach class in TOP {
	*****loop over per capita and log*****
		local graphlist lncontPC lnsolicitPC contPC solicitPC
		di "Creating Graphs for `class', outcomes:"
		di "`graphlist'"
		foreach outcome of local graphlist {		
			****Create Basic SCM Graphs******
			****Graph of AZ ORG vs Control
			clear all
			di "------"
			di "Creating SCM graphs for `class' `outcome'"
			qui cd "`output'\tempfiles"
			if "`class'"!="TOP" & "`class'"!="ALL" {	
				use AZ_SCM_`class'_`outcome'
				if "`outcome'"=="contPC" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(1997.5) xtitle("Year") ytitle("Per Capita Contributions") xlabel(1990(2)2012)
				}
				if "`outcome'"=="lncont" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(1997.5) xtitle("Year") ytitle("ln(Contributions)") xlabel(1990(2)2012)	
				}
				if "`outcome'"=="lncontPC" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(1997.5) xtitle("Year") ytitle("ln(Per Capita Contributions)") xlabel(1990(2)2012)	
				}
			}
			if "`class'"=="TOP"  | "`class'"=="ALL" { 
				clear all
				qui cd "`datadir'"
				if "`class'"=="ALL" {
					use AZ_Credits_Awarded
				}
				if "`class'"=="TOP" {
					use AZTOP_Credits_Awarded
				}
				qui cd "`output'\tempfiles"
				merge 1:m _time using AZ_SCM_`class'_`outcome'
				drop _merge
				label var _Y_synthetic "Synthetic Arizona"
				label var _Y_treated "Arizona"
				if "`outcome'"=="contPC" {
					gen _Y_expected = _Y_synthetic+creditsPC
					label var _Y_expected "Expected Arizona"
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)) ///
					(scatter _Y_expected _time if _time>=1998, connect(l) lpattern(dot)) ,  ///
					xline(1997.5) xtitle("Year") ytitle("Per Capita Contributions") xlabel(1990(2)2012)
				}
				if "`outcome'"=="lncont" {
					gen _Y_expected=ln(exp(_Y_synthetic)+(credits_adj))
					label var _Y_expected "Expected Arizona"
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)) ///
					(scatter _Y_expected _time if _time>=1998, connect(l) lpattern(dot)) , ///
					xline(1997.5) xtitle("Year") ytitle("ln(Contributions)") xlabel(1990(2)2012)	
				}
				if "`outcome'"=="lncontPC" {
					gen _Y_expected=ln(exp(_Y_synthetic)+(creditsPC))	
					label var _Y_expected "Expected Arizona"
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)) ///
					(scatter _Y_expected _time if _time>=1998, connect(l) lpattern(dot)) ,  ///
					xline(1997.5) xtitle("Year") ytitle("ln(Per Capita Contributions)") xlabel(1990(2)2012)	
				}
			}
			if "`outcome'"=="solicitPC" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(1997.5) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("Fundraising Expenditures") xlabel(1990(2)2012)
			}
			if "`outcome'"=="lnsolicit" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(1997.5) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("ln(Fundraising Expenditures)") xlabel(1990(2)2012)		
			}
			if "`outcome'"=="lnsolicitPC" {
				twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
				xline(1997.5) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("ln(Per Capita Fundraising Expenditure)") xlabel(1990(2)2012)
			}			
			if "`class'"=="ALL" {
				if "`outcome'"=="numPC" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(1997.5) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("Number of Nonprofits per 100,000") xlabel(1990(2)2012)
				}
				if "`outcome'"=="lnnum" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(1997.5) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("ln(Number of Nonprofits)") xlabel(1990(2)2012)		
				}
				if "`outcome'"=="lnnumPC" {
					twoway (scatter _Y_treated _time, connect(l)) (scatter _Y_synthetic _time, connect(l) lpattern(dash)), ///
					xline(1997.5) xline(2007.5, lp(shortdash)) xtitle("Year") ytitle("ln(Number of Nonprofits per 100,000)") xlabel(1990(2)2012)
				}					
			}
			qui cd "`output'\graphs"
			**PC Version********
			if "`myPC'"=="yes" {	
				graph export AZ_`class'_`outcome'_SCM1.png, replace
			}
			****CCS Version*******
			if "`ccs'"=="yes" {
				graph export AZ_`class'_`outcome'_SCM1.eps, replace
			}
			*********************
			****Placebo Graphs Option
			if "`placebo'"=="yes" {
				****Graph of DIFF vs Placebos
				**merge together file of differences between observation and synth with placebos.
				clear all
				qui cd "`output'\tempfiles"
				use AZ_`class'_DIFF_`outcome'
				rename c1 AZ	
				if "`outcome'" == "lncontPC" | "`outcome'"=="contPC" {
					merge 1:1 _rowname using AZ_`class'_DIFF_`outcome'_NET
					rename NETDIFF AZNET	
					drop _merge					
				}
				merge 1:1 _rowname using AZ_`class'_PL_`outcome'
				drop _merge
				***destring and rename year variable
				destring _rowname, replace
				rename _rowname year
				****set NumCntrl local***
				*r(k) gives the number of variables.  Subtract 1 for rowname and 1 for AZ
				qui describe
				local NumCntrl=r(k)-3
				di "There are `NumCntrl' `class' controls for `outcome'"
				local call =""
				sum AZ
				local top = 4*r(max)
				local bottom = 4*r(min)
				local N_tr=`NumCntrl'+1
				di "`NumCntrl' + 1 = `N_tr'"				
				qui cd "`output'\graphs"
				***define Placebo lines****
				forval j = 1/`NumCntrl' {
					local call `call' line pl`j' year if pl`j'<`top' & pl`j'>`bottom', lc(gs10) lw(vvthin) ||
				}				
				***Graph Placebos and overlay
				if "`outcome'"=="contPC" {
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in Per Capita Contributions") legend(order(`N_tr' "Arizona" 1 "Placebos"))
				}
				if "`outcome'"=="lncont" {
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' )  ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in ln(Contributions)") legend(order(`N_tr' "Arizona" 1 "Placebos"))
				}
				if "`outcome'"=="lncontPC" {
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' )  ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in ln(Per Capita Contributions)") legend(order(`N_tr' "Arizona" 1 "Placebos"))
				}	
				if "`outcome'"=="solicitPC" {		
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) xline(2007.5, lp(shortdash)) ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in Per Capita Fundraising Expenditure") legend(order(`N_tr' "Arizona" 1 "Placebos"))
				}
				if "`outcome'"=="lnsolicit" {			
					twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) xline(2007.5, lp(shortdash)) ///
					lc(black) xlab(1990(2)2012) ytitle("Gap in ln(Fundraising Expenditure)") legend(order(`N_tr' "Arizona" 1 "Placebos"))
				}				
				if "`outcome'"=="lnsolicitPC" {			
					twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) xline(2007.5, lp(shortdash)) ///
					lc(black) xlab(1990(2)2012) ytitle("Gap in ln(Per Capita Fundraising Expenditure)") legend(order(`N_tr' "Arizona" 1 "Placebos"))
				}
				if "`class'"=="ALL"{
					if "`outcome'"=="numPC" {
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) xline(2007.5, lp(shortdash)) ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in Number of Nonprofits per 100,000") legend(order(`N_tr' "Arizona" 1 "Placebos"))
					}	
					if "`outcome'"=="lnnum" {
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) xline(2007.5, lp(shortdash)) ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in ln(Number of Nonprofits)") legend(order(`N_tr' "Arizona" 1 "Placebos"))
					}
					if "`outcome'"=="lnnumPC" {
						twoway `call' || line AZ year, yline(0) xline(1997.5 `endline' ) xline(2007.5, lp(shortdash)) ///
						lc(black) xlab(1990(2)2012) ytitle("Gap in ln(Number of Nonprofits per Million)") legend(order(`N_tr' "Arizona" 1 "Placebos"))
					}
				}
				*****end Log graph command******
				cd "`output'\graphs"
				****export Graph****
				if "`ccs'"=="yes" {
					graph export AZ_`class'_`outcome'_SCM2.eps, replace
				}		
				if "`myPC'"=="yes" {
					graph export AZ_`class'_`outcome'_SCM2.png, replace
				}							
			}
			*****End Placebo Graphs Option
		}
		***end loop over outcomes******
	}
	****End loop over classes	****ALTOUT GRAPHS, BASELINE ONLY*************************
	di "ALTOUT GRAPHS USING `outcome' WEIGHTS:"
	foreach outcome in lncontPC {
		clear all
		local agg TOP
		qui cd "`output'\tempfiles"
		use AZ_`agg'_ALTOUT_`outcome'
		foreach var in lncontPC lnsolicitPC lnINCperCAP unemploymentrate top1 lndir_expPC lnown_revPC  {
			if "`var'"=="lnsolicitPC" {
				local ytitle = "ln(Fundraising Expenditure Per Capita)"
				local xline = "xline(2007.5, lp(dot))"
			}
			if "`var'"=="lncontPC" {
				local ytitle = "ln(Contributions Per Capita)"
				local xline = ""
			}
			if "`var'"=="lnINCperCAP" {
				local ytitle = "ln(Per Capita Income)"
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
			if "`var'"=="lndir_expPC" {
				local ytitle = "ln(State and Local Expenditure Per Capita)"
				local xline=""
			}					
			if "`var'"=="lnown_revPC" {
				local ytitle = "ln(State and Local Revenue Per Capita)"
				local xline=""
			}								
			twoway (scatter synth_`var' year if treated==1, connect(l)) (scatter synth_`var' year if treated==0, connect(l) lpattern(dash)), ///
			xline(1997.5) `xline' xtitle("Year") ytitle("`ytitle'") legend(label(1 "Arizona") label(2 "Synthetic Control")) xlabel(1990(2)2012)
			cd "`output'\graphs"
			****CCS Version*******
			if "`ccs'"=="yes" {
				graph export AZ_`agg'_ALTOUT_`var'_w_`outcome'.eps, replace
			}	
		}
		****End loop over altoutcomes
	}
	****End loop over SCM outcomes	
}
