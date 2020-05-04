import delimited "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-counties.csv", clear

* this produces "date" which is formatted MM/DD. It preserves olddate as str: yyyymmdd
rename date oldate
replace oldate = subinstr(oldate, "-", "",.)
*this uses the installed ado todate
todate oldate, gen(date) p(yyyymmdd) f(%tdnn/dd)
drop oldate

/* note cases and deaths in the NYT file are already cumulative */

*this generates two-digit state names, "st"

gen st=""

replace st = "AL" if state=="Alabama"
replace st = "AK" if state=="Alaska"
replace st = "AZ" if state=="Arizona"
replace st = "AR" if state=="Arkansas"
replace st = "CA" if state=="California"
replace st = "CO" if state=="Colorado"
replace st = "CT" if state=="Connecticut"
replace st = "DE" if state=="Delaware"
replace st = "DC" if state=="District of Columbia"
replace st = "FL" if state=="Florida"
replace st = "GA" if state=="Georgia"
replace st = "HI" if state=="Hawaii"
replace st = "ID" if state=="Idaho"
replace st = "IL" if state=="Illinois"
replace st = "IN" if state=="Indiana"
replace st = "IA" if state=="Iowa"
replace st = "KS" if state=="Kansas"
replace st = "KY" if state=="Kentucky"
replace st = "LA" if state=="Louisiana"
replace st = "ME" if state=="Maine"
replace st = "MD" if state=="Maryland"
replace st = "MA" if state=="Massachusetts"
replace st = "MI" if state=="Michigan"
replace st = "MN" if state=="Minnesota"
replace st = "MS" if state=="Mississippi"
replace st = "MO" if state=="Missouri"
replace st = "MT" if state=="Montana"
replace st = "NE" if state=="Nebraska"
replace st = "NV" if state=="Nevada"
replace st = "NH" if state=="New Hampshire"
replace st = "NJ" if state=="New Jersey"
replace st = "NM" if state=="New Mexico"
replace st = "NY" if state=="New York"
replace st = "NC" if state=="North Carolina"
replace st = "ND" if state=="North Dakota"
replace st = "OH" if state=="Ohio"
replace st = "OK" if state=="Oklahoma"
replace st = "OR" if state=="Oregon"
replace st = "PA" if state=="Pennsylvania"
replace st = "RI" if state=="Rhode Island"
replace st = "SC" if state=="South Carolina"
replace st = "SD" if state=="South Dakota"
replace st = "TN" if state=="Tennessee"
replace st = "TX" if state=="Texas"
replace st = "UT" if state=="Utah"
replace st = "VT" if state=="Vermont"
replace st = "VA" if state=="Virginia"
replace st = "WA" if state=="Washington"
replace st = "WV" if state=="West Virginia"
replace st = "WI" if state=="Wisconsin"
replace st = "WY" if state=="Wyoming"

drop if st=="" /* delete territories */
drop if county=="Unknown"

replace county = "Dona Ana" if county=="DoÃ±a Ana" /* special character */

/* County notes:
   NYT created Kansas City MO as a county with the part of the counties that are in the city. I gave it pop 491918
   NYT combined NYC counties into NYC, NY; I summed their pops to 8336817
   I otherwise changed Census names to match NYT names, eg deleting "parish"
   Watch out for these cases if you are adding more county variables to the dataset.
*/

/* This makes "cyst," which is formatted as: County, ST. Later it's renamed NAME to match the other files */
egen cyst = concat(county st), p(", ")

replace cyst = subinstr(cyst, ".", "",.)
egen cystf = concat(county state), p(", ")

sort cyst date

by cyst: egen maxdeath = max(death) /* mark each year with the county maximium */
by cyst: egen maxcase = max(cases) /* mark each year with the county maximium */
gen newdeaths=.
replace newdeaths = death-death[_n-1]
by cyst: replace newdeaths=0 if _n==1

by cyst: gen newcases=0 if _n==1
replace newcases= cases-cases[_n-1]
replace newcases = 0 if newcases<0 /* some pick up the cases from the end of the previous record */

* add county population
save counties, replace
import delimited "https://raw.githubusercontent.com/philipncohen/county-pop/master/county-pop.csv", clear
sort cystf
save countypop, replace

use counties, clear
sort cystf
merge m:1 cystf using countypop
keep if _merge==3
drop _merge

sort fips

save counties, replace

* make it a list of ALL COUNTIES, not just those with any cases-cases
* note this is quick but those with no cases won't have anything but a fips, no name, state, etc.

import delimited "https://raw.githubusercontent.com/philipncohen/county-pop/master/all-geocodes-v2017.csv", stringcols(2 3) clear
keep if level==50
drop level
rename name countyname
egen tfips =concat(state county)
destring tfips, gen(fips)
drop tfips
sort fips

merge 1:m fips using counties
drop _merge

replace cases=0 if cases==.
replace deaths=0 if deaths==.
replace maxcase=0 if maxcase==.
replace maxdeath=0 if maxdeath==.
replace newcases=0 if newcases==.
replace newdeaths=0 if newdeaths==.

save counties, replace

/* Add a rural county indicator/NY */

*  list from this source: https://www.consumerfinance.gov/policy-compliance/guidance/mortgage-resources/rural-and-underserved-counties-list/

sort fips

import delimited "https://raw.githubusercontent.com/philipncohen/county-pop/master/list%20of%20rural%20counties%20cfpb%202019.csv", clear
keep fips
gen rural=1
sort fips
save rural, replace

merge 1:m fips using counties
replace cases=0 if cases==.

*drop if _merge==2
drop _merge
replace rural=0 if rural==.

* NOTE places with no cases have no identifying info except FIPS and the Census countyname, so they should be mapped as zeros ok

save counties, replace

/* this adds the clinton and trump vote, which I modified a little, from 2016 from this source:
Lab, MIT Election Data and Science. 2019.
“County Presidential Election Returns 2000-2016.”
Harvard Dataverse. DOI:10.7910/DVN/VOQCHQ
*/

import delimited "https://raw.githubusercontent.com/philipncohen/county-pop/master/countypres_2000-2016.csv", clear
keep if candidate=="Donald Trump"
rename candidatevotes trump
keep fips trump
sort fips
save djt, replace
sum

import delimited "https://raw.githubusercontent.com/philipncohen/county-pop/master/countypres_2000-2016.csv", clear
keep if candidate=="Hillary Clinton"
rename candidatevotes clinton
keep fips clinton
sort fips
save hrc, replace

use counties, clear
merge m:1 fips using hrc
drop if _merge==2
drop _merge
save counties, replace

use counties, clear
merge m:1 fips using djt
drop if _merge==2
drop _merge

* combine nyc counties
replace clinton=2164575 if cyst=="New York City, NY"
replace trump=494548 if cyst=="New York City, NY"
gen trump16=(trump/(clinton+trump))*100

save counties, replace

*correct for 4/7
replace death=27 if cyst=="District of Columbia, DC" & date==22012

sort cyst date

***** adding in county median household income

* source: Source: U.S. Census Bureau, Small Area Income and Poverty Estimates, 2018 estimates:
* https://www.census.gov/data/datasets/2018/demo/saipe/2018-state-and-county.html
* total for US: 61937

import delimited "C:\Users\pnc\Dropbox\coronavirus\data files\household median income counties 2018.csv", clear

sort fips
save medhhinc, replace

use counties, clear
sort fips
merge m:1 fips using medhhinc
drop if _merge==2
drop _merge

rename cyst name

*** add place notes
gen placenote=""
replace placenote= "Tyson poultry plant" if name=="Accomack, VA"
replace placenote= "Navajo reservation" if name=="Apache, AZ"
replace placenote= "Tyson pork plant" if name=="Black Hawk, IA"
replace placenote= "Tourism" if name=="Blaine, ID"
replace placenote= "State prison" if name=="Bledsoe, TN"
replace placenote= "Nursing home outbreak" if name=="Butler, KY"
replace placenote= "State prison" if name=="Calhoun, GA"
replace placenote= "Tyson pork plant" if name=="Cass, IN"
replace placenote= "Tyson beef plant" if name=="Dakota, NE"
replace placenote= "Tyson beef plant" if name=="Dawson, NE"
replace placenote= "Tyson chicken plant" if name=="Dooly, GA"
replace placenote= "Nursing home outbreak" if name=="Early, GA"
replace placenote= "State mental hospital" if name=="East Feliciana, LA"
replace placenote= "Tyson beef plant" if name=="Finney, KS"
replace placenote= "National/Cargill beef plants" if name=="Ford, KS"
replace placenote= "Wind turbine factory" if name=="Grand Forks, ND"
replace placenote= "Ski resort" if name=="Gunnison, CO"
replace placenote= "Nursing home outbreak" if name=="Holmes, MS"
replace placenote= "Jennie-O Turkey" if name=="Kandiyohi, MN"
replace placenote= "Nursing home outbreak" if name=="Lauderdale, MS"
replace placenote= "State prison" if name=="Lincoln, AR"
replace placenote= "State prison" if name=="Logan, CO"
replace placenote= "Tysons pork plant" if name=="Louisa, IA" 
replace placenote= "Tyson pork plant" if name=="Madison, NE"
replace placenote= "State prison" if name=="Marion, OH"
replace placenote= "Navajo/Zuni reservations" if name=="McKinley, NM"
replace placenote= "JBS beef plant" if name=="Moore, TX"
replace placenote= "JBS pork plant" if name=="Nobles, MN"
replace placenote= "Tyson pork plant" if name=="Dallas, IA"
replace placenote= "State prison" if name=="Pickaway, OH"
replace placenote= "Meatpacking" if name=="Platte, NE"
replace placenote= "Nursing home outbreak" if name=="Randolph, GA"
replace placenote= "State prison" if name=="Richmond, VA"
replace placenote= "Poultry plants" if name=="Robeson, NC"
replace placenote= "Smithfield pork plant" if name=="Saline, NE"
replace placenote= "National beef plant" if name=="Seward, KS"
replace placenote= "State prison" if name=="Southampton, VA"
replace placenote= "Meatpacking" if name=="Stearns, MN"
replace placenote= "Iowa Premium beef plant" if name=="Tama, IA"
replace placenote= "Nursing home outbreak" if name=="Terrell, GA"
replace placenote= "Seaboard pork plant" if name=="Texas, OK"
replace placenote= "State prison" if name=="Trousdale, TN"
replace placenote= "Ski resort" if name=="Eagle, CO"
replace placenote= "Tyson beef plant" if name=="Woodbury, IA"

gen rectype = ""
replace rectype = "County" /* county record type */

label var st "State code of county"
label var cystf "County and state name"
label var county "County name"
label var state "State of county"
label var fips "County code"
label var clinton "Clinton votes 2016"
label var trump "Trump votes 2016"
label var trump16 "Trump share of two-party vote"
label var hhmedinc "County median household income"

save counties, replace
