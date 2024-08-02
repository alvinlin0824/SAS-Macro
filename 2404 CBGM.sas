dm 'log' clear; /* CLEARS LOG WINDOW */
dm pgm 'winclose'; /* CLOSES PROGRAM EDITOR WINDOW*/
/*******************************************************************
Program Name:				2404 CBGM
SAS Version:				9.4 TS Level 1M6
Location:					h:\Data\Study_Data\Apollo\UK_PM\14020\2404\SAS Code
Programmer:					w amor
Purpose:					Run PUMA-CBGM	
Program History:
Date	Programmer	Type	Change made
_______	__________	_______	____________________________
13jun24	w amor		new
*******************************************************************/

*** CURRENT DATE TIME;
%let startdt=%sysfunc(putn(%sysfunc(datetime()),datetime20.)); *** OBTAINS CURRENT DATA AND TIME 
																IN DDMMMYYY:HH:MM:SS FORMAT;
data _null_;
currentdatetime="&startdt";
suffix=translate(currentdatetime,"_",":"); *** REPLACES : WITH _ ;
call symput('fdtm',trim(left(suffix)));
run;

*** CREATES DATE IDENTIFIER FOR OUTPUT FILES;
data _null_;
      call symput("fdate",lowcase(left(put("&sysdate"d,date9.))));
run;

ods escapechar='^';

%let auuroot=\\oneabbott.com\EMEA\UK\Witney\ADC\Data\Study_RawData\Apollo\UK_PM\14020\24\2404\AUUdata;
             
/*%Include "F:\Custom\SASPROGS\DEV\PUMA\PUMA_A2SDataStacking\PUMA_A2SDataStacking.SAS";*/
/*%PUMA_A2SDataStacking(&auuroot, &auuroot);*/

%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_CBGM.sas";
          
/*LOCATION OF STACKED DATA*/
%let PUMASM=h:\data\Study_RawData\Apollo\UK_PM\14020\24\2404\AUUdata\PUMAout;

libname PUMASM "&PUMASM" eoc=no access=readonly;

/*GET LIST OF STACKED DATASETS*/
proc contents data=PUMASM._all_ out=PUMAOUT noprint;
run;

proc sql noprint;
/*GET SUFFIX OF MOST RECENT STACKED BG DATASET*/
select distinct substr(memname,4) into :SMdate 
from PUMAOUT 
where substr(upcase(memname),1,2)="BG" 
having max(crdate)=crdate;
quit;

%put &SMdate;
%let stripadj=-1.45;
%PUMA_CBGM(P4in=&PUMASM,
ds=&SMdate,
bg_dup = 1,
strip_adj=&stripadj);
