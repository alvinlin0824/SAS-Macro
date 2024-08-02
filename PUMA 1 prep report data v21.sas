dm 'log' clear; /* CLEARS LOG WINDOW */
dm pgm 'winclose'; /* CLOSES PROGRAM EDITOR WINDOW*/
/*******************************************************************
Program Name:				PUMA 1 prep report data v21
SAS Version:				9.4 TS Level 1M6
Programmer:					w amor
Purpose:					Using PUMA macros to reproduce the results for study ADC-UK-PMS-14020/14021 Events
Program History:
Date	Programmer	Version	Change made
_______	__________	_______	____________________________
22oct21	w amor		1
29oct21 w amor		1.1		add check for sensors not included in lot reports to be excluded 
09nov21	w amor		1.2		display BG adjustment to 2dp
10jan22	w amor		1.3		only include lots from paired data in wear_duration data
22mar22	w amor		2		nonmatch macro section updated
29mar22	w amor		4		only include operational hours and sensor accountability for locked EDC data
19may22 w amor		5		updates to nonmatch section to eliminate warning messages
25may22	w amor		6		update wear duration CENSOR=1 for DI and AE reasons only
25may22	w amor		7		change values used for ACTYPE
25aug22	w amor		8		add flag for suitablity of lots
29sep22	w amor		9		keep unique sensors for wear duration based on application date, removal date and successful activation
07oct22	w amor		10		correction to saved dataset of mpbbylev to include mg/dl results for levels 1 and 2
21oct22	w amor		11		update to coding of CENSOR value in wear duration to assign value of 1 where SAPRYN is a missing value
02nov22	w amor		12		recode CENSOR value to assign value of 0 for SAPRYN='Yes' and SAPRREA in ('Other') and for SAAPYN='Yes' and SAPRYN='No' 
06jan23	w amor		13		add code to set historic pairing window for OUS Libre 3 to 5 and 15 for all other analysis values
30jan23	w amor		14		updated text to include number of successfully applied sensors in text for wear duration
							remove dataset for signature boxes - now created in PUMA 2 report output code
							update CENSOR and apply after merging SA CRF data with Sensor data in wear duration section
							add where statment to lifetest and SENSOR_DATA column to wera duration output dataset
							only import AE, DI and PD listings if EDC data is locked
31jan23	w amor		15		omit high and low calculations if there are no high or low readings
20jun23	w amor		16		updated to use IE visit data for FPI
12jul23	w amor		17		updated to create wd0 dataset for nonmatch macro
22aug23	w amor		18		replace hardcode 100mg/dL break point with macro variable &accbreak
25aug23	w amor		19		update Excluded Duplicated and Not in Agreement BG Reference Listing to remove used BGs
11oct23	w amor		20		exclude non suitable lots from histograms and appendix tables
01mar24	w amor		21		add code to allow macro created in paramater code to run for alternatice acceptance criteria
*******************************************************************/

%global nlots nlotslev  cbgmdel  nlotso  difile aefile pdfile 
distat aestat pdstat nceg nacc nhist outroot reports FPI LPO glucose suffix memos num_memos;

%global GLUCOSE CBGM CBGMDEL NEWLAB HILOOBS CBGMDUPOBS BGADJ SURVIVAL N_SENSOR TOTSENSORS N_WEAR

am amunadj  nlots nlotslev nlotsacc nlotso nlots6 difile aefile pdfile distat aestat pdstat Ndisae;
%global hiloobs  CBGMDUPobs nlotso  
nceg nacc nhist outroot reports FPI LPO glucose suffix memos num_memos tot_sensors n_sensors  ;

ods listing close;

/*GET LIST OF STACKED DATASETS*/
proc contents data=sm._all_ out=SMOUT noprint;
run;

proc sql noprint;
/*GET NAME OF MOST RECENT STACKED GLUCOSE DATASET*/
select distinct memname into :GLUCOSE 
from SMOUT 
where substr(upcase(memname),1,7)="GLUCOSE" 
having max(crdate)=crdate;
quit;

%put &glucose;

/*GET LIST OF CBGM DATASETS*/
proc contents data=cbgm._all_ out=CBGM noprint;
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

data _null_;
if upcase("&analysis")='OUS LIBRE 3' then call symputx('XHWIN',5);
else call symputx('XHWIN',15);
run;

/*RUN THE PAIRING MACRO FOR ADJSUTED GL AND ADJUSTED REF DATA*/
%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_Pairing.sas";
data P2PARAMS;
P2GLIN="&SMLOC";
P2GL="&glucose";
P2REFIN="&CBGMLOC";
P2REF="&cbgm";
P2OUT="&outroot";
P2RTWIN=5;
P2HWIN=&XHWIN;
P2MAXDIF=30.5;
output;
run;
%PUMA_pairing;

data _null_;
set cbgm.&cbgm;
call symputx('BGADJ',put(BG_ADJUSTMENT,6.2));
run;

%put &bgadj;

/*SAVE PAIRED DATASET AND ASSIGN HIGH AND LOW READINGS AND ADD PRODUCT NAMES, STRIP_BATCH AND BG_ADJUSTMENT*/
data out.adjpaired;
length Product $20;
set P2GLREF_5;
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
if lowcase(event)=:"historic" then Product="&prodhist";
else if lowcase(event)=:"real" then Product="&prodreal";
label Product="Product";
length STRIP_BATCH $10 BG_ADJUSTMENT 8;
STRIP_BATCH="&striplot";
BG_ADJUSTMENT=&BGADJ.;
run;

proc sort data=out.adjpaired;
by subjectid refdtm;
run;

proc sort data=cbgm.&cbgm out=cbgm;
by subjectid refdtm;
run;

/*CREATE UNADJUSTED PAIRED DATASET BY MERGING PAIRED DATA WITH UNADJUSTED REFERENCES AND PRODUCT NAMES*/
data out.unadjpaired(drop=unadj_ref);
length Product $20;
merge out.adjpaired(in=kp drop=ref refall ref_hilo) cbgm(keep=SUBJECTID REFDTM BG_READING UNADJ_REF);
by subjectid refdtm;
if kp;
REF=UNADJ_REF;
REFALL=UNADJ_REF;
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
if lowcase(event)=:"historic" then Product="&prodhist";
else if lowcase(event)=:"real" then Product="&prodreal";
label Product="Product";
run;

/*RUN ANALYSIS MACRO FOR ADJUSTED REF PAIRED DATA*/
%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_AM.sas";
data P3PARAMS;
P3IN="&outroot";
P3GLREF="adjpaired";
P3OUT="&outroot";
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

/*RUN ANALYSIS MACRO FOR UNADJUSTED REF PAIRED DATA*/
%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_AM.sas";
data P3PARAMS;
P3IN="&outroot";
P3GLREF="unadjpaired";
P3OUT="&outroot";
P3CREF_FACTOR="1";
P3CONSENSUS="CONSENSUS";
P3CLARKE="CLARKE";
P3WITEXC_LUT="am_witexc_lpm";
P3CONCRATE_LUT="am_concrate_std";
output;
run;
%puma_am;

/*UNADJUSTED DATA*/
proc sort data=p3glref out=AMUNADJdata;
by sensor_sn;
run;

/******************************************************************************************/
/******************************************************************************************/

/* BETWEEN RUNNING PUMA-AM AND PUMA-SUM NEED TO ADD IN THE VARIABLES FOR BY GROUP PROCESSING*/

/*ADD DOUBLE QUOTATION MARKS TO NONSUITABLE VALUE*/
data _null_;
call symputx('xnotsuitable','"'||strip(tranwrd("&notsuitable",',','","'))||'"');
run;

/*MERGE IN SENSOR LOT NUMBER FROM THE LOT REPORT DATASET*/
proc sort data=senloc.sensorlots out=sndata;
by sensor_sn;
run;

/*ADD SUITABLE COLUMN TO SENSORLOTS DATA*/
data sndata;
set sndata;
length SUITABLE $3;
if lot in (&xnotsuitable) then SUITABLE='No';
else SUITABLE='Yes';
label SUITABLE="Suitable as &analysis.?";
run;

data stacked;
length Product $20;
set sm.&glucose;
/*ADD PRODUCT NAMES*/
if lowcase(event)=:"historic" then Product="&prodhist";
else if lowcase(event)=:"real" then Product="&prodreal";
label Product="Product";
run;

/*USE STACKED DATA FOR MERGING IN ALL LOT NUMBERS FOR PAIRED POINTS AND DEMOGRAPHICS CALCULATIONS*/
proc sort data=stacked;
by sensor_sn;
run;

data stacked2 out.notlisted;
merge stacked(in=kp1) sndata(in=kp2 keep=LOT SENSOR_SN SENSOR_DMX EXPIRY_DATE SENSORLOTID SUITABLE);
by sensor_sn;
if kp1 and kp2 then output stacked2;
else if kp1 and not kp2 then output out.notlisted;
run;

/*UNIQUE SUBJECT PRODUCT / EVENTS AND LOTNUMBERS*/
proc sort data=stacked2 out=SUBEVENTLOTS nodupkey;
by subjectid &prodevt lot;
run;

data SUBEVENTLOTS;
set SUBEVENTLOTS;
event=propcase(event);
label event ='Event';
run;

/*MERGE LOT NUMBERS INTO ADJUSTED DATA*/
data amdata2 out.amnotlisted;
merge amdata(in=kp1) sndata(in=kp2);
by sensor_sn;
length Subject 8;
Subject=input(SubjectID,9.);
event=propcase(event);
label event ='Event' Subject="Subject";
label Subject="Subject";
if kp1 and kp2 then output amdata2;
else if kp1 and not kp2 then output out.amnotlisted;
run;

/*MERGE LOT NUMBERS INTO UNADJUSTED DATA*/
data AMUNADJdata2 out.amunadjnotlisted;
merge AMUNADJdata(in=kp1) sndata(in=kp2);
by sensor_sn;
length Subject 8;
Subject=input(SubjectID,9.);
event=propcase(event);
label event ='Event' Subject="Subject";
label Subject="Subject";
if kp1 and kp2 then output AMUNADJdata2;
else if kp1 and not kp2 then output out.amunadjnotlisted;
run;

/*MERGE IN CRF DATA FROM OPENCLINICA EXTRACT FILES*/

/*DEMOGRAPHICS*/
proc sort data=edc.dm out=dm1(keep=__studyoid subject sex age race raceoth);
by __studyoid subject;
run;

/*VITAL SIGNS*/
proc sort data=edc.vs(rename=(vshgt=HEIGHTCM vswgt=WEIGHT)) out=vs1(keep=__studyoid subject HEIGHTCM WEIGHT);
by __studyoid subject;
run;

/*SITE NAMES*/
proc sort data=edc2.studydetails out=sites;
by __studyoid ;
run;

data sites(keep=__studyoid Clinic);
length Clinic $50;
set sites;
if count(studyname,'-') > 5;
clinic=strip(scan(studyname,6,'-'));
label clinic="Clinical Site";
run;

/*MERGE VITAL SIGNS WITH DEMOGRAPHICS*/
data dm2;
merge dm1 vs1; 
by __studyoid subject;
run;

options VARLENCHK=NOWARN;

/*MERGE IN SITE NAMES*/
data dm(drop=__studyoid);
length RACE $10 RACEOTH $50;
merge dm2(in=kp) sites;
by __studyoid ;
if kp;
length HEIGHT BMI 8 BMIgroup $ 5;
HEIGHT=HEIGHTCM/100;
/*CALULATE BMI*/
BMI=WEIGHT/((HEIGHTCM/100)**2);
/*CREATE AGE GROUPS*/
if 18 le age le 21 then AGE_GROUP='18 to 21 Years';
else if 22 le age le 40 then AGE_GROUP='22 to 40 Years';
else if 41 le age le 60 then AGE_GROUP='41 to 60 Years';
else if age ge 61 then AGE_GROUP='61+ Years';
/*CREATE BMI GROUPS*/
if 0 le round(bmi) lt 25 then bmigroup='<25';
else if 25 le round(bmi) le 30 then bmigroup='25-30';
else if round(bmi) gt 30 then bmigroup='>30';
label BMI="Body Mass Index (kg/m²)" bmigroup="BMI Range" AGE_GROUP="Age Group" WEIGHT='Weight (kg)' HEIGHTCM='Height (cm)' HEIGHT='Height (metres)'  age='Age (years)' 
race='Race' sex='Sex';
run;

options VARLENCHK=WARN;

proc sort data=dm;
by subject;
run;

/*IMPORT DIABETES HISTORY*/
proc sort data=edc.dh out=dh;
by subject;
run;

/*IMPORT INSULIN PUMP USE*/
proc sort data=edc.im out=im;
by subject;
run;

data mh(keep=SUBJECT DTYPE DH: INSMETHOD INSPUMP);
merge dh(drop=DHNDR DHDAT rename=(DHDTYPE=Dtype)) im(rename=(IMCYN=INSPUMP));
by subject;
length INSMETHOD $4;
if DHINYN='Yes' then do;
	if INSPUMP='Yes' then INSMETHOD='Pump';
	else if INSPUMP='No' then INSMETHOD='MDI';
end;
else if DHINYN='No' then do;
	if INSPUMP='' then INSPUMP='No';
	INSMETHOD='N/A';
end;
label INSMETHOD="Method of Insulin Administration" INSPUMP="Insulin Pump Use";
run;

/*IMPORT HBA1C RESULTS*/
proc sort data=edc.lb out=lb2;
by subject;
run;

data lb2(keep=subject hba1c hba1cm hba1cgroup hba1cgroup1 /*lborres lborresu*/);
set lb2;
length HbA1cgroup $8;
if Lb1tu1='%' then hba1c=Lb1tr1;
else hba1c=round(0.0915*Lb1tr1 + 2.15,0.1);
if Lb1tu1='mmol/mol' then hba1cm=Lb1tr1;
else hba1cm=round(10.929*(Lb1tr1-2.15),1);
/*CREATE HBA1C GROUPS*/
if 0 le round(hba1c,0.1) lt 7.0 then hba1cgroup='<7.0%';
else if 7.0 le round(hba1c,0.1) le 8.5 then hba1cgroup='7.0-8.5%';
else if round(hba1c,0.1) gt 8.5 then hba1cgroup='>8.5%';
HbA1cgroup1=HbA1cgroup;
if HbA1cgroup1='' then HbA1cgroup1='N/A';
label Hba1c="HbA1c (%)" Hba1cm="HbA1c (mmol/mol)" HbA1cgroup="HbA1c Range" HbA1cgroup1="HbA1c Range";
run;

/*CREATE FULL DEMOGRAPHIC DATASET*/
data out.demog;
length SubjectID $10;
merge dm mh lb2;
by subject;
where subject ne .;
subjectid=strip(subject);
run;

proc sort data=amdata2;
by subject;
run;

proc sort data=AMUNADJdata2;
by subject;
run;

/*MERGE GL AND ADJUSTED BG WITH DEMOGRAPHICS*/
data out.amdata;
merge amdata2(in=kp) out.demog;
by subject;
if kp;
run;

/*MERGE GL AND UNADJUSTED BG WITH DEMOGRAPHICS*/
data out.AMUNADJdata;
merge AMUNADJdata2(in=kp) out.demog;
by subject;
if kp;
run;

/*MERGE LOTS WITH DEMOGRAPHIC DATA*/
data out.demoglots;
merge SUBEVENTLOTS(keep=&prodevt subjectid lot suitable) out.demog;
by subjectid;
run;

/******************************************************************************************/
/******************************************************************************************/

/*SECTION USING PUMA-SUM TO CREATE THE SUMMARY RESULTS NEEDED FOR THE REPORT*/

/********************************************************************************************/
/* MAIN FULL ANALYSIS - TABLES A, B, H, I, L, TABLE A6, TABLE A7 */
/* % WITHIN CONSENSUS GRID, BIAS MEASURES, ACCURACY MEASURES*/ 
/********************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN CEGPLOT;
set out.amdata;
/*ADD TR_USE - TO BE INTRODUCED IN PUMA-PM VERSION 2.0*/
if upcase(EVENT) = "HISTORIC GLUCOSE" then TR_USE = TR_CALC;
else TR_USE = TR;
/*CREATE FLAG FOR DATA EXCLUDING RAPIDLY CHANGING GLUCOSE*/
if tr_use in (1,2,3) then do;
	EXRAPID="Excluding Rapidly Changing Glucose";
	CEGPLOTID="Not Rapidly Changing Glucose";
end;
else CEGPLOTID="Rapidly Changing Glucose";
/*CREATE FLAG FOR DATA EXCLUDING RAPIDLY CHANGING GLUCOSE AND GLUCOSE < 80 MG/DL*/
if tr_use in (1,2,3) and GL ge 80 then EXRAPID80="Excluding Rapidly Changing Glucose or Glucose < 80 mg/dL";
label EXRAPID="Excluding Rapidly Changing Glucose" EXRAPID80="Excluding Rapidly Changing Glucose or Glucose < 80 mg/dL" TR_USE = "Trend Arrow";
run;

/*SAVE DATA FOR CEG PLOTS*/
data out.cegplot;
set cegplot;
run;

proc sort data=cegplot;
by &prodevt lot subjectid dtm;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable";output;
bygroup="reftype cref_factor &prodevt exrapid lot suitable";output;
bygroup="reftype cref_factor &prodevt exrapid80 lot suitable";output;
run;

%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
%puma_sum(P5PREFIX=TEST);

/*ADDITIONAL CALCULATIONS FOR US FREESTYLE LIBRE*/

data P5IN(keep=reftype cref_factor &prodevt lot suitable sensor_sn cref gl rwithin:);
set out.amdata;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable sensor_sn";output;
run;

%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
%puma_sum(P5PREFIX=SENSOR);

/*CALCULATE SD OF PERCENTS WITHIN BY LOT*/
data xsensor_accr;
set sensor_accr;
where first(acclevel)='C' and break=80 and high in (20) and total ge 28;
run;

data P5IN(keep=reftype cref_factor &prodevt lot suitable AAA_PERCENT);
set xsensor_accr(rename=percent=AAA_PERCENT);
run;

data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable";output;
run;

%puma_sum(P5PREFIX=PW2020SDR);

/******************************************************************************************/

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor bg_adjustment STRIP_BATCH event lot suitable expiry_date";output;
run;

data P5IN;
set out.amdata;
run;

%include 'F:\Custom\SASPROGS\DEV\PUMA\Macros\puma_sum.sas';
%puma_sum(P5PREFIX=DATA);

/******************************************************************************************/
/******************************************************************************************/

/********************************************************************************************/
/*PAIRED POINTS CALCULATION - TABLE C*/
/* CATEGORY ANALYSIS ONLY*/
/********************************************************************************************/

/*PREPARE DATA FOR PAIRED POINTS CALCULATION*/
proc sql;
create table xpaired as
select *, n(dif_gl_cref) as npaired
from out.amdata
group by subjectid, &prodevt, lot, suitable;
quit;

%global npaired;

data _null_;
if "&protocol"="14021" then call symputx('npaired',32);
else call symputx('npaired',28);
run;

data P5IN(keep=subject subjectid clinic aaa_: &prodevt lot suitable);
set xpaired;
if npaired ge &npaired. then AAA_01_PAIRED="Number of Participants with ^{unicode 2265} &npaired. Paired Points";
else AAA_01_PAIRED="Number of Participants with < 28 Paired Points";
label AAA_01_PAIRED="Number of Paired Points";
run;

/*MERGE IN MISSING SUBJECTS AND LOTS;*/
proc sort data=P5IN;
by subject subjectid clinic &prodevt lot suitable;
run;

proc sort data=out.demoglots;
by subject subjectid clinic &prodevt lot suitable suitable;
run;

data P5IN;
merge P5IN out.demoglots;
by subject subjectid clinic &prodevt lot suitable;
if AAA_01_PAIRED='' then AAA_01_PAIRED="Number of Participants with < &npaired. Paired Points";
run;

proc sort data=P5IN nodupkey;
by subject &prodevt lot suitable;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $50;
bygroup="&prodevt lot suitable";output;
run;

%puma_sum(P5PREFIX=POINTS);

/******************************************************************************************/
/******************************************************************************************/

/********************************************************************************************/
/*DEMOGRAPHICS OVERALL AND BY CLINICAL SITE - TABLES D, F*/
/********************************************************************************************/

/*PREPARE DATA FOR DEMOGRAPHICS OVERALL AND BY CLINICAL SITE*/
data P5IN(keep=ALL subject subjectid clinic aaa_: drop=AAA_02_HEIGHTCM);
Length All $3;
retain All 'All';
set out.demoglots(rename=(AGE=AAA_01_AGE  HEIGHTCM=AAA_02_HEIGHTCM HEIGHT=AAA_02_HEIGHT WEIGHT=AAA_03_WEIGHT BMI=AAA_04_BMI HBA1C=AAA_06_HBA1C HBA1CM=AAA_05_HBA1CM
SEX=AAA_01_SEX RACE=AAA_02_RACE AGE_GROUP=AAA_03_AGE_GROUP INSPUMP=AAA_06_INSPUMP DTYPE=AAA_05_DTYPE));
if suitable='Yes';
run;

proc sort data=P5IN nodupkey;
by _all_;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
infile datalines truncover;
input BYGROUP $ 1-50;
datalines;
clinic
all
;
run;

%puma_sum(P5PREFIX=DEMOG);

/******************************************************************************************/
/******************************************************************************************/

/********************************************************************************************/
/*DEMOGRAPHICS BY SENSOR LOT NUMBER - TABLE E, TABLE G*/
/********************************************************************************************/
/*PREPARE DATA FOR DEMOGRAPHICS BY SENSOR LOT NUMBER */
data P5IN(keep=subject subjectid clinic aaa_: lot suitable drop=AAA_02_HEIGHTCM);
set out.demoglots(rename=(AGE=AAA_01_AGE  HEIGHTCM=AAA_02_HEIGHTCM HEIGHT=AAA_02_HEIGHT WEIGHT=AAA_03_WEIGHT BMI=AAA_04_BMI HBA1C=AAA_06_HBA1C HBA1CM=AAA_05_HBA1CM
SEX=AAA_01_SEX RACE=AAA_02_RACE AGE_GROUP=AAA_03_AGE_GROUP INSPUMP=AAA_06_INSPUMP DTYPE=AAA_05_DTYPE));
where suitable='Yes';
run;

proc sort data=P5IN nodupkey;
by subject lot suitable;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
infile datalines truncover;
input BYGROUP $ 1-50;
datalines;
lot suitable
;
run;

%puma_sum(P5PREFIX=DEMOLOT);

/******************************************************************************************/
/******************************************************************************************/

/********************************************************************************************/
/*BY GLUCOSE LEVEL ANALYSIS - TABLE J*/
/* BIAS MEASURES AND REFERENCE ONLY*/
/* RESULTS ALSO TO BE USED FOR FIGURE 2, FIGURE 3, FIGURE 4*/
/********************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN(keep=CREF_FACTOR REFTYPE &prodevt LOT suitable DIF_GLMM_CREFMM PDIF_GL_CREF CREF DIF_GL_CREF LEVEL LEVELMM LEVELMG);
set out.amdata;
length LEVEL $1 LEVELMM LEVELMG $20;
if round(CREF) le 50 then do;
	LEVEL='1';
	LEVELMM='^{unicode 2264} 2.77';
	LEVELMG='^{unicode 2264} 50';
end;
else if 50 lt round(CREF) le 80 then do;
	LEVEL='2';
	LEVELMM='2.77-4.44';
	LEVELMG='50-80';
end;
else if 80 lt round(CREF) le 120 then do;
	LEVEL='3';
	LEVELMM='4.44-6.66';
	LEVELMG='80-120';
end;
else if 120 lt round(CREF) le 200 then do;
	LEVEL='4';
	LEVELMM='6.66-11.10';
	LEVELMG='120-200';
end;
else if 200 lt round(CREF) le 300 then do;
	LEVEL='5';
	LEVELMM='11.10-16.65';
	LEVELMG='200-300';
end;
else if 300 lt round(CREF) le 400 then do;
	LEVEL='6';
	LEVELMM='16.65-22.20';
	LEVELMG='300-400';
end;
else if round(CREF) gt 400 then do;
	LEVEL='7';
	LEVELMM='> 22.20';
	LEVELMG='> 400';
end;
label LEVEL="Glucose Level" LEVELMM='mmol/L' LEVELMG='mg/dL';
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor lot suitable &prodevt level levelmm levelmg";output;
run;

%puma_sum(P5PREFIX=LEVEL);

/******************************************************************************************/
/******************************************************************************************/

/********************************************************************************************/
/*PASSING AND BABLOK REGRESSION ANALYSIS - TABLE K*/
/* REGRESSION RESULTS ONLY*/
/********************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN(keep=reftype cref_factor &prodevt lot suitable cref gl);
set out.amdata;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable";output;
run;
%puma_sum(P5PREFIX=REG,P5PBREG=1);

data P5IN(keep=subjectid reftype cref_factor bg_adjustment event lot suitable cref gl);
set out.amdata;
run;

data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor bg_adjustment event lot suitable";output;
run;
%puma_sum(P5PREFIX=DATAREG,P5PBREG=1);

proc contents data=reg_reg1 out=regc noprint;
run;

data regc(keep=newlab);
set regc;
if index(lowcase(label),'label') > 0;
newlab=strip(name)||"='N'";
run;

proc sql noprint;
select newlab into : NEWLAB separated by ' '
from regc;
quit;

data _null_;
call symputx('NEWLAB',"label &newlab");
run;

%put &newlab;
data reg_reg1;
set reg_reg1;
&newlab;
run;

data reg_reg2;
set reg_reg2;
label N='N';
run;

/********************************************************************************************/
/*BY DAY OF SENSOR WEAR - TABLE A4, TABLE A5*/
/* RESULTS ALSO TO BE USED FOR FIGURE 6*/
/********************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN(keep=CREF_FACTOR REFTYPE &prodevt LOT suitable DAY PDIF_GL_CREF CONSENSUS);
set out.amdata;
length DAY $2;
/*ADD DAY - TO BE INTRODUCED IN PUMA-PM VERSION 2.0*/
if (floor(SENSOR_TIME/hms(24,0,0))+1) < 10 then DAY = ' '||strip(floor(SENSOR_TIME/hms(24,0,0))+1);
else DAY = strip(floor(SENSOR_TIME/hms(24,0,0))+1);
label DAY = 'Day';
if day le &days;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable day";output;
run;

%puma_sum(P5PREFIX=DAY);

/********************************************************************************************/
/*UNADJUSTED BG REFERENCE - TABLE A9*/
/*CONSENSUS GRID ANALYSIS*/
/********************************************************************************************/

data P5IN(keep=reftype cref_factor &prodevt lot suitable consensus) CEGPLOTUNADJ ;
set out.AMUNADJdata;
/*ADD TR_USE - TO BE INTRODUCED IN PUMA-PM VERSION 2.0*/
if EVENT = "HISTORIC GLUCOSE" then TR_USE = TR_CALC;
else TR_USE = TR;
/*CREATE FLAG FOR DATA EXCLUDING RAPIDLY CHANGING GLUCOSE*/
if tr_use in (1,2,3) then do;
	EXRAPID="Excluding Rapidly Changing Glucose";
	CEGPLOTID="Not Rapidly Changing Glucose";
end;
else CEGPLOTID="Rapidly Changing Glucose";
/*CREATE FLAG FOR DATA EXCLUDING RAPIDLY CHANGING GLUCOSE AND GLUCOSE < 80 MG/DL*/
if tr_use in (1,2,3) and GL ge 80 then EXRAPID80="Excluding Rapidly Changing Glucose or Glucose < 80 mg/dL";
label EXRAPID="Excluding Rapidly Changing Glucose" EXRAPID80="Excluding Rapidly Changing Glucose or Glucose < 80 mg/dL" TR_USE = "Trend Arrow";
run;

/*SAVE DATA FOR UNADJUSTED CEG PLOTS*/
data out.CEGPLOTUNADJ;
set CEGPLOTUNADJ;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable";output;
run;

%puma_sum(P5PREFIX=UNADJ);

/*DELETE PUMA-SUM WORK DATASETS*/
proc datasets library=work;
delete _p5:;
run;
quit;

/******************************************************************************************/
/******************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN(keep=subject subjectid clinic apdif_gl_cref reftype cref_factor &prodevt lot suitable sensor_start sensor_sn);
set out.amdata(drop=clarke consensus within: rwithin: exceeds: rexceeds:);
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable subject subjectid sensor_start";output;
run;
%puma_sum(P5PREFIX=SUBJECT);

/*SAVE DATA FOR MEAN ABSOLUTE % BIAS HISTOGRAMS*/
data out.histo_mapb;
set subject_stat1;
run;

/******************************************************************************************/
/******************************************************************************************/

/*ADD ADDITIONAL CLASS VARIABLES*/
data P5IN(keep=subject subjectid clinic pdif_gl_cref apdif_gl_cref reftype cref_factor &prodevt lot suitable sensor_start sensor_sn);
set out.amdata(drop=clarke consensus within: rwithin: exceeds: rexceeds:);
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="reftype cref_factor &prodevt lot suitable subject subjectid sensor_start";output;
run;
  
%puma_sum(P5PREFIX=xSUBJECT);

/*SAVE DATA FOR MEAN % BIAS HISTOGRAMS*/
data out.histo_mpb;
set xsubject_stat1;
run;

/********************************************************************************************/
/*PREPARING SUMMARY RESULTS FOR LISTINGS - NOT PART OF SUMMARY MACRO*/
/********************************************************************************************/

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

%macro ac14021;
/*CHECKS MACRO DOAC EXISTS AND RUNS IT*/
		%let ndoac=0;

		proc sql noprint;
		select n(objname) into : ndoac
		from sashelp.vcatalg
		where libname='WORK' and memname='SASMACR' and objname='DOAC';
		quit;

		%put &ndoac;

		%if %eval(&ndoac) > 0 %then %do;
			%doac;
		%end;

%mend;
%ac14021;

proc sort data=AC1;
by &prodevt lot suitable;
run;

/*ADD ACCEPTANCE CRITERIA COLUMN*/
data AC_TABLE;
set AC1;
by reftype &prodevt lot suitable;
length ac $40;
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
by &prodevt lot suitable;
run;

proc sort data=AC_TABLE_US2;
by &prodevt lot suitable;
run;

data AC_TABLE_US(keep=&prodevt lot suitable percent ac1 sd ac2);
merge AC_TABLE_US1 AC_TABLE_US2;
by &prodevt lot suitable;
run;

******************************************************************************************;
/*TABLE B: CONCLUSION MEAN % BIAS AND MEAN ABSOLUTE % BIAS TABLE BY PRODUCT AND SENSOR LOT*/
******************************************************************************************;

data SUM_TABLE;
set test_stat1;
where bygrouporder=' 1';
run;

proc sort data=SUM_TABLE;
by &prodevt lot suitable;
run;

/********************************************************************************************/
/*TABLE C: NUMBER OF PARTICIPANTS WITH GREATER THAN OR EQUAL X PAIRED POINTS*/
/********************************************************************************************/

proc sort data=points_freq1 out=pairedpoints0;
by lot catvar category catval;
where index(catval,'<') =0;
run;

proc transpose data=pairedpoints0(where=(lot ne '')) out=PAIREDPOINTS;
by lot suitable catvar category catval;
var ResultCP;
id &prodevt;
idlabel &prodevt;
run;

/******************************************************************************************/
/*TABLE D: PARTICIPANT DEMOGRAPHICS BY SITE*/
/******************************************************************************************/

data demo_site1;
retain clinid 0;
set demog_freq1;
if Clinic='' then Clinic='All';
if lag(clinic) ne clinic then clinid+1;
call symputx('NCLIN',clinid);
call symputx('CLIN'||left(clinid),strip(clinic));
countlab='N';
percentlab='%';
format count 6. percent 6.1;
run;

proc sort data=demo_site1;
by catvar category catval;
run;

proc transpose data=demo_site1 prefix=COUNT out=demo_site1a(drop=_name_ _label_);
by catvar category catval;
var COUNT;
id clinid;
idlabel countlab;
run;

proc transpose data=demo_site1 prefix=PERCENT out=demo_site1b(drop=_name_ _label_);
by catvar category catval;
var PERCENT;
id clinid;
idlabel percentlab;
run;

data DEMO_SITE(rename=(count&nclin=COUNTALL percent&nclin=PERCENTALL));
merge demo_site1a demo_site1b;
by catvar category catval;
run;

/******************************************************************************************/
/*TABLE E: PARTICIPANT DEMOGRAPHICS BY SENSOR LOT*/
/******************************************************************************************/

data demo_lot1;
retain xlotid 0;
set demolot_freq1;
if lag(lot) ne lot then xlotid+1;
call symput('NLOTS',xlotid);
call symputx('LOT'||left(xlotid),strip(lot));
countlab='N';
percentlab='%';
format count 6. percent 6.1;
where suitable='Yes';
run;

proc sort data=demo_lot1;
by catvar category catval;
run;

proc transpose data=demo_lot1 prefix=COUNT out=demo_lot1a(drop=_name_ _label_);
by catvar category catval;
var COUNT;
id xlotid;
idlabel countlab;
run;

proc transpose data=demo_lot1 prefix=PERCENT out=demo_lot1b(drop=_name_ _label_);
by catvar category catval;
var PERCENT;
id xlotid;
idlabel percentlab;
run;

data DEMO_LOT;
merge demo_lot1a demo_lot1b DEMO_SITE(keep=catvar category catval countall percentall);
by catvar category catval;
run;

/******************************************************************************************/
/*TABLE F: BASELINE CHARACTERISTICS BY SITE*/
/******************************************************************************************/

data CHAR_SITE;
set demog_stat3;
if clinic='' then clinic='All';
label clinic='Site' measure='Characteristic';
varorder2=varorder;
/*SD OF SINGLE VALUE IS 0*/
if n=1 and SD=. then SD=0;
run;

proc sort data=CHAR_SITE;
by varorder bygrouporder clinic;
run;

/******************************************************************************************/
/*TABLE G: BASELINE CHARACTERISTICS BY SENSOR LOT*/
/******************************************************************************************/

data CHAR_LOT;
set demolot_stat3(in=kp) demog_stat3(where=(bygrouporder=' 2')) ;
if lot='' then lot='All';
label measure='Characteristic';
varorder2=varorder;
/*SD OF SINGLE VALUE IS 0*/
if n=1 and SD=. then SD=0;
run;

proc sort data=CHAR_LOT;
by varorder measure bygrouporder lot suitable;
run;

/******************************************************************************************/
/*TABLE H: CONSENSUS ERROR GRID ANALYSIS OF GM VS. BG REFERENCE*/
/******************************************************************************************/

data tablecegx;
length Data $60;
set test_grids;
where bygrouporder in (' 1',' 2',' 3');
if bygrouporder=' 1' then Data='All';
else data=strip(compbl((exrapid||exrapid80)));
nlabel='N';
plabel='%';
run;

proc sort data=tablecegx;
by &prodevt bygrouporder data lot suitable consensus_total;
run;

proc transpose data=tablecegx out=tablecegn(drop=_name_ _label_) prefix=N;
by &prodevt bygrouporder data lot suitable consensus_total;
id zone;
var consensus_n;
idlabel nlabel;
run;

proc transpose data=tablecegx out=tablecegp(drop=_name_ _label_) prefix=PC;
by &prodevt bygrouporder data lot suitable consensus_total;
id zone;
var consensus_percent;
idlabel plabel;
run;

data TABLECEG;
merge tablecegn tablecegp;
by &prodevt bygrouporder data lot suitable consensus_total;
NAB=sum(NA,NB);
PCAB=sum(PCA,PCB);
label NAB='N' PCAB='%';
format PC: 8.1;
run;

/******************************************************************************************/
/*TABLE I: MEAN BIAS OVER ALL LEVELS */
/******************************************************************************************/

/*RENAME DIFFERENCE MEASURES*/
data BIASALL;
set test_stat3;
if index(measure,'Difference')>0 then do;
	if index(measure,'%')>0 then measure=tranwrd(measure,'Difference','Relative Bias');
	else measure=tranwrd(measure,'Difference','Bias');
end;
run;

/******************************************************************************************/
/*TABLE J: MEAN BIAS MEASURES BY GLUCOSE LEVEL*/
/******************************************************************************************/

/*MMOL/L AND PERCENT BIAS*/
data mpbbyleva;
set level_stat3;
if (level in ('1','2') and varorder=1) or (level > '2' and varorder=3);
mblab='Mean Bias';
countlab='N';
run;

/*MG/DL AND PERCENT BIAS*/
data mpbbylevamg;
set level_stat3;
if (level in ('1','2') and varorder=2) or (level > '2' and varorder=3);
mblab='Mean Bias';
countlab='N';
run;

data mpbbylevax(rename=(mean=meancref));
set level_stat3;
if varorder=4;
run;

proc sort data=mpbbylevamg;
by &prodevt lot suitable level;
run;

proc sort data=mpbbylevax;
by &prodevt lot suitable level;
run;

data mpbbylevplot;
merge mpbbylevamg mpbbylevax(keep=meancref &prodevt lot suitable level);
by &prodevt lot suitable level;
label meancref='Mean Comparative Reference (mg/dL)'; 
run;

/*SAVE DATA FOR BY LEVEL TABLE PLOT*/
data out.mpbbylev;
set mpbbylevplot;
run;

proc sort data=mpbbyleva;
by lot suitable;
run;

data mpbbylevb;
retain xlotid 0;
set mpbbyleva;
where suitable='Yes';
if lag(lot) ne lot then xlotid+1;
call symput('NLOTSLEV',xlotid);
call symputx('LOT'||left(xlotid),strip(lot));
run;

proc sort data=mpbbylevb;
by &prodevt level levelmm levelmg;
run;

proc transpose data=mpbbylevb prefix=MEAN out=mpbbylevc(drop=_name_ _label_);
by &prodevt level levelmm levelmg;
var MEAN;
id xlotid;
idlabel mblab;
run;

proc transpose data=mpbbylevb prefix=N out=mpbbylevdx(drop=_name_ _label_);
by &prodevt level levelmm levelmg;
var N;
id xlotid;
idlabel countlab;
run;

/*TRANSPOSE BACK TO ASSIGN 0 TO MISSING VALUES*/
proc transpose data=mpbbylevdx out=mpbbylevdy(rename=(_name_=xlotid _label_=countlab));
var N:;
by &prodevt level levelmm levelmg;
run;

data mpbbylevdy;
set mpbbylevdy;
if col1=. then col1=0;
run;

proc transpose data=mpbbylevdy out=mpbbylevd(drop=_name_);
by &prodevt level levelmm levelmg;
var col1;
id xlotid;
idlabel countlab;
run;

data MPBBYLEV;
merge mpbbylevc mpbbylevd;
by &prodevt level levelmm levelmg;
run;

/******************************************************************************************/
/*TABLES L : SYSTEM ACCURACY OF GM VS. BG REFERENCE (ROUNDED METHOD)*/
/******************************************************************************************/

data tableaccxR;
set test_accr;
where break=&accbreak and bygrouporder=' 1' and first(acclevel)='C'  and first(acclabel)='W' and high in (15,20,30,40);
run;

proc sort data=tableaccxR;
by &prodevt break high low lot suitable ;
run;

data tableaccyR;
set tableaccxR;
by &prodevt break high low lot suitable ;
where suitable='Yes';
id+1;
if first.low then id=1;
length xwithin $30;
xwithin=tranwrd(scan(acclabel,1,'('),'or','/');
xwithin=tranwrd(xwithin,'Within ±','Within ± ');
label xwithin="% Within BG Reference";
call symput('NLOTSACC',id);
run;

proc sort data=tableaccyR;
by &prodevt break high low xwithin;
run;

proc transpose data=tableaccyR out=TABLEACCR(drop=_name_ _label_) prefix=withinacc;
var resultcp;
by &prodevt break high low xwithin;
id id;
idlabel lot;
run;

/******************************************************************************************/
/*TABLE M : HIGH AND LOW READINGS */
/******************************************************************************************/


/*ASSESS OUT OF RANGE READINGS WITH CONSENSUS ERROR GRID*/
data out.HILOADJ;
set out.amdata(drop=PUMA_AM_VERSION CREF_FACTOR CREF CREFMM REFMM GLMM DIF_GL_CREF ADIF_GL_CREF PDIF_GL_CREF APDIF_GL_CREF DIF_GLMM_CREFMM ADIF_GLMM_CREFMM
GL_CREF GLMM_CREFMM CONSENSUS CLARKE WITHIN_: EXCEEDS_: RWITHIN_: REXCEEDS_: CONC:);
where gl_hilo ne '';
gl=glall;
ref=refall;
run;

PROC SQL noprint;
 SELECT nobs into : HILOOBS
 FROM DICTIONARY.TABLES
 WHERE UPCASE(LIBNAME)="OUT" and UPCASE(MEMNAME)="HILOADJ";
QUIT;

%put &hiloobs;

%macro hilo;

%if %eval(&hiloobs) > 0 %then %do;

/*RUN ANALYSIS MACRO FOR ADJUSTED REF PAIRED DATA*/
%include "F:\Custom\SASPROGS\DEV\PUMA\Macros\PUMA_AM.sas";
data P3PARAMS;
P3IN="&outroot";
P3GLREF="HILOADJ";
P3OUT="&outroot";
P3CREF_FACTOR="1";
P3CONSENSUS="CONSENSUS";
P3CLARKE="na";
P3WITEXC_LUT="na";
P3CONCRATE_LUT="na";
output;
run;
%puma_am(p3output=0);

proc sort data=p3glref;
by &prodevt subjectid lot suitable dtm gl_hilo refdtm;
run;

proc sql;
create table hiloadj
	as select &prodevt, subjectid, lot, suitable, dtm, gl_hilo, refdtm, crefmm, refall*cref_factor/18.016 as crefallmm
	from out.amdata
	where gl_hilo ne ''
	order by &prodevt, subjectid, lot, suitable, dtm, gl_hilo, refdtm;
create table hilounsadj
	as select &prodevt, subjectid, lot, suitable, dtm, gl_hilo, refdtm, crefmm as crefmmunadj, refall*cref_factor/18.016 as crefallmmunadj
	from out.AMUNADJdata
	where gl_hilo ne ''
	order by &prodevt, subjectid, lot, suitable, dtm, gl_hilo, refdtm;
quit;

data hilo;
merge hiloadj hilounsadj p3glref(keep=&prodevt subjectid lot suitable dtm gl_hilo refdtm consensus);
by &prodevt subjectid lot suitable dtm gl_hilo refdtm;
label subjectid='Participant' dtm='Date and Time of Excluded GM' gl_hilo='Reason for Exclusion' refdtm='BG Reference Date and Time' crefmm='BG Reference (mmol/L)'
crefmmunadj='Unadjusted BG Reference (mmol/L)' crefallmm='BG Reference (mmol/L)' crefallmmunadj='Unadjusted BG Reference (mmol/L)';
format crefmm crefmmunadj 8.2;
run;

%end;

%mend;
%hilo;


/******************************************************************************************/
/*TABLES N : LISTING OF EXCLUDED, DUPLICATED AND NOT IN AGREEMENT BG REFERENCE */
/******************************************************************************************/

proc sql;
create table CBGMDUP0
as select *, REF/18.016 as REFMM format=8.2, UNADJ_REF/18.016 as UNADJ_REFMM format=8.2
from cbgm.&cbgmdel
where flagy='Duplicate BGs not in Agreement'
order by subjectid, reader_id, refdtm, recid;
quit;

proc sort data=cbgm.&cbgm out=bgused;
by subjectid reader_id refdtm recid;
run;

/*MERGE IN AND EXCLUDE BGS USED IN CLEANED DATA*/
data CBGMDUP;
length used $1;
merge CBGMDUP0(in=kp) bgused(in=dp keep=subjectid reader_id refdtm recid);
by subjectid reader_id refdtm recid;
if kp;
if dp then delete;
run;

proc sort data=CBGMDUP nodupkey;
by subjectid reader_id refdtm recid;
run;

PROC SQL noprint;
 SELECT nobs into : CBGMDUPOBS
 FROM DICTIONARY.TABLES
 WHERE UPCASE(LIBNAME)="WORK" and UPCASE(MEMNAME)="CBGMDUP";
QUIT;

/******************************************************************************************/
/*TABLE O: SUMMARY BY DAY OF SENSOR WEAR*/
/******************************************************************************************/

data mpbbyday;
set day_stat3;
where bygrouporder=' 1' and varorder=1;
run;

proc sort data=mpbbyday;
by &prodevt day lot suitable;
run;

/*SAVE DATA FOR MPB BY DAY PLOT*/
data out.mpbbyday;
set mpbbyday;
run;

data mpbbyday;
set mpbbyday;
where suitable='Yes';
by &prodevt day lot suitable;
id+1;
if first.day then id=1;
call symput('NLOTSO',id);
run;

proc transpose data=mpbbyday out=mpbbydaya(drop=_name_ _label_) prefix=mpb_;
by &prodevt day ;
var mean;
id id;
idlabel lot;
run;

data consensus;
set day_grids;
where bygrouporder=' 1' and zone='A';
run;

proc sort data=consensus;
by &prodevt day lot suitable;
run;

data consensus;
set consensus;
where suitable='Yes';
by &prodevt day lot suitable;
id+1;
if first.day then id=1;
run;

proc transpose data=consensus out=zoneA(drop=_name_ _label_) prefix=zoneA_;
by &prodevt day;
var consensus_percent;
id id;
idlabel lot;
run;

data TABLEBYDAY;
retain prodid 0;
merge mpbbydaya zoneA;
by &prodevt day;
if &prodevt ne  lag(&prodevt) then prodid+1;
run;


/******************************************************************************************/
/*TABLE P: SYSTEM ACCURACY OF GM VS. BG REFERENCE, GLUCOSE < 5.55 MMOL/L*/
/*TABLE Q: SYSTEM ACCURACY OF GM VS. BG REFERENCE, GLUCOSE GE 5.55 MMOL/L*/
/******************************************************************************************/

/*PREPARE TABLES P AND Q RESULTS (ROUNDED)*/
data tablea6xR;
set test_accr;
where break=&accbreak and bygrouporder=' 1' and first(acclevel) ne 'C' and first(acclabel)='W' and high in (15,20,30,40)and suitable='Yes';
run;

proc sort data=tablea6xR;
by &prodevt break high low acclevel acclabel lot suitable;
run;

data tablea6yR;
set tablea6xR;
by &prodevt break high low acclevel acclabel lot suitable;
id+1;
if first.acclabel then id=1;
label acclabel="% Within BG Reference";
call symput('NLOTS6',id);
run;

proc transpose data=tablea6yR out=TABLEACCR_BYLEV(drop=_name_ _label_) prefix=withinacc;
var resultcp;
by &prodevt break high low acclevel acclabel;
id id;
idlabel lot;
run;

data TABLEACCR_BYLEV;
retain NewLabel Acclabel;
set TABLEACCR_BYLEV;
if acclevel='High' then Newlabel=strip(scan(acclabel,1,'±')||'± '||scan(acclabel,2,'±'));
else if acclevel='Low' then Newlabel=strip(scan(acclabel,1,'±')||'± '||scan(acclabel,2,'()')||' ('||strip(scan(acclabel,2,'±('))||')');
label NewLabel="% Within BG Reference";
run;

/******************************************************************************************/
/*TABLE R: CONSENSUS ERROR GRID ANALYSIS OF GM VS. BG REFERENCE (UNADJUSTED)*/
/******************************************************************************************/

data tablea9x;
set unadj_grids;
nlabel='N';
plabel='%';
run;

proc sort data=tablea9x;
by &prodevt bygrouporder lot suitable consensus_total;
run;

proc transpose data=tablea9x out=tablea9n(drop=_name_ _label_) prefix=N;
by &prodevt bygrouporder lot suitable consensus_total;
id zone;
var consensus_n;
idlabel nlabel;
run;

proc transpose data=tablea9x out=tablea9p(drop=_name_ _label_) prefix=PC;
by &prodevt bygrouporder lot suitable consensus_total;
id zone;
var consensus_percent;
idlabel plabel;
run;

data CEG_UNADJ;
merge tablea9n tablea9p;
by &prodevt bygrouporder lot suitable consensus_total;
NAB=sum(NA,NB);
PCAB=sum(PCA,PCB);
label NAB='N' PCAB='%';
format PC: 8.1;
run;

/*MACRO FOR IMPORTING LIST OF DI, AE AND PD REPORTS*/
%macro DIreport;

data _null_;
call symput('edcstatus',upcase("&edcloc"));
run;

%if &edcstatus=FINAL %then %do;

/********************************************************************************************/
/*THIS SECTION OF CODE SEARCHES CLINICALS DIRECTORY FOR PREVIOUSLY SUPPLIED LISTING TO EXTRACT CASEIDS THAT HAVE BEEN ADDED*/
/********************************************************************************************/

/*CLINICAL AFFAIRS LOCATION OF FILES TO IMPORT*/
/*CHECK LOCATION IS CORRECT*/

/*CHECK THAT FILE PATH EXISTS*/
   options noxwait; 
   %local rc fileref ; 
   %let rc = %sysfunc(filename(fileref,&reports)) ; 

/*IF FILE PATH EXIST FOLLOWING CODE RUNS TO CREATE A DATASET REPDIRS CONTAINING FILEPATHs AND FILENAMES*/
   %if %sysfunc(fexist(&fileref))  %then %do;

/*GET EXISTING REPORT DIRECTORIES AND SUBDIRECTORIES;*/
	filename _root_ pipe "dir /-c /q /t:w ""&reports""";

/*	CREATES DATASET WITH FULL FILENAMES FROM ROOT DIRECTORY AND SUBDIRECTORIES*/
	data repdirs;
	length reptype $2 path filename $255 line $1024 owner $17 temp $16 date time 8;
	retain path ;
	infile _root_ length=reclen ;
	input line $varying1024. reclen ;
	if reclen = 0 then delete ;
	if scan( line, 1, ' ' ) = 'Volume'  | /* BEGINNING OF LISTING */
       scan( line, 1, ' ' ) = 'Total'   | /* ANTEPENULTIMATE LINE */
       scan( line, 2, ' ' ) = 'File(s)' | /* PENULTIMATE LINE     */
       scan( line, 2, ' ' ) = 'Dir(s)'    /* ULTIMATE LINE        */
	then delete ;

	dir_rec = upcase( scan( line, 1, ' ' )) = 'DIRECTORY' ;

	if dir_rec then
       path = left( substr( line, length( "Directory of" ) + 2 )) ;
 	else do ;
       date = input(scan( line, 1, ' ' ),ddmmyy10.);
       time = input(scan( line, 2, ' ' ),hhmmss.);
       temp = scan( line, 3, ' ' ) ;
       if temp = '<DIR>' then size = 0 ;
	   else size = input(compress(temp,'()'), best. ) ;
       owner = scan( line, 4, ' ' ) ;
/*     SCAN DELIMITERS CAUSE FILENAME PARSING TO REQUIRE SPECIAL TREATMENT */
       filename=substr(line,60,length(line)-59);
	   if filename in ( '.' '..' ) then delete ;
       ndx = index( line, scan( filename, 1 )) ;
  	end;
	drop dir_rec line ndx temp ;
	if index(lowcase(line),'locked')>0 and index(lowcase(line),'caseids')=0 and index(lowcase(line),'protected')>0;
	if index(lowcase(line),'device incident')>0 then reptype='DI';
	else if index(lowcase(line),'adverse event')>0 then reptype='AE';
	else if index(lowcase(line),'protocol deviation')>0 then reptype='PD';
	else delete;
format date date9. time hhmm.;
run;

data repdirs0;
set repdirs;
status=scan(scan(filename,-3,''),-1,'_');
run;

proc sort data=repdirs0;
by reptype status path date time;
run;

data repdirs1;
set repdirs0;
by reptype status path date time;
if last.reptype;
run;

%let difile=;
%let aefile=;
%let pdfile=;
%let distat=;
%let aestat=;
%let pdstat=;

data _null_;
set repdirs1;
if reptype='DI' then do;
	call symputx('DIFILE',strip(path)||'\'||strip(filename));
	call symputx('DISTAT',strip(upcase(status)));
end;
if reptype='AE' then do;
	call symputx('AEFILE',strip(path)||'\'||strip(filename));
	call symputx('AESTAT',strip(upcase(status)));
end;
if reptype='PD' then do;
	call symputx('PDFILE',strip(path)||'\'||strip(filename));
	call symputx('PDSTAT',strip(upcase(status)));
end;
run;

/*CREATE TABLE OF BY VARIABLES FOR SUMMARIES*/
data P5BYVARS;
length BYGROUP $100;
bygroup="studystatus";output;
run;

data P5IN(rename=(DUSAEYN=AAA_DUSAEYN));
set edc.du;
run;

%puma_sum(P5PREFIX=DI);

%let Ndisae=0;
data _null_;
set di_freq1;
where lowcase(catval)='yes';
call symputx('NDISAE',count);
run;

%put &ndisae;
data _null_;
if &ndisae=0 then call symputx('NDITEXT',"No device incidents");
else if &ndisae=1 then call symputx('NDITEXT',"One device incident");
else if &ndisae > 1 then call symputx('NDITEXT',propcase(strip(put(&ndisae,words.)),'~')||" device incidents");
run;

data disummary;
length disum $300;
if "&difile" ="" then do;
/*disum="&nditext could have led to a serious adverse event. Final listings for all device incidents that occurred during the study are currently not available.";output;*/
disum="No device incidents were recorded.";output;
end;
else do;
disum="&nditext could have led to a serious adverse event. All device incidents that occurred during the study can be found in:";output;
disum="&difile";output;
end;
run;

data aesummary;
length aesum $300;
if "&aefile" ="" then do;
/*aesum="Final listings for all adverse events that occurred during the study are currently not available.";output;*/
aesum="No adverse events were recorded.";output;
end;
else do;
aesum="All adverse events that occurred during the study can be found in:";output;
aesum="&aefile";output;
end;
run;

data pdsummary;
length pdsum $300;
if "&pdfile" ="" then do;
/*pdsum="Final listings for all protocol deviations that occurred during the study are currently not available.";output;*/
pdsum="No protocol deviations were recorded.";output;
end;
else do;
pdsum="All protocol deviations that occurred during the study can be found in:";output;
pdsum="&pdfile";output;
end;
run;
 
proc format;
value $disum "&difile"="&difile";
value $aesum "&aefile"="&aefile";
value $pdsum "&pdfile"="&pdfile";
run;

%end;
%else %do;
/*FOLLOWING CODE RUNS IF FILE PATH DOES NOT EXIST - CREATES AN EMPTY DATA SET REPDIRS*/
%put NOTE: The directory "&root" does not exist ; 
/*	CREATES EMPTY DATASET IF DIRECTORY DOES NOT EXIST*/
	data repdirs;
	length path filename $255 line $1024 owner $17 temp $16 date time 8;
	delete;
	run;
%end;

%end;

%mend;

%DIreport;

/******************************************************************************************/
/* CONSENSUS ERROR GRID PLOTS*/
/******************************************************************************************/

%macro cegplot;

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
set CEGPLOT;
P6DEFAULTGROUP='1';
where suitable='Yes';
run;

%let P6BYVAR=&prodevt LOT;
%let P6GROUP=CEGPLOTID;
%let P6ATTRPRIORITY=COLOR;
%let P6XVAR=CREF;
%let P6YVAR=GL;
%let P6XVARMM=CREFMM;
%let P6YVARMM=GLMM;

ods graphics / antialias=on antialiasmax=100000;

/*SET DEFAULT SYMBOLS*/
%let P6SYMBOLS=circlefilled TriangleFilled StarFilled DiamondFilled SquareFilled TriangleDownFilled TriangleLeftFilled TriangleRightFilled HomeDownFilled; 

/*SET DEFAULT COLORS*/
%let P6COLORS=CX009CDE CXE4002B CX00B140 CXEEB33B CX64CCC9 CXAA0061 CX888B8D CX004F71 CX470A68 CX7CCC6C; 

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
				entrytitle halign=center " " &P6BYVALS2.;
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

	/*CREATE FOLDER FOR FIGURE 1 OUTPUTS*/
	options dlcreatedir;

	libname fig1 "&outroot\figure1" eoc=no;

	options noxwait xmin;
	/*DELETE EXISTING PNG FILES*/
	X "del ""&outroot\figure1\*.png""";

	data _null_;
	x=sleep(5);
	run;

	/*CREATE CEG PLOTS*/
	ods listing gpath="&outroot\figure1" image_dpi=300;
	ods graphics on / reset=index imagename='FIGUREA' outputfmt=png;

	%cegplot;

	/*GET LIST OF PNG FILES*/

	filename fig1 pipe "dir ""&outroot\figure1\"" /b";

	data fig1list;
		length file $20 id 8;
		infile fig1 length=reclen ;
		input file $varying20. reclen ;
		id=input(compress(upcase(file),"FIGUREA.PNG"),3.);
	run;

	/*SORT IN CREATION ORDER*/
	proc sort data=fig1list;
	by id;
	run;

	data fig1list;
	set fig1list;
	aorder+1;
	call symput('ALAST',aorder);
	run;

	%put &alast;

data _null_;
call symputx('NCEG',ceil(&alast/4)-1);
run;
%put &nceg;

	%macro gslidea;

	%if %sysfunc(cexist(figurea , u)) %then %do;
	proc catalog catalog=figurea kill;
	quit;
	%end;
	%else %do;
	%put catalog figurea does not exist or cannot be opened;
	%end;

	%do i=1 %to &alast;

	data _null_;
	set fig1list;
	if &i=aorder;
	call symputx('FILE1',file);
	run;

	%put &file1;

	title;footnote;
	goptions iback="&outroot\figure1\&file1" imagestyle=fit;
	proc gslide gout=figurea ;
	run;
	quit;

	%end;
	%mend;

	%gslidea;

/******************************************************************************************/
/* END OF CONSENSUS ERROR GRID PLOTS*/
/******************************************************************************************/

/******************************************************************************************/
/* ACCURACY PLOTS*/
/******************************************************************************************/

%macro accplot;

	%macro anno_sg_accuracy(break,low,high,maxx);

	options EXTENDOBSCOUNTER=NO;
	%global breakd lowd highd maxxd; 

	data _null_;
	call symputx('BREAKD',translate("&break",'D','.'));
	call symputx('LOWD',translate("&low",'D','.'));
	call symputx('HIGHD',translate("&high",'D','.'));
	call symputx('MAXXD',translate("&maxx",'D','.'));
	run;

	data sg_acc_&breakd._&lowd._&highd._&maxxd;
	length drawspace $9 function $4 x1 y1 x2 y2 8 linecolor $9 linethickness 8;
	retain drawspace 'datavalue';
	/*CENTRAL LINE*/
	function='line';	x1=0;		y1=0;					x2=&maxx;	y2=0;					linecolor='cx888888';	linethickness=1;output;
	/*UPPER LINE*/
	function='line';	x1=0;		y1=&low;				x2=&break;	y2=&low;				linecolor='cx000000';	linethickness=1;output;
	function='line';	x1=&break;	y1=&low;				x2=&break;	y2=&break*(&high/100);	linecolor='cx000000';	linethickness=1;output;
	function='line';	x1=&break;	y1=&break*(&high/100);	x2=&maxx;	y2=&maxx*(&high/100);	linecolor='cx000000';	linethickness=1;output;
	/*LOWER LINE*/
	function='line';	x1=0;		y1=-&low;				x2=&break;	y2=-&low;				linecolor='cx000000';	linethickness=1;output;
	function='line';	x1=&break;	y1=-&low;				x2=&break;	y2=-&break*(&high/100);	linecolor='cx000000';	linethickness=1;output;
	function='line';	x1=&break;	y1=-&break*(&high/100);	x2=&maxx;	y2=-&maxx*(&high/100);	linecolor='cx000000';	linethickness=1;output;
	run;

	%mend;

	%anno_sg_accuracy(&accbreak,&acclow,&acchigh,500);

data P6IN;
set CEGPLOT;
P6DEFAULTGROUP='1';
where suitable='Yes';
run;

%let P6BYVAR=&prodevt LOT;
%let P6GROUP=CEGPLOTID;
%let P6ATTRPRIORITY=COLOR;
%let P6XVAR=CREF;
%let P6YVAR=DIF_GL_CREF;
%let P6XVARMM=CREFMM;
%let P6YVARMM=DIF_GLMM_CREFMM;
%let P6XMAX=500;
%let P6YMAX=300;

/******************************************************************************************/

ods graphics / antialias=on antialiasmax=100000;

/*SET DEFAULT SYMBOLS*/
%let P6SYMBOLS=circlefilled TriangleFilled StarFilled DiamondFilled SquareFilled TriangleDownFilled TriangleLeftFilled TriangleRightFilled HomeDownFilled; 

/*SET DEFAULT COLORS*/
%let P6COLORS=CX009CDE CXE4002B CX00B140 CXEEB33B CX64CCC9 CXAA0061 CX888B8D CX004F71 CX470A68 CX7CCC6C; 

data _null_;
	call symputx('P6XMAX',500);
	call symputx('P6YMAX',300);
	call symputx('P6INCRX',100);
	call symputx('P6INCRY',50);
	call symputx('P6XMAXMM',25);
	call symputx('P6YMAXMM',16);
    call symputx('P6INCRMMX',5);
	call symputx('P6INCRMMY',2);
	call symput("P6SQLBYVAR",translate(compbl("&P6BYVAR"),',',' '));
	call symput('P6NUMBYVARS',countw("&P6BYVAR"));
	call symputx('P6BYVALS',"#byval("||strip(tranwrd("&P6BYVAR"," ",") #byval("))||")");
run;

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

/******************************************************************************************/

	/*CREATE UNIQUE VALUES FROM BY VARIABLES AND LEGEND VARIABLE*/
proc sort data=P6IN out=_P6CKD1(keep=&P6BYVAR. &P6GROUP.) nodupkey;
by &P6BYVAR. &P6GROUP.;
run;

		/*CALCULATE THE NUMBER OF LEGEND VALUES IN EACH BY VARIABLE SET*/
		/*KEEPING UNIQUE BY VARIABLE VALUES AND THE NUMBER OF LEGEND VALUES*/
proc sql noprint;
create table _P6CKD2 as 
select distinct &P6SQLBYVAR., n(&P6GROUP.) as xxxcount
from _P6CKD1
group by &P6SQLBYVAR.;
quit;

/*CREATE WHERE STATEMENTS FOR BY VARIABLES*/

/*GET THE BY VARIABLES AND TYPE VALUES*/
proc contents data=_P6CKD2 out=_P6CKCONTD2(keep=name type varnum where=(upcase(name) ne 'XXXCOUNT')) noprint;
run;

proc sort data=_P6CKCONTD2;
by varnum;
run;

/*CREATE THE MACRO VARIABLES CONTAINING THE BY VARIABLE NAMES*/
data _null_;
set _P6CKCONTD2;
call symputx("BYVAR"||strip(varnum),name);
run;

/*TRANSPOSE THE BY VARIABLE NAMES*/
proc transpose data=_P6CKCONTD2 out=_P6CKBYVARD2(drop=_name_ _label_) prefix=BYVAR;
var name;
id varnum;
run;

/*TRANSPOSE THE BY VARIABLE TYPES*/
proc transpose data=_P6CKCONTD2 out=_P6CKBYTYPED2(drop=_name_ _label_) prefix=BYTYPE;
var type;
id varnum;
run;

/*MERGE BY VARIABLES AND TYPES WITH UNIQUE VALUES*/
proc sql;
create table _P6CKD3 as
select a.*, b.*, c.*
from _P6CKD2 as a, _P6CKBYVARD2 as b, _P6CKBYTYPED2 as c;
quit;

/*CREATE WHERE STATEMENTS FOR EACH BY VARIABLE*/
%macro doloop;
	data _P6CKD4;
	set _P6CKD3;
	%do i = 1 %to &P6NUMBYVARS.;
		if BYTYPE&i=2 then WHERE&i=strip(BYVAR&i)||'="'||strip(&&BYVAR&i)||'"';
		else WHERE&i=strip(BYVAR&i)||'='||strip(&&BYVAR&i);
	%end;
	run;
%mend;
%doloop;

/*CREATE THE WHERE STATEMENT FOR EACH UNIQUE BY VALUES*/
data _P6CKD5(drop=WHERE: BYTYPE: BYVAR:);
set _P6CKD4;
XWHERE="where "||catx(' and ',of WHERE:);
run;

proc sort data=_P6CKD5;
by &P6BYVAR.;
run;

/*CREATE COUNTER AND GET NUMBER OF UNIQUE VALUES*/
data _P6CKD6;
zz+1;
set _P6CKD5;
call symput('ZZLAST',zz);
run;
%put &zzlast.;

proc sort data=P6IN;
by  &P6BYVAR.;
run;

/* LOOP THE LEGEND VALUE TO NUMBER OF LEGENDS*/

%do i=1 %to &zzlast;

data _null_;
set _P6CKD6;
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

ods path(prepend) work.templat(update);

	ods graphics on / attrpriority=&P6ATTRPRIORITY. noborder;
	proc template;
	    define statgraph sgdesign;
	    dynamic &P6XVAR. &P6YVAR. &P6XVARMM. &P6YVARMM. &P6BYVALS1.	; 
			begingraph / border=false
			designheight=&P6HEIGHT.cm designwidth=15cm datacontrastcolors  =(&P6COLORS.) datasymbols=(&P6SYMBOLS.);
					entrytitle halign=center " " &P6BYVALS2.;
				layout lattice / rowdatarange=data columndatarange=data rowgutter=10 columngutter=10;
					layout overlay /
						xaxisopts=( 
							griddisplay=off 
							labelattrs=(family="Arial" size=11pt weight=normal) 
							linearopts=(viewmin=0.0 viewmax=&P6XMAX. minorticks=ON minortickcount=9
										tickvaluesequence=( start=0.0 end=&P6XMAX. increment=&P6INCRX.))) 
						yaxisopts=( 
							griddisplay=off 
							labelattrs=(family="Arial" size=11pt weight=normal)
							linearopts=(viewmin=-&P6YMAX. viewmax=&P6YMAX. minorticks=ON minortickcount=9 
										tickvaluesequence=( start=-&P6YMAX. end=&P6YMAX. increment=&P6INCRY.)))
						x2axisopts=( 
							griddisplay=off
							labelattrs=(family="Arial" size=11pt weight=normal)
							linearopts=(viewmin=0.0 viewmax=%sysevalf(&P6XMAX. / 18.016) minorticks=ON  minortickcount=4
										tickvaluesequence=( start=0.0 end=&P6XMAXMM. increment=&P6INCRMMX.))) 
						y2axisopts=( 
							griddisplay=off
							labelattrs=(family="Arial" size=11pt weight=normal)
							linearopts=(viewmin=%sysevalf(-&P6YMAX. / 18.016) viewmax=%sysevalf(&P6YMAX. / 18.016) minorticks=ON  minortickcount=4
										tickvaluesequence=( start=-&P6YMAXMM. end=&P6YMAXMM. increment=&P6INCRMMY.)))
										;
							scatterplot x= &P6XVAR. y= &P6YVAR. / group=&P6GROUP. name='scatter' markerattrs=(size=5pt);
							scatterplot x= &P6XVAR. y= &P6YVARMM. / name='scatter2' yaxis=y2 datatransparency=1;
							scatterplot x= &P6XVARMM. y= &P6YVAR. / name='scatter3' xaxis=x2 datatransparency=1;
/*						&P6XREFLINE.;*/
/*						&P6YREFLINE.;*/
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

	    proc sgrender data=P6IN template=sgdesign 
			sganno=sg_acc_&breakd._&lowd._&highd._&maxxd.
		;
	 		by &P6BYVAR.;
			&P6WHERE.;
	    dynamic &P6XVAR.="'&P6XVAR.'n" &P6YVAR.="'&P6YVAR.'n" 
			&P6XVARMM.="'&P6XVARMM.'n" &P6YVARMM.="'&P6YVARMM.'n"
		;
	    run;
		quit;
	%end;

%mend;

	/*CREATE FOLDER FOR FIGURE 1 OUTPUTS*/
	options dlcreatedir;

	libname fig2 "&outroot\figure2" eoc=no;

	options noxwait xmin;
	/*DELETE EXISTING PNG FILES*/
	X "del ""&outroot\figure2\*.png""";

	data _null_;
	x=sleep(5);
	run;


	/*CREATE CEG PLOTS*/
	ods listing gpath="&outroot\figure2" image_dpi=300;
	ods graphics on / reset=index imagename='FIGUREB' outputfmt=png;

	%accplot;

	/*GET LIST OF PNG FILES*/

	filename fig2 pipe "dir ""&outroot\figure2\"" /b";

	data fig2list;
		length file $20 id 8;
		infile fig2 length=reclen ;
		input file $varying20. reclen ;
		id=input(compress(upcase(file),"FIGUREB.PNG"),3.);
	run;

	/*SORT IN CREATION ORDER*/

	proc sort data=fig2list;
	by id;
	run;

	data fig2list;
	set fig2list;
	border+1;
	call symput('BLAST',border);
	run;

	%put &blast;

data _null_;
call symputx('NACC',ceil(&blast/4)-1);
run;
%put &nacc;

	%macro gslideb;

	%if %sysfunc(cexist(figureb , u)) %then %do;
	proc catalog catalog=figureb kill;
	quit;
	%end;
	%else %do;
	%put catalog figureb does not exist or cannot be opened;
	%end;

	%do i=1 %to &blast;

	data _null_;
	set fig2list;
	if &i=border;
	call symputx('FILE2',file);
	run;

	%put &file2;

	title;footnote;
	goptions iback="&outroot\figure2\&file2" imagestyle=fit;
	proc gslide gout=figureb;
	run;
	quit;

	%end;
	%mend;

	%gslideb;


/******************************************************************************************/
/* END OF ACCURACY PLOTS*/
/******************************************************************************************/

/******************************************************************************************/
/* HISTOGRAMS FOR US */
/******************************************************************************************/

%macro US;

%if "&ACTYPE"="A18023-001" %then %do;

title;footnote;
%macro histo(P6XVAR,P6BINWIDTH, P6BYVAR,P6HCOLOR);

data _P6GRAPH1;
	set P6IN;
	run;

	%let P6XVAR=percent;
	%let P6BINWIDTH=2;

	data _null_;
	call symputx('P6BYVALS',"#byval("||strip(tranwrd("&P6BYVAR"," ",") #byval("))||")");
	run;

/*DETERMINE RANGE OF MIDPOINTS BASED ON BIN WIDTH OPTION*/
	proc sql;
	create table _P6RANGEX as
	select min(&P6XVAR.) as min, max(&P6XVAR.) as max
	from  _P6GRAPH1
	quit;

	data _P6RANGEX;
	set _P6RANGEX;
	minr=round(min,&P6BINWIDTH.);
	maxr=round(max,&P6BINWIDTH.);
	if maxr<max then newmax=maxr+(&P6BINWIDTH.);
	else newmax=maxr+&P6BINWIDTH.;
	if minr>min then newmin=minr-(&P6BINWIDTH.);
	else newmin=minr-&P6BINWIDTH.;
	run;

	data _null_;
	set _P6RANGEX;
/*	call symputx('P6XMIN',min(newmin,&P6XMIN.));*/
/*	call symputx('P6XMAX',max(newmax,&P6XMAX.));*/
	call symputx('P6XMIN',newmin);
	call symputx('P6XMAX',98);
	run;

%put ******************************************************;
%put P6XMIN = &P6XMIN., P6XMAX = &P6XMAX.;
%put ******************************************************;

/*DETERMINE MAXIMUM PERCENT VALUE FOR XAXIS*/
	data _P6RANGEY1;
	set _P6GRAPH1;
	P6XVAR=round(&P6XVAR.,&P6BINWIDTH.);
	run;
	
/*SORT IF BY VARIABLES HAVE BEEN SUPPLIED*/
	proc sort data=_P6RANGEY1;
	by &P6BYVAR.; 
	run;

/*CALCULATE PERCENTAGES*/
	proc freq noprint;
	table P6XVAR / out=_P6RANGEY2;
	by &P6BYVAR.; 
	run;

/*CALCULATE MAXIMUM PERCENTAGE VALUE FOR RESPONSE AXIS RANGE*/
	proc sql;
	create table _P6RANGEY3
	as select Max(percent) as P6MAXP
	from _P6RANGEY2;
	quit;

	data _P6RANGEY3;
	set _P6RANGEY3;
	if P6MAXP le 10 then do;
		if P6MAXP gt round(P6MAXP,2) then call symputx('P6MAXP',round(P6MAXP,2)+2);
		else call symputx('P6MAXP',round(P6MAXP,2));
		call symputx('P6INCP',2);
	end;
	else if 10 lt P6MAXP le 40 then do;
		if P6MAXP gt round(P6MAXP,5) then call symputx('P6MAXP',round(P6MAXP,5)+5);
		else call symputx('P6MAXP',round(P6MAXP,5));
		call symputx('P6INCP',5);
	end;
	else if P6MAXP gt 40 then do;
		if P6MAXP gt round(P6MAXP,10) then call symputx('P6MAXP',round(P6MAXP,10)+10);
		else call symputx('P6MAXP',round(P6MAXP,10));
		call symputx('P6INCP',10);
	end;
	run;

	proc sort data=_P6GRAPH1;
		by &P6BYVAR.; 
	run;

options pagesize=max linesize=max nobyline;
ods graphics on / width=15cm height=15cm;

proc sgplot data=_P6GRAPH1;
/*histogram &P6XVAR. /SCALE=PERCENT BINSTART=&P6XMIN. BINWIDTH=&P6BINWIDTH. FILLATTRS=(COLOR=&P6HCOLOR.);*/
histogram &P6XVAR. /SCALE=PERCENT BINSTART=0 BINWIDTH=2 FILLATTRS=(COLOR=&P6HCOLOR.);
title1 "&P6BYVALS.";
by &P6BYVAR; 
/*xaxis values=(&P6XMIN. to &P6XMAX. by &P6BINWIDTH.) minor thresholdmin=1 thresholdmax=1 labelattrs=(family="Arial" size=11pt weight=normal);*/
xaxis values=(0 to 100 by 2) minor thresholdmin=1 thresholdmax=1 labelattrs=(family="Arial" size=11pt weight=normal);
yaxis values=(0 to &P6MAXP. by &P6INCP.) label="Percent" minor thresholdmin=1 thresholdmax=1 labelattrs=(family="Arial" size=11pt weight=normal);
run;
quit;
options pagesize=max linesize=max;

%mend;

	/*CREATE FOLDER FOR FIGURE 3 OUTPUTS*/
	options dlcreatedir;

	libname fig3 "&outroot\figure3" eoc=no;

	options noxwait xmin;
	/*DELETE EXISTING PNG FILES*/
	X "del ""&outroot\figure3\*.png""";

	data _null_;
	x=sleep(5);
	run;

	/*CREATE HISTOGRAMSS*/
	ods listing gpath="&outroot\figure3" image_dpi=300;
	ods graphics on / reset=index imagename='FIGUREC' outputfmt=png;

	data P6IN;
	set xsensor_accr;
	where first(event) in (&acgluc) and total ge 28 and suitable='Yes';
	label percent ='% Within 20mg/dL/20%';
	run;

	%histo(percent,2,&prodevt LOT,CornFlowerBlue);

	/*GET LIST OF PNG FILES*/

	filename fig3 pipe "dir ""&outroot\figure3\"" /b";

	data fig3list;
		length file $20 id 8;
		infile fig3 length=reclen ;
		input file $varying20. reclen ;
		id=input(compress(upcase(file),"FIGUREC.PNG"),3.);
	run;

	/*SORT IN CREATION ORDER*/

	proc sort data=fig3list;
	by id;
	run;

	data fig3list;
	set fig3list;
	corder+1;
	call symput('CLAST',corder);
	run;

	%put &clast;

data _null_;
call symputx('NHIST',ceil(&clast/4)-1);
run;
%put &nhist;

	%macro gslidec;

	%if %sysfunc(cexist(figurec , u)) %then %do;
	proc catalog catalog=figurec kill;
	quit;
	%end;
	%else %do;
	%put catalog figurec does not exist or cannot be opened;
	%end;

	%do i=1 %to &clast;

	data _null_;
	set fig3list;
	if &i=corder;
	call symputx('FILE3',file);
	run;

	%put &file3;

	title;footnote;
	goptions iback="&outroot\figure3\&file3" imagestyle=fit;
	proc gslide gout=figurec;
	run;
	quit;

	%end;
	%mend;

	%gslidec;

%end;

%mend;
%US;

/******************************************************************************************/
/* END OF HISTOGRAMS*/
/******************************************************************************************/

%macro params;
/*CREATE LISTING OF PARAMETER VALUES USED*/
data study_params0;
length id 8 Parameter $50 Value $200;
id=1;parameter="Protocol Number";value="&protocol";output;
id=2;parameter="Event Number";value="&eventid";output;
id=3;parameter="Analysis";value="&analysis";output;
id=4;parameter="By Product or Event?";value="&prodevt"; output;
id=5;parameter="Strip Lot Number";value="&striplot";output;
id=6;parameter="Strip Adjustment Value";value="&BGADJ";output;
id=7;parameter="Product assigned to Historic Data";value="&prodhist";output;
id=8;parameter="Product assigned to Real Time Data";value="&prodreal";output;
%if "&actype"="A18023" %then %do;
id=9;parameter="Acceptance Criterion Value";value="&actype: &ac";output;
%end;
%else %if "&actype"="A18023-001" %then %do;
id=9;parameter="Acceptance Criteria Values";value="&actype: &acus1, &acus2";output;
%end;
id=10;parameter="Number of Days";value="&days";output;
id=11;parameter="EDC Data location";value="&edc";output;
id=12;parameter="Stacked Data Location";value="&smloc";output;
id=13;parameter="Cleaned BG Data Location";value="&cbgmloc";output;
id=14;parameter="Sensor List Data Location";value="&senloc";output;
id=15;parameter="Output Location";value="&outroot";output;
id=16;parameter="DI, AE and PD Report Listings Location";value="&reports";output;
id=17;parameter="Input Glucose Data File";value="&glucose";output;
id=18;parameter="Clean BG Data File";value="&cbgm";output;
id=19;parameter="BG Exclusions Data File";value="&cbgmdel";output;
id=20;parameter="Accuracy Plot Annotation Values";value="Breakpoint = &accbreak mg/dL; High = &acchigh %; Low = &acclow mg/dL";output;
id=21;parameter="Historic data paired within";value="&XHWIN minutes";output;
run;

data study_params;
set study_params0;
if upcase("&prodevt")="EVENT" then do;
if id in (7,8) then delete;
end;
format value $200.;
run;
%mend;
%params;

/*CREATE LOCATION LINKS FORMAT*/
data paramlinks(keep=fmtname type start end label);
set study_params;
retain fmtname 'LOCATION' type 'c' ;
start=value;
end=value;
label=value;
if substr(upcase(value),1,3)="H:\";
run;

proc sort data=paramlinks nodupkey;
by _all_;
run;

proc format cntlin=paramlinks;
run;

/*FPI AND LPO*/
proc sql noprint;
create table fpilpo as
select 'FPI:' as FPITXT,  min(a.svscrdat) as FPI format=date9., 'LPO:' as LPOTXT, max(b.dsdat) as LPO format=date9.
from edc.ie as a, edc.ds as b;
quit;

%macro wear;

data _null_;
call symput('edcstatus',upcase("&edcloc"));
run;

/*OPERATIONAL HOURS AND SENSOR ACCOUNTABILITY*/

data wd00(rename=(SASENSN=SENSOR_SN SALOT=SENSORLOTID));
length STUDY $4 SITE $20 SUBJECTID $10 SUBJECT 8;
set edc.sa(keep=subject sa: drop=SAREDSN);
SITE_ID=substr(strip(subject),5,3);
study="&eventid";
if SITE_ID="043" then SITE="Manchester";
else if SITE_ID="044" then SITE="Bath";
else if SITE_ID="046" then SITE="Ipswich";
else if SITE_ID="060" then SITE="Oxford";
else if SITE_ID="061" then SITE="Southampton";
else if SITE_ID="120" then SITE="Truro";
else if SITE_ID="126" then SITE="Leeds";
else if SITE_ID="134" then SITE="Manchester (MAC)";
else if SITE_ID="165" then SITE="East Surrey";
else if SITE_ID="166" then SITE="Guildford";
else if SITE_ID="170" then SITE="Frimley";
else if SITE_ID="191" then SITE="Blackpool";
else if SITE_ID="192" then SITE="Stockton-on-Tees";
SubjectID=strip(subject);
label STUDY='Study Event' SITE_ID='Site ID' SITE='Site' SUBJECTID='Subject' SUBJECT='Subject';
run;

/*REMOVE DUPLICATE SENSOR_SN ENTRIES IN SA CRF BASED ON APPLICATION DATE, REMOVAL DATE AND SUCCESSFUL ACTIVATION*/
proc sort data=wd00;
by subjectid sensor_sn saapdat sarmdat saavyn;
run;

data wd0;
set wd00;
by subjectid sensor_sn saapdat sarmdat saavyn;
if last.sensor_sn;
run;

%if &edcstatus=FINAL %then %do;

proc sql;
create table wdlots as select distinct sensorlotid, suitable
from subeventlots
order by sensorlotid;
quit;

/*ADD LOT SUITABILITY TO SA CRF DATA*/
proc sql;
create table wd as
select a.*, SUITABLE
from wd0 as a, wdlots as b
where a.sensorlotid=b.sensorlotid
order by subject, subjectid, sensor_sn, sensorlotid;
quit;

proc sort data = senloc.sensorlots 
out=sensorlots(keep=sensor_sn lot) nodupkey ;
by sensor_sn;
run;

proc sort data = wd;
by sensor_sn;
run;

/*ADD SENSOR LOT NUMBERS TO SA CRF DATA*/
data wd2;
merge wd(in=a) sensorlots;
by sensor_sn;
if a;
run;

/*ADD OPERATIONAL HOURS TO SENSOR DATA*/
data time_op;
set sm.&glucose(keep=subjectid reader_id sensor_sn sensor_start dtm sensor_start event);
TIME_OPERATIONAL = dtm - sensor_start;
run;

proc sort data = time_op;
by  sensor_start decending time_operational;
run;

data time_op_ ;
 set time_op;
 by sensor_start;
 if first.sensor_start;
 OP_HRS = time_operational/3600;
 format time_operational time10.;
run;

proc sort data = time_op_
out = time_op_ (keep= subjectid reader_id sensor_sn time_operational op_hrs);
by subjectid sensor_sn;
run;

proc sort data=wd2;
by subjectid sensor_sn;
run;

data out.wear_duration_&eventid. ;
length SENSOR_DATA $3.;
merge wd2 (in=sa) time_op_(in=auu);
by subjectid sensor_sn;

if time_operational=. then time_operational=0;
if op_hrs=. then op_hrs=0;

/*APPLY CENSOR VALUES*/
if SAPRREA = 'Other' then CENSOR = 0; /* ’Other’ used for non device failures regardless of whether application successful or not*/

/*SENSOR DATA AVAILABLE*/
else if auu then do;
	if SAPRYN='No' then CENSOR=0; /* sensor not prematurely removed */
	else CENSOR=1;/* all other cases treated as failures */
end;

/*SENSOR DATA NOT AVAILABLE*/
else do;
	if SAAPYN='' and SAPRREA='' then CENSOR=0; /* Sensor application not answered and no reason given for premature removal */
	else CENSOR=1;/* all other cases treated as failures */
end;

if auu then SENSOR_DATA='Yes';
else SENSOR_DATA='No';

label censor='Censor' time_operational='Operational Time' op_hrs='Operational Hours' SENSOR_DATA='Sensor Data Available?';
run;

/*ADD COMPARISON VALUE FOR OPERATIONAL HOURS*/
data wdx;
set out.wear_duration_&eventid.;
WDvalue=(&days*24)-12;
call symput('TIMELIM',WDvalue);
where suitable='Yes';
run;

ods exclude all;
proc lifetest data=wdx method=KM timelim=&timelim timelist=0 to &timelim by 12;
time op_hrs*censor(0);
where SENSOR_DATA='Yes' or SAAPYN='Yes';
label op_hrs='Seconds Operational';
ods output productlimitestimates=bucket_estimates;
run;
ods exclude none;

data bucket_estimates;
set bucket_estimates;
SurvivalPC=survival*100;
format timelist 6. survivalpc 6.1;
label timelist='Operational Hours' SurvivalPC='Survival Probability Estimate (%)';
run;

proc sql noprint;
select survival into : SURVIVAL
from bucket_estimates
having max(timelist)=timelist;
quit;

%put &survival;

data _null_;
call symputx('SURVIVAL',put(round(&survival*100,0.1),4.1));
run;
%put &survival;

/*TOTAL NUMBER OF SENSORS AND NUMBERS MEETING TARGET OPERATIONAL HOURS*/
proc sql noprint;
select n(sensorlotid) into : TOTSENSORS
	from wdx;
select n(sensorlotid) into : N_WEAR
	from wdx
	where op_hrs ge WDvalue;
select n(sensorlotid) into : N_SUCCESSFUL_APP
	from wdx
	where SENSOR_DATA='Yes' or SAAPYN='Yes';
quit;

/*NUMBER OF SENSOR INCLUDED IN ACCURACY ANALYSIS*/
proc sql noprint;
select n (sensor_sn) into : N_SENSOR 
from (select distinct subjectid, sensor_sn, suitable
from amdata2
where suitable='Yes');
quit;

data _null_;
call symputx('N_SENSOR',"&n_sensor");
call symputx('TOTSENSORS',"&totsensors");
call symputx('N_WEAR',"&n_wear");
call symputx('N_SUCCESSFUL_APP',"&n_successful_app");
run;

data accountability;
acc="From the &totsensors sensors where an insertion was attempted, &n_successful_app sensors were successfully applied and &n_sensor sensors were included in the accuracy analysis.";
output;
run;

data wear;
wear="From the &totsensors sensors where an insertion was attempted, &n_wear sensors lasted &days Days.";
output;
run;

%end;

%mend;
%wear;

/*MACRO FOR IMPORTING LIST OF MEMOS*/
%macro memos;

/********************************************************************************************/
/*THIS SECTION OF CODE SEARCHES MEMOS FOLDER FOR ADDITIONAL DOCUMENTS TO INCLUDE BY LINKS*/
/********************************************************************************************/

/*CLINICAL AFFAIRS LOCATION OF FILES TO IMPORT*/
/*CHECK LOCATION IS CORRECT*/

/*CHECK THAT FILE PATH EXISTS*/
   options noxwait; 
   %local rc fileref ; 
   %let rc = %sysfunc(filename(fileref,&memos)) ; 

/*IF FILE PATH EXIST FOLLOWING CODE RUNS TO CREATE A DATASET REPDIRS CONTAINING FILEPATHS AND FILENAMES*/
   %if %sysfunc(fexist(&fileref))  %then %do;

/*GET EXISTING REPORT DIRECTORIES AND SUBDIRECTORIES;*/
	filename _root_ pipe "dir /-c /q /t:w ""&memos""";

%let num_memos=0;

/*	CREATES DATASET WITH FULL FILENAMES FROM ROOT DIRECTORY AND SUBDIRECTORIES*/
	data memdirs;
	length path filename $255 line $1024 owner $17 temp $16 date time 8;
	retain path ;
	infile _root_ length=reclen ;
	input line $varying1024. reclen ;
	if reclen = 0 then delete ;
	if scan( line, 1, ' ' ) = 'Volume'  | /* BEGINNING OF LISTING */
       scan( line, 1, ' ' ) = 'Total'   | /* ANTEPENULTIMATE LINE */
       scan( line, 2, ' ' ) = 'File(s)' | /* PENULTIMATE LINE     */
       scan( line, 2, ' ' ) = 'Dir(s)'    /* ULTIMATE LINE        */
	then delete ;

	dir_rec = upcase( scan( line, 1, ' ' )) = 'DIRECTORY' ;

	if dir_rec then
       path = left( substr( line, length( "Directory of" ) + 2 )) ;
 	else do ;
       date = input(scan( line, 1, ' ' ),ddmmyy10.);
       time = input(scan( line, 2, ' ' ),hhmmss.);
       temp = scan( line, 3, ' ' ) ;
       if temp = '<DIR>' then size = 0 ;
	   else size = input(compress(temp,'()'), best. ) ;
       owner = scan( line, 4, ' ' ) ;
/*     SCAN DELIMITERS CAUSE FILENAME PARSING TO REQUIRE SPECIAL TREATMENT */
       filename=substr(line,60,length(line)-59);
	   if filename in ( '.' '..' ) then delete ;
       ndx = index( line, scan( filename, 1 )) ;
  	end;
	drop dir_rec line ndx temp ;
	if scan(lowcase(line),-1,'.')='pdf';
format date date9. time hhmm.;
filepath=strip(path)||'\'||strip(filename);
x+1;
call symput('NUM_MEMOS',x);
run;

/* LINKS */
	data memolinks(keep=fmtname type start end label);
	set memdirs;
	retain fmtname 'MEMO' type 'c' ;
	start=filepath;
	end=filepath;
	label=filepath;
	run;

	proc format cntlin=memolinks;
	run;

	%end;
%else %do;
/*FOLLOWING CODE RUNS IF FILE PATH DOES NOT EXIST - CREATES AN EMPTY DATA SET REPDIRS*/
%put NOTE: The directory "&memos" does not exist ; 
/*	CREATES EMPTY DATASET IF DIRECTORY DOES NOT EXIST*/
	data memmdirs;
	length path filename $255 line $1024 owner $17 temp $16 date time 8;
	delete;
	run;
%end;
%mend;

%memos;

%macro nonmatch;

data _NULL_;
 if 0 then set out.notlisted nobs=n;
 call symputx('totobs',n);
 stop;
run;

%if %eval(&totobs) > 0 %then %do;

/*OBTAINS CURRENT DATA AND TIME IN DDMMMYYY:HH:MM:SS FORMAT*/
%let startdt=%sysfunc(putn(%sysfunc(datetime()),datetime20.));

/*REPLACES : WITH _ FOR FILE SUFFIX*/
data _null_;
currentdatetime="&startdt";
suffix=translate(currentdatetime,"_",":");
call symput('fdtm',trim(left(suffix)));
run;

goptions device=png300 targetdevice=png300
xmax=7.5in xpixels=2250 hsize=7.5in
ymax=7.5in ypixels=2250 vsize=5in
aspect=1 hpos=90 vpos=40
ftext='Arial' htext=10pt;

ods rtf file="&outroot\Check Non-matched sensors &protocol-&eventid &fdtm..rtf" style=daisy startpage=no;

proc sort data=wd0;
by subjectid sensor_sn;
run;

proc sort data=out.notlisted out=notlisted(keep=subjectid reader_id sensor_sn);
by subjectid sensor_sn;
run;

data notlisted2;
merge wd0 notlisted(in=kp) ;
by subjectid sensor_sn;
if kp;
run;
 
proc tabulate data=notlisted2 missing;
class subjectid sensor_sn saseq sensorlotid;
classlev subjectid sensor_sn saseq sensorlotid / style=[background=cxffffff];
table subjectid*sensor_sn*saseq*sensorlotid,n;
run;

ods rtf close;

%end;

%mend;
%nonmatch;
