clear all
drop _all
capture log close

****************************************************
******Standard Preamble***************************
******************************************************
******Cluster directories*****
local projectdir="/econ/dteles/CrowdOut"
local datadir="/econ/dteles/CrowdOut/data"
local output="/econ/dteles/CrowdOut/output"
local parentdir="/econ/dteles/CrowdOut"
local project="AmeriCorpsCrowdOut_DatasetBuilder"
*********************************
*cluster installs***************
ssc install reclink
ssc install egenmore
*****Locals: WHICH SECTIONS TO RUN?***********
local logthis="yes"
local cleanAC="yes"
local cleanIRS="yes"
local mergeNCCS="yes"
local cleanNCCS="yes"
local crosswalk="yes"
local combine="yes"
***Log********
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
*set matsize 11000
set linesize 120
set maxvar 5000
set scheme s1color, perm
*************************************************
*Dan Teles Mar 2017
***************************************************
set more off
/*First match on city state org
  Second match on city state program
  Third match on state org
  Fourth match on state program
  Fifth match on org */
************ 
*********************************************
*******AmeriCorps Data****************
*********************************************
if "`cleanAC'"=="yes"{
	foreach file in members grants {
		clear all
		cd "`datadir'"
		if "`file'"=="members" {
			import excel AmeriCorps_Clean, firstrow
			**rename variables
			rename Organization org
			rename City city
			rename Program program_name
			replace org=program_name if org=="" 			
			rename State state
			rename YEAR year
			**create new numeric variable for Number of AmeriCorps**
			egen corps=sieve(Number_of_AmeriCorps), keep(numeric)
			destring corps,replace
			replace corps=0 if corps==.
		}	
		if "`file'"=="grants" {
			clear all
			insheet using "AmeriCorps_Grants.csv", comma clear names
			save Grants_temp.dta, replace
			**rename variables
			rename org_name org
			rename org_city city
			rename org_state state
			rename total_fed_~t award
			rename fy_nbr year
			**Convert ein and award to numeric****
			replace ein = subinstr(ein," ","",.) /*removes spaces*/
			replace award = subinstr(award,"$","",1)/*removes $*/
			replace award = subinstr(award,",","",.)/*removes ,*/
			replace award = subinstr(award," ","",.)/*removes spaces*/
			destring ein, replace force
			destring award, replace
		}	
		*****************************************************
		*****CREATE VARIABLES FOR AMERICORPS TYPE************
		*****************************************************
		if "`file'"=="members" {
			***clean strings*****
			qui {
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "*", " ",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "_", " ",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "(ed", "",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "award)", "",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "withoutCommissions", "", .)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "- South", "", .)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "Dakota", "", .)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "Vista", "VISTA",.)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "VISTA State", "AmeriCorps VISTA",.)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "FellowsNational", "Fellows",.)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "Fellows National", "Fellows",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "NationalHome", "National Home",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "landSecurity", "land",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "State Homeland", "State Homeland Security",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "Awards", "Award",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "Award", "Awards",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "(State)", " (State)",1)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, "  ", " ",.)
				replace AmeriCorpsType = subinstr(AmeriCorpsType, " ", "",1) if substr(AmeriCorpsType,1,1) == " "  
				replace AmeriCorpsType = trim(AmeriCorpsType)
				replace AmeriCorpsType="AmeriCorps Fixed Amount Grant" if AmeriCorpsType=="AmeriCorps Fixed A" 
				gen actype=AmeriCorpsType
				replace actype="TRIBES" if actype=="AmeriCorps Indian Tribes"
				replace actype="NCCC_CAMPUS" if actype=="AmeriCorps NCCC Campus"
				replace actype="NCCC_PROJECT" if actype=="AmeriCorps NCCC In-State Projects"
				replace actype="NATL" if actype=="AmeriCorps National" | actype=="AmeriCorps National Homeland Security" 
				replace actype="PROM" if actype=="AmeriCorps Promise Fellows" | actype=="Promise Fellows AmeriCorps National"
				replace actype="STATE" if actype=="AmeriCorps Fixed Amount Grant" | actype=="AmeriCorps Fixed Amount Grant (State)"
				replace actype="STATE" if regexm(actype,"AmeriCorps State") 
				replace actype="VISTA" if regexm(actype, "VISTA")
				replace actype="EAP" if actype=="Education Awards Program" | actype=="Education Awards Program(State)" | actype=="Education Awards Program (State)"
				sort actype
				gen S_DIRECT=0
				gen N_DIRECT=0
				gen EAP_DIRECT=0
				gen DIRECT=0
				label var DIRECT "State and National Direct"
				gen VISTA=0
				label var VISTA "VISTA"
				gen NCCC=0
				label var NCCC "NCCC"
				replace N_DIRECT=N_DIRECT+corps if actype=="NATL" | actype=="PROM"
				replace S_DIRECT=S_DIRECT+corps if actype=="STATE" | actype=="TRIBES" 
				replace EAP_DIRECT=corps if actype=="EAP"
				replace VISTA=corps if actype=="VISTA"
				replace DIRECT=N_DIRECT+S_DIRECT+EAP_DIRECT
				replace NCCC=NCCC+corps if actype=="NCCC_CAMPUS" | actype=="NCCC_PROJECT"
				gen TOTAL=DIRECT+VISTA+NCCC
				label var TOTAL "Total"
				preserve
				gen test=0
				replace test=1 if TOTAL==corps
				noi sum test
				drop if test==1
				noi save ac_clean_temp, replace
				restore
			}	
		}
		if "`file'"=="grants"{
			qui {
				rename crpp_cd actype
				replace actype="STATE" if actype=="STATEHS" | actype=="STATESD"
				replace actype="NATL" if actype=="NATLHS"
				replace actype="PROM" if actype=="AMERPROM"
				replace actype="VISTA" if actype=="VISTAS" | actype=="VISTAH"
				replace actype="EAP" if actype=="EAS"
				replace actype="TRIBES" if actype=="TERR"
			}
		}	
		****************************************
		****CLEANING NAMES**********************
		****************************************
		***Clean AmeriCorps string Data formatting***
		qui {
			local stringvars org state city
			if "`file'"=="members" {
				local stringvars `stringvars' program_name
			}
			noi di "Cleaning string variables `stringvars'"
			foreach var of varlist `stringvars' {
				replace `var'=upper(`var')
				replace `var' = subinstr(`var', "CORP.", "CORPORATION",.)
				replace `var' = subinstr(`var', "&", " AND ",.)
				replace `var' = subinstr(`var', "-", " ",.)
				replace `var' = subinstr(`var', "/", " ",.)
				replace `var' = subinstr(`var', ",", " ",.)
				replace `var' = subinstr(`var', "ASSOC", "ASSOCIATION",.)
				replace `var' = subinstr(`var', "ASSOCIATIONIATION", "ASSOCIATION",.)
				replace `var' = subinstr(`var', "INCORPORATED", "",.)
				replace `var' = subinstr(`var', "INC.", "",.)
				replace `var' = subinstr(`var', "  ", " ",.)
				replace `var' = subinstr(`var', "  ", " ",.)
				egen `var'2=sieve(`var'), keep(alphabetic numeric space)
				replace `var'=`var'2
				drop `var'2
				replace `var'=trim(`var')
				replace `var'=trim(`var')
			}		
			****Specific Misspellings****
			replace org = subinstr(org, "16TH STREET HEALTH CENTER", "SIXTEENTH STREET COMMUNITY HEALTH CENTER",.)
			replace org = subinstr(org, "ST EDWARD UNIVERSITY", "ST EDWARDS UNIVERSITY",.)
			replace org = subinstr(org, "SEXUALASSAULT", "SEXUAL ASSAULT",.)
			replace org = subinstr(org, "CNCL", "COUNCIL",.)
			replace org = subinstr(org, "DISTREICT", "DISTRICT",.)
			replace org = subinstr(org, "ACTIONCOMMITTEE", "ACTION COMMITEE",.)
			replace org = subinstr(org, "AMERICAN YOUTH WORKS", "AMERICAN YOUTHWORKS",.)
			replace org = subinstr(org, "LAKESYOUTH", "LAKES YOUTH",.)
			replace org = subinstr(org, "COMMUNITY TEAMWORK INC", "COMMUNITY TEAMWORK",.)
			replace org = subinstr(org, "COMMUNITY TEAMWORK INC", "COMMUNITY TEAMWORK",.)
			replace org = subinstr(org, "CONNECTICUT COLLEGEOFFICE OF VOLUNTEERS FOR", "CONNECTICUT COLLEGE OFFICE OF VOLUNTEERS FORCOMMUNTIY SERVICE",.)
			replace org = subinstr(org, "CONNECTICUT COLLEGEOFFICE OF VOLUNTEERS FORCOMMUNTIY SERV", "CONNECTICUT COLLEGE OFFICE OF VOLUNTEERS FORCOMMUNTIY SERVICE",.)
			replace org = subinstr(org, "CONNECTICUT COLLEGEOFFICE OF VOLUNTEERS FORCOMMUNTIY SERVICE", "CONNECTICUT COLLEGE OFFICE OF VOLUNTEERS FORCOMMUNTIY SERVICE",.)
			replace org = subinstr(org, "CONVERSE COUNTY COALITION AGAINST FAMILYVIOLENCE AND SEXUAL ASSAULT", "CONVERSE COUNTY COALITION AGAINST FAMILY VIOLENCE AND SEXUAL ASSAULT",.)
			replace org = subinstr(org, "CORNERSTONE OUTREACH", "CORNERSTONE OUTREACH CENTER",.)
			replace org = subinstr(org, "CORPORATION FOR OHIO APPALACHIAN DEVELOPMENTCOAD", "CORPORATION FOR OHIO APPALACHIAN DEVELOPMENT COAD",.)
			replace org = subinstr(org, "COUNTY OF SAN DIEGO AGING AND INDEPENDENCESERVICES", "COUNTY OF SAN DIEGO AGING AND INDEPENDENCE SERVICES",.)
			replace org = subinstr(org, "CTR FOR ALTERNATIVE SENTENCING AND EMPLOYMENTSERVICES", "CTR FOR ALTERNATIVE SENTENCING AND EMPLOYMENT",.)
			replace org = subinstr(org, "CURATORS OF UNIVERSITY OF MISSOURI", "CURATORS OF THE UNIVERSITY OF MISSOURI",.)
			replace org = subinstr(org, "DELTA STATE UNIVERSITY CENTER FOR COMMUNITYDEVELOPMENT", "DELTA STATE UNIVERSITY CENTER FOR COMMUNITY DEVELOPMENT",.)
			replace org = subinstr(org, "DEPARTMENT OF LAW AND PUBLIC SAFETY JUVENILE JUSTICECOMMISSION", "DEPARTMENT OF LAW AND PUBLIC SAFETY JUVENILE JUSTICE",.)
			replace org = subinstr(org, "DEPARTMENT OF NATURAL RESOURCES MARYLANDCONSERVATION CORPS", "DEPARTMENT OF NATURAL RESOURCES MARYLAND CONSERVATION CORPS",.)
			replace org = subinstr(org, "DEPARTMENT OF SVCS CHILDREN YOUTH FAMILES", "DEPARTMENT OF SERVICES FOR CHILDREN YOUTH FAMILES",.)
			replace org = subinstr(org, "DISABILITY RESOURCECENTER OF FAIRFIELD COUNTY", "DISABILITY RESOURCECENTER OF FAIRFIELD COUNTY DRC",.)
			replace org = subinstr(org, "DISNEY GOALS VISTA INITIATIVEDISNEY GOALS", "DISNEY GOALS",.)
			replace org = subinstr(org, "DIVISION OF AGING AND ADULT SERVICE", "DIVISION OF AGING AND ADULT SERVICE1",.)
			replace org = subinstr(org, "EAST CAROLINA SCHOOL OF EDUCATION PROJECT HEART", "EAST CAROLINA SCHOOL OF EDUCATION",.)
			replace org = subinstr(org, "EAST POINT COMMUNITY ACTIONEAST POINT COMMUNITY ACTION TEAM", "EAST POINT COMMUNITY ACTION TEAM",.)
			replace org = subinstr(org, "EL PASO AFFORDABLE HOUSING CREDIT UNION SERVICEORGANIZATION", "EL PASO AFFORDABLE HOUSING CREDIT UNION SERVICE ORGANIZATION",.)
			replace org = subinstr(org, "EL PUNTE CDC", "EL PUENTE COMMUNITY DEVELOPMENT CORPORATION",.)
			replace org = subinstr(org, "ELDER CARE SERVICES INC", "ELDER CARE SERVICES",.)
			replace org = subinstr(org, "CONNECT MICHIGAN ALLIANCE MICHIGAN CAMPUSCOMPACT", "CONNECT MICHIGAN ALLIANCE",.)
			replace org = subinstr(org, "COOL GIRLS AMERICORPS PROGRAMCOOL GIRLS", "COOL GIRLS",.)
			replace org = subinstr(org, "FAITHWORKS OF ABILENE INC", "FAITHWORKS OF ABILENE",.)
			replace org = subinstr(org, "FAMILY AND COMMUNITY SERVICES OF PORTAGE COUNTY", "FAMILY AND COMMUNITY SERVICES",.)
			replace org = subinstr(org, "FAMILY AND COMMUNITY SERVICES OF PORTAGE COUNTY INC", "FAMILY AND COMMUNITY SERVICES",.)
			replace org = subinstr(org, "FAMILY SERVICE OF MONTGOMERY COUNTY PA", "FAMILY SERVICE OF MONTGOMERY COUNTY PA FSMC",.)
			replace org = subinstr(org, "FANNIN COUNTY FAMILY CONNECTION BOARD OF", "FANNIN COUNTY FAMILY CONNECTION BOARD OF COMMISSIONERS FISCAL AGENT",.)
			replace org = subinstr(org, "FANNIN COUNTY FAMILY CONNECTION BOARD OFCOMMISSIONERS FISCAL AGENT", "FANNIN COUNTY FAMILY CONNECTION BOARD OF COMMISSIONERS FISCAL AGENT",.)
			replace org = subinstr(org, "FOOD BANK OF CENTRAL LOUISIANA", "FOOD BANK OF CENTRAL LA",.)
			replace org = subinstr(org, "FOSTER AND ADOPTION MENTORING AND ENRICHMENTFAME", "FOSTER AND ADOPTION MENTORING AND ENRICHMENT FAME",.)
			replace org = subinstr(org, "FRESNO COUNTY ECONOMIC OPPORTUNITIESCOMMISSION", "FRESNO COUNTY ECONOMIC OPPORTUNITIES COMMISSION",.)
			replace org = subinstr(org, "FRIENDS OF THE CHILDREN BOSTO", "FRIENDS OF THE CHILDREN BOSTON",.)
			replace org = subinstr(org, "FROSTBURG STATE UNIVERSI", "FROSTBURG STATE UNIVERSITY",.)
			replace org = subinstr(org, "FULFILLING OUR RESPONSIBILITY UNTO MANKINDFORUM", "FULFILLING OUR RESPONSIBILITY UNTO MANKIND FORUM",.)
			replace org = subinstr(org, "GONZAGA UNIVERSITY CENTER FOR COMMUNITY ACTION AND SERVICE LEARNING", "GONZAGA UNIV CENTER FOR COMMUNITY ACTION AND SERVICE LEARNING",.)
			replace org = subinstr(org, "GREAT BASIN INSTITUTE NEVADA CONVERVATION CORPS", "GREAT BASIN INSTITUTE NEVADA CONSERVATION CORPS",.)
			replace org = subinstr(org, "HANDS ON GULF COAST AMERICORPS", "HANDS ON GULF COAST",.)
			replace org = subinstr(org, "HANDSON NEW ORLEANS", "HANDSON NEW ORLEANS1",.)
			replace org = subinstr(org, "HAWAII COMMISSION FOR NATIONAL AND COMMUNITYSERVICE", "HAWAII COMMISSION FOR NATIONAL AND COMMUNITY SERVICE VISTA",.)
			replace org = subinstr(org, "HEART OF OREGON CORPS", "HEART OF OREGON",.)
			replace org = subinstr(org, "HELPING OTHERS PROSPER EVERYDAY INC", "HELPING OTHERS PROSPER EVERYDAY",.)
			replace org = subinstr(org, "HISTORIC EAST BALTIMORE COMMUNITY ACTIONCOALITION", "HISTORIC EAST BALTIMORE COMMUNITY ACTION COALITION",.)
			replace org = subinstr(org, "HOUSING SERVICES OF TEXAS", "HOUSING SERVICES",.)
			replace org = subinstr(org, "IDA AND ASSET BUILDING COLLABORATIVE OF NORTHCAROLINA", "IDA AND ASSET BUILDING COLLABORATIVE OF NORTH CAROLINA",.)
			replace org = subinstr(org, "INTERNATIONAL INSTITUTE OF MN", "INTERNATIONAL INSTITUTE OF MINNESOTA",.)
			replace org = subinstr(org, "ISLES INC", "ISLES",.)
			replace org = subinstr(org, "JEKYLL ISLAND STATE PARK AUTHORITY DBA GEORGIA SEA", "JEKYLL ISLAND STATE PARK AUTHORITY DBA GEORGIA SEA TURTLE CENTER",.)
			replace org = subinstr(org, "JEWISH FAMILY SERVICE OF SOMERSET HUNTERDON ANDWARREN COUNTIES", "JEWISH FAMILY SERVICE OF SOMERSET HUNTERDON AND WARREN COUNTIES",.)
			replace org = subinstr(org, "JOHNS HOPKINS UNIVERSITY BALTIMORE", "JOHNS HOPKINS UNIVERSITY",.)
			replace org = subinstr(org, "KNOXVILLE KNOX COUNTY CAC", "KNOXVILLE KNOX COUNTY COMMUNITY ACTION COMMITTEE",.)
			replace org = subinstr(org, "KNOXVILLE KNOX COUNTY COMMUNITY ACTION COMMITEE", "KNOXVILLE KNOX COUNTY COMMUNITY ACTION COMMITTEE",.)
			replace org = subinstr(org, "LAND OF LINCOLN LEGAL ASSISTANCE FOUNDAT", "LAND OF LINCOLN LEGAL ASSISTANCE FOUNDATION",.)
			replace org = subinstr(org, "LAWRENCE FAMILY DEVELOPMENT AND EDUCATIONFUND", "LAWRENCE FAMILY DEVELOPMENT AND EDUCATION FUND INC",.)
			replace org = subinstr(org, "LEGAL ASSISTANCE FOUNDATION OF METROPOLITANCHICAGO", "LEGAL ASSISTANCE FOUNDATION OF METROPOLITAN CHICAGO",.)
			replace org = subinstr(org, "LEGAL ASSISTANCE OF WESTERN NEW YORK 1", "LEGAL ASSISTANCE OF WESTERN NEW YORK",.)
			replace org = subinstr(org, "LINCOLN ACTION PROGRAM INC", "LINCOLN ACTION PROGRAM",.)
			replace org = subinstr(org, "LITERACY PARTNERSHIP FO SOUTHEAST MICHIGAN", "LITERACY PARTNERSHIP OF SOUTHEAST MICHIGAN",.)
			replace org = subinstr(org, "LYCOMING CLINTON COUNTIES COMMISSION FOR COMMUNITY ACTION STEP", "LYCOMING CLINTON COUNTIES COMMISSION FORCOMMUNITY ACTION STEP",.)
			replace org = subinstr(org, "MARQUETTE ALGER REGIONAL EDUCATIONAL SERVICE", "MARQUETTE ALGER REGIONAL EDUCATIONAL SERVICE AGENCY",.)
			replace org = subinstr(org, "MARQUETTE ALGER REGIONAL EDUCATIONAL SERVICEAGENCY", "MARQUETTE ALGER REGIONAL EDUCATIONAL SERVICE AGENCY",.)
			replace org = subinstr(org, "MASSACHUSETTS LEAGUE OF COMMUNITY HEALTHCENTERS", "MASSACHUSETTS LEAGUE OF COMMUNITY HEALTH CENTERS",.)
			replace org = subinstr(org, "MINNESOTA ASSOCIATION FOR VOLUNTEERADMINISTRATION", "MINNESOTA ASSOCIATION FOR VOLUNTEER ADMINISTRATION",.)
			replace org = subinstr(org, "NEIGHBORHOOD SERVICES OF CENTRAL INDIANA MARYRIGG NEIGHBORHOOD CENTER", "NEIGHBORHOOD SERVICES OF CENTRAL INDIANA MARY RIGG NEIGHBORHOOD CENTER",.)
			replace org = subinstr(org, "NEW JERSEY COMMISSION ON NATIONAL COMMUNITY", "NEW JERSEY COMMISSION ON NATIONAL COMMUNITY SERVICE",.)
			replace org = subinstr(org, "NEW JERSEY COMMISSION ON NATIONAL COMMUNITYSERVICE", "NEW JERSEY COMMISSION ON NATIONAL COMMUNITY SERVICE",.)
			replace org = subinstr(org, "NEW RIVER COMMUNTIY ACTION INC", "NEW RIVER COMMUNITY ACTION",.)
			replace org = subinstr(org, "OHIO COMMUNITY COMPUTING NETWORK", "OHIO COMMUNITY COMPUTER CENTERS NETWORK",.)
			replace org = subinstr(org, "OKLAHOMA CONFERENCE OF THE UNITED METHODIST", "OKLAHOMA CONFERENCE OF THE UNITED METHODIST CHURCH",.)
			replace org = subinstr(org, "OKLAHOMA CONFERENCE OF THE UNITED METHODISTCHURCH", "OKLAHOMA CONFERENCE OF THE UNITED METHODIST CHURCH",.)
			replace org = subinstr(org, "OREGON MICROENTERPRISE NETWORK OMEN", "OREGON MICROENTERPRISE NETWORK",.)
			replace org = subinstr(org, "PHILADELPHIA YOUTH FOR CHANGE INC", "PHILADELPHIA YOUTH FOR CHANGE",.)
			replace org = subinstr(org, "ROCK VALLEY ROTARY CLUB", "ROCK VALLEY ROTARY CLUB FOUNDATION",.)
			replace org = subinstr(org, "SC ASSOCIATION OF COMMUNITY DEVELOPMENTCORPORATIONS", "SC ASSOCIATION OF COMMUNITY DEVELOPMENT CORPORATIONS",.)
			replace org = subinstr(org, "SCHULENBURG WEIMER IN FOCUS TOGETHER", "SCHULENBURG WEIMAR IN FOCUS TOGETHER",.)
			replace org = subinstr(org, "SGSM NETWORK FORMERLY SOUTH GRAND SENIORMINISTRY", "SGSM NETWORK FORMERLY SOUTH GRAND SENIOR MINISTRY",.)
			replace org = subinstr(org, "STATE COURT ADMINISTRATORS OFFICE IOWA JUDICIALBRANCH", "STATE COURT ADMINISTRATORS OFFICE IOWA JUDICIAL BRANCH",.)
			replace org = subinstr(org, "STATE DEPT OF EDUCATION", "STATE DEPARTMENT OF EDUCATION",.)
			replace org = subinstr(org, "STATE OF HAWAII DEPARTMENT OF EDUCATION", "STATE OF HAWAII DEPARTMENT OF EDUCATION VISTA",.)
			replace org = subinstr(org, "STATE PLANNING OFFICE MAINE EXECUTIVE DEPT", "STATE PLANNING OFFICE MAINE EXECUTIVE DEPARTMENT",.)
			replace org = subinstr(org, "THE WESLEY FOUNDATION AT THE UNIVERSITY OF VA", "THE WESLEY FOUNDATION AT THE UNIVERSITY OF VIRGINIA",.)
			replace org = subinstr(org, "THREAD CONNECTING EARLY CARE AND EDUCATION TOALASKA", "THREAD CONNECTING EARLY CARE AND EDUCATION TO ALASKA",.)
			replace org = subinstr(org, "UNITED WAY OF PONCA CITY INC", "UNITED WAY OF PONCA CITY",.)
			replace org = subinstr(org, "VOLUNTEER CENTER OF LEWIS MASON AND THURSTONCOUNTIES", "VOLUNTEER CENTER OF LEWIS MASON AND THURSTON COUNTIES",.)
			replace org = subinstr(org, "WAYNESVILLE R VI SCHOOL DISTRICT", "WAYNESVILLE RVI SCHOOL DISTRICT",.)
			replace org = subinstr(org, "WESTERN DAIRYLAND EOC", "WESTERN DAIRYLAND ECONOMIC OPPORTUNITY COUNCIL",.)
			replace org = subinstr(org, "WI DEPARTMENT OF AGRICULTURE TRADE AND CONSUMERPROTECTION", "WI DEPARTMENT OF AGRICULTURE TRADE AND CONSUMER PROTECTION",.)
			replace org = subinstr(org, "YOUTH ACTION PROGRAMS AND HOMES INC", "YOUTH ACTION PROGRAMS AND HOMES",.)
			replace org = subinstr(org, "GREATER DC CARES WASHINGTON DC", "GREATER DC CARES INC",.)
			****Other Typos and Corrections****
			replace state="FL" if org=="FLORIDA LITERACY COALITION" 
			replace state="FL" if org=="FLORIDA STATE UNIVERSITY"
			replace state="GA" if org=="LITERACY VOLUNTEERS OF AMERICA METRO ATLANTA"
			replace state="MN" if org=="MINNESOTA HOUSING PARTNERSHIP"
			replace state="NC" if org=="NORTH CAROLINA CAMPUS COMPACT ELON UNIVERSITY"
			replace state="CA" if org=="THE REGENTS OF THE UNIVERSITY OF CALIFORNIA"
			**Naming Convnetions for National Networks of Locally Run Nonprofits**
			/*Make sure that programs are not collapsed at the state level
			by renaming to a basic convention */
			**Boys and Girls Clubs**
			gen BGA=1 if regexm(org,"BOYS AND GIRLS CLUB")
			replace org = "BOYS AND GIRLS CLUB "+city if BGA==1
			drop BGA
			**Habitat for Humanity**
			gen HFH=1 if regexm(org,"HABITAT FOR HUMANITY") | regexm(org,"HFH") | regexm(org, "HABITAT FOR HUMANITIES")
			replace org = "HABITAT FOR HUMANITY "+city if HFH==1
			drop HFH
			**Rebuilding Together
			gen RBT=1 if regexm(org, "REBUILDING TOGETHER")
			if "`file'"=="members" {		
				replace program_name = city if RBT==1
			}
			replace org = "REBUILDING TOGETHER "+city if RBT==1
			drop RBT
			*Big Brothers Big Sisters**
			gen BBBS=1 if regexm(org,"BIG BROTHERS BIG SISTERS")
			replace org = "BIG BROTHERS BIG SISTERS "+city if BBBS==1
			drop BBBS
			**state programs**
			/*(DEFAULT)- programs are collapsed to state level*/
			*Campus Compact: changes made to orgs in NCCS database*/
			gen CC=1 if regexm(org, "CAMPUS COMPACT")
			gen ccname=org if CC==1
			*Campus Compact: changes made to orgs in NCCS database*/
			replace org="ILLINOIS CAMPUS COMPACT" if org=="IL CAMPUS COMPACT"
			replace org="WASHINGTON CAMPUS COMPACT" if org=="COMPACT" & state=="CA"
			replace CC=1 if org=="COMPACT" & state=="CA"			
			replace org="MA CAMPUS COMPACT" if regexm(org, "TUFTS") & CC==1
			replace org="CAMPUS COMPACT FOR NEW HAMPSHIRE" if CC==1 & regexm(org,"HAMPSHIRE")
			replace org="CAMPUS COMPACT FOR NEW HAMPSHIRE" if CC==1 & regexm(org,"NH")
			replace org="MARYLAND DISTRICT OF COLUMBIA CAMPUS COMPACT INC" if org=="MARYLAND CAMPUS COMPACT"
			replace org="OHIO CAMPUS COMPACT" if CC==1 & regexm(org,"OHIO")
			replace org="OREGON CAMPUS COMPACT" if CC==1 & regexm(org,"OREGON")
			replace org="CAMPUS COMPACT OF THE MOUNTAIN WEST" if CC==1 & regexm(ccname,"COLORADO")
			replace city="PORTLAND" if CC==1 & regexm(ccname,"OREGON")
			replace city="GRANVILLE" if CC==1 & regexm(org,"OHIO")
			replace city="DENVER" if CC==1 & regexm(ccname,"COLORADO")
			replace city="BEDFORD" if CC==1 & regexm(org,"HAMPSHIRE")
			replace city="EMMITSBURG" if CC==1 & regexm(org,"MARYLAND")
			replace state="OR" if CC==1 & regexm(org,"OREGON")
			replace state="OH" if CC==1 & regexm(org,"OHIO")
			replace state="CO" if CC==1 & regexm(ccname,"COLORADO")
			replace state="NH" if CC==1 & regexm(org,"HAMPSHIRE")
			replace state="NH" if CC==1 & regexm(org,"NH")
			replace state="OH" if CC==1 & regexm(org,"MARYLAND")
			drop ccname CC
			**LIFT INC****
			gen NSP=1 if regexm(org, "NATIONAL STUDENT PARTNERSHIP")
			replace NSP=1 if regexm(org, "NSP ")
			replace NSP=1 if regexm(org, "LIFT INC")
			sort NSP
			if "`file'"=="members" {
				replace program_name = city if NSP==1		
			}
			replace org = "LIFT INC" if NSP==1
			drop NSP
			**Naming Convnetions for Nationally Run Nonprofits**
			/*Reassign these programs to the correct city and state*/
			**Student Conservation Assoc***
			gen SCA=1 if org=="STUDENT CONSERVATION ASSOCIATION"
			if "`file'"=="members" {
				replace SCA=1 if regexm(program_name, "STUDENT CONSERVATION ASSOCIATION")
				replace SCA=1 if regexm(org, "SCA AMERICORPS")
				replace program_name=city if SCA==1
			}	
			replace city="ARLINGTON" if SCA==1
			replace state= "VA" if SCA==1
			replace org="STUDENT CONSERVATION ASSOCIATION INC" if SCA==1
			drop SCA
			***UND ACE****
			gen UND=1 if org=="ACE" | org=="ACE LEADERSHIP" | org=="UNIVERSITY OF NOTRE DAME ACE"
			replace UND=1 if regexm(org, "UNIVIERSITY") & regexm(org, "NOTRE DAME")
			if "`file'"=="members" {
				replace program_name=city if UND==1
			}	
			replace city="NOTRE DAME" if UND==1
			replace state= "IN" if UND==1
			replace org="UNIVERSITY OF NOTRE DAME DU LAC" if UND==1
			drop UND
			****NOTRE DAME MISSION*****
			gen NDM=1 if regexm(org, "NOTRE DAME AMERICORPS") | regexm(org, "NOTRE DAME MISSION")
			if "`file'"=="members" {
				replace program_name=city if NDM==1
			}	
			replace city = "BALTIMORE" if NDM==1
			replace state= "MD" if NDM==1
			replace org = "NOTRE DAME VOLUNTEER CORPORATION" if NDM==1
			drop NDM
			***CATHOLIC VOL NETWORK*****
			gen CVN=1 if regexm(org, "CATHOLIC VOLUNTEER") | regexm(org,"CATHOLIC NETWORK OF VOLUNTEER")
			if "`file'"=="members" {
				replace program_name = city if CVN==1
			}
			replace org = "CATHOLIC VOLUNTEER NETWORK" if CVN==1
			replace city = "TAKOMA PARK" if CVN==1
			replace state= "MD" if CVN==1
			drop CVN
			****COLLEGE OF NJ****
			gen CNG=1 if regexm(org, "COLLEGE OF NEW JERSEY")
			if "`file'"=="members" {
				replace program_name=city if CNG==1
			}
			replace city="EWING" if CNG==1
			replace state= "NJ" if CNG==1
			replace org="THE COLLEGE OF NEW JERSEY FOUNDATION" if CNG==1
			drop CNG
			****CORNELL UNIVERSITY****
			gen CU=1 if regexm(org, "CORNELL UNIVERSITY")
			if "`file'"=="members" {
				replace program_name=city if CU==1
			}
			replace city="ITHACA" if CU==1
			replace state= "NY" if CU==1
			replace org="CORNELL UNIVERSITY" if CU==1
			drop CU			
			***BONNER LEADERS****
			gen BON = 1 if regexm(org, "BONNER LEADERS")
			if "`file'"=="members" {
				replace program_name = city if BON==1
			}
			replace org = "BONNER FAMILY FOUNDATION INC" if BON==1
			drop BON
			***RED CROSS****
			gen RC=1 if regexm(org, "RED CROSS")
			if "`file'"=="members" {
				replace program_name=city if RC==1
			}
			replace org = "AMERICAN NATIONAL RED CROSS" if RC==1
			replace state = "DC" if RC==1
			replace city = "WASHINGTON" if RC==1
			drop RC
			***ST BERNARD PROJECT****
			gen SBP=1 if regexm(org, "ST BERNARND PROJECT")
			if "`file'"=="members" {
				replace program_name=state if SBP==1
			}
			replace org = "ST BERNARND PROJECT" if SBP==1
			replace state = "LA" if SBP==1
			replace city = "CHALMETTE" if SBP==1
			drop SBP
			***THE CORPS NETWORK****
			gen CN=1 if regexm(org, "CORPS NETWORK") 
			replace CN=1 if regexm(org, "NATIONAL") & regexm(org, "CONSERVATION CORPS")
			if "`file'"=="members" {
				replace program_name=city if CN==1
			}
			replace org = "THE CORPS NETWORK" if CN==1
			replace state = "DC" if CN==1
			replace city = "WASHINGTON" if CN==1
			drop CN
			***YOUTH VENTURE****
			gen YV=1 if regexm(org, "YOUTH VENTURE")
			if "`file'"=="members" {
				replace program_name=city if YV==1
			}
			replace org = "YOUTH VENTURE INC" if YV==1
			replace state = "VA" if YV==1
			replace city = "ARLINGTON" if YV==1
			drop YV
		}	
		**********************************************
		*****Collapse to Program/Org/State/Year Level *****
		**********************************************
		if "`file'"=="members" {
			sort org state city year program_name
			collapse (sum) N_DIRECT S_DIRECT DIRECT VISTA TOTAL corps, by(org state city year program_name)
			gen test=0
			replace test =1 if TOTAL==corps
			di "Test All values =1 ensures 1 observation for each org, state, city, year, and program"
			sum test
			drop test
			cd "`datadir'"
			save acmembers_citystateprogram, replace
		}	
		**********************************************
		*****Collapse Prograps to Org/City/Year Level *****
		**********************************************
		sort city state org year
		by city state org year: gen n=_N
		di "n=number of programs/grants within city state org year"
		sum n
		drop n
		if "`file'"=="members" {
			gen programs=1
			sort city state org year
			collapse (sum) N_DIRECT S_DIRECT DIRECT VISTA TOTAL corps programs (first) program_name, by(city state org year)
			label var programs "number of programs"
		}	
		if "`file'"=="grants" {
			gen grants=1
			sort city state org year
			by city state org year: egen ein1=mode(ein), minmode
			rename org_zip zip
			gen address=org_street_addr1
			replace address=address + org_street_addr2 if org_street_addr2!=""
			collapse (sum) award grants (first) ein1 address zip, by(city state org year)
			label var grants "number of grants"
		}	
		***save city level file****
		save ac`file'_citystateorg, replace
		**********************************************
		*****Collapse Prograps to Org/City/Year Level *****
		**********************************************
		sort org state year
		by org state year: gen n=_N
		di "n=number of programs/grants within state org year"
		sum n	
		drop n
		if "`file'"=="members" {
			collapse (sum) N_DIRECT S_DIRECT DIRECT VISTA TOTAL corps programs (first) program_name, by(org state year)
			***gen org id numbers****
			sort org state year
			egen orgid=group(org state)
		}	
		if "`file'"=="grants" {
			by org state: egen ein2=mode(ein)
			replace ein1=ein2
			drop ein2
			collapse (sum) award grants (first) ein address city zip, by(org state year)
		}
		by org state year: gen test=_N
		di "Test All values =1 ensures 1 observation for each org, state, year"
		sum test
		count if test>1
		count if test==1	
		drop test
		***save state level file****
		save ac`file'_stateorg, replace	
		****Save xwalk file
		if "`file'"=="members" {
			collapse (first) orgid program_name, by(org state)
		}
		if "`file'"=="grants" { 
			collapse (first) ein address city zip, by(org state) 
		}
		save ac`file'_xwalk, replace
	}
	**end loop over member and grants files***	
	****************************
	***Merge Xwalk files****
	****************************
	cd "`datadir'"
	clear all
	**merge city level files***
	clear all 	
	use acmembers_xwalk
	merge 1:1 org state using acgrants_xwalk
	save ac_xwalk, replace	
	***adding EINs***
	replace ein1=200409846 if org=="7TH GENERATION COMMUNITY SERVICES CORPORATION" & state=="FL"
	replace ein1=141790447 if org=="ABODE OF THE MESSAGE" & state=="NY"
	replace ein1=202917932 if org=="ACCESS OF WESTERN NEW YORK" & state=="NY"
	replace ein1=043219159 if org=="ACCION INTERNATIONAL" & state=="GA"
	replace ein1=850417347 if org=="ACCION NEW MEXICO" & state=="NM"
	replace ein1=043219159 if org=="ACCION USA" & state=="FL"
	replace ein1=391053365 if org=="ADVOCAP INC" & state=="WI"
	replace ein1=222707246 if org=="AIDS ACTION" & state=="MA"
	replace ein1=363412054 if org=="AIDS FOUNDATION OF CHICAGO" & state=="IL"
	replace ein1=340965339 if org=="AKRON SUMMIT COMMUNITY ACTION AGENCY" & state=="OH"
	replace ein1=46982469 if org=="ALBANY PINE BUSH PRESERVE COMMISSION" & state=="NY"
	replace ein1=651163540 if org=="AMERICA SCORES" & state=="CA"
	replace ein1=364386992 if org=="AMERICA SCORES" & state=="IL"
	replace ein1=43482756 if org=="AMERICA SCORES" & state=="MA"
	replace ein1=200500153 if org=="AMERICA SCORES" & state=="OH"
	replace ein1=300223534 if org=="AMERICA SCORES" & state=="TX"
	replace ein1=710931983 if org=="AMERICA SCORES" & state=="WA"
	replace ein1=371473291 if org=="AMERICAN CONSERVATION EXPERIENCE" & state=="CA"
	replace ein1=742687273 if org=="AMERICAN FOUNDATION FOR THE ELDERLY DEAF" & state=="TX"
	replace ein1=410693889 if org=="AMHERST H WILDER FOUNDATION" & state=="MN"
	replace ein1=341691158 if org=="ARAB AMERICAN COMMUNITY CENTER FOR ECONOMIC AND SOCIAL SERVICES" & state=="OH"
	replace ein1=600002593 if org=="ARAB AMERICAN FAMILY SERVICES" & state=="IL"
	replace ein1=840499858 if org=="ARCHDIOCESE OF DENVER" & state=="CO"
	replace ein1=272263942 if org=="ARCHDIOCESE OF WASHINGTON" & state=="DC"
	replace ein1=522404929 if org=="ARKWINGS FOUNDATION" & state=="TN"
	replace ein1=943148481 if org=="ARTSPAN" & state=="CA"
	replace ein1=411736822 if org=="ASIAN MEDIA ACCESS INC" & state=="MN"
	replace ein1=760545292 if org=="ASPIRING YOUTH OF HOUSTON" & state=="TX"
	replace ein1=362166961 if org=="ASSOCIATION HOUSE OF CHICAGO" & state=="IL"
	replace ein1=611361750 if org=="ASSOCIATION OF COMMUNITY MINISTRIES" & state=="KY"
	replace ein1=264421601 if org=="MYRTLE AVENUE COMMUNITY DEVELOPMENT CORPORATION" & state=="TX"
	replace ein1=330771222 if org=="BARRIO LOGAN COLLEGE INSTITUTE" & state=="CA"
	replace ein1=454463754 if org=="BASTROP COUNTY LONG TERM RECOVERY TEAM" & state=="TX"
	replace ein1=720768965 if org=="BATON ROUGE CRISIS INTERVENTION CENTER" & state=="LA"
	replace ein1=741159753 if org=="BAYLOR UNIVERSITY" & state=="TX"
	replace ein1=330917039 if org=="BAYVIEW CHARITIES" & state=="CA"
	replace ein1=450453966 if org=="BEYOND SHELTER" & state=="ND"
	replace ein1=752679331 if org=="BIG BEND NATIONAL PARK" & state=="TX"
	replace ein1=470492640 if org=="BLUE VALLEY COMMUNITY ACTION INC" & state=="NE"
	replace ein1=521420138 if org=="BLUE WATER BALTIMORE" & state=="MD"
	replace ein1=454040991 if org=="BOAT PEOPLE SOS" & state=="TX"
	replace ein1=300737900 if org=="BOAT PEOPLE SOS ATLANTA" & state=="TX"
	replace ein1=43351427 if org=="BOTTOM LINE" & state=="MA"
	replace ein1=860630295 if org=="BOYS HOPE GIRLS HOPE" & state=="AZ"
	replace ein1=363734433 if org=="BOYS HOPE GIRLS HOPE" & state=="CA"
	replace ein1=841239769 if org=="BOYS HOPE GIRLS HOPE" & state=="CO"
	replace ein1=431927487 if org=="BOYS HOPE GIRLS HOPE" & state=="KS"
	replace ein1=720905785 if org=="BOYS HOPE GIRLS HOPE" & state=="LA"
	replace ein1=522356443 if org=="BOYS HOPE GIRLS HOPE" & state=="MD"
	replace ein1=382536444 if org=="BOYS HOPE GIRLS HOPE" & state=="MI"
	replace ein1=132990982 if org=="BOYS HOPE GIRLS HOPE" & state=="NY"
	replace ein1=311054816 if org=="BOYS HOPE GIRLS HOPE" & state=="OH"
	replace ein1=251625524 if org=="BOYS HOPE GIRLS HOPE" & state=="PA"
	replace ein1=870435214 if org=="BRAIN INJURY ASSOCIATION OF UTAH INC" & state=="UT"
	replace ein1=521138207 if org=="BREAD FOR THE CITY" & state=="DC"
	replace ein1=222717615 if org=="BREAD OF LIFE MINISTRIES" & state=="ME"
	replace ein1=251621208 if org=="BROWNSVILLE AREA REVITALIZATION CORPORATION" & state=="PA"
	replace ein1=943235649 if org=="CALDERA" & state=="OR"
	replace ein1=770379630 if org=="CESAR E CHAVEZ FOUNDATION" & state=="CA"
	replace ein1=363777709 if org=="CHICAGO CARES INC" & state=="IL"
	replace ein1=135562191 if org=="THE CHILDRENS AID SOCIETY" & state=="NY"
	replace ein1=521362103 if org=="CHRIST HOUSE" & state=="DC"
	replace ein1=756000402 if org=="CHRIST THE KING CHURCH" & state=="TX"
	replace ein1=570314374 if org=="CLAFLIN UNIVERSITY" & state=="SC"
	replace ein1=953814898 if org=="COACHELLA VALLEY HOUSING COALITION" & state=="CA"
	replace ein1=570324908 if org=="COLUMBIA BETHLEHEM COMMUNITY CENTER" & state=="SC"
	replace ein1=742369020 if org=="COMMUNITIES IN SCHOOLS OF CENTRAL TEXAS" & state=="TX"
	replace ein1=943080214 if org=="COMMUNITY ACTION CENTER" & state=="WA"
	replace ein1=582140984 if org=="COMMUNITY MEDIATION CENTER INC" & state=="TN"
	replace ein1=541190896 if org=="COMMUNITY MEDIATION CENTER" & state=="VA"
	replace ein1=931155559 if org=="COMMUNITY PARTNERS FOR AFFORDABLE HOUSING" & state=="OR"
	replace ein1=232735283 if org=="COMMUNITY PREVENTION PARTNERSHIP OF BERKS COUNTY" & state=="PA"
	replace ein1=621308387 if org=="COMMUNITY RESOURCE CENTER" & state=="TN"
	replace ein1=591110325 if org=="COMMUNITY SERVICES COUNCIL OF BREVARD COUNTY INC" & state=="FL"
	replace ein1=990259857 if org=="COMMUNITY WORK DAY PROGRAM" & state=="HI"
	replace ein1=221958634 if org=="CONCERNED PARENTS FOR HEAD START" & state=="NJ"
	replace ein1=410693977 if org=="CONCORDIA COLLEGE CORPORATION" & state=="MN"
	replace ein1=931140056 if org=="CORVALLIS ENVIRONMENTAL CENTER" & state=="OR"
	replace ein1=160743025 if org=="CRADLE BEACH CAMP INC" & state=="NY"
	replace ein1=381443363 if org=="CROSSROADS FOR YOUTH" & state=="MI"
	replace ein1=953510046 if org=="CRYSTAL STAIRS INC" & state=="CA"
	replace ein1=300106285 if org=="CULLMAN COUNTY PARTNERSHIP FOR CHILDREN INC" & state=="AL"
	replace ein1=202626404 if org=="DENVER MOUNTAIN PARKS FOUNDATION INC" & state=="CO"
	replace ein1=720437696 if org=="DIOCESE OF LAFAYETTE" & state=="LA"
	replace ein1=621608838 if org=="DISABILITY RESOURCE CENTER INC" & state=="TX"
	replace ein1=430971877 if org=="DOUGLASS COMMUNITY SERVICES INC" & state=="MO"
	replace ein1=311640182 if org=="DRESS FOR SUCCESS CINCINNATI" & state=="OH"
	replace ein1=204448864 if org=="EAGLE RIVER WATERSHED COUNCIL INC" & state=="CO"
	replace ein1=330923085 if org=="EAST AFRICAN COMMUNITY OF ORANGE COUNTY" & state=="CA"
	replace ein1=510171851 if org=="EAST BAY ASIAN LOCAL DEVELOPMENT CORPORATION" & state=="CA"
	replace ein1=861096987 if org=="EAST RIVER DEVELOPMENT ALLIANCE INC" & state=="NY"
	replace ein1=942816185 if org=="THE ECONOMIC DEVELOPMENT CORPORATION SERVING FRESNO COUNTY" & state=="CA" 
	replace ein1=223798916 if org=="EDUCATION WORKS INC" & state=="PA"
	replace ein1=223798916 if org=="EDUCATION WORKS INC" & state=="PA"
	replace ein1=931268069 if org=="ELKTON COMMUNITY EDUCATION CENTER" & state=="OR"
	replace ein1=100002102 if org=="EVERYBODY WINS VERMONT" & state=="VT"
	replace ein1=521938281 if org=="EVERYBODY WINS WITH AMERICORPS DC" & state=="DC"
	replace ein1=263698436 if org=="EXPERIENCE CORPS WASHINGTON DC" & state=="DC"
	replace ein1=421465808 if org=="EXTEND THE DREAM FOUNDATION" & state=="IA"
	replace ein1=760769742 if org=="FAITH COMMUNITIES FOR DISASTER RECOVERY" & state=="TX"
	replace ein1=621573547 if org=="FALL CREEK FALLS STATE PARK" & state=="TN"
	replace ein1=510424714 if org=="FAMILIES FIRST" & state=="PA"
	replace ein1=570524498 if org=="FAMILY HEALTH CENTERS" & state=="SC"
	replace ein1=411332828 if org=="FAMILY PATHWAYS" & state=="MN"
	replace ein1=431071300 if org=="FAMILY RESOURCE CENTER" & state=="MO"
	replace ein1=630660148 if org=="FAMILY SERVICES CENTER" & state=="AL"
	replace ein1=990230341 if org=="FAMILY SUPPORT SERVICES OF WEST HAWAII" & state=="HI"
	replace ein1=202862598 if org=="FAYETTE COUNTY EDUCATION FUND" & state=="WV"
	replace ein1=50258871 if org=="FEDERAL HILL HOUSE" & state=="RI"
	replace ein1=943317612 if org=="FIRE SAFE COUNCIL OF NEVADA COUNTY" & state=="CA"
	replace ein1=371391104 if org=="FISHES AND LOAVES OUTREACH MINISTRIES" & state=="IL"
	replace ein1=271053791 if org=="FITTING BACK IN" & state=="OK"
	replace ein1=721154072 if org=="FOOD BANK OF CENTRAL LA" & state=="LA"
	replace ein1=412278687 if org=="FRANKLIN WATERSHED COMMITTEE" & state=="VT"
	replace ein1=10346944 if org=="FREEPORT HISTORICAL SOCIETY" & state=="ME"
	replace ein1=481129469 if org=="FRIENDS OF RECOVERY ASSOCIATION" & state=="KS"
	replace ein1=237112657 if org=="FRIENDSHIP CENTER" & state=="WI"
	replace ein1=562276012 if org=="FUTURES FOR KIDS" & state=="NC"
	replace ein1=208442170 if org=="GENERATION ONE" & state=="TX"
	replace ein1=742587818 if org=="GEORGE GERVIN YOUTH CENTER" & state=="TX"
	replace ein1=521683270 if program_name=="EARTH CONSERVATION CORPS" & state=="DC"
	replace ein1=580603146 if org=="GEORGIA TECH RESEARCH CORPORATION" & state=="GA"
	replace ein1=856011246 if org=="GIRL SCOUTS OF NEW MEXICO TRAILS" & state=="NM"
	replace ein1=363467921 if org=="GOODCITY NFP" & state=="IL"
	replace ein1=860512633 if org=="GRAND CANYON TRUST" & state=="AZ"
	replace ein1=820586174 if org=="GRAND COMPANIONS HUMANE SOCIETY" & state=="TX"
	replace ein1=880396516 if org=="GREAT BASIN OUTDOOR SCHOOL" & state=="NV"
	replace ein1=570528228 if org=="GREATER COLUMBIA LITERACY COUNCIL" & state=="SC"
	replace ein1=208151937 if org=="GREEN LIGHT NEW ORLEANS" & state=="LA"
	replace ein1=570521414 if org=="GREENVILLE LITERACY ASSOCIATION" & state=="SC"
	replace ein1=320182692 if org=="GROUNDWORK MILWAUKEE" & state=="WI"
	replace ein1=560529982 if org=="GUILFORD COLLEGE" & state=="NC"
	replace ein1=590862883 if org=="GULF STREAM BAPTIST ASSOCIATION" & state=="FL"
	replace ein1=990348767 if org=="HAWAIIAN COMMUNITY ASSETS" & state=="HI"
	replace ein1=830314268 if org=="HEADWATERS COMMUNITY ARTS AND CONFERENCE CENTER ASSOCIATION" & state=="WY"
	replace ein1=581048435 if org=="HISTORIC WESTVILLE" & state=="GA"
	replace ein1=953794653 if org=="HOPE CHRISTIAN CENTER" & state=="CA"
	replace ein1=208903301 if org=="HOPE FOR KIDS" & state=="PA"
	replace ein1=990153863 if org=="HUI MALAMA LEARNING CENTER" & state=="HI"
	replace ein1=841150542 if org=="I HAVE A DREAM FOUNDATION OF BOULDER COUNTY" & state=="CO"
	replace ein1=931037323 if org=="I HAVE A DREAM FOUNDATION OF OREGON" & state=="OR"
	replace ein1=362170136 if org=="ILLINOIS INSTITUTE OF TECHNOLOGY" & state=="IL"
	replace ein1=582039158 if org=="INDEPENDENT LIVING RESOURCES OF GREATER" & state=="AL"
	replace ein1=237260197 if org=="INDIAN CREEK NATURE CENTER" & state=="IA"
	replace ein1=942166244 if org=="INSTITUTE FOR CONTEMPORARY STUDIES" & state=="CA"
	replace ein1=135660870 if org=="INTERNATIONAL RESCUE" & state=="NY"
	replace ein1=421405188 if org=="IOWA DENTAL FOUNDATION" & state=="IA"
	replace ein1=431191832 if org=="KANSAS CITY NEIGHBORHOOD ALLIANCE" & state=="KS"
	replace ein1=570820792 if org=="MARLBORO LITERACY COUNCIL" & state=="SC"
	replace ein1=42613803 if org=="MASSACHUSETTS COLLEGE OF LIBERAL ARTS" & state=="MA"
	replace ein1=911850344 if org=="MEDICAL OUTREACH COALITION" & state=="NE"
	replace ein1=746088061 if org=="MEXICAN AMERICAN UNITY COUNCIL" & state=="TX"
	replace ein1=421324801 if org=="MIRACLES IN MOTION THERAPEUTIC EQUESTRIAN CENTER" & state=="IA"
	replace ein1=860888028 if org=="NEIGHBORHOOD ECONOMIC DEVELOPMENT CORPORATION" & state=="AZ"
	replace ein1=60872959 if org=="NEW ENGLAND FARM WORKERS" & state=="MA"
	replace ein1=570899274 if org=="NEW HORIZON MINISTRIES" & state=="MS"
	replace ein1=233011224 if org=="NORTHEAST PENNSYLVANIA AREA HEALTH EDUCATIONCENTER" & state=="PA"
	replace ein1=382282180 if org=="OAKLAND COMMUNITY COLLEGE" & state=="MI"
	replace ein1=310842542 if org=="OHIO ASSOCIATION OF COMMUNITY ACTION AGENCIES" & state=="OH"
	replace ein1=582282396 if org=="PEE DEE HEALTHY START" & state=="SC"
	replace ein1=820461673 if org=="POCATELLO NEIGHBORHOOD HOUSING SERVICES" & state=="ID"
	replace ein1=50262713 if org=="PROVIDENCE PUBLIC LIBRARY" & state=="RI"
	replace ein1=237146768 if org=="REGIONAL MEDICAL CENTER AT LUBEC" & state=="ME"
	replace ein1=134336082 if org=="RIVERS TO RIDGES HERITAGE TRAIL" & state=="WV"
	replace ein1=250965390 if org=="SARAH HEINZ HOUSE" & state=="PA"
	replace ein1=237394320 if org=="SOUTH BEND HERITAGE FOUNDATION" & state=="IN"
	replace ein1=352032442 if org=="TALTREE ARBORETUM AND GARDENS" & state=="IN"
	replace ein1=232817418 if org=="THE LAND CONSERVANCY FOR SOUTHERN CHESTER COUNTY" & state=="PA"
	replace ein1=930591582 if org=="TRANSITION PROJECTS" & state=="OR"
	replace ein1=731624311 if org=="TWO RIVERS NATIVE AMERICAN TRAINING CENTER" & state=="OK"
	replace ein1=640387703 if org=="UNITED WAY OF EAST MISSISSIPPI" & state=="MS"
	replace ein1=710236869 if org=="UNITED WAY OF SOUTHEAST ARKANSAS" & state=="AR"
	replace ein1=42708670 if org=="UPHAMS CORNER COMMUNITY CENTER" & state=="MA"
	replace ein1=237022588 if org=="MOBILE MEDICAL CARE" & state=="MD"
	replace ein1=431618182 if org=="SOUTHEASTERN MISSOURI AREA HEALTH EDUCATION CENTER" & state=="MO"
	save ac_xwalk2, replace
	***merge state level files****
	clear all 	
	use ac_xwalk2
	sort orgid state org
	gen tempid=_n
	expand 9
	sort tempid
	by tempid: gen year=2004+_n
	drop tempid
	capture drop _merge
	merge 1:1 orgid org state year using acmembers_stateorg
	rename _merge membermerge
	merge 1:1 org state year using acgrants_stateorg
	rename _merge grantsmerge
	rename ein1 ein
	***expand orgid and ein number to observations where they are missing*******
	sort org state
	by org state: egen orgid2=min(orgid)
	qui sum orgid
	local numorgs=r(max)
	qui gen test=0
	qui replace test=1 if orgid2==.
	di "test: mean is pct without orgid"
	sum test
	drop test
	egen orgid3=group(org state) if orgid2==.
	replace orgid3=orgid3+`numorgs'
	order orgid orgid2 orgid3
	replace orgid=orgid2
	replace orgid=orgid3 if orgid==.
	drop orgid2 orgid3
	by org state: egen ein2 = mode(ein), minmode
	order orgid ein ein2
	qui gen test=0
	qui replace test=1 if ein2==.
	di "test: mean is pct without ein"
	sum test
	drop test
	replace ein=ein2	
	drop ein2
	destring ein, force replace
	recast long ein
	***save*****
	save ac_master, replace	
	***save crosswalk file****
	sort orgid ein
	collapse (first) city state org, by(orgid ein)
	cd "`datadir'/Crosswalk"
	save cross_temp_AC, replace	
}
*********************************************
********Clean IRS MasterFiles:********************
*********************************************
if "`cleanIRS'"=="yes"{
	clear all
	cd "`datadir'"
	foreach n of numlist 1/4{
		insheet using eo`n'.csv, comma
		keep ein name street city state zip
		save IRSMF`n', replace
		clear all
	}
	use IRSMF1
	foreach n of numlist 2/4{
	append using IRSMF`n'
	}
	rename name org
	drop if state==""
	***Clean Data formatting***
	foreach var of varlist org state city {
			replace `var'=upper(`var')
			replace `var' = subinstr(`var', "CORP.", "CORPORATION",.)
			replace `var' = subinstr(`var', "&", " AND ",.)
			replace `var' = subinstr(`var', "-", " ",.)
			replace `var' = subinstr(`var', "/", " ",.)
			replace `var' = subinstr(`var', ",", " ",.)
			replace `var' = subinstr(`var', "ASSOC", "ASSOCIATION",.)
			replace `var' = subinstr(`var', "ASSOCIATIONIATION", "ASSOCIATION",.)
			replace `var' = subinstr(`var', "INCORPORATED", "",.)
			replace `var' = subinstr(`var', "INC.", "",.)
			replace `var' = subinstr(`var', "  ", " ",.)
			replace `var' = subinstr(`var', "  ", " ",.)
			egen `var'2=sieve(`var'), keep(alphabetic numeric space)
			replace `var'=`var'2
			drop `var'2
			replace `var'=trim(`var')
			replace `var'=trim(`var')
	}	
	**Change Naming Convnetions to match AmeriCorps Dataset****
	/* Convention ensures that programs are not collapsed at the state 
	level by renaming to a basic convention */
	gen BGA=1 if regexm(org,"BOYS AND GIRLS CLUB")
	replace org = "BOYS AND GIRLS CLUB "+city if BGA==1
	drop BGA
	gen HFH=1 if regexm(org,"HABITAT FOR HUMANITY") | regexm(org,"HFH") | regexm(org, "HABITAT FOR HUMANITIES")
	replace org = "HABITAT FOR HUMANITY "+city if HFH==1
	drop HFH
	*Big Brothers Big Sisters**
	gen BBBS=1 if regexm(org,"BIG BROTHERS BIG SISTERS")
	replace org = "BIG BROTHERS BIG SISTERS"+city if BBBS==1
	drop BBBS
	*so that both names are shown after merge*
	rename org org3
	***save temp file****
	cd "`datadir'/Crosswalk"
	save cross_temp_IRS, replace
}
*********************************************
********Combine NCCS Extracts:********************
*********************************************
if "`mergeNCCS'"=="yes"{
	cd "/econ/dteles/NCCSdata/Extracts"
	****Create 2013 temp file****
	/*	1989-2012 tempfiles were created in CombinedNCCS_V_<date>.do for use
		in the State Tax Credits study   */	
	use CorePC2013
	keep ein fisyr name-zip5 cont progrev invinc totrev ass_boy-liab_eoy lessdirf fundfees lessdirf lessdirg rentexp compens
		***Edit Fundraising Expenses for consistancy after change in 990 Form
		gen solicit=fundfees+lessdirf+lessdirg	
		****destring for help with merge and sort.
		destring ein fisyr , replace
		recast long ein
		****generate a variable for which version the data came from
		gen yr_filed = 2013
	***Save 2013temp file***
	save CorePC2013_temp, replace
	****merge*****
	foreach num of numlist 2004/2012{
		append using CorePC`num'_temp
	}
	**saving**
	cd "`datadir'"
	save NCCS_core_combined_temp, replace
}
*********************************************
********Clean NCCS Extracts:********************
*********************************************
if "`cleanNCCS'"=="yes"{
	clear all
	cd "`datadir'"
	use NCCS_core_combined_temp
	rename name org
	****Clean String Data****
	foreach var of varlist org state city {
		qui {
			replace `var'=upper(`var')
			replace `var' = subinstr(`var', "CORP.", "CORPORATION",.)
			replace `var' = subinstr(`var', "&", " AND ",.)
			replace `var' = subinstr(`var', "-", " ",.)
			replace `var' = subinstr(`var', "/", " ",.)
			replace `var' = subinstr(`var', ",", " ",.)
			replace `var' = subinstr(`var', "ASSOC", "ASSOCIATION",.)
			replace `var' = subinstr(`var', "ASSOCIATIONIATION", "ASSOCIATION",.)
			replace `var' = subinstr(`var', "INCORPORATED", "",.)
			replace `var' = subinstr(`var', "INC.", "",.)
			replace `var' = subinstr(`var', "  ", " ",.)
			replace `var' = subinstr(`var', "  ", " ",.)
			egen `var'2=sieve(`var'), keep(alphabetic numeric space)
			replace `var'=`var'2
			drop `var'2
			replace `var'=trim(`var')
			replace `var'=trim(`var')
		}	
	}
	keep if fisyr>=2004
	keep if fisyr<=2013
	**Some observations have mulitple entries, keep most recent filing**
	sort ein fisyr yr_filed
	by ein fisyr: gen n1=_N
	by ein fisyr: gen n2=_n
	keep if n1==n2
	drop n1 n2
	sort yr_filed
	count
	/*Make sure that programs are not collapsed at the state level
	by renaming to a basic convention */
	qui {
		gen BGA=1 if regexm(org,"BOYS AND GIRLS CLUB")
		replace org = "BOYS AND GIRLS CLUB "+city if BGA==1
		drop BGA
		gen HFH=1 if regexm(org,"HABITAT FOR HUMANITY") | regexm(org,"HFH")
		replace org = "HABITAT FOR HUMANITY "+city if HFH==1
		drop HFH
		*Big Brothers Big Sisters**
		gen BBBS=1 if regexm(org,"BIG BROTHERS BIG SISTERS")
		replace org = "BIG BROTHERS BIG SISTERS"+city if BBBS==1
		drop BBBS
		replace org="MA CAMPUS COMPACT" if org=="CAMPUS COMPACT" & state=="MA"
		**ensure all orgs have the same name listed each year***
		sort ein fisyr
		egen org2=first(org), by(ein)
		gen invyr=2020-fisyr
		sort ein invyr
		egen org3=first(org), by(ein)
		replace org=org3
		drop invyr org3
		gen org2_flag=0
		replace org2_flag=1 if org2!=org
		cd "`datadir'"
	}
	****Saving***********
	save NCCS_core_combined, replace
} 
********************************************
*******Merge IRS data with NCCS*************
********************************************
if "`crosswalk'"=="yes"{
	clear all
	cd "`datadir'"
	use NCCS_core_combined
	/*collapse to a single entry / remove years  and financial data*/
	collapse (first) org2 address zip org2_flag, by(ein org state city)
	cd "`datadir'/Crosswalk"
	merge m:1 ein using cross_temp_IRS
	drop _merge
	rename street address2
	foreach var of varlist address address2 org org2 org3 {
		recast str99 `var'
	}
	replace address2=address if address2=="" 
	replace address=address2 if address==""
	replace org=org3 if org==""
	replace org2=org3 if org2==""
	replace org3=org if org3==""
	gen org3_flag=0
	replace org3_flag=1 if org3!=org & org3!=org2
	replace org2_flag=0 if org2_flag==.
	***save crosswalk
	cd "`datadir'/Crosswalk"
	save cross_temp_IRS_NCCS, replace
	/*collapse by ein*/
	preserve	
	collapse (first)  org state city org2 address zip org2_flag, by(ein)	
	save cross_temp_IRS_NCCS_ein, replace
	restore
	/*collapse by state org*/
	preserve	
	***collapse by orgnames ****
	gen org1=org
	sort state org1 org2 org3 org
	gen numeins=1
	collapse (first) org city address zip org2_flag org3_flag (sum) numeins (min) ein, by(state org1 org2 org3)
	drop if org==""
	***count duplicates by each of 3 names
	foreach a in 1 2 3 {
		sort state org`a'
		by state org`a': gen org`a'n=_N
		di "solos org `a'"
		count if org`a'n==1
		di "duplicates org `a'"
		count if org`a'n>1
	}
	****collapse to single observation, keeping up to 3 names****
	foreach a in 2 3 {
		replace org`a'="" if org`a'==org1
		if `a'==3 {
			replace org3="" if org3==org2
		}	
		qui sum org1n
		local x=r(max)
		foreach x in 1/`x' {
			sort state org
			by state org: replace org`a'=org`a'[_n-1] if org`a'==""
			by state org: replace org`a'=org`a'[_n+1] if org`a'==""
		}
		sort state org
		if `a'==2 {
			by state org: egen temp=mode(org2), minmode
		}
		if `a'==3 {
			by state org: egen temp=mode(org3), maxmode	
		}
		replace org`a'=temp
		drop temp
		replace org`a'=org if org`i'==""
	}
	sort state org
	collapse (first) ein org1 org2 org3 city address zip org2_flag org3_flag (sum) numeins, by(state org)	
	save cross_temp_IRS_NCCS_storg, replace
	restore
}
***************************************
*******Merge on EIN, then State and Organization***
********************************************
if "`crosswalk'"=="yes" {
	cd "`datadir'/Crosswalk"
	foreach n of numlist 1/7 {
		local j=`n'-4
		local k=`n'-3
		local l = `n'-2
		local m=`n'-1
		clear all
		di "--------"
		****1. MERGE ON EIN*******
		if `n'==1 {
			di "merge on ein"
			use cross_temp_AC
			rename city city2
			merge m:1 ein using cross_temp_IRS_NCCS_ein	
		}
		****2. MERGE ON FIRST ORG NAME*********
		if `n'==2 {
			di "merge on org name `m'"
			use nomatch_AC`m'		
			merge 1:1 state org using cross_temp_IRS_NCCS_storg
		}
		****3. MERGE ON SECOND ORG NAME*********
		****4. MERGE ON THIRD ORG NAME*********
		if `n'==3  | `n'==4 {
			di "merge on org name `m'"
			use nomatch_AC`m'
			merge 1:1 state org using nomatch_NCCS`m'	
		}
		****5. FUZZY MERGE ON FIRST ORG NAME*********
		****6. FUZZY MERGE ON SECOND ORG NAME*********
		****7. FUZZY MERGE ON THIRD ORG NAME*********	
		if `n'==5 | `n'==6  | `n'==7 {
			di "fuzzy merge on org name `j'"
			use nomatch_AC`m'
			if `n'==5 {
				rename city2 city
			}
			reclink city state org using nomatch_NCCS`m', idm(orgid) idu(ein2) gen(match) required(state) orblock(state) wmatch(1 100 10)
		}
		****Save files by merge type******
		if `n' <=4 {
			foreach i of numlist 1/3 {
				preserve
				keep if _merge==`i'
				***AC only***
				if `i'==1 {
					keep org orgid state city2		
					save nomatch_AC`n', replace
				}
				***NCCS only****
				if `i'==2 {
					drop city2 orgid _merge
					if `n'==2 |`n'==3 {
						replace org=org`n'
						collapse (first) ein org1 org2 org3 city address zip org2_flag org3_flag (sum) numeins, by(state org)			
					}
					if `n'==4 {
						replace org=org1
						gen double ein2=ein
						sort ein2
						by ein2: gen n=_n
						replace ein2=ein2*10+n-1
						drop n
					}					
					save nomatch_NCCS`n', replace			
				}
				***MATCH***
				if `i'==3 {
					save match`n', replace
				}
				restore
			}
		}
		if `n' >=5 {
			***match******
			preserve
			keep if match>.99835
			keep ein ein2 orgid org org1 org2 org3 state city address numeins
			save match`n', replace
			restore
			***nomatch***
			drop if match>.99835
			collapse (first) state org city, by(orgid)	
			save nomatch_AC`n', replace
			***reorder org name list
			if `n'==5 | `n'==6 {
				clear all
				use nomatch_NCCS`m'
				replace org=org`k'
				save nomatch_NCCS`n', replace
			}
		}		
	}
	***End loop over merges
	clear all
	use match1
	foreach n of numlist 2/7 {
		append using match`n'
	}
	save crosswalk, replace
}
****************************************
*******Combine Data*************************
********************************************
if "`combine'"=="yes"{
	***Load Crosswalk***
	cd "`datadir'/Crosswalk"
	clear all
	use crosswalk
	keep orgid ein numeins state city org1 org2 org3
	rename state state2
	rename city city2
	expand 9
	sort orgid
	by orgid: gen year=2004+_n
	***merge in AmeriCorps Data***
	cd "`datadir'"
	rename ein ein_xwalk
	merge 1:1 orgid year using ac_master
	destring ein, force replace
	replace ein = ein_xwalk if ein==.	
	save ac_merged, replace
	drop if _merge==2
	drop _merge
	rename year fisyr
	/*organizations listed under 2 names for AmeriCorps matched
	to the same EIN number*/
	count
	sort state ein fisyr
	by state ein fisyr: gen n=_N
	count if n!=1
	drop n
	sort ein fisyr
	by ein fisyr: gen n=_N
	count if n!=1
	drop n
	foreach var of varlist org state {
		by ein fisyr: egen temp=mode(`var'), maxmode
		replace `var' = temp
		drop temp
	}
	collapse (first) org orgid state (sum) N_DIRECT-corps award grants, by(ein fisyr)
	****merge in NCCS data****
	merge 1:1 ein fisyr using NCCS_core_combined
	sort ein fisyr
	foreach var of varlist org state ntee1 nteecc {
		bysort ein: carryforward `var', replace
	}
	gsort ein - fisyr
	foreach var of varlist org state ntee1 nteecc {
		by ein: carryforward `var', replace
		di "Checking to make sure no `var' identifiers are missing"
		di "Number missing:"
		count if `var'==""		
	}
	****Save*****
	sort ein fisyr	
	save NCCS_AC_master, replace
}


/* To do list:  Keep working with merge and data cleaning of final dataset.
