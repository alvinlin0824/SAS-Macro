dm 'log' clear; /* CLEARS LOG WINDOW */
dm pgm 'winclose'; /* CLOSES PROGRAM EDITOR WINDOW*/
/*******************************************************************
Program Name:				2404 OUS Libre current PUMA parameters.sas
SAS Version:				9.4 TS Level 1M6
Programmer:					w amor
Purpose:					Using PUMA macros to reproduce the results for study ADC-UK-PMS-14020/14021 Events
Program History:
Date	Programmer	Type	Change made
_______	__________	_______	____________________________
30may24	w amor		new		
*******************************************************************/

/*DELETE ALL MACRO VALUES AND WORK DIRECTORY DATASETS*/
%macro deleteAllMacroVars();
%local macro_vars_to_delete;
	proc sql noprint;
		select name into :macro_vars_to_delete separated by " " from dictionary.macros
		where scope="GLOBAL" and not substr(name,1,3) =  "SYS" and not name = "GRAPHTERM";
	quit;
	%symdel &macro_vars_to_delete.;

	proc sql noprint;
	select count(memname) into : dscount from dictionary.members
	where libname='WORK' and memtype='DATA';
	quit;

	%if %eval(&dscount) > 0 %then %do;
		proc datasets lib=work kill memtype=data;run;quit;
	%end;
%mend deleteAllMacroVars;
%deleteAllMacroVars();

%global protocol eventid ACTYPE edms outputfile analysis accbreak acclow acchigh prodevt striplot prodhist prodreal ACGLUC ac acus1 acus2
days edcloc edcstatus root1 root2 root3 root4 memos outroot reptitle SMLOC CBGMLOC SENLOC edc edc2 notsuitable author Stats_approver QA_approver;

%let eventid=2404;
%let edcloc=Current;
%let edms=DOC51058 Revision A;
%let striplot=4500187036;
%let year=24;

/*DOCUMENT REVISION HISTORY*/
data docrev;
length revision  $3 Description $500;
revision='A';Description='Introduction of new document. Pre-lock report.';output;
/*revision='B';Description='Post-lock report. Electronic Data Capture related results added.';output;*/
run;

%let notsuitable=;

libname suit "\\oneabbott.com\EMEA\UK\Witney\ADC\data\Study_Data\Apollo\UK_PM\14020\&year.\&eventid.\Analysis\Data Review\Product Suitability" access=readonly;

proc sql;
select lot into :notsuitable
from suit.product_suitability
where study="&eventid" and lowcase(fsl12_suitable)='no';
quit;

%let protocol=14020;
%let author=Walter Amor;
%let Stats_approver=Andrew Lawrence;
%let QA_approver=Darren Shipley;

%let ACTYPE=A18023;
%let analysis=OUS Libre;

data _null_;
if upcase("&edcloc")="FINAL" then call symputx('edcstatus','Post-lock');
else if upcase("&edcloc")="CURRENT" then call symputx('edcstatus','Pre-lock');
call symputx('docnum',tranwrd("&edms",' Revision ','_rev-'));
run;

%let outputfile=&docnum &analysis - ADC-UK-PMS-&protocol-&eventid &ACTYPE &edcstatus Results;
%let reptitle=&analysis - ADC-UK-PMS-&protocol Study Event &eventid;

%let accbreak=100;
%let acclow=20;
%let acchigh=20;

%let prodevt=EVENT;

%let prodhist=FreeStyle Libre-Pro;
%let prodreal=FreeStyle Libre;
%let ACGLUC="R";
%let ac=73;
%let acus1=79;
%let acus2=20.2;

%let days=14;

/*PUMS-SM and PUMA-CBGM run by DM*/
/*LOCATION OF STACKED DATA*/
%let SMLOC=H:\Data\Study_RawData\Apollo\UK_PM\&protocol.\&year.\&eventid.\AUUdata\PUMAout;
/*LOCATION OF CBGM DATA*/
%let CBGMLOC=H:\Data\Study_RawData\Apollo\UK_PM\&protocol.\&year.\&eventid.\AUUdata\PUMAout;
/*LOCATION OF SENSOR LIST*/
%let SENLOC=H:\Data\Study_RawData\Apollo\UK_PM\&protocol.\&year.\&eventid.\LotReports;

/*LOCATION OF CRF DATA*/
%let edc=H:\Data\Study_RawData\Apollo\UK_PM\&protocol.\&year.\&eventid.\OpenClinica_Extracts\&edcloc;
%let edc2=H:\Data\Study_RawData\Apollo\UK_PM\&protocol.\&year.\&eventid.\OpenClinica_Extracts\&edcloc\metadata;

/*LOCATION OF AE DI AND PD LISTINGS*/
%let reports=H:\Data\Study_Data\Apollo\UK_PM\&protocol.\&year.\&eventid.\reports;

/*LIBNAME FOR STACKED DATASETS*/
libname sm "&SMLOC" eoc=no access=readonly;
/*LIBNAMR FOR CBGM DATA*/
libname cbgm "&CBGMLOC" eoc=no access=readonly;
/*LIBNAME FOR SENSOR LIST*/
libname senloc "&SENLOC" eoc=no access=readonly;
/*LIBNAME FOR EDC DATA*/
libname edc "&edc" eoc=no access=readonly;
/*LIBNAME EDC METADATA*/
libname edc2 "&edc2" eoc=no access=readonly;

/*LOCATION FOR OUTPUT FILES*/
%let root1=H:\Data\Study_Data\Apollo\UK_PM\&protocol.\&year.\&eventid.;
%let root2=&root1.\Analysis;
%let root3=&root1.\Analysis\PUMA;
%let root4=&root1.\Analysis\MEMOS;
%let memos=&root1.\Analysis\MEMOS\&analysis;
%let outroot=&root1.\Analysis\PUMA\&analysis;

options DLCREATEDIR;
/*LIBNAMES CREATE OUTPUT FOLDERS IF NOT ALREADY EXISTING*/
libname out "&root1" eoc=no;
libname out "&root2" eoc=no;
libname out "&root3" eoc=no;
libname out "&root4" eoc=no;
/*LIBNAME FOR OUPUT LOCATION*/
libname out "&outroot" eoc=no;
libname memos "&memos" eoc=no;

options papersize=a4 orientation=portrait pagesize=max linesize=max nocenter;
/*LOCATION FOR ANALYSIS DATASETS*/
libname ad "\\oneabbott.com\EMEA\UK\Witney\ADC\Data\Study_Data\Apollo\UK_PM\Analysis Datasets\Unverified" eoc=no;
libname ad "&outroot\pre-lock datasets" eoc=no;

options NODLCREATEDIR;

/*TEXT FOR BACKGROUND SECTION*/
data background;
length text $500;
text="The purpose of this report is to summarize data collected under protocol ADC-UK-PMS-14020 (Performance Check of the Abbott FreeStyle Flash Glucose Monitoring System).";output;
text="The data has been analysed in accordance with A18025 (Guidance for Statistical Analysis of FreeStyle Libre and Libre Pro PMS Clinical Studies) and A18023
 (Clinical Performance Monitoring of FreeStyle Libre and FreeStyle Libre Pro).";output;
run;

%put &notsuitable;
