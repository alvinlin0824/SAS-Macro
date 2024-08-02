dm 'log' clear; /* CLEARS LOG WINDOW */
dm pgm 'winclose'; /* CLOSES PROGRAM EDITOR WINDOW*/

/*******************************************************************
Program Name:				2404 A2S Status with plots.sas
SAS Version:				9.4 TS Level 1M6
Programmer:					w amor
Purpose:					Summarise data processed with A2S
Procedures used:			ADC-UK-PMS-14020
Program History:
Date	Programmer	Type	Change made
_______	__________	_______	____________________________
17apr24 w amor		new
16may24 w amor		update	update BG adjustment, add PTU data
*******************************************************************/

/* IF RUN REMOTELY USE CISCO TO SEND EMAIL*/

options pagesize=max linesize=max;
%global eventid protocol doplots ppoints exc_pre_fpi analysis ac acus1 acus2;

%let eventid=2404;
%let year=24;
%let protocol=14020;
%let ptu=yes;
%let doplots=yes;
/* CRITERION FOR PAIRED POINTS: 14020 = 28, 14021 = 32*/
%let ppoints=28;

/*USE MEAN PERCENT BIAS FOR STRIPADJ OR 999 FOR NO ADJUSTMENT*/
%let stripadj=-1.45;

/*TO EXCLUDE PRFOFILE PLOTS WITH SENSOR_START BEFORE FPI USE  %let exc_pre_fpi=YES */
%let exc_pre_fpi=NO;

%let analysis=OUS;

%let ac=73;
%let acus1=79;
%let acus2=20.2;

/*MACRO TO DELETE ALL DATASETS IN THE WORK DIRECTORY*/
%macro deldata;

proc sql noprint;
   select count(memname) into : dscount
   from dictionary.members
   where libname='WORK' and memtype='DATA';
quit;

%if %eval(&dscount) > 0 %then %do;

proc datasets lib=work kill memtype=data;
run;
quit;
%end;

%mend;
%deldata;

options source2;
%include "H:\Data\Study_Data\Apollo\UK_PM\SAS Code\A2S_Status\A2S Status with plots.sas";

%macro email;

DATA text;
length text $250;
text="ADC-UK-PMS-&protocol. Study Event &eventid. - &analysis";output;
PUT " ";
text="A2S Data Summary: (includes summary of paired points, links to ceg and profile plots, comparison of AUU data with SA CRF data and plots plots of paired points and biases.)";output;
PUT " ";
text="Strip Adjustment using Mean Percent Bias value: &stripadj";output;

	%if %upcase(&ptu)=YES %then %do;
text="Libre 3 data included.";output;
	%end;
text="file://oneabbott.com/EMEA/UK/Witney/ADC/Data/Study_RawData/Apollo/UK_PM/&protocol./&year./&eventid./AUUdata/Links%20to%20A2S%20&analysis.%20output%20files%20for%20ADC-UK-PMS-&protocol.-&eventid..html";output;
RUN;

options emailsys=smtp emailhost=mail.abbott.com emailport=25;

filename test 

email to=("Walter.Amor@abbott.com" "jianghong.wang@abbott.com" "Tim.Barker@abbott.com" "Andrew.Lawrence@abbott.com" "Sarah.Blacow@abbott.com" "april.baxter@abbott.com" 
"mark.lazarus@abbott.com" "anthony.copeman@abbott.com" "joshua.lovegrove@abbott.com" "kimberley.boucher@abbott.com" "james.morris2@abbott.com" "michael.needham@abbott.com")

/*email to=("Walter.Amor@abbott.com")*/

subject="&eventid.: &analysis A2S Data updated for ADC-UK-PMS-&protocol. Study Event &eventid."

Content_Type="text/html";

ODS html body=test style = pearl;

options nocenter;

proc report data=text nofs spanrows style(column)=[just=l vjust=c] style(report)=[font_size=10pt /*outputwidth=28cm */rules=none cellspacing=0] missing split='~'
style(header)=[background=cxffffff];
column text;
define text / display ' ';
run;

%if %sysfunc(exist(pairedpoints)) %then %do;

	/*PAIRED POINTS TABLE*/

	proc contents data=pairedpoints out=pairedorder0 noprint;
	run;

	proc sort data=pairedorder0;
	by varnum;
	run;

	data pairedorder ;
	retain name label;
	length def $ 200;
	set pairedorder0;
	if upcase(name)=:'CAT' or upcase(name)=:'_' or upcase(name) in ('LOT','SENSORLOTID') then delete;
	def=strip(name)||" / display"; 
	ord+1;
	call symput('maxord',ord);
	run;

	/*CREATE MACRO VARIABLES FOR REPORTING*/
	data _null_;
	set pairedorder;
	call symputx("PPVAR"||strip(ord),name);
	call symputx("PPDEF"||strip(ord),def);
	run;

	title;footnote;
	proc report data=pairedpoints split='~' style(report)=[cellpadding =0 cellspacing = 0 font_size=10pt] spanrows missing
		style(header)=[fontsize=10pt] style(column)=[fontsize=10pt vjust=c just=c];
	column (lot sensorlotid  ("Number of Participants with ^{unicode 2265} &ppoints Paired Points" %do i=1 %to &maxord; &&ppvar&i %end;));
	define lot / group;
	define sensorlotid / group;
	%do i=1 %to &maxord; 
	define &&ppdef&i ;
	compute &&ppvar&i;
		if input(scan(&&ppvar&i,1),2.) ge 15 then call define(_col_, "style", "style=[background=cx99ff99]");
	endcomp;
	%end;
	run;
%end;

ods html close;

%mend;
%email;

/* FOOTER */
/* OBTAIN END DATETIME IN DDMMMYYY:HH:MM:SS FORMAT*/
%let enddt=%sysfunc(putn(%sysfunc(datetime()),datetime20.)); 
														

/* CALCULATE TIME DIFFERENCE AND OUTPUT AS HH:MM:SS */
data _null_;
call symput('runtime',trim(left(put("&enddt"dt-"&startdt"dt,time10.))));
output;
run;

%put Time program took to complete = &runtime;

options orientation=portrait;
dm 'log'; *** MAKES LOG WINDOW ACTIVE;
dm log 'file "H:\Data\Study_Data\Apollo\UK_PM\14020\&year.\&eventid.\SAS Code\logs\&eventid A2S &analysis Status log &fdtm..log" replace'; *** SAVES LOG;
