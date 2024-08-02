/*******************************************************************
Program Name:				A2S Status with plots.sas
SAS Version:				9.4 TS Level 1M6
Programmer:					w amor
Purpose:					Summarise data processed with A2S
Procedures used:			ADC-UK-PMS-14020/14021
Program History:
Version Date	Programmer	Type	Change made
_______	__________	_______	____________________________
1		27may22 w amor		new
2		01jun22	w amor		update	add title;footnote; statements before proc report statments
3		13jun22	w amor		update	change plotid to numeric and set axis as 0 to 10000 by 1000
4		16jun22 w amor		new		updated to include PTU data
5		30jun22	w amor		update	add singular text for tooltip
									fix symbol colours in profile plots so that Historic and Real Time colours are then same for each sensor
6		01jul22 w amor		update 	exclude sensors with sensor_start time before FPI date from profile plots
7		03aug22	w amor		update	add message in output file for missing SENSORLOTS dataset
8		09aug22	w amor		update	correction to symbol creation in profile plots
9		12sep22	w amor		update	add switch to allow sensor_start before fpi to be included in profile plots
10		19oct22	w amor		update	enable strip adjustment and add regression line for Mean % Bias vs Sensor Serial Plot, add date and time of analysis
11		29nov22	w amor		update 	highlight phone rows - remove highlight for missing Phone reader_id in SAS CRF, set font size to 10pt in all tables
									readerspedis not calculated for Phone
12		12dec22	w amor		update	adjust height used in profile plot legend statement based on maximum length of plotid value by subject
13		03feb23	w amor		update	add listing of PTU files with life count resets, reduce symbol sizes in profile plots, add reader version to Reader Initialization table
14		05may23	w amor		update	add option to collapse table of contents to 1 level.	
15		13oct23	w amor		update	add bias plots
16		20oct23	w amor		update	move Libre 3 bias data to Libre Real Time plots and drop Classic Historic.
17		30oct23	w amor		update	correct reader check to show most recent log clear event per reader
									add options for use with US Libre and US Libre Pro stacked data
18		17nov23	w amor		update	add sensorlotid to legen of bias plots
19		29nov23	w amor		update	combine links to plots in one table
20		01dec23	w amor		update	use 5 minute window for paring Historic PTU data
									add tables of summary results
21		05dec23	w amor		update	add sensor type to mean % bias table for OUS data
22		16jan24	w amor		update	add year folder for studies from 2024 and later
									change browser title to display eventid - analysis
23		07feb24	w amor		update	modify for use with ADC-UK-PMS-20048
24		22mar24	w amor		update	include subjects with no paired points for paired points denominator 
									update bias plot symbol colours to match profile plots
*******************************************************************/

/*OBTAINS CURRENT DATA AND TIME IN DDMMMYYY:HH:MM:SS FORMAT*/
%let startdt=%sysfunc(putn(%sysfunc(datetime()),datetime20.));

/*REPLACES : WITH _ FOR FILE SUFFIX*/
data _null_;
currentdatetime="&startdt";
suffix=translate(currentdatetime,"_",":");
call symput('fdtm',trim(left(suffix)));
run;

/*CREATES DATE IDENTIFIER FOR OUTPUT FILES*/
data _null_;
      call symput("fdate",lowcase(left(put("&sysdate"d,date9.))));
run;

options nodate nonumber;

ods escapechar='^';

%global yearid;

data _null_;
call symputx('yearid',substr(strip("&eventid"),1,2));
run;


%macro root;

%global root studydata rawdata SENLOC a2sdata ptudata;

%if %eval(&protocol)=20048 %then %do;

	%let studydata=H:\Data\Study_Data\Apollo\ADC-UK-PMS-&protocol.\&eventid.;
	%let rawdata=H:\Data\Study_RawData\Apollo\ADC-UK-PMS-&protocol.\&eventid.;
	/*LOCATION OF SENSOR LIST*/
	%let SENLOC=H:\Data\Study_RawData\Apollo\ADC-UK-PMS-&protocol.\&eventid.\LotReports;
	/*INPUT LOCATION*/
	%let a2sdata=\\oneabbott.com\emea\UK\Witney\ADC\Data\Study_RawData\Apollo\ADC-UK-PMS-&protocol.\&eventid.\AUUdata;
	%let ptudata=\\oneabbott.com\EMEA\UK\Witney\ADC\Data\Study_RawData\Apollo\ADC-UK-PMS-&protocol.\&eventid.\PTUdata;

%end;
%else %do;

	%if %eval(&yearid) ge 24 %then %do;
		%let studydata=H:\data\Study_Data\Apollo\UK_PM\&protocol.\&yearid.\&eventid.;
		%let rawdata=H:\data\Study_RawData\Apollo\UK_PM\&protocol.\&yearid.\&eventid.;
		/*LOCATION OF SENSOR LIST*/
		%let SENLOC=H:\Data\Study_RawData\Apollo\UK_PM\&protocol\&yearid.\&eventid\LotReports;
		/*INPUT LOCATION*/
		%let a2sdata=\\oneabbott.com\emea\UK\Witney\ADC\Data\Study_RawData\Apollo\UK_PM\&protocol.\&yearid.\&eventid.\AUUdata;
		%let ptudata=\\oneabbott.com\EMEA\UK\Witney\ADC\Data\Study_RawData\Apollo\UK_PM\&protocol.\&yearid.\&eventid.\PTUdata;
	%end;
	%else %do;
		%let studydata=H:\data\Study_Data\Apollo\UK_PM\&protocol.\&eventid.;
		%let rawdata=H:\data\Study_RawData\Apollo\UK_PM\&protocol.\&eventid.;
		/*LOCATION OF SENSOR LIST*/
		%let SENLOC=H:\Data\Study_RawData\Apollo\UK_PM\&protocol\&eventid\LotReports;
		/*INPUT LOCATION*/
		%let a2sdata=\\oneabbott.com\emea\UK\Witney\ADC\Data\Study_RawData\Apollo\UK_PM\&protocol.\&eventid.\AUUdata;
		%let ptudata=\\oneabbott.com\EMEA\UK\Witney\ADC\Data\Study_RawData\Apollo\UK_PM\&protocol.\&eventid.\PTUdata;
	%end;
%end;

/*LOCATION OF AUU DATA*/
%if "&analysis"="OUS" %then %do;
%let root=&rawdata\AUUdata;
%end;
%else %do;
%let root=&usroot;
%end;

%mend;
%root;

/*LOCATION FOR AUU OUTPUT LINKS*/
%let outroot2=&rawdata\AUUdata;
/*LOCATION FOR EXTRACTED DATA*/
%let sasdata=&rawdata\OpenClinica_Extracts\Current;
/*LOCATION FOR EXTRACTED METADATA AND FORMAT CATALOG*/
%let sasdata2=&sasdata\metadata;
/*LOCATION FOR LOGS*/
%let log=&studydata\sas code\logs;

libname sasdata "&sasdata"  eoc=no;
libname sasdata2 "&sasdata2" eoc=no;

options dlcreatedir;
libname plots "&outroot2\plots" eoc=no;
options nodlcreatedir;

* FIND EXISTING REPORT DIRECTORIES;
filename _root_ pipe "dir /b/s &root";

* CREATES DATASET WITH FULL FILENAMES ROOT DIRECTORY;
data repdirs;
	infile _root_ truncover;
	input filepath $char200.;
run;

filename _root_;

/*OBTAIN SITE NAMES FROM OPENCLINICA*/
data sitenames(keep=label start fmtname);
	set sasdata2.studydetails;
	Label=strip(scan(studyname,-3,'-'));
	Start=strip(scan(studyname,-2,'-'));
	if start='PMS' then delete;
	fmtname = '$XCLINIC';
run;

/*CREATE FORMAT FOR SITE NAMES*/
proc format cntlin=sitenames;
run;

%global fpi;

/*FPI*/
proc sql noprint;
select min(csdat) into :FPI
from sasdata.ie;
quit;

data sa(drop=__:);
length SubjectID $10 SAappdtm 8 sa1 $10 sa2 sa3 $20 sa4 sa5 $50; 
set sasdata.sa(rename=(__itemgrouprepeatkey=itemgrouprepeatkey));
if "&eventid"="001" then subjectid='00'||strip(subject);
else subjectid=strip(subject);
if saseq ne . then sa1=', Sensor '||strip(saseq);
if saapdat ne . then sa2=', Applied '||strip(put(saapdat,date9.));
if sarmdat ne . then sa3=', Removed '||strip(put(sarmdat,date9.));
if sapryn ne ' ' then sa4=', Prematurely Removed = '||strip(sapryn);
if saprrea ne ' ' then sa5=', Reason Prematurely Removed = '||strip(saprrea);
SAappdtm=dhms(SAAPDAT,0,0,input(saaptim,time.));
format SAappdtm datetime13.;
run;

data pdf0;
	set repdirs;
	length xxxx $10 event $4 subject 8 SubjectID $10 clinic $3 ext $7 Condition $3 filename $50;
	where index(lowcase(filepath), 'audit') = 0 
			and index(lowcase(filepath),'a2s') > 0 
			and index(lowcase(filepath),'pdf')>0
			and index(lowcase(filepath),'pumaout') = 0;
	file2=left(reverse(filepath));
	pos=index(file2,'\'); /* FIND LAST OCCURRENCE OF \ */
	dir=left(reverse(substr(file2,pos))); /* EXTRACTS DIRECTORY PART */
	filename=reverse(substr(file2,1,pos-1)); /* EXTRACTS FULL FILENAME PART */
	posdot=index(filename,'.'); /* FINDS DOT SEPARATOR */
	file=substr(filename,1,posdot-1); /* EXTRACTS FILE NAME */
	ext=substr(filename,posdot+1); /* EXTRACTS EXTENSION */
	if filename=file and filename=ext then delete; /*EXCLUDE FILES WITH NO EXTENSION*/
	event="&eventid.";
	if "&protocol."="20048" then subject=input(substr(filename,index(filename,"&eventid"),10),10.);/*GET SUBJECT NUMBER*/
	else subject=input(substr(filename,index(filename,"&eventid"),9),9.);/*GET SUBJECT NUMBER*/
	if "&eventid"="001" then subjectid='00'||strip(subject);
	else subjectid=strip(subject);
	if "&protocol"="20048" then clinic=substr(left(subjectid),4,3);/* GET SITE ID*/
	else clinic=substr(left(subjectid),5,3);/* GET SITE ID*/
	lenfile=length(file); /*DETERMINE LENGTH OF FILENAME*/
	if lenfile=29 then condition=substr(file,15,3); /*GET CONDITION FROM FILENAME*/
	if lenfile in (23,29);
	dtm=dhms(input(scan(file,-2,'_'),yymmdd6.),0,0,input(scan(file,-1,'_'),B8601TM.)); /*GET DATE AND TIME FROM FILE NAME*/
	format dtm datetime13. clinic $xclinic.;
	varid=compress(condition||ext);
	if index(lowcase(filepath),'scanned') eq 0; /*EXCLUDE FILENAMES CONTAINING THE STRING 'SCANNED'*/
run;

/*GET LIST OF MOST RECENT FILES*/
proc sql;
	create table pdf as
	select *
	from pdf0
	group by subjectid, condition, clinic
	having max(dtm)=dtm;
quit;

proc sort data=pdf;
	by subjectid condition clinic dtm ext filepath;
run;

/* CREATE FORMATS FOR LINKS TO A2S OUTPUT FILES */
data pdflink(rename=(filename=start filepath=label));
	set pdf;
	retain fmtname 'PDFLK' type 'c' ;
	end=filename;
run;

proc format cntlin=pdflink;
run;

proc sort data=pdf;
	by subjectid clinic condition dtm ext filepath pos;
run;

/*TRANSPOSE FILENAMES INTO COLUMNS*/
proc transpose data=pdf out=pdft;
	var filename;
	by subjectid clinic condition dtm;
run;

/*MOVE DATA INTO REPORT FILES INTO SEPARATE DATASET*/
data pdftreprt(rename=(col1=reprt) keep=subjectid col1) pdftcond;
	set pdft;
	if condition='' then output pdftreprt;
	else output pdftcond;
run;

/*GET NUMBER OF SUBJECTS ANALYSED*/
proc sql noprint;
select n(subjectid) into : nsubjects
from pdftreprt;
quit;

/*MERGE REPORT COLUMN WITH PLOT AND EXCEL FILES*/
data pdft;
	merge pdftreprt pdftcond;
	length date 8;
	date=datepart(dtm);
	format date worddatx18.;
	by subjectid;
run;

data pdft3;
set pdft;
length worddtm $22;
worddtm=put(dtm,datetime22.);
run;

/*SORT AND CREATE WEB PAGE WITH LINKS TO A2S OUTPUT FILES*/
proc sort data=pdft;
by clinic subjectid dtm reprt;
run;

proc sql noprint;
select max(date) into :maxdate
from pdft;
select worddtm into :maxdtm
	from (select distinct worddtm 
	from pdft3
	having max(dtm)=dtm);
quit;

data title;
length title $250;
	title="ADC-UK-PMS-&protocol.-&eventid. - &analysis";	output;
	title="";output;
	title=strip("&nsubjects Subjects");output;
	title="";output;
	title=compbl("Updated on &startdt - Last file analysed on &maxdtm");output;
run;

proc format;
value bg &maxdate ='cx99ff99'
		other='cxffffff';
run;

/*LIBNAME FOR SENSOR LIST*/
libname senloc "&SENLOC" eoc=no access=readonly;

%macro pairedpoints;

%global WORKDIR PUMASM SMdate cbgm;

%if %sysfunc(exist(senloc.sensorlots)) %then %do;

	%let workdir = %sysfunc(getoption(work));
	%put &workdir;

	options nomlogic nomprint nosymbolgen;
	/*RUN A2S STACKING MACRO*/
	options nosource2;
	%Include "F:\Custom\SASPROGS\DEV\PUMA\PUMA_A2SDataStacking\PUMA_A2SDataStacking.SAS";
	options source2;
	%PUMA_A2SDataStacking(&a2sdata,&workdir);

	/*GET AUU DATA*/
	%if "&analysis"="OUS" %then %do;
	libname auu "&workdir\PUMAout"; 
	%end;
	%else %if "&analysis"="US Libre" %then %do;
	libname auu "&usroot\PUMAout\ReaderIDReplaced"; 
	%end;
	%else %if "&analysis"="US Libre Pro" %then %do;
	libname auu "&usroot\PUMAout\USLibrePro"; 
	%end;

	proc contents data=auu._all_ out=auu;
	run;

	%global auuglucdata;

	proc sql noprint;
	/*GET NAME OF MOST RECENT STACKED GLUCOSE DATASET*/
	select distinct upcase(memname) into :auuglucdata 
	from auu
	where substr(upcase(memname),1,7)="GLUCOSE" 
	having max(crdate)=crdate;
	quit;

	%put &auuglucdata;

	%if "&analysis"="US Libre" %then %do;
	libname pout "&workdir\PUMAout"; 
	data pout.&auuglucdata;
	set auu.&auuglucdata;
	run;
	%end;
	%else %if "&analysis"="US Libre Pro" %then %do;
	libname pout "&workdir\PUMAout"; 
	data pout.&auuglucdata;
	set auu.&auuglucdata;
	run;
	%end;

	%if %upcase(&ptu)=YES %then %do;

		options nosource2;
		%include "H:\Data\Study_Data\Apollo\UK_PM\SAS Code\A2S_Status\PTU_Stacker.sas";
		options source2;
		%ptu_stacker(&ptudata,&workdir);

		/*GET PTU DATA*/
		libname ptu "&workdir.\PTUout"; 

		proc contents data=ptu._all_ out=ptu;
		run;

		proc sql noprint;
		/*GET NAME OF MOST RECENT STACKED GLUCOSE DATASET*/
		select distinct upcase(memname) into :ptuglucdata 
		from ptu
		where substr(upcase(memname),1,7)="GLUCOSE" 
		having max(crdate)=crdate;
		quit;

		%put &ptuglucdata.;

	%end;

	/*LOCATION OF STACKED BG DATA*/
	%let PUMASM=&workdir\PUMAout;

	libname PUMASM "&PUMASM" eoc=no;

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

	options nosource2;
	%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_CBGM.sas";
	options source2;

	%PUMA_CBGM(P4in=&PUMASM,
	ds=&SMdate,
	bg_dup = 1,
	strip_adj=&stripadj);

	/*GET LIST OF CBGM DATASETS*/
	proc contents data=PUMASM._all_ out=CBGM noprint;
	run;

	proc sql noprint;
	/*GET MOST RECENT CLEANED DATASET AND BG EXCLUSION DATASET*/
	select distinct memname into :CBGM 
	from CBGM 
	where substr(upcase(memname),1,12)="OUT_CBGM_DAT" 
	having max(crdate)=crdate;
	select distinct memname into :CBGMDEL 
	from CBGM 
	where substr(upcase(memname),1,12)="OUT_CBGM_DEL" 
	having max(crdate)=crdate;
	quit;

	%put &cbgm;
	%put &cbgmdel;

	%global BGADJ;

	data _null_;
	set PUMASM.&cbgm;
	if BG_ADJUSTMENT ne . then xxx="Strip Adjustment Value = "||strip(put(BG_ADJUSTMENT,6.2));
	else xxx='No Strip Adustment Applied';
	call symputx('BGADJ',xxx);
	run;

	/*RUN THE PAIRING MACRO FOR ADJUSTED GL AND ADJUSTED REF DATA*/
	options nosource2;
	%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_Pairing.sas";
	options source2;
	data P2PARAMS;
	P2GLIN="&workdir.\PUMAout";
	P2GL="&auuglucdata";
	P2REFIN="&PUMASM";
	P2REF="&cbgm";
	P2OUT="&PUMASM";
	P2RTWIN=5;
	P2HWIN=15;
	P2MAXDIF=30.5;
	output;
	run;
	%PUMA_pairing;

	data pairedAUU;
	set P2GLREF_5;
	run;

	%if %upcase(&ptu)=YES %then %do;
	data P2PARAMS;
	P2GLIN="&workdir.\PTUout";
	P2GL="&ptuglucdata.";
	P2REFIN="&PUMASM";
	P2REF="&cbgm";
	P2OUT="&PUMASM";
	P2RTWIN=5;
	P2HWIN=5;
	P2MAXDIF=30.5;
	output;
	run;
	%PUMA_pairing;

	data pairedPTU;
	set P2GLREF_5;
	run;

	%end;

	/*COMBINE AUU AND PTU DATA*/
	options papersize=a4 orientation=portrait pagesize=max linesize=max nocenter dlcreatedir;
	/*LOCATION FOR COMBINED AUU AND PTU STACKED GLUCOSE DATA*/
	libname ap "&workdir.\AUUPTUout" eoc=no;

	%if %upcase(&ptu)=YES %then %do;
		data ap.&auuglucdata.;
		set auu.&auuglucdata. ptu.&ptuglucdata.;
		run;
	%end;
	%else %do;
		data ap.&auuglucdata.;
		set auu.&auuglucdata.;
		run;
	%end;

	/*SAVE PAIRED DATASET AND ASSIGN HIGH AND LOW READINGS AND ADD PRODUCT NAMES, STRIP_BATCH AND BG_ADJUSTMENT*/
	data PUMASM.adjpaired;
	%if %upcase(&ptu)=YES %then %do;
	set pairedAUU pairedPTU;
	%end;
	%else %do;
	set pairedAUU;
	%end;
	if reftype="BG" then do;
		if 0 le REFALL lt 20 then do;
			REF_HILO = 'LO';
			REF = .;
		end;
		else if REFALL gt 500 then do;
			REF_HILO = 'HI';
			REF = .;
		end;
	end;
	run;

	/*RUN ANALYSIS MACRO FOR ADJUSTED REF PAIRED DATA*/
	options nosource2;
	%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_AM.sas";
	options source2;
	data P3PARAMS;
	P3IN="&PUMASM";
	P3GLREF="adjpaired";
	P3OUT="&PUMASM";
	P3CREF_FACTOR="1";
	P3CONSENSUS="CONSENSUS";
	P3CLARKE="CLARKE";
	P3WITEXC_LUT="am_witexc_lpm";
	P3CONCRATE_LUT="am_concrate_std";
	output;
	run;
	%puma_am(p3output=0);

	proc sort data=p3glref out=amdata;
	by sensor_sn;
	run;

	/*MERGE IN SENSOR LOT NUMBER FROM THE LOT REPORT DATASET*/
	proc sort data=senloc.sensorlots out=sndata;
	by sensor_sn;
	run;

	/*USE STACKED DATA FOR MERGING IN ALL LOT NUMBERS FOR PAIRED POINTS AND DEMOGRAPHICS CALCULATIONS*/
	proc sort data=ap.&auuglucdata. out=stacked;
	by sensor_sn;
	run;

	data stacked2 pumasm.notlisted;
	merge stacked(in=kp1) sndata(in=kp2 keep=LOT SENSOR_SN SENSOR_DMX EXPIRY_DATE SENSORLOTID);
	by sensor_sn;
	if kp1 and kp2 then output stacked2;
	else if kp1 and not kp2 then output pumasm.notlisted;
	run;

	/*UNIQUE SUBJECT PRODUCT / EVENTS AND LOT NUMBERS*/
	proc sort data=stacked2 out=SUBEVENTLOTS nodupkey;
	by subjectid event lot;
	run;

	data SUBEVENTLOTS;
	set SUBEVENTLOTS;
	event=propcase(event);
	label event ='Event';
	run;

	proc sort data=sasdata.ie out=ie(keep=subject);
	by subject;
	run;

	data ie;
	length SubjectID $10;
	set ie;
	subjectid=strip(subject);
	run;

	/*MERGE LOTS WITH DEMOGRAPHIC DATA*/
	data demoglots;
	merge SUBEVENTLOTS(keep=event subjectid lot sensorlotid) ie(keep=subject subjectid);
	by subjectid;
	run;

	/*MERGE LOT NUMBERS INTO ADJUSTED DATA*/
	data amdata2 pumasm.amnotlisted;
	merge amdata(in=kp1) sndata(in=kp2);
	by sensor_sn;
	length Subject 8;
	Subject=input(SubjectID,9.);
	event=propcase(event);
	label event ='Event' Subject="Subject";
	label Subject="Subject";
	if kp1 and kp2 then output amdata2;
	else if kp1 and not kp2 then output pumasm.amnotlisted;
	run;

	data pumasm.amdata;
	set amdata2;
	run;

	data P5IN(keep=event lot sensorlotid sensor_sn subjectid pdif_gl_cref sensor_dmx);
	set amdata2;
	run;

	/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
	data P5BYVARS;
	length BYGROUP $100;
	bygroup="event lot sensorlotid sensor_sn subjectid sensor_dmx";output;
	run;

	options nosource2;
	%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
	options source2;
	%puma_sum(P5PREFIX=SENSOR);

	data mpbbysensor;
	set sensor_stat3;
	length plotid 8;
	plotid=input(substr(sensor_dmx,12),5.);
	label plotid='Sensor Serial';
	run;

	/*PREPARE DATA FOR PAIRED POINTS CALCULATION*/
	proc sql;
	create table xpaired as
	select *, n(dif_gl_cref) as npaired
	from pumasm.amdata
	group by subjectid, event, lot;
	create table subpaired as
	select distinct subjectid, event, lot, npaired
	from xpaired;
	quit;

	data P5IN(keep=subject subjectid aaa_: event sensorlotid lot);
	set xpaired;
	if npaired ge &ppoints then AAA_01_PAIRED="Number of Participants with ^{unicode 2265} &ppoints Paired Points";
	else AAA_01_PAIRED="Number of Participants with < &ppoints Paired Points";
	label AAA_01_PAIRED="Number of Paired Points";
	run;

	proc sort data=demoglots;
	by subject subjectid event lot;
	run;

	proc sort data=P5IN;
	by subject subjectid event lot;
	run;

	data P5IN;
	merge P5IN demoglots;
	by subject subjectid event lot;
	if AAA_01_PAIRED='' then AAA_01_PAIRED="Number of Participants with < &ppoints. Paired Points";
	run;

	proc sort data=P5IN nodupkey;
	by subject subjectid event lot;
	run;

	/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
	data P5BYVARS;
	length BYGROUP $50;
	bygroup="event lot sensorlotid";output;
	run;
	
	options nosource2;
	%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
	options source2;
	%puma_sum(P5PREFIX=POINTS);

	proc sort data=points_freq1 out=pairedpoints0;
	by sensorlotid lot catvar category catval;
	where index(catval,'<') =0;
	run;

	proc transpose data=pairedpoints0(where=(lot ne '')) out=PAIREDPOINTS;
	by sensorlotid lot catvar category catval;
	var ResultCP;
	id event;
	idlabel event;
	run;

/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN;
set amdata2;
if length(sensor_sn)=9 then prodtype='Libre 3';
else prodtype='Classic';
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="prodtype reftype cref_factor EVENT lot";output;
run;

%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
%puma_sum(P5PREFIX=TEST);

/*ADDITIONAL CALCULATIONS FOR US FREESTYLE LIBRE*/

data P5IN(keep=reftype cref_factor EVENT lot sensor_sn cref gl rwithin:);
set amdata2;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor EVENT lot sensor_sn";output;
run;

%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
%puma_sum(P5PREFIX=XXSENSOR);

/*CALCULATE SD OF PERCENTS WITHIN BY LOT*/
data xsensor_accr;
set xxsensor_accr;
where first(acclevel)='C' and break=80 and high in (20) and total ge 28;
run;

data P5IN(keep=reftype cref_factor EVENT lot AAA_PERCENT);
set xsensor_accr(rename=percent=AAA_PERCENT);
run;

data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor EVENT lot";output;
run;

%puma_sum(P5PREFIX=PW2020SDR);


******************************************************************************************;
/*TABLE A: OUS CONCLUSION GRID ZONE A TABLE BY PRODUCT AND SENSOR LOT*/
******************************************************************************************;
/*EXTRACT BY PRODUCT AND SENSOR LOT ZONE A RESULTS*/
data AC1;
set test_grids;
where bygrouporder=' 1' and zone='A';
result=strip(round(consensus_percent)||'% '||scan(consensus_resultpc,2,' '));
label result='% Within Consensus Error Grid Zone A';
run;

proc sort data=AC1;
by event lot;
run;

/*ADD ACCEPTANCE CRITERIA COLUMN*/
data AC_TABLE;
set AC1;
by reftype event lot;
length ac $40;
/*if first.reftype then ac="^{unicode 2265} &ac.%";*/
if round(consensus_percent) ge &ac then ac="Meets ^{unicode 2265} &ac.%";
else ac="Does not meet ^{unicode 2265} &ac.%";
label ac='Acceptance Criteria';
run;

/******************************************************************************************/
/*TABLES A : US SYSTEM ACCURACY OF GM VS. BG REFERENCE (ROUNDED METHOD)*/
/******************************************************************************************/

data AC_TABLE_US1;
set test_accr;
length ac1 $40;
where break=80 and bygrouporder=' 1' and first(acclevel)='C'  and first(acclabel)='W' and high in (20);
if round(percent) ge &acus1 then ac1="Meets ^{unicode 2265} &acus1.%";
else ac1="Does not meet ^{unicode 2265} &acus1.%";
label ac1='Acceptance Criteria' percent="% sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result";
run;

/******************************************************************************************/
/*TABLES A : US SYSTEM ACCURACY OF GM VS. BG REFERENCE (ROUNDED METHOD)*/
/******************************************************************************************/

data AC_TABLE_US2;
set PW2020SDR_stat3;
length ac2 $40;
if round(SD,0.1) le &acus2 then ac2="Meets ^{unicode 2264} &acus2.%";
else ac2="Does not meet ^{unicode 2264} &acus2.%";
label ac2='Acceptance Criteria' SD="Between sensor (within lot) SD of sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result";
run;

proc sort data=AC_TABLE_US1;
by event lot;
run;

proc sort data=AC_TABLE_US2;
by event lot;
run;

data AC_TABLE_US(keep=event lot percent ac1 sd ac2);
merge AC_TABLE_US1 AC_TABLE_US2;
by event lot;
run;

******************************************************************************************;
/*TABLE B: CONCLUSION MEAN % BIAS AND MEAN ABSOLUTE % BIAS TABLE BY PRODUCT AND SENSOR LOT*/
******************************************************************************************;

data SUM_TABLE;
set test_stat1;
where bygrouporder=' 1';
run;

proc sort data=SUM_TABLE;
by event lot;
run;

/******************************************************************************************/
/******************************************************************************************/
/******************************************************************************************/

	%if "&analysis"="OUS" %then %do;

	/*READER INTILIALIZATION CHECKS*/

	/*IMPORT LOG CLEAR AND SENSOR START TIMES*/
	data log_clear0(keep=subjectid reader_id dtm rename = (dtm = log_clear_time)) 
		 sens_start(keep=subjectid reader_id dtm col9 condition_id sensor_num rename=(dtm=sensor_start_time col9=sensor_serial));
	set PUMASM.all_&SMdate.;
	if type='13' then output log_clear0;
	else if type='58' then output sens_start;
	run;

	proc sort data = log_clear0;
	by subjectid reader_id log_clear_time;
	run;

	data log_clear;
	set log_clear0;
	by subjectid reader_id log_clear_time;
	if last.reader_id;
	run;

	/* VISIT 1 SENSOR START TIME */
	proc sort data = sens_start;
		by subjectID reader_id sensor_start_time;
	run;

	data day1_sens_start(rename = (sensor_start_time = day1_start_time));
		set sens_start(drop=sensor_serial condition_id sensor_num);
		by subjectID reader_id sensor_start_time;
		if first.reader_id and first.sensor_start_time;
	run;

	proc sort data = log_clear nodupkey;
		by subjectid reader_id log_clear_time;
	run;

	/* COMBINE LOG CLEAR TIME AND SENSOR START TIME */
	/* TIME DIFFERENCE IN DAYS BETWEEN LOG CLEAR TIME AND SENSOR START TIME ON DAY 1 */
	data richeck0;
		merge day1_sens_start log_clear;
		by subjectid reader_id; 
		time_diff = (day1_start_time - log_clear_time)/(60*60*24);
	run;

/*	ADD READER REV*/
	proc sort data = uploads;
		by subjectid reader_id;
	run;

	data richeck00;
	merge richeck0 uploads(keep=subjectid reader_id reader_rev);
	by subjectid reader_id;
	run;

	proc sort data = richeck00;
		by descending time_diff subjectid reader_id;
	run;

	data richeck(keep=observation subjectID reader_id reader_rev day1_start_time log_clear_time time_diff);
		length observation 8;
		retain subjectID reader_id reader_rev day1_start_time log_clear_time time_diff;
		set richeck00;
		observation = _n_;
		format observation 8. time_diff 4.1;
		label SubjectID='Subject' reader_id='Reader ID' reader_rev='Reader Version' day1_start_time='Sensor Start Time On Day 1' log_clear_time='Log Clear Time'
		time_diff='Time Difference (in Days)';
	run;

	/******************************************************************************************/
	/******************************************************************************************/

	/*REMOVE DUPLICATES - SAME SENSOR COULD BE STARTED MULTIPLE TIMES */
	proc sort data = sens_start nodupkey out = a2s_sensor_serials;
		by subjectid condition_id reader_id sensor_serial;
	run;

	/* SENSOR DATA: EVERY ROW OF SENSOR DATA HAS CORRESPONDING SENSOR SERIAL NUMBER */
	proc sort data=PUMASM.all_&SMdate. out=alldata;
		by subjectid condition_id reader_id sensor_num;
	run;

	proc sort data=a2s_sensor_serials;
		by subjectid condition_id reader_id sensor_num;
	run;

	data sensor_serials;
		merge a2s_sensor_serials alldata;
		by subjectid condition_id reader_id sensor_num;
	run;

	/* EACH READER'S LOG CLEAR EVENTS WITH THE DTM */
	/* WHEN READER IS INITIALIZED */

	data sensor_serials2(keep=subjectid reader_id log_clear_dtm);
	set sensor_serials;
	where event='LOG_CLEAR';
	log_clear_dtm = dhms(datepart(dtm), hour(dtm), minute(dtm),0);
	format log_clear_dtm datetime16.;
	run;

	proc sort data=sensor_serials2; 
		by subjectid reader_id Log_clear_dtm;
	run;

	%end;

%end;
%mend;
%pairedpoints;

%macro cegplot(P6BYVAR=SUBJECT EVENT,P6GROUP=SENSOR_SN);

/*CREATE 500 X 500 CONSENSUS ERROR GRID ANNOTATE DATA*/
data sg_consensus_mg500;
length drawspace $9 function $4 x1 y1 x2 y2 8 linecolor $9 linethickness 8 label $1 textfont $10 textcolor $8 textweight $6 textsize 8;
retain drawspace 'datavalue';
function='line';	x1=0;			y1=0;	x2=500;			y2=500;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=0;			y1=50;	x2=30;			y2=50;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=30;			y1=50;	x2=140;			y2=170;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=140;			y1=170;	x2=280;			y2=380;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=280;			y1=380;	x2=(280-(380*(15/17)))+(500*(15/17));		y2=500;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=0;			y1=60;	x2=30;			y2=60;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=30;			y1=60;	x2=50;			y2=80;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=50;			y1=80;	x2=70;			y2=110;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=70;			y1=110;	x2=(70-(110*(19/44)))+(500*(19/44));		y2=500;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=0;			y1=100;	x2=25;			y2=100;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=25;			y1=100;	x2=50;			y2=125;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=50;			y1=125;	x2=80;	y2=215;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=80;			y1=215;	x2=(80-(215*(9/67)))+(500*(9/67));	y2=500;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=0;	y1=150;	x2=35;	y2=155;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=35;	y1=155;	x2=(30-(155*(4/79)))+(500*(4/79));	y2=500;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=50;	y1=0;	x2=50;	y2=30;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=50;	y1=30;	x2=170;	y2=145;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=170;	y1=145;	x2=385;	y2=300;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=385;	y1=300;	x2=500;	y2=(300-(385*(30/33)))+(500*(30/33));	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=120;	y1=0;	x2=120;	y2=30;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=120;	y1=30;	x2=260;	y2=130;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=260;	y1=130;	x2=500;	y2=(130-(260*(12/29)))+(500*(12/29));	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=250;	y1=0;	x2=250;	y2=40;	linecolor='cx000000';	linethickness=1;output;
function='line';	x1=250;	y1=40;	x2=500;	y2=(40-(250*(11/30)))+(500*(11/30));	linecolor='cx000000';	linethickness=1;output;
function='text';	x1=30;			y1=10;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='A';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=10;			y1=30; x2=.;			y2=.;	linecolor='';			linethickness=.;	label='A';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=450;			y1=410;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='A';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=370;			y1=450;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='A';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=450;			y1=270;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='B';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=250;			y1=450;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='B';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=450;			y1=150;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='C';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=150;			y1=450;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='C';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=450;			y1=40;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='D';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=75;			y1=450;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='D';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
function='text';	x1=25;			y1=450;	x2=.;			y2=.;	linecolor='';			linethickness=.;	label='E';	textfont='Arial'; textcolor='cx000000';	textweight='normal';	textsize=10;output;
run;

data P6IN;
set pumasm.amdata;
P6DEFAULTGROUP='1';
run;

/*	%let P6BYVAR=SUBJECT EVENT;*/
/*	%let P6GROUP=SENSOR_SN;*/
%let P6ATTRPRIORITY=COLOR;
%let P6XVAR=CREF;
%let P6YVAR=GL;
%let P6XVARMM=CREFMM;
%let P6YVARMM=GLMM;

ods graphics / antialias=on antialiasmax=100000;

/*SET DEFAULT SYMBOLS*/
%let P6SYMBOLS=circlefilled TriangleFilled StarFilled DiamondFilled SquareFilled TriangleDownFilled TriangleLeftFilled TriangleRightFilled HomeDownFilled; 

/*SET DEFAULT COLORS*/
%let P6COLORS=CX009CDE CXE4002B CX00B140 CXEEB33B CX64CCC9 CXAA0061 CX888B8D CX004F71 CX470A68 CX9900FF; 

data _null_;
	call symputx('P6XMAX',500);
	call symputx('P6YMAX',500);
	call symputx('P6INCR',100);
    call symputx('P6XMAXMM',25);
	call symputx('P6YMAXMM',25);
    call symputx('P6INCRMM',5);
	call symput("P6SQLBYVAR",translate(compbl("&P6BYVAR"),',',' '));
	call symput('P6NUMBYVARS',countw("&P6BYVAR"));
	call symputx('P6BYVALS',"#byval("||strip(tranwrd("&P6BYVAR"," ",") #byval("))||")");
run;

/*options nomprint nomlogic nosymbolgen;*/

/*CREATE TITLES FOR BY GROUPS*/
%if %eval(&P6NUMBYVARS.) gt 0 %then %do;
	%do i=1 %to &P6NUMBYVARS.;
		%if %eval(&i)=1 %then %do;
			data _null_;
			call symputx('P6BYVALS1','_BYVAL1_');
			run;
		%end;
		%else %if %eval(&i) gt 1 %then %do;
			data _null_;
			call symputx('P6BYVALS1',"&P6BYVALS1."||" _BYVAL&i._");
			run;
		%end;
	%end;
	data _null_;
	call symputx('P6BYVALS2', tranwrd("&P6BYVALS1.", ' ',' " " '));
	run;
%end;

%put &P6BYVALS1;

%put &P6BYVALS2;

proc sort data=P6IN out=_P6CKC1(keep=&P6BYVAR. &P6GROUP.) nodupkey;
by &P6BYVAR. &P6GROUP.;
run;

proc sql noprint;
create table _P6CKC2 as 
select distinct &P6SQLBYVAR., n(&P6GROUP.) as xxxcount
from _P6CKC1
group by &P6SQLBYVAR.;
quit;

/*GET THE BY VARIABLES AND TYPE VALUES*/
proc contents data=_P6CKC2 out=_P6CKCONTC2(keep=name type varnum where=(upcase(name) ne 'XXXCOUNT')) noprint;
run;

proc sort data=_P6CKCONTC2;
by varnum;
run;

/*CREATE THE MACRO VARIABLES CONTAINING THE BY VARIABLE NAMES*/
data _null_;
set _P6CKCONTC2;
call symputx("BYVAR"||strip(varnum),name);
run;

/*TRANSPOSE THE BY VARIABLE NAMES*/
proc transpose data=_P6CKCONTC2 out=_P6CKBYVARC2(drop=_name_ _label_) prefix=BYVAR;
var name;
id varnum;
run;

/*TRANSPOSE THE BY VARIABLE TYPES*/
proc transpose data=_P6CKCONTC2 out=_P6CKBYTYPEC2(drop=_name_ _label_) prefix=BYTYPE;
var type;
id varnum;
run;

/*MERGE BY VARIABLES AND TYPES WITH UNIQUE VALUES*/
proc sql;
create table _P6CKC3 as
select a.*, b.*, c.*
from _P6CKC2 as a, _P6CKBYVARC2 as b, _P6CKBYTYPEC2 as c;
quit;

/*CREATE WHERE STATEMENTS FOR EACH BY VARIABLE*/
%macro doloop;
	data _P6CKC4;
	set _P6CKC3;
	%do i = 1 %to &P6NUMBYVARS.;
		if BYTYPE&i=2 then WHERE&i=strip(BYVAR&i)||'="'||strip(&&BYVAR&i)||'"';
		else WHERE&i=strip(BYVAR&i)||'='||strip(&&BYVAR&i);
	%end;
	run;
%mend;
%doloop;

/*CREATE THE WHERE STATEMENT FOR EACH UNIQUE BY VALUES*/
data _P6CKC5(drop=WHERE: BYTYPE: BYVAR:);
set _P6CKC4;
XWHERE="where "||catx(' and ',of WHERE:);
run;

proc sort data=_P6CKC5;
by &P6BYVAR.;
run;

/*CREATE COUNTER AND GET NUMBER OF UNIQUE VALUES*/
data _P6CKC6;
zz+1;
set _P6CKC5;
call symput('ZZLAST',zz);
run;
%put &zzlast.;

proc sort data=P6IN;
by  &P6BYVAR.;
run;

/* LOOP THE LEGEND VALUE TO NUMBER OF LEGENDS*/

%do i=1 %to &ZZLAST.;

data _null_;
set _P6CKC6;
where zz=&i;
call symput("P6LEGENDCOUNT",xxxcount);
call symputx("P6WHERE",xwhere);
run;

data _null_;
call symput("P6HEIGHT",15 + (0.38*(ceil(&P6LEGENDCOUNT./2))));
run;

%put &P6LEGENDCOUNT.;
%put &P6WHERE;
%put &P6HEIGHT;
%put &P6XVAR. &P6YVAR.  &P6XVARMM. &P6YVARMM. &P6BYVALS1.;

ods path(prepend) work.templat(update);

	ods graphics on / attrpriority=&P6ATTRPRIORITY. noborder;
	proc template;
		define statgraph sgdesign;
		dynamic &P6XVAR. &P6YVAR.  &P6XVARMM. &P6YVARMM. &P6BYVALS1.;
			begingraph / border=false
				designheight=&P6HEIGHT.cm designwidth=15cm datacontrastcolors=(&P6COLORS.) datasymbols=(&P6SYMBOLS.);
				entrytitle halign=center "&analysis " &P6BYVALS2.;
				layout lattice / rowdatarange=data columndatarange=data rowgutter=10 columngutter=10;
					layout overlay /
						xaxisopts=( 
							griddisplay=off 
							labelattrs=(family="Arial" size=11pt weight=normal) 
							linearopts=(viewmin=0.0 viewmax=&P6XMAX. minorticks=ON minortickcount=9
							tickvaluesequence=( start=0.0 end=&P6XMAX. increment=&P6INCR.))) 
						yaxisopts=( 
							griddisplay=off 
							labelattrs=(family="Arial" size=11pt weight=normal)
							linearopts=(viewmin=0.0 viewmax=&P6YMAX. minorticks=ON minortickcount=9 
							tickvaluesequence=( start=0.0 end=&P6YMAX. increment=&P6INCR.)))
						x2axisopts=(
							griddisplay=off
							labelattrs=(family="Arial" size=11pt weight=normal)
							linearopts=(viewmin=0.0 viewmax=%sysevalf(&P6XMAX. / 18.016) minorticks=ON  minortickcount=4
							tickvaluesequence=( start=0.0 end=&P6XMAXMM. increment=&P6INCRMM.))) 
						y2axisopts=( 
							griddisplay=off
							labelattrs=(family="Arial" size=11pt weight=normal)
							linearopts=(viewmin=0.0 viewmax=%sysevalf(&P6YMAX. / 18.016) minorticks=ON  minortickcount=4
							tickvaluesequence=( start=0.0 end=&P6YMAXMM. increment=&P6INCRMM.)))
						;
						scatterplot x= &P6XVAR. y= &P6YVAR.    / group=&P6GROUP. name='scatter' markerattrs=(size=5pt);
						scatterplot x= &P6XVAR. y= &P6YVARMM.    / name='scatter2' yaxis=y2 datatransparency=1;
						scatterplot x= &P6XVARMM. y= &P6YVAR.    / name='scatter3' xaxis=x2 datatransparency=1;
						annotate;
					endlayout;
					sidebar / align=bottom spacefill=false;
						/*LEGEND OPTIONS IF REQUIRED*/
						discretelegend 'scatter' / across=2 autoitemsize=true border=false displayclipped=true opaque=true order=rowmajor
						halign=center valign=center  
						title='' titleattrs=(family="Arial" size=10pt weight=bold);
					endsidebar;
				endlayout;
			endgraph;
		end;
	run;
	quit;

proc sort data=P6IN;
by &P6BYVAR. &P6GROUP.;
run;

ods graphics on / height=&P6HEIGHT. cm ;
options nobyline;

ods proclabel ="#byval1 #byval2";
proc sgrender data=P6IN template=sgdesign
sganno=sg_consensus_mg500
;
by &P6BYVAR.;
&P6WHERE.;
dynamic &P6XVAR.="'&P6XVAR.'n" &P6YVAR.="'&P6YVAR.'n" 
&P6XVARMM.="'&P6XVARMM.'n" &P6YVARMM.="'&P6YVARMM.'n"
;
run;
quit;

%end; /* P6GRAPH=2*/

%mend;

%macro profplot;

/*CREATE FORMAT TO INCLUDE MMOL/L VALUES XAXIS TICK MARK VALUES*/
data xaxis;
do start=50 to 550 by 50;
end=start;
label=strip(start)||' ('||strip(put((start/18.016),4.1))||')';
fmtname='xaxis';
type='n';
output;
end;
run;

proc format cntlin=xaxis;
run;

/*IMPORT PLOT DATA*/
proc sort data=ap.&auuglucdata. out=glucose_data0;
by sensor_sn;
run;

proc sort data=senloc.sensorlots out=sensorlots_data(keep=lot sensor_sn sensor_dmx expiry_date sensorlotid);
by sensor_sn;
run;

data glucose_data;
retain plotid;
merge glucose_data0(in=kp) sensorlots_data;
by sensor_sn;
if kp;
condition=compress(condition_id,'_');
pl1=propcase(strip(tranwrd(event,'GLUCOSE','')))||': Sensor '||strip(sensor_sn)||', Reader '||strip(reader_id)||', Condition '||strip(Condition);
if lot ne '' then pl2=', Lot '||strip(lot)||' ('||strip(sensorlotid)||')';
plotid=cats(of PL1-PL2);
run;

/*ADD BG DATA*/
data plotdata0(keep=subjectid reader_id gl dtm plotid lot condition condition_id sensor_sn sensorlotid sensor_start);
retain plotid;
set glucose_data(in=a) PUMASM.&cbgm(in=b rename=(refdtm=dtm ref=gl));
if b then plotid='BG Reading';
format gl xaxis.;
run;

/*GET UNIQUE SUBJECTID, READER_ID AND SENSOR_SN FROM AUU DATA*/
proc sql;
create table uplotdata as
select distinct SubjectID, READER_ID, SENSOR_SN, sensorlotid, SENSOR_START
from plotdata0
where SENSOR_SN ne '';
quit;

/*COMBINE AUU DATA WITH SA DATA*/
proc sql;
create table uplotdata2 as
select a.*, b.reader_id, b.sensor_sn, b.sensorlotid
from sa as a, uplotdata as b
where a.subjectid=b.subjectid;
quit;

data uplotdata3;
retain SubjectID Sensor_SN SASENSN;
length x1 8;
retain Reader_ID SAREDSN SENSORLOTID SALOT;
set uplotdata2;
/*COMPARE SENSOR_SN IN AUU AND SA DATA*/
x1=spedis(sensor_sn, sasensn);
run;

/*KEEP SMALLEST SPELLING DISTANCE FOR EACH SUBJECT AND SENSOR*/
proc sql;
create table uplotdata4 as 
select *, min(x1) as minx1
from uplotdata3
group by subjectid, sensor_sn
having x1=calculated minx1;
quit;

data uplotdata5;
length sadetails $235 sa6 sa7 $30 sa8 $15;
set uplotdata4;
if sensor_sn ne SASENSN then sa6=', SA Sensor '||strip(SASENSN );
if reader_id ne SAREDSN then sa7=', SA Reader '||strip(SAREDSN);
if sensorlotid ne SALOT then sa8=', SA Lot '||strip(salot);
sadetails=cats(of SA1-SA8);
run;

proc sql;
create table uplotdata6
as select min(x1) as minx21, *
from uplotdata5
group by subjectid, SASENSN
having x1=calculated minx21
order by subjectid, Sensor_sn;
quit;

proc sort data=plotdata0;
by subjectid sensor_sn;
run;

data plotdata1(drop=plotid0);
length lenplotid 8 plotid $500;
merge plotdata0(in=kp rename=plotid=plotid0) uplotdata6;
by subjectid sensor_sn;
if kp;
if sadetails='' and plotid0 ne 'BG Reading' then sadetails=' - No closely matched Sensor SN in SA CRF data';
if plotid0 ne 'BG Reading' then plotid=catt(plotid0,sadetails);
else plotid=plotid0;
lenplotid=length(plotid);
run;

proc sql;
create table plotdata as
select max(lenplotid) as maxplotid, *
from plotdata1
group by subjectid;
quit;

/*EXCLUDED DATA BEFORE FPI*/
data plotdataxx;
set plotdata;
%if %upcase(&exc_pre_fpi)=YES %then %do;
where (datepart(sensor_start) ge &fpi) or (first(plotid)='B' and dtm ge &fpi);
%end;
run;

/*GET UNIQUE LIST OF PLOT IDS*/
proc sql;
create table symb1 as 
select distinct subjectid, sensor_sn, first(plotid) as cat, plotid
from plotdataxx
order by subjectid, sensor_sn, cat, plotid;
quit;

/*ASSIGN COLOR ID NUMBERS*/
data symb1a;
retain colorid 0;
set symb1;
by subjectid sensor_sn cat;
/*ASSIGN UNIQUE COLORID FOR EACH SENSOR*/
if sensor_sn ne '' and sensor_sn ne lag(sensor_sn) then colorid+1;
if first.subjectid and sensor_sn='' then colorid=0;
else if first.subjectid and sensor_sn ne '' then colorid=1;
run;

proc sort data=symb1a;
by subjectid plotid;
run;

/*ASSIGN SYMBOL ID NUMBERS*/
data symb2;
retain symbid 0;
set symb1a;
by subjectid plotid;
symbid+1;
if first.subjectid then symbid=1;
run;

/*CREATE COLOUR LIST */
proc sql; 
create table colors (COLORID num(8), COLOR char(8)); 
insert into colors 
values (1,'cx009cde') 
values (2,'cxe4002b') 
values (3,'cxeeb33b') 
values (4,'cx00b140') 
values (5,'cx470a68') 
values (6,'cx888b8d') 
values (7,'cxa52a2a') 
values (8,'cxaa0061') 
values (9,'cx00ffff') 
values (10,'cxffd100') 
values (11,'cx64ccc9') 
; 
quit;

/*proc sql; */
/*create table colors (COLORID num(8), COLOR char(10)); */
/*insert into colors */
/*values (1,'a009cdecc') */
/*values (2,'ae4002bcc') */
/*values (3,'aeeb33bcc') */
/*values (4,'a00b140cc') */
/*values (5,'a470a68cc') */
/*values (6,'a888b8dcc') */
/*values (7,'aa52a2acc') */
/*values (8,'aaa0061cc') */
/*values (9,'a00ffffcc') */
/*values (10,'affd100cc') */
/*values (11,'a64ccc9cc') */
/*; */
/*quit;*/

proc sort data=symb2;
by colorid;
run;

data symb;
merge symb2(in=kp) colors;
by colorid;
if kp;
run;

data symb;
set symb;
length v $3 f $6 h 8;
if cat='B' then do;
	V='V';
	f='marker';
	color='cx000000';
	h=0.375;
end;
else if cat='H' then do;
	v='dot';
	f=''; 
	h=0.225;
end;
else if cat='R' then do;
	v='X';
	f='marker';
	h=0.2625;
end;
run;

proc sort data=symb;
by subjectid symbid;
run;

/*MACRO FOR PLOT ID SYMBOLS*/
%macro clinsymb;

data clinsymb;
set symb;
x+1;
where subjectid="&sub";
call symput('csymb',x);
run;

%do cli=1 %to &&csymb;

data _null_;
set clinsymb;
if x=&&cli;
call symputx('v',v);
call symputx('f',f);
call symputx('c',color);
call symputx('h',h);
run;
symbol&cli v=&&v f=&&f c=&&c h=&&h interpol=none;
%end;
%mend;

/*GET START AND END DATES*/
proc sql;
create table night as 
select distinct subjectid, maxplotid, min(dtm) as start format=datetime., max(dtm) as end format=datetime.
	from plotdataxx
	group by subjectid
	order by subjectid;
quit;

/*CREATE AXIS RANGES*/
data night2;
set night;
axstart=dhms(datepart(start),0,0,0);
axend=dhms(datepart(end)+1,0,0,0);
format axstart axend datetime.;
run;

data night3;
retain xsys ysys '2' when 'b' xorder '1';
set night2;
by subjectid;
do x=dhms(datepart(axstart),6,0,0) to dhms(datepart(axend),6,0,0) by dhms(1,0,0,0),
		dhms(datepart(axstart),23,0,0) to dhms(datepart(axend),23,0,0) by dhms(1,0,0,0), axstart, axend;
output;
end;
format x datetime16.;
run;

/*CREATE SHADING ANNOTATE DATASET*/
data annonight(drop=start end axstart axend);
length function $8;
set night3(in=kp);
if kp then do;
	if x < axstart then delete;
	if x > axend then delete;
	if x=axstart or timepart(x)='23:00:00't then do;
		function='move';
		y=0;
	end;
	if x=axend or timepart(x)='06:00:00't then do;
		function='bar';
		style='solid';
		color='cxdddddd';
		y=550;
	end;
end;
run;

proc sort data=annonight;
by subjectid xorder x y;
run;

proc sort data=plotdataxx;
by subjectid;
run;

proc sql;
create table axes0 as select
distinct subjectid, maxplotid, axstart, axend
from night2
order by subjectid;
quit;

data axes;
set axes0;
id+1;
call symput('lastid',id);
/*if maxplotid >240 then legtext=9;*/
/*else legtext=10;*/
run;

/*symbol1 v=V f=marker c=cx000000 h=0.5 repeat=1;*/
/*symbol2 v=dot f= c= h=0.35 repeat=11;*/

axis1 label=(a=90 'Glucose, mg/dL (mmol/L)') order=(0 to 550 by 50);


%do i=1 %to &lastid;

data _null_;
set axes;
if id=&i;
call symputx('sub',subjectid);
call symput('axstart',axstart);
call symput('axend',axend);
/*call symput('legtext',legtext);*/
run;
%put &sub &axstart &axend;

goptions reset=symbol;

%clinsymb;

/*DETERMINE HEIGHT VALUE TO BE USED IN LEGEND STATEMENT BASED ON MIXIUM LENGTH OF PLOTID VALUE*/
data xclinsymb;
length len 8;
set clinsymb;
len=length(plotid);
run;

proc sql;
create table xclinsymb2
as select distinct max(len) as maxlen
from xclinsymb;
quit;

data _null_;
set xclinsymb2;
if maxlen > 220 then call symputx('legh',8);
else call symputx('legh',10);
run;

legend1 label=none value=(height=&legh.pt) repeat=1 shape=symbol(1,0.5) across=1;
axis2 label=('Date and Time') order=(&axstart to &axend by dtday) offset=(0.5cm) value=none /*(h=6pt angle=25)*/;

title1 lspace=5pt f='Arial/Bold' "Subject &sub - &analysis";
/*footnote1 j=l 'Night Time (11pm to 6am) shaded in grey';*/
ods proclabel="Subject &sub";
proc gplot data=plotdataxx;
plot gl*dtm=plotid/
annotate=annonight legend=legend1 vaxis=axis1 vref=70 180 wvref=2
description="Subject #byval(subject)" name='PLOT';
where subjectid="&sub";
by subjectid;
format dtm datetime13.;
run;
quit;

%end;

%mend;

%macro biasplots;

data plots;
retain liblotsn;
set pumasm.amdata;
format sensor_time hhmm7.;
if length(sensor_sn)=9 then liblotsn=compbl(sensor_sn||' Libre 3 '||lot||' ('||sensorlotid||')');
else liblotsn=compbl(sensor_sn||' Classic '||lot||' ('||sensorlotid||')');
label liblotsn='Libre Lot Serial number';
%if %upcase(&ptu)=YES %then %do;
if length(sensor_sn)=9 or event=:'R' then xevent='Classic Real Time Glucose / Libre 3 Historic Glucose';
else xevent='Classic Historic Glucose';
%end;
%else %do;
xevent='Classic '||strip(event);
%end;
if xevent='Classic Historic Glucose' and "&analysis" ne "US Libre Pro" then delete;
run;

proc sort data=plots;
by subjectid xevent liblotsn sensor_time;
run;

proc sql;
create table biassubs as select distinct subjectid, xevent, max(apdif_gl_cref) as maxampb
from plots 
group by subjectid, xevent 
order by subjectid, xevent;
quit;

data biassubs;
set biassubs;
maxmpb=max(ceil(maxampb/20)*20,80);
if maxmpb > 100 then mpbby=20;
else mpbby=10;
x+1;
call symputx('xlast',x);
run;

legend1 label=none value=(font='Arial/Bold' height=16pt) repeat=1 frame shape=symbol(1,0.5) /*across=2*/;

symbol1 f='Wingdings' v='A2'x  c=cx009cde h=1 i=sm70;
symbol2 f='Wingdings' v='A2'x  c=cxe4002b h=1 i=sm70;
symbol3 f='Wingdings' v='A2'x  c=cxeeb33b h=1 i=sm70;
symbol4 f='Wingdings' v='A2'x  c=cx00b140 h=1 i=sm70;
symbol5 f='Wingdings' v='A2'x  c=cx470a68 h=1 i=sm70;
symbol6 f='Wingdings' v='A2'x  c=cx888b8d h=1 i=sm70;
symbol7 f='Wingdings' v='A2'x  c=cxa52a2a h=1 i=sm70;
symbol8 f='Wingdings' v='A2'x  c=cxaa0061 h=1 i=sm70;
symbol9 f='Wingdings' v='A2'x  c=cx00ffff h=1 i=sm70;
symbol10 f='Wingdings' v='A2'x  c=cxffd100 h=1 i=sm70;
symbol11 f='Wingdings' v='A2'x  c=cx64ccc9 h=1 i=sm70;

/*CX009CDE CXE4002B CX00B140 CXEEB33B CX64CCC9 CXAA0061 CX888B8D CX004F71 CX470A68 CX9900FF*/

%do i=1 %to &xlast;

data _null_;
set biassubs;
if x=&i;
call symputx('sub',subjectid);
call symputx('xevent',xevent);
call symputx('maxmpb',maxmpb);
call symputx('mpbby',mpbby);
run;

title1 lspace=5pt f='Arial/Bold' "Subject &sub &analysis &xevent";
ods proclabel="&sub &xevent";
proc gplot data=plots;
	plot pdif_gl_cref*sensor_time=liblotsn / haxis=axis1 vaxis=axis2 legend=legend1 vref=0 lvref=3
	description="#byval(subjectid) #byval(xevent)" name='PLOT';
	by subjectid xevent;
	axis1 order=('00:00't to '336:00't by '24:00't) offset=(0.5cm,0.5cm) label=none;
	axis2 order=(-&maxmpb. to &maxmpb. by &mpbby.) label=(a=90 'Mean % Bias');
	where subjectid="&sub" and xevent="&xevent";
run;
quit;

%end;

%mend;

%macro doceg;

%if %upcase(&doplots)=YES %then %do;

	%if %sysfunc(exist(pairedpoints)) %then %do;


		goptions reset=all;
		options papersize=a4 orientation=landscape pagesize=max linesize=max nocenter dlcreatedir;
		title;footnote;
/*		ods pdf file="&outroot2\plots\&eventid CEG Plots by Lot &fdtm..pdf" style=daisy columns=2 pdftoc=1;*/
/*		CREATE CEG PLOTS IN BY SUBJECT EVENT = SENSOR_SN =C:\TEMP*/
		ods pdf file="c:\temp\&eventid &analysis CEG Plots by Lot &fdtm..pdf" style=daisy columns=2 pdftoc=1;

		%cegplot(P6BYVAR=LOT EVENT,P6GROUP=SUBJECTID);

		ods pdf close;

		goptions reset=all;
		options papersize=a4 orientation=landscape pagesize=max linesize=max nocenter dlcreatedir;
		title;footnote;
/*		ods pdf file="&outroot2\plots\&eventid CEG Plots by Subject &fdtm..pdf" style=daisy columns=2 pdftoc=1;*/
/*		CREATE CEG PLOTS IN BY SUBJECT EVENT = SENSOR_SN =C:\TEMP*/
		ods pdf file="c:\temp\&eventid &analysis CEG Plots by Subject &fdtm..pdf" style=daisy columns=2 pdftoc=1;

		%cegplot(P6BYVAR=SUBJECTID EVENT,P6GROUP=SENSOR_SN);

		ods pdf close;

		goptions reset=all reset=symbol;
		options center nobyline papersize=('20in' '10in') orientation=landscape;
		goptions device=png300 target=png300 rotate=landscape hpos=90 vpos=40 gwait=0 aspect=0.5
		ftext='Arial' htitle=16pt htext=11pt  hby=16pt gsfname=exfile gsfmode=replace
		xmax=19in hsize=19in ymax=9.5in  vsize=9.5in;
/*		 colors=(cx009cde cxe4002b cxeeb33b cx00b140 cx470a68 cx888b8d brown cxaa0061 cyan cxffd100 cx64ccc9);*/

		title;footnote;
		
		/*CREATE PROFILE PLOTS IN C:\TEMP*/
		ods pdf file="c:\temp\&eventid &analysis Profile Plots by Subject &fdtm..pdf" style=daisy pdftoc=1;

		%profplot;

		ods pdf close;

		goptions reset=all reset=symbol;
		options center nobyline papersize=('20in' '10in') orientation=landscape;
		goptions device=png300 target=png300 rotate=landscape hpos=90 vpos=40 gwait=0 aspect=0.5
		ftext='Arial' htitle=20pt htext=16pt  hby=20pt gsfname=exfile gsfmode=replace
		xmax=19in hsize=19in ymax=9.5in  vsize=9.5in;

		title;footnote;
		/*CREATE BIAS PLOTS IN C:\TEMP*/
		ods pdf file="c:\temp\&eventid &analysis Bias Plots by Subject &fdtm..pdf" style=daisy pdftoc=1;

		%biasplots;

		ods pdf close;

		data linkceglot;
		plots="&eventid &analysis CEG Plots by Lot &fdtm..pdf";
		output;
		label plots="Link to Consensus Error Grid Plots by Lot";
		run;

		data linkcegsub;
		plots="&eventid &analysis CEG Plots by Subject &fdtm..pdf";
		output;
		label plots="Link to Consensus Error Grid Plots by Subject";
		run;

		data linkprofplot;
		plots="&eventid &analysis Profile Plots by Subject &fdtm..pdf";
		output;
		label plots="Link to Profile Plots by Subject";
		run;

		data linkbiasplot;
		plots="&eventid &analysis Bias Plots by Subject &fdtm..pdf";
		output;
		label plots="Link to Bias Plots by Subject";
		run;

		data links;
		length xlabel plots flyover $80;
		xlabel="Link to Consensus Error Grid Plots by Lot";
		plots="&eventid &analysis CEG Plots by Lot &fdtm..pdf";
		flyover='Click here to view consensus error grid plots by lot';
		output;
		xlabel="Link to Consensus Error Grid Plots by Subject";
		plots="&eventid &analysis CEG Plots by Subject &fdtm..pdf";
		flyover='Click here to view consensus error grid plots by subject';
		output;
		xlabel="Link to Profile Plots by Subject";
		plots="&eventid &analysis Profile Plots by Subject &fdtm..pdf";
		flyover='Click here to view profile plots by subject';
		output;
		xlabel="Link to Bias Plots by Subject";
		plots="&eventid &analysis Bias Plots by Subject &fdtm..pdf";
		flyover='Click here to view bias plots by subject';
		output;
		run;

		data links2;
		set links;
		link="&outroot2\plots\"||strip(plots);
		run;

		data links3(drop=xlabel plots flyover link);
		set links2(in=a rename=(link=label)) links2(in=b rename=(flyover=label));
		if a then fmtname='PLOTLK';
		if b then fmtname='PLOTFO';
		start=plots;
		end=plots;
		type='c' ;
		run;

		proc format cntlin=links3;
		run;

		/*MOVE PLOT FILES TO OUTPUT LOCATION*/
		options noxwait xmin;
		dm "x move ""c:\temp\* &fdtm..pdf"" ""&outroot2\plots\"" ";

	%end;

%end;

%mend;
%doceg;

%macro links;

ods listing close;
options papersize=a4 orientation=landscape center nobyline pagesize=max linesize=max ;
title;footnote;

proc template;
	define style Styles.USLibre;
	parent = Styles.htmlblue;
	style body / backgroundcolor=cxffffdd;
	end;
run;

proc template;
	define style Styles.USLibrePro;
	parent = Styles.htmlblue;
	style body / backgroundcolor=cxffdddd;
	end;
run;

%if "&analysis"="OUS" %then %do;

ods html5 style=htmlblue path="&outroot2" (url=none) file="Links to A2S &analysis output files for ADC-UK-PMS-&protocol.-&eventid..html"
(title="&eventid - &analysis")
gpath="&outroot2\plots" options(bitmap_mode="inline");

%end;
%else %if "&analysis"="US Libre" %then %do;

ods html5 style=USLibre path="&outroot2" (url=none) file="Links to A2S &analysis output files for ADC-UK-PMS-&protocol.-&eventid..html"
(title="&eventid - &analysis")
gpath="&outroot2\plots" options(bitmap_mode="inline");

%end;
%else %if "&analysis"="US Libre Pro" %then %do;

ods html5 style=USLibrePro path="&outroot2" (url=none) file="Links to A2S &analysis output files for ADC-UK-PMS-&protocol.-&eventid..html"
(title="&eventid - &analysis")
gpath="&outroot2\plots" options(bitmap_mode="inline");

%end;

ods graphics / imagemap=on imagefmt=svg;

proc report data=title nowindows style(report)=[cellpadding = 4pt cellspacing = 0.5pt]
	style(column)=[just=c fontsize=14pt font_weight=bold rules=none];
	column title;
	define title / display '';
run;

%macro ppoints;

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
	proc report data=pairedpoints split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows missing
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

	%if %upcase(&doplots)=YES %then %do;

	data bgadjval;
	bgadjval="&bgadj";
	output;
	run;

	title;footnote;
	proc report data=bgadjval nowindows style(report)=[cellpadding = 4pt cellspacing = 0.5pt bordercolor=cxffffff rules=none]
		style(header)=[fontsize=10pt] style(column)=[fontsize=14pt vjust=c just=c font_weight=bold];
		column bgadjval;
		define bgadjval/ display ' ';
	run;


	/*LINK TO CEG PLOTS*/
	title;footnote;
	proc report data=links nowindows style(report)=[cellpadding = 4pt cellspacing = 0.5pt bordercolor=cxffffff]
		style(header)=[fontsize=10pt] style(column)=[fontsize=10pt vjust=c just=l cellheight=1cm];
		column ('Links to Plots' xlabel plots);
		define xlabel / display '' style(column)=[font_weight=bold];
		define plots / display '' style(column)=[url=$plotlk. flyover=$plotfo.];
	run;

	/******************************************************************************************/
	/* SUMMARY RESULTS*/
	/******************************************************************************************/

	%if "&analysis"="OUS" %then %do;
	proc report data=AC_TABLE split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows missing
	style(header)=[fontsize=11pt] style(column)=[fontsize=11pt vjust=c just=c];
	column ("^S={just=l background=cxffffff}Acceptance Criteria" prodtype event lot result ac);
	define prodtype / group 'Sensor Type';
	define event / group;
	define lot / group;
	define result / group style=[cellwidth=4cm];
	define ac / group style=[protectspecialchars=off cellwidth=5cm];
	where (prodtype='Classic' and first(event)='R') or (prodtype='Libre 3' and first(event)='H');
	run;
	%end;

	%else %if "&analysis"="US Libre" %then %do;
	proc report data=AC_TABLE_US split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows missing
	style(header)=[fontsize=11pt] style(column)=[fontsize=11pt vjust=c just=c];
	column ("^S={just=l background=cxffffff}Acceptance Criteria" event lot 
	("% sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result" percent ac1) 
	("Between sensor (within lot) SD of sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result" sd ac2));
	define event / group;
	define lot / group style(column)=[vjust=c just=c protectspecialchars=off cellwidth=3cm];
	define percent / group 'Percent' style(column)=[vjust=c just=c protectspecialchars=off cellwidth=2cm];
	define ac1 / group style=[protectspecialchars=off cellwidth=5cm];
	define sd / group 'S.D.' style(column)=[vjust=c just=c protectspecialchars=off cellwidth=2cm];
	define ac2 / group style=[protectspecialchars=off cellwidth=5cm];
	format percent 6. sd 6.1;
	where first(event) in ('R');
	run;
	%end;

	%else %if "&analysis"="US Libre Pro" %then %do;
	proc report data=AC_TABLE split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows missing
	style(header)=[fontsize=11pt] style(column)=[fontsize=11pt vjust=c just=c];
	column ("^S={just=l background=cxffffff}Acceptance Criteria" event lot result ac);
	define event / group;
	define lot / group;
	define result / group style=[cellwidth=4cm];
	define ac / group style=[protectspecialchars=off cellwidth=5cm];
	where first(event)='H';
	run;
	%end;

	%if "&analysis"="OUS" %then %do;
	proc report data=SUM_TABLE split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows missing
	style(header)=[fontsize=11pt] style(column)=[fontsize=11pt vjust=c just=c];
	column prodtype event lot pdif_gl_cref_mean apdif_gl_cref_mean;
	define prodtype / group 'Sensor Type';
	define event / group;
	define lot / group;
	define pdif_gl_cref_mean / display 'Mean % Bias' format=6.1;
	define apdif_gl_cref_mean / display 'Mean Absolute % Bias' format=6.1;
	run;
	%end;

	%else %do;
	proc report data=SUM_TABLE split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows missing
	style(header)=[fontsize=11pt] style(column)=[fontsize=11pt vjust=c just=c];
	column event lot pdif_gl_cref_mean apdif_gl_cref_mean;
	define event / group;
	define lot / group;
	define pdif_gl_cref_mean / display 'Mean % Bias' format=6.1;
	define apdif_gl_cref_mean / display 'Mean Absolute % Bias' format=6.1;
	run;
	%end;

	/******************************************************************************************/
	/* PLOT OF BG READINGS FROM SUPPLIES CRF*/
	/******************************************************************************************/

	%if %eval(&protocol.) ne 20048 %then %do;

	data bg1;
	length SubjectID $9;
	set sasdata.sp1;
	SubjectID=strip(subject);
	label SubjectID='Subject';
	run;

	ods exclude Tabulate.Report.Table;
	proc tabulate data=bg1 out=bg2;
	class subjectid spredsn;
	var spgsr;
	table subjectid*(spredsn all),spgsr*(sum n max min);
	run;

	data bg3;
	set bg2;
	if spredsn='' then do;
		spredsn='Combined';
		id='C';
	end;
	else id='A';
	run;

	data bg4;
	set bg3;
	if id='C' and spgsr_n le 1 then delete;
	if id='C' and spgsr_sum=spgsr_max then delete;
	run;

	proc sort data=bg4;
	by subjectid spgsr_sum id;
	run;

	data bg5;
	length tooltip $100;
	set bg4;
	if spgsr_sum =  1 then 
	tooltip='title='||
	quote(
	'   Subject: '||strip(subjectid)||'0D'x||
	'   Reader ID: '||strip(spredsn)||'0D'x||
	'   '||strip(spgsr_sum)||" BG Reading"
	);
	else tooltip='title='||
	quote(
	'   Subject: '||strip(subjectid)||'0D'x||
	'   Reader ID: '||strip(spredsn)||'0D'x||
	'   '||strip(spgsr_sum)||" BG Readings"
	);
	run;

	proc sql;
	create table maxn as select max(spgsr_sum) as maxn
	from bg5;
	quit;

	data maxn;
	set maxn;
	call symputx('maxn',(ceil(maxn/10))*10);
	run;

	%put &maxn;

	goptions reset=all device=svg hsize=15in vsize=5in gsfname=svgout xpixels=1500 ypixels=500
	ftext='Arial' htext=10pt noaltdesc;

	goptions reset=symbol;
	symbol1 v=dot color=A009CDECC h=3 font=;
	symbol2 v='X' color=AE4002BCC h=1.5 font=marker;
	axis1 label=(a=90 'Number of Paired Points') order=(0 to &maxn by 10);
	axis2 label=('Subject') offset=(0.5cm) value=(angle=25);
	legend1 label=none repeat=1 shape=symbol(1,2) value=("Single Reader Number" "Combined Readers Total") ;

	title;footnote;
	title1 h=14pt "Number of Blood Glucose Strip Readings - Event &eventid - &analysis";
	proc gplot data=bg5;
	plot spgsr_sum*subjectid=id / vref=&ppoints
	vaxis=axis1
	haxis=axis2
	legend=legend1
	html=tooltip;
	run;
	quit;

	%end;

	options pagesize=max linesize=max;
/******************************************************************************************/
/*	PLOT OF NUMBER OF PAIRED POINTS VS SUBJECT*/
/******************************************************************************************/

	proc sort data=subpaired;
	by lot;
	run;
		
	proc sql noprint;
	select ceil(max(npaired)/10)*10 into : maxnpaired
	from subpaired;
	quit;
	goptions reset=all;

	goptions reset=all device=svg hsize=10in vsize=4in gsfname=svgout xpixels=1000 ypixels=400
	 ftext='Arial' htext=10pt noaltdesc;

	data subpaired;
	length tooltip $100;
	set subpaired;
	if npaired=1 then tooltip='title='||
	quote(
	'   Subject: '||strip(subjectid)||'0D'x||
	'   Lot: '||strip(lot)||'0D'x||
	'   '||strip(npaired)||" "||strip(event)||" paired point"
	);
	else tooltip='title='||
	quote(
	'   Subject: '||strip(subjectid)||'0D'x||
	'   Lot: '||strip(lot)||'0D'x||
	'   '||strip(npaired)||" "||strip(event)||" paired points"
	);
	run;

	symbol1 v=dot color=CX009CDE h=3 font=;
	symbol2 v=dot color=CXE4002B h=3 font=;
	symbol1 v=dot color=A009CDECC h=3 font=;
	symbol2 v='X' color=AE4002BCC h=1.5 font='marker';
	axis1 label=(a=90 'Number of Paired Points') order=(0 to &maxnpaired by 10);
	axis2 label=('Subject') offset=(0.5cm) value=(angle=25);
	legend1 repeat=1 shape=symbol(1,2);

	title;footnote;
	title1 h=14pt "Number of Paired Points - Lot #byval(lot) - &analysis";
	proc gplot data=subpaired;
	plot npaired*subjectid=event / vref=&ppoints
	vaxis=axis1
	haxis=axis2
	legend=legend1
	html=tooltip;
	by lot;
	run;
	quit;
	options pagesize=max linesize=max;

	/******************************************************************************************/
	/*	PLOT OF MPB VS SENSOR SERIAL*/
	/******************************************************************************************/

	goptions reset=all device=svg hsize=12in vsize=4in gsfname=svgout xpixels=1000 ypixels=400
	 ftext='Arial' htext=10pt noaltdesc;

	title;footnote;

	symbol1 v=dot repeat=8 h=3 font= i=rl;
	axis1 label=(a=90 'Mean % Bias') order=(-50 to 50 by 10);
	axis2 label=('Sensor Serial') offset=(0.5cm) order=(0 to 10000 by 1000) /*value=none*/;
	legend1 repeat=1 shape=symbol(1,2);

	proc sort data=mpbbysensor;
	by subjectid;
	run;

	data mpbbysensor1;
	retain Page 0;
	set mpbbysensor;
	if lag(subjectid) ne subjectid then page+1;
	run;

	data mpbbysensor2;
	length tooltip $400;
	set mpbbysensor1;
	tooltip='title='||
	quote(
	'   Sensor DMX: '||strip(sensor_dmx)||'0D'x||
	'   Subject: '||strip(subjectid)||'0D'x||
	'   Lot: '||strip(lot)||'0D'x||
	'   Sensor SN: '||strip(sensor_sn)||'0D'x||
	'   Mean % Bias = '||strip(put(mean,6.1))||'%'||'0D'x||
	'   N = '||strip(put(n,3.))||'0D'x||
	'   Click to view profile plot'
	)||" href=""&outroot2\plots\&eventid &analysis Profile Plots by Subject &fdtm..pdf#page="||strip(page)||'"';
	run;

	proc sort data=mpbbysensor2;
	by event plotid;
	run;

	title;footnote;
	title1 h=14pt "Mean % Bias vs Sensor Serial - #byval(event) - &bgadj - &analysis";
	proc gplot data=mpbbysensor2;
	plot mean*plotid=lot / vref=0
	vaxis=axis1
	haxis=axis2
	legend=legend1
	html=tooltip;
	by event;
	run;
	quit;
	options pagesize=max linesize=max;

	/******************************************************************************************/
	/* COMPARISON OF AUU DATE WITH SA CRF DATA*/
	/******************************************************************************************/
	
	proc sql noprint;
	create table auusacomp0 as
	select distinct subjectid, itemgrouprepeatkey, sensor_sn, reader_id, sensorlotid, saseq, sasensn, saredsn, salot, lot, saappdtm, saapunk, sensor_start
	from plotdata
	where sensor_sn ne ''
	order by subjectid, itemgrouprepeatkey;
	quit;

	data auusacomp;
	set auusacomp0;
	timedif=sensor_start-saappdtm;
	format timedif hhmm. sensor_start saappdtm datetime13.;
	if reader_id ne 'Phone' then readerspedis=spedis(reader_id, saredsn);
	id+1;
	run;

	/*ADD ID TO ENABLE SHADING FOR EVERY OTHER SUBJECT*/
	data auusacomp2;
	retain id2 0;
	length id3 8;
	set auusacomp ;
	if lag(subjectid)ne subjectid then id2+1;
	id3=mod(id2,2);
	run;

/*	proc sql;*/
/*	create table sublink0 as select distinct subjectid as start*/
/*	from auusacomp;*/
/*	quit;*/

	/* CREATE FORMATS FOR LINKS TO A2S OUTPUT FILES */
/*	data sublink;*/
/*	set sublink0;*/
/*	label="&outroot2\plots\&eventid Profile Plots by Subject &fdtm..pdf#Subject "||strip(start)||"=TOC";*/
/*	fmtname='SUBLK';*/
/*	type='c' ;*/
/*	end=start;*/
/*	run;*/

	proc sort data=auusacomp2 out=sublink00(keep=subjectid) nodupkey;
	by subjectid;
	run;

	data sublink0;
	set sublink00;
	page+1;
	run;

	data sublink;
	set sublink0(rename=(subjectid=start));
	label="&outroot2\plots\&eventid &analysis Profile Plots by Subject &fdtm..pdf#page"||strip(page);
	fmtname='SUBLK';
	type='c' ;
	end=start;
	run;

	proc format cntlin=sublink;
	run;

	/*GET LIST OF SUBJECTS FOR SHADING*/
	proc sql noprint;
	select distinct subjectid into : subs2 separated by '","'
	from auusacomp2
	where id3=0;
	select distinct sensor_sn into : unk separated by '","'
	from auusacomp2
	where saapunk ne '';
	quit;

	data auusacomp;
	set auusacomp;
	if saapunk='Unknown' then saappdtm=1;
	label saseq='SA CRF~Sensor~Number' 
		sasensn='SA CRF~Sensor Kit~Serial Number' 
		saredsn='SA CRF~Reading Device ID' 
		readerspedis='Reader ID~Spelling~Distance'
		saappdtm='SA CRF~Sensor Application~Time'
		timedif='Start - Application~Time Difference'
		salot='SA CRF~Sensor~Lot ID' 
	%if %upcase(&ptu)=YES %then %do;
		sensor_sn='AUU/PTU~Sensor Kit~Serial Number' 
		reader_id='AUU/PTU~Reading Device ID'
		sensor_start='AUU/PTU~Sensor Start~Time' 
		sensorlotid='AUU/PTU~Sensor~Lot ID'
	%end;
	%else %do;
		sensor_sn='AUU~Sensor Kit~Serial Number' 
		reader_id='AUU~Reading Device ID'
		sensor_start='AUU~Sensor Start~Time' 
		sensorlotid='AUU~Sensor~Lot ID'
	%end;
	;
	run;

	proc format;
	value dtunk 1 = 'Unknown'
	other=[datetime13.];
	value ridsped . = ' '
	other=[8.];
	run;

	title;footnote;
	proc report data=auusacomp missing split='~' style(header)=[vjust=b fontsize=10pt] style(column)=[vjust=m fontsize=10pt];
	column ('Sensor Data / Sensor Application CRF Comparisons' id subjectid saseq sensor_sn sasensn reader_id saredsn readerspedis sensor_start saappdtm /*saapunk*/ timedif lot sensorlotid salot);
	define id / display '#';
	define subjectid / display style(column)=[just=c /*url=$sublk. flyover='Click here to open the Profile Plot'*/];
	define saseq / display style=[just=c];	
	define sensor_sn / display;
	define sasensn / display;
	define reader_id / display;
	define saredsn / display;
	define readerspedis / display style=[just=c] format=ridsped.;
	define sensor_start / display style=[just=c];
	define saappdtm / display style=[just=c] format=dtunk.;
	define timedif / display style=[just=c];
	define lot / display;
	define sensorlotid / display style=[just=c];
	define salot / display style=[just=c];
/*	SHADING FOR ALTERNATING SUBJECTS WITH BOLD TEXT FOR LIBRE 3*/
	compute reader_id;
		if subjectid in ("&subs2") then do;
			if reader_id='Phone' then call define(_row_, "style", "style=[background=cxddffff font_weight=bold]");
			else call define(_row_, "style", "style=[background=cxbbffff]");
		end;
		else do;
			if reader_id='Phone' then call define(_row_, "style", "style=[background=cxffffdd font_weight=bold]");
			else call define(_row_, "style", "style=[background=cxffffbb]");
		end;
	endcomp;
/*	HIGHLIGHT NON-MATCHING SENSOR SN*/
	compute sasensn;
		if sasensn ne sensor_sn then call define(_col_,"style","style=[background=cxffaaaa]");
	endcomp;
/*	HIGHLIGHT NON-MATCHING READER ID*/
	compute saredsn;
		if reader_id ne 'Phone' and saredsn ne reader_id then call define(_col_,"style","style=[background=cxffaaaa]");
	endcomp;
/*	HIGHLIGHT NON-MATCHING LOT ID*/
	compute salot;
		if salot ne sensorlotid then call define(_col_,"style","style=[background=cxffaaaa]");
	endcomp;
	/*	HIGHLIGHT  MISSING SENSOR NUMBER*/
	compute saseq;
		if saseq = . then call define(_col_,"style","style=[background=cxffaaaa foreground=cxffaaaa]");
	endcomp;
/*	HIGHLIGHT NON-MATCHING APPLICATION DATE*/
	compute saappdtm;
		if saappdtm ne 1 then do;
			if datepart(sensor_start) ne datepart(saappdtm) then call define(_col_,"style","style=[background=cxffaaaa]");
		end;
	endcomp;
/*	HIGHLIGHT SENSOR START - APPLICATION TIME DIFFERENCE > 10 MINUTES*/
	compute timedif;
		if abs(timedif) gt 600 then call define(_col_,"style","style=[background=cxffaaaa]");
	endcomp;
/*	HIGHLIGHT SENSOR START BEFORE FPI*/
	compute sensor_start;
		if datepart(sensor_start) lt &fpi then call define(_col_,"style","style=[background=cxffcc00 font_weight=bold]");
	endcomp;
	run;

	%end;

	%if "&analysis"="OUS" %then %do;

	/*READER INITIALIZATION CHECKS*/
	proc contents data=richeck out=richeckorder0 noprint;
	run;

	proc sort data=richeckorder0;
	by varnum;
	run;

	data richeckorder ;
	retain name label;
	length def $ 200;
	set richeckorder0;
	name=upcase(name);
	if name='OBSERVATION' then def=strip(name)||" / display ' '"; 
	else def=strip(name)||" / display"; 
	ord+1;
	call symput('maxriord',ord);
	run;

	/*CREATE MACRO VARIABLES FOR REPORTING*/
	data _null_;
	set richeckorder;
	call symputx("RIVAR"||strip(ord),name);
	call symputx("RIDEF"||strip(ord),def);
	run;

	title;footnote;
	proc report data=richeck split='~' style(report)=[cellpadding = 4pt cellspacing = 0.5pt rules=all bordercolor=cx999999] spanrows missing
		style(header)=[fontsize=10pt] style(column)=[fontsize=10pt vjust=c just=c];
	column (("Event &eventid Reader Initialization Time and Sensor Start Time" %do i=1 %to &maxriord; &&rivar&i %end;));
	%do i=1 %to &maxriord; 
	define &&ridef&i ;
	%end;
	compute time_diff;
		if time_diff > 5 then call define(_col_,"style","style=[font_weight=bold background=cxff9999]");
		else if 1 le time_diff lt 5 then call define(_col_,"style","style=[background=cx9999ff]");
		else if time_diff=. then call define(_col_,"style","style=[background=cxffff99]");
		else call define(_col_,"style","style=[background=cx99ff99]");
	endcomp;
	compute day1_start_time;
		if day1_start_time = . then call define (_col_,'style', 'style=[background=cxffff99]');
	endcomp;
	run;
	%end;

%end;
%else %do;

data nosl;
text="SENSORLOTS dataset needs to be created in order to produce plots and tables.";
output;
run;

proc report data=nosl nowindows style(report)=[cellpadding = 4pt cellspacing = 0.5pt bordercolor=cxffffff]
	style(column)=[just=c fontsize=14pt];
	column text;
	define text / display '';
run;

%end;

	%if %upcase(&ptu)=YES %then %do;

	PROC SQL noprint;
	 SELECT nobs into : RESETOBS
	 FROM DICTIONARY.TABLES
	 WHERE UPCASE(LIBNAME)="WORK" and UPCASE(MEMNAME)="ALL_RESET_SUMMARY";
	QUIT;

		%if %eval(&resetobs) > 0 %then %do;

			title1 h=14pt "Event &eventid PTU files with life count resets";
			proc report data=all_reset_summary nowindows style(report)=[cellpadding = 4pt cellspacing = 0.5pt]
			style(header)=[fontsize=10pt] style(column)=[fontsize=10pt];
			column SubjectID Sensor_SN filename;
			define SubjectID / display 'Subject';
			define Sensor_SN / display 'Sensor Serial Number';
			define filename / display 'File Name';
			run;

		%end;

	%end;
title1 h=14pt "#byval(clinic)";

proc report data=pdft nowindows style(report)=[cellpadding = 4pt cellspacing = 0.5pt] spanrows
	style(header)=[fontsize=10pt] style(column)=[fontsize=10pt];
	column subjectid reprt condition  col1 date dtm;
	define subjectid / order 'Subject';
	define reprt / order 'A2S Report' style(column)=[just=c url=$pdflk. flyover='Click here to open the A2S Report'];
	define condition / 'Condition ID';
	define col1 / display 'A2S Plot' style(column)=[just=c url=$pdflk. flyover='Click here to open the A2S Profile Plot'];
	define date/ display 'Date analysed' style=[background=bg.];
	define dtm / display 'Date and Time analysed';
	by clinic;
run;

title;footnote;

%mend;
%ppoints;

ods html5 close;

/*EDIT HTML FILE TO REMOVE PLOT TOOLTIPS*/
options xmin;

%let cpath_file=&outroot2\Links to A2S &analysis output files for ADC-UK-PMS-&protocol.-&eventid..html;

data check1;
application_exe = "powershell.exe -command ";
command = "(gc ""'&cpath_file'"") | ForEach-Object { $_ -replace '<title>Number of Paired Points - Lot #byvallot - &analysis;</title>', '<!-- -->' } | sc ""'&cpath_file'""";
cmd = application_exe || '"' || command || '"'; 
  putlog "NOTE-Processing command" cmd;
  call system(cmd);
run;

data check1;
application_exe = "powershell.exe -command ";
command = "(gc ""'&cpath_file'"") | ForEach-Object { $_ -replace '<title>Mean % Bias vs Sensor Serial - #byvalevent - &bgadj - &analysis;</title>', '<!-- -->' } | sc ""'&cpath_file'""";
cmd = application_exe || '"' || command || '"'; 
  putlog "NOTE-Processing command" cmd;
  call system(cmd);
run;

data check1;
application_exe = "powershell.exe -command ";
command = "(gc ""'&cpath_file'"") | ForEach-Object { $_ -replace '<title>Number of Blood Glucose Strip Readings - Event &eventid - &analysis;</title>', '<!-- -->' } | sc ""'&cpath_file'""";
cmd = application_exe || '"' || command || '"'; 
  putlog "NOTE-Processing command" cmd;
  call system(cmd);
run;

%mend;
%links;
