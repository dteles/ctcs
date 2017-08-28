*************************************************
* Charitable Tax Credits Analysis
* CharitableTaxCredits.do
* 8/18/2017, version 2.1
* Dan Teles
*************************************************
* This is the main file for the CTC analysis
* It calls the other .do files and does program setup
*************************************************
* Program Setup
*************************************************
version 14              // Set Version number for backward compatibility
set more off            // Disable partitioned output
clear all               // Start with a clean slate
set linesize 120        // Line size limit to make output more readable
macro drop _all         // clear all macros
capture log close       // Close existing log files
set trace off			// Disable debugger
set matsize 11000		// Define matrix size 
set maxvar 32767, perm  // Define max variables
set scheme s1color, perm //Define color scheme for graphs
**************************************************
* Directories
**************************************************
local projectdir="D:\Users\dteles\Box Sync\DTeles\CharitableTaxCredits"
local project="CharitableTaxCredits"
**************************************************
* Locals to define which sections to run
**************************************************
local makedata "no" 
local Iowa "yes"
local Arizona "no"
**************************************************
* Define Directory
**************************************************
cd "`projectdir'\ctcs_dofiles"
**************************************************
* Create Log File
**************************************************
global logthis "no" 	//change to "no" if no log file is desired
global makecopy "no"   //change to "no" if copies of do files are desired
local time : di %tcCCYYNNDD!_HHMMSS clock("`c(current_date)'`c(current_time)'","DMYhms")
if "$makecopy"=="yes"{
	copy `project'.do "`project'_`time'.do"
}
if "$logthis"=="yes"{
	log using `project'_`time'.log, replace text
	pwd
	display "$S_DATE $S_TIME"
}
di "-------------------------"
di "`c(username)' `c(current_date)'"
di "`c(current_time)'"
di "-------------------------"

**************************************************
* Net Installs ensure all programs are loaded
**************************************************
/* right now, we don't need these
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
*/

**************************************************
* Create Datasets
**************************************************
cd "`projectdir'\ctcs_dofiles"
if "`makedata'"=="yes" do CTC_makedata.do
**************************************************
* Analysis of Endow Iowa Tax Credit
**************************************************
cd "`projectdir'\ctcs_dofiles"
if "`Iowa'"=="yes" do CTC_IA.do


**************************************************
* Close the log, end the file
**************************************************
macro drop _all
capture log close
exit
