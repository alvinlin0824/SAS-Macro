options source;
dm 'log' clear; /* CLEARS LOG WINDOW */
dm pgm 'winclose'; /* CLOSES PROGRAM EDITOR WINDOW*/
/*******************************************************************
Program Name:				PUMA 2 report output v17.sas
SAS Version:				9.4 TS Level 1M6
Programmer:					w amor
Purpose:					creates output of Libre PM / Masked Study Results	
Program History:
Date	Programmer	Version	Change made
_______	__________	_______	____________________________
24jun21	w amor		1
22oct21	w amor		2		edms and outputfile %let statements move to PUMA 1 parameters code
							full parameters table moved to the end of the output file
02feb22	w amor		3		add title and analysis to output metadata
29mar22	w amor		4		only include accountability and operational hours for locked EDC data
04may22	w amor		5		pagebreak adjustment between biases and biases by level table
25may22	w amor		6		change values used for ACTYPE
25aug22	w amor		7		only include suitable lots
26aug22	w amor		8		correction to paired points table to use npaired macro value introduced in PUMA 1 prep report data v8.sas
16nov22	w amor		9		only include demographics for locked EDC data
05jan23	w amor		10		remove redundant report code
26jan23	w amor		11		create signature box datasets and add tables for background, signatures and revision history
							add consensus error grid zone to high and low listing
							only include links to AE, DI and PD listings for locked EDC data
01mar23	w amor		12		add names to signature boxes
22mar23 w amor		13		adjustment to footer
02jun23	w amor		14		add powerpoint summary with plots, rename and move vbscript to c:\temp for creating pdf copy
02aug23 w amor				correction to Program Name in header
22aug23	w amor		15		add breakpoint to system accuracy tables
25aug23	w amor		16		add breakpoint to system accuracy table titles
06sep23 w amor				correction to Program Name in header
01mar23	w amor		17		remove rows form approvals signature box if name not provided
*******************************************************************/

ods listing close;

/* RUN CODE AFTER PUMA 1 IN THE SAME SAS SESSION*/ 

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

options papersize=a4 orientation=portrait pagesize=max linesize=max center dlcreatedir nodate nonumber;
goptions device=png300 targetdevice=png300;

%global tab fig apx sow;

/*AUTHOR SIGNATURE BOX*/
data autsigbox;
length Department Name Signature Date $20;
Department='R&D';Name="&author.";Signature='';Date='';output;
run;

/*APROVAL SIGNATURE BOXES*/
data appsigbox;
length Department Name Signature Date $20;
Department='R&D';Name="&Stats_approver.";Signature='';Date='';output;
Department='Quality Assurance';Name="&QA_approver.";Signature='';Date='';output;
run;

data appsigbox;
set appsigbox;
if name='' then delete;
run;

ods rtf file="&outroot\&outputfile &fdtm..rtf" title="&reptitle - &analysis" image_dpi=400 style=daisy startpage=no /*contents=yes notoc_data*/;

title1 h=10pt j=l "Abbott Diabetes Care (ADC)" j=c " &edms " j=r "Page ^{pageof}";
title2 h=10pt j=c "^{newline}&reptitle";

footnote1 h=8pt j=l "&outputfile &fdtm - Analysis performed by &sysuserid";

/*ods rtf text= "^S={outputwidth=100% just=l}{\field{\*\fldinst {\\TOC \\f \\h} } }";*/

proc report data=fpilpo split='~' spanrows  missing
	style(report)=[bordercolor=cx000000 /*outputwidth=19cm*/]
	style(column)=[vjust=c just=c protectspecialchars=on just=l]
	style(header)=[font_weight=bold vjust=c just=l];
column fpitxt fpi lpotxt lpo;
define fpitxt / display '' style(column)=[cellwidth=1.5cm background=cxd8d8d8 font_weight=bold];
define fpi / display '' style(column)=[cellwidth=8cm];
define lpotxt / display '' style(column)=[cellwidth=1.5cm background=cxd8d8d8 font_weight=bold];
define lpo / display '' style(column)=[cellwidth=8cm];
run;

proc report data=study_params split='~' spanrows  missing
	style(report)=[bordercolor=cx000000 outputwidth=19cm]
	style(column)=[vjust=c just=c protectspecialchars=on just=l]
	style(header)=[font_weight=bold vjust=c just=l];
column parameter value;
define parameter / display '' style=[cellwidth=6cm];
define value / display '' style(column)=[url=$location.];
where parameter='Analysis' or parameter=:'Strip' ;
run;


proc report data=background style(report)=[outputwidth=19cm frame=void rules=none bordercolor=cxffffff];
column ("^S={just=l background=cxffffff font_weight=bold}Background:" text);
define text / display '';
run;

proc report data=memdirs style(report)=[outputwidth=19cm frame=void rules=none bordercolor=cxffffff];
column ("^S={just=l background=cxffffff}For additional information please refer to the following:" filepath);
define filepath / display '' style(column)=[url=$memo.];
run;

proc report data=autsigbox split='~' spanrows  missing
	style(report)={bordercolor=cx000000 outputwidth=19cm}
	style(column)={vjust=c just=c protectspecialchars=off cellwidth=4cm cellheight=1.25cm}
	style(header)={font_weight=bold vjust=c just=l background=cxffffff};
column ('Document Author' department name signature date);
define department / display 'Department' style(header)={just=c background=cxd8d8d8};
define name / display 'Print Name' style(header)={just=c background=cxd8d8d8};
define signature / display 'Signature' style(header)={just=c background=cxd8d8d8};
define date / display 'Date' style(header)={just=c background=cxd8d8d8};
run;

proc report data=appsigbox split='~' spanrows  missing
	style(report)={bordercolor=cx000000 outputwidth=19cm}
	style(column)={vjust=c just=c protectspecialchars=off cellwidth=4cm cellheight=1.25cm}
	style(header)={font_weight=bold vjust=c just=l background=cxffffff};
column ('Document Approvals' department name signature date);
define department / display 'Department' style(header)={just=c background=cxd8d8d8};
define name / display 'Print Name' style(header)={just=c background=cxd8d8d8};
define signature / display 'Signature' style(header)={just=c background=cxd8d8d8};
define date / display 'Date' style(header)={just=c background=cxd8d8d8};
run;

proc report data=docrev split='~' spanrows  missing
	style(report)={bordercolor=cx000000 outputwidth=19cm}
	style(column)={vjust=c just=c protectspecialchars=off}
	style(header)={font_weight=bold vjust=c just=l background=cxffffff};
column ('Document Revision History' revision description);
define revision / display 'Revision' style(column)=[cellwidth=2cm] style(header)={just=c background=cxd8d8d8};
define description / display 'Description of Change' style(column)=[cellwidth=17cm just=l] style(header)={just=c background=cxd8d8d8};
run;

%macro demorep;

%let tab=0;
%let fig=0;
%let apx=0;

******************************************************************************************;
/*TABLE A: CONCLUSION GRID ZONE A TABLE*/
******************************************************************************************;

data _null_;
call symputx('tab',&tab+1);
run;

options orientation=portrait;
ods rtf startpage=now;

/*OUS*/%if "&actype"="A18023" %then %do;

	proc report data=AC_TABLE split='~' spanrows  missing
		style(report)=[bordercolor=cx000000]
		style(column)=[vjust=c just=c protectspecialchars=off cellwidth=4cm]
		style(header)=[font_weight=bold vjust=c];
	column ("^S={just=l background=cxffffff}Table &tab: Acceptance Criteria" &prodevt lot result ac);
	define &prodevt / group;
	define lot / group;
	define result / group;
	define ac / group style=[bordercolor=cxffffff];
	where first(event) in (&acgluc) and suitable='Yes';
	run;

/*OUS*/%end;
/*US*/%else %if "&actype"="A18023-001" %then %do;

	proc report data=AC_TABLE_US split='~' spanrows  missing
		style(report)=[bordercolor=cx000000]
		style(column)=[vjust=c just=c protectspecialchars=off cellwidth=4cm]
		style(header)=[font_weight=bold vjust=c];
	column ("^S={just=l background=cxffffff}Table &tab: Acceptance Criteria" &prodevt lot 
	("% sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result" percent ac1) 
	("Between sensor (within lot) SD of sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result" sd ac2));
	define &prodevt / group;
	define lot / group style(column)=[vjust=c just=c protectspecialchars=off cellwidth=3cm];
	define percent / group 'Percent' style(column)=[vjust=c just=c protectspecialchars=off cellwidth=2cm];
	define ac1 / group style=[bordercolor=cxffffff];
	define sd / group 'S.D.' style(column)=[vjust=c just=c protectspecialchars=off cellwidth=2cm];
	define ac2 / group style=[bordercolor=cxffffff];
	format percent 6. sd 6.1;
	where first(event) in (&acgluc) and suitable='Yes';
	run;

	/******************************************************************************************/
	/*INSERT FIGURE 1 % WITHIN 20% / 20 MG/DL*/
	/******************************************************************************************/

	/*proc sql;*/
	/*create table prods10 as*/
	/*select distinct &prodevt */
	/*from xsensor_accr */
	/*order by &prodevt;*/
	/*quit;*/
	/**/
	/*data prods10;*/
	/*set prods10;*/
	/*x10+1;*/
	/*call symput('xlast10',x10);*/
	/*run;*/

	data _null_;
	call symputx('fig',&fig+1);
	run;


	/*%macro sdpwres;*/

	options orientation=portrait;
	ods rtf startpage=now nogtitle nogfootnote;

	goptions hsize=7in vsize=7in;

	ods rtf text="^S={font_weight=bold}Figure &fig: % sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result";

	proc greplay igout=work.figurec nofs tc=sashelp.templt template=l2r2;
	%do p3=0 %to %eval(&nhist);
	treplay 1:%eval(1+(&p3*4)) 2:%eval(3+(&p3*4)) 3:%eval(2+(&p3*4)) 4:%eval(4+(&p3*4));
	%end;
	run;
	quit;

	ods rtf startpage=now;

	/*%mend;*/
	/**/
	/*ods rtf startpage=now;*/
	/**/
	/*%sdpwres;*/
/*US*/%end;

******************************************************************************************;
/*TABLE B: CONCLUSION MEAN % BIAS AND MEAN ABSOLUTE % BIAS TABLE BY PRODUCT AND SENSOR LOT*/
******************************************************************************************;
options orientation=portrait;
ods rtf startpage=now;

data _null_;
call symputx('tab',&tab+1);
run;

/*ods rtf text= "^S={outputwidth=100% just=l} {\tc\f3\fs0\cf8 Table 2: Summary of the sensor lot performance}";*/
proc report data=SUM_TABLE split='~' spanrows missing
	style(report)=[bordercolor=cx000000]
	style(column)=[vjust=c just=c cellwidth=4cm]
	style(header)=[font_weight=bold vjust=c];
column ("^S={just=l background=cxffffff}Table &tab: Summary of the sensor lot performance" &prodevt lot pdif_gl_cref_mean apdif_gl_cref_mean);
define &prodevt / group;
define lot / group;
define pdif_gl_cref_mean / display 'Mean % Bias' format=6.1;
define apdif_gl_cref_mean / display 'Mean Absolute % Bias' format=6.1;
where suitable='Yes';
run;

%if %eval(&nlots) > 6 %then %do;
ods rtf startpage=now;
%end;

/********************************************************************************************/
/*TABLE C: NUMBER OF PARTICIPANTS WITH GREATER THAN OR EQUAL 28 PAIRED POINTS*/
/********************************************************************************************/

%global maxord;

proc contents data=pairedpoints out=pairedorder noprint;
run;

data pairedorder ;
retain name label;
length videf $ 200;
set pairedorder ;
if upcase(name)='SUITABLE' then delete;
%if "&actype"="A18023" %then %do;
if upcase(name)=:'CAT' or upcase(name)=:'_' or upcase(name)='LOT' then delete;
%end;
%else %if "&actype"="A18023-001" %then %do;
if first(name) in (&acgluc);
%end;
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

data _null_;
call symputx('tab',&tab+1);
run;

proc report data=pairedpoints split='~' spanrows missing
	style(report)=[bordercolor=cx000000 outputwidth=12cm]
	style(column)=[vjust=c just=c /*cellwidth=4cm*/]
	style(header)=[font_weight=bold protectspecialchars=off];
column ("^S={just=l background=cxffffff}Table &tab: Number of Participants with ^{unicode 2265} &npaired Paired Points"
lot ("Number of Participants with ^{unicode 2265} &npaired Paired Points" %do i=1 %to &maxord; &&ppvar&i %end;));
define lot / group;
%do i=1 %to &maxord; 
define &&ppdef&i ;
%end;
where suitable='Yes';
run;

%if &edcstatus=FINAL %then %do;

	options orientation=landscape;
	ods rtf startpage=now;

	/******************************************************************************************/
	/*TABLE D: PARTICIPANT DEMOGRAPHICS BY SITE*/
	/******************************************************************************************/

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=DEMO_SITE nofs spanrows split='~'
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000]
		style(column)=[vjust=middle textalign=center]
		style(header)=[font_weight=bold vjust=middle];
	column ("^S={just=l background=cxffffff}Table &tab: Participant Demographics by Site"
	('Demographic' catvar category catval) ('Site' %do id=1 %to %eval(&nclin-1); ("&&clin&id" count&id percent&id) %end; ('All' countall percentall)));
	define catvar / noprint order order=data;
	define category / id order order=data '' style(column)=[cellwidth=3.39cm just=l font_weight=bold];
	define catval / id order order=data '' style(column)=[cellwidth=2.56cm just=l];
	%do id=1 %to %eval(&nclin-1);
		define count&id /display 'N' style(column)=[cellwidth=1.2cm];
		define percent&id /display '%' f=5.1 style(column)=[cellwidth=1.25cm];
	%end;
	define countall /display 'N' style(column)=[cellwidth=1.2cm];
	define percentall /display '%' f=5.1 style(column)=[cellwidth=1.25cm];
	run; quit;

	ods rtf startpage=now;

	/******************************************************************************************/
	/*TABLE E: PARTICIPANT DEMOGRAPHICS BY SENSOR LOT*/
	/******************************************************************************************/

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=DEMO_LOT nofs spanrows split='~'
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000]
		style(column)=[vjust=middle textalign=center font_size=9pt]
		style(header)=[font_weight=bold vjust=middle font_size=9pt];
	column ("^S={just=l background=cxffffff}Table &tab: Participant Demographics by Sensor Lot"
	('Demographic' catvar category catval) ('Lot' %do id=1 %to &nlots; ("&&lot&id" count&id percent&id) %end; ('All' countall percentall)));
	define catvar / noprint order order=data style(column)=[cellwidth=2.5cm];
	define category / id order order=data '' style(column)=[cellwidth=2.5cm just=l font_weight=bold];
	define catval / id order order=data '' style(column)=[just=l];
	%do id=1 %to &nlots;
		define count&id /display 'N' style(column)=[cellwidth=1.35cm];
		define percent&id /display '%' f=5.1 style(column)=[cellwidth=1.35cm];
	%end;
	define countall /display 'N' style(column)=[cellwidth=1.35cm];
	define percentall /display '%' f=5.1 style(column)=[cellwidth=1.35cm];
	run; quit;


	options orientation=portrait;
	ods rtf startpage=now;

	/******************************************************************************************/
	/*TABLE F: BASELINE CHARACTERISTICS BY SITE*/
	/******************************************************************************************/

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=CHAR_SITE split='~' spanrows missing
		style(report)=[outputwidth=18cm bordercolor=cx000000]
		style(column)=[vjust=c just=c]
		style(header)=[font_weight=bold protectspecialchars=off];
	column ("^S={just=l background=cxffffff}Table &tab: Baseline Characteristics by Site" varorder measure bygrouporder clinic varorder2 mean sd median minimum maximum n);
	define varorder / group order=data noprint;
	define measure / group style(column)=[font_weight=bold cellwidth=2.6cm];
	define bygrouporder / order order=data noprint;
	define clinic / display style(column)=[font_size=9pt just=l];
	define varorder2 / display noprint;
	define mean / display style(column)=[cellwidth=1.8cm];
	define sd / display style(column)=[cellwidth=1.8cm];
	define median / display style(column)=[cellwidth=1.8cm];
	define minimum / display style(column)=[cellwidth=1.8cm];
	define maximum / display style(column)=[cellwidth=1.8cm];
	define n / display format=3. style(column)=[cellwidth=1cm];
	compute maximum;
		if varorder2 in (1,3,5) then do;
			call define (6,'format', '6.1');
			if sd=0 then call define (7,'format', '6.');
			else call define (7,'format', '6.1');
			call define (8,'format', '6.1');
			do i=9 to 10;
			call define (i,'format', '6.');
			end;
		end;
		else if varorder2 eq 2 then do;
			call define (6,'format', '6.2');
			if sd=0 then call define (7,'format', '6.');
			else call define (7,'format', '6.2');
			do i=8 to 10;
			call define (i,'format', '6.2');
			end;
		end;
		else do;
			call define (6,'format', '6.1');
			if sd=0 then call define (7,'format', '6.');
			else call define (7,'format', '6.1');
			do i=8 to 10;
			call define (i,'format', '6.1');
			end;
		end;
	endcomp;
	compute clinic;
		if clinic='All' then call define(_col_,'style','style=[font_weight=bold font_size=10pt]');
		else call define(_col_,'style','style=[font_weight=medium]');
	endcomp;
	run;

	ods startpage=now;

	/******************************************************************************************/
	/*TABLE G: BASELINE CHARACTERISTICS BY SENSOR LOT*/
	/******************************************************************************************/

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=CHAR_LOT split='~' spanrows missing
	style(report)=[bordercolor=cx000000 outputwidth=18cm]
	style(column)=[vjust=c just=c]
	style(header)=[font_weight=bold protectspecialchars=off] ;
	column ("^S={just=l background=cxffffff}Table &tab: Baseline Characteristics by Sensor Lot" varorder measure bygrouporder lot varorder2 mean sd median minimum maximum n);
	define varorder / group order=data noprint;
	define measure / group style(column)=[font_weight=bold cellwidth=2.6cm];
	define bygrouporder / order order=data noprint;
	define lot / display style=[vjust=c];
	define varorder2 / display noprint;
	define mean / display style(column)=[cellwidth=1.8cm];
	define sd / display style(column)=[cellwidth=1.8cm];
	define median / display style(column)=[cellwidth=1.8cm];
	define minimum / display style(column)=[cellwidth=1.8cm];
	define maximum / display style(column)=[cellwidth=1.8cm];
	define n / display format=3. style(column)=[cellwidth=1cm];
	compute maximum;
		if varorder2 in (1,3,5) then do;
			call define (6,'format', '6.1');
			if sd=0 then call define (7,'format', '6.');
			else call define (7,'format', '6.1');
			call define (8,'format', '6.1');
			do i=9 to 10;
			call define (i,'format', '6.');
			end;
		end;
		else if varorder2 eq 2 then do;
			call define (6,'format', '6.2');
			if sd=0 then call define (7,'format', '6.');
			else call define (7,'format', '6.2');
			do i=8 to 10;
			call define (i,'format', '6.2');
			end;
		end;
		else do;
			call define (6,'format', '6.1');
			if sd=0 then call define (7,'format', '6.');
			else call define (7,'format', '6.1');
			do i=8 to 10;
			call define (i,'format', '6.1');
			end;
		end;
	endcomp;
	compute lot;
		if lot='All' then call define(_col_,'style','style=[font_weight=bold]');
		else call define(_col_,'style','style=[font_weight=medium]');
	endcomp;
	run;

%end;

%mend;
%demorep;

/******************************************************************************************/
/*INSERT FIGURE 1 CONSENSUS ERROR GRID PLOTS HERE USING PUMA-PLOT*/
/******************************************************************************************/

proc sql;
create table prods1 as
select distinct &prodevt 
from tableceg 
order by &prodevt;
quit;

data prods1;
set prods1;
x1+1;
call symput('xlast1',x1);
run;

data _null_;
call symputx('fig',&fig+1);
run;

%macro cegres;

	options orientation=portrait;
	ods rtf startpage=now nogtitle nogfootnote;

	goptions hsize=7in vsize=7in;

	ods rtf text="^S={font_weight=bold}Figure &fig: Consensus Error Grid Analysis of GM vs. BG Reference";

	proc greplay igout=work.figurea nofs tc=sashelp.templt template=l2r2;
	%do pl=0 %to %eval(&nceg);
	treplay 1:%eval(1+(&pl*4)) 2:%eval(3+(&pl*4)) 3:%eval(2+(&pl*4)) 4:%eval(4+(&pl*4));
	%end;
	run;
	quit;
	
	ods rtf startpage=now;

%do i=1 %to &xlast1;

	data _null_;
	set prods1;
	where x1=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

/******************************************************************************************/
/*TABLES H: CONSENSUS ERROR GRID ANALYSIS OF GM VS. BG REFERENCE*/
/******************************************************************************************/

	proc report data=TABLECEG spanrows split='~'
		style(report)=[rules=group bordercolor=cx000000 outputwidth=19cm]
		style(header)=[font_weight=bold font_size=9pt protectspecialchars=off]
		style(column)=[just=c vjust=c font_size=9pt ];
	columns ("^S={just=l background=cxffffff}Table &tab: &product Consensus Error Grid Analysis of GM vs. BG Reference" bygrouporder data lot
	("Consensus Error Grid Zone" ('A' na pca) ('B' nb pcb) ('A & B' nab pcab) ('C' nc pcc) ('D' nd pcd) ('E' ne pce)) consensus_total);
	define bygrouporder / group order=internal noprint;
	define data / group style=[vjust=c font_size=9pt cellwidth=3cm];
	define lot / order=internal;
	define na / display style(column)=[cellwidth=1cm];
	define pca / display style(column)=[cellwidth=1cm];
	define nb / display style(column)=[cellwidth=1cm];
	define pcb / display style(column)=[cellwidth=1cm];
	define nab / display style(column)=[cellwidth=1cm];
	define pcab / display style(column)=[cellwidth=1cm];
	define nc / display style(column)=[cellwidth=1cm];
	define pcc / display style(column)=[cellwidth=1cm];
	define nd / display style(column)=[cellwidth=1cm];
	define pcd / display style(column)=[cellwidth=1cm];
	define ne / display style(column)=[cellwidth=1cm];
	define pce / display style(column)=[cellwidth=1cm];
	define consensus_total / display 'Total';
	where &prodevt="&product" and suitable='Yes';
	run;
	%if %eval(&i)=1 %then %do;
		%if %eval(&nlots) > 6 %then %do;
			ods rtf startpage=now;
		%end;
	%end;

%end;

%mend;

ods rtf startpage=now;

%cegres;

/******************************************************************************************/
/*TABLES I: GM DIFFERENCE MEASURES VS. BG REFERENCE*/
/******************************************************************************************/

ods rtf startpage=now;

proc sql;
create table prods2 as
select distinct &prodevt 
from BIASALL
order by &prodevt;
quit;

data prods2;
set prods2;
x2+1;
call symput('xlast2',x2);
run;

%macro diffmeas;

%do i=1 %to &xlast2;

	data _null_;
	set prods2;
	where x2=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=BIASALL spanrows split='~'
		style(report)=[rules=group bordercolor=cx000000 outputwidth=18cm]
		style(header)=[font_weight=bold protectspecialchars=off]
		style(column)=[just=c vjust=c];
	columns ("^S={just=l background=cxffffff}Table &tab: &product GM Difference Measures vs. BG Reference" lot varorder measure mean sd median minimum maximum n);
	define lot / group;
	define varorder / order=internal noprint;
	define measure / display style=[cellwidth=4.8cm];
	define mean / display;
	define sd / display;
	define median / display;
	define minimum / display;
	define maximum / display;
	define n /display;
	where varorder in(1,2,5,6) and bygrouporder=' 1' and &prodevt="&product" and suitable='Yes';
	format mean sd median minimum maximum 8.1;
	run;

	%if %eval(&xlast2) > 1 %then %do; 
		%if %eval(&i)=1 %then %do;
			%if %eval(&nlots) > 4 %then %do;
				ods rtf startpage=now;
			%end;
		%end;
	%end;
%end;

%mend;
%diffmeas;

/******************************************************************************************/
/*TABLE J: MEAN BIAS MEASURES BY GLUCOSE LEVEL*/
/******************************************************************************************/

%macro table9;

proc sql;
create table prods3 as
select distinct &prodevt 
from MPBBYLEV
order by &prodevt;
quit;

data prods3;
set prods3;
x3+1;
call symput('xlast3',x3);
run;


options orientation=landscape;
ods rtf startpage=now;

proc format;
picture mm (round default=20)
	.='N/A'
	low-<0 ="9.9 mmol/L" (prefix='-')
	other ="9.9 mmol/L";
picture pc (round default=20)
	.='N/A'
	low-<0 ="9.9 %" (prefix='-')
	other ="9.9 %";
run;
quit;

%do i=1 %to &xlast3;

data _null_;
set prods3;
where x3=&i;
call symputx('product',&prodevt);
run;

%let ow=;
data _null_;
call symputx('tab',&tab+1);
if &nlots > 6 then call symputx('fs',9);
else call symputx('fs',10);
if &nlots le 2 then call symputx('ow','outputwidth=14cm');
run;

proc report data=MPBBYLEV nofs spanrows split='~'
	style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 &ow]
	style(column)=[vjust=middle textalign=center protectspecialchars=off font_size=&fs.pt]
	style(header)=[font_weight=bold vjust=middle font_size=&fs.pt];
column ("^S={just=l background=cxffffff}Table &tab: &product Mean Bias Measures by Glucose Level"
level ('Glucose Level' levelmm levelmg) ('Lot' %do id=1 %to &nlotslev; ("&&lot&id" mean&id n&id) %end; ));
define level / noprint order=data;
define levelmm / order order=data;
define levelmm / order order=data;
%do id=1 %to &nlotslev;
	define mean&id /display 'Mean Bias';
	define n&id /display 'N' f=5.;
	compute mean&id;
		if level in ('1','2') then call define(_col_,'format','mm.');
		else call define(_col_,'format','pc.');
	endcomp;
%end;
where &prodevt="&product";
run;
quit;

%end;

/******************************************************************************************/
/*INSERT FIGURE 2 MEAN BIAS MEASURES BY GLUCOSE LEVEL PLOTS HERE USING PUMA-PLOT*/
/******************************************************************************************/

/******************************************************************************************/
/*INSERT FIGURE 3 DISTRIBUTION OF FREESTYLE LIBRE SENSOR MEAN ABSOLUTE % BIAS HISTOGRAMS HERE USING PUMA-PLOT*/
/******************************************************************************************/

/******************************************************************************************/
/*INSERT FIGURE 4 DISTRIBUTION OF FREESTYLE LIBRE-PRO SENSOR MEAN ABSOLUTE % BIAS HISTOGRAMS HERE USING PUMA-PLOT*/
/******************************************************************************************/

options orientation=portrait;
ods rtf startpage=now;

/******************************************************************************************/
/*TABLE K: GM PASSING & BABLOK ANALYSIS FOR GM VS. BG REFERENCE*/
/******************************************************************************************/

proc sql;
create table prods4 as
select distinct &prodevt 
from reg_reg1
order by &prodevt;
quit;

data prods4;
set prods4;
x4+1;
call symput('xlast4',x4);
run;

%do i=1 %to &xlast4;

	data _null_;
	set prods4;
	where x4=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=reg_reg1 spanrows split='~'
		style(report)=[rules=group bordercolor=cx000000 outputwidth=18cm]
		style(header)=[font_weight=bold protectspecialchars=off]
		style(column)=[just=c vjust=c];
	columns ("^S={just=l background=cxffffff}Table &tab: &product Passing & Bablok Analysis for GM vs. BG Reference" lot pb_slp pb_intmm pb_r pb_apres pb_n);
	define lot / group;
	define pb_slp / display;
	define pb_intmm / display;
	define pb_r / display;
	define pb_apres / display 'Mean Absolute~% Residual';
	define pb_n /display;
	format pb_slp pb_intmm pb_r 8.2 pb_apres 8.1;
	where &prodevt="&product" and suitable='Yes';
	run;

%end;

/******************************************************************************************/
/*TABLE L:  SYSTEM ACCURACY OF GM VS. BG REFERENCE*/
/******************************************************************************************/

proc sql;
create table prods5 as
select distinct &prodevt 
from TABLEACCR 
order by &prodevt;
quit;

data prods5;
set prods5;
x5+1;
call symput('xlast5',x5);
run;

%let sow=;



%if %eval(&nlotsacc) eq 8 %then %do;
%let fs=9;
%end; 
%else %do;
%let fs=10;
%end; 


%if %eval(&nlotsacc) le 4 %then %do;
options papersize=a4 orientation=portrait;
%end;
%else %if %eval(&nlotsacc) gt 4 %then %do;
options papersize=a4 orientation=landscape;
%end;
%if %eval(&nlotsacc) le 2 %then %do;
data _null_;
call symputx('sow','outputwidth=14cm');
run;
%end;

ods rtf startpage=now;

%do i=1 %to &xlast5;

	data _null_;
	set prods5;
	where x5=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=TABLEACCR spanrows split='~'
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 &sow]
		style(column)=[vjust=middle textalign=center protectspecialchars=off font_size=&fs.pt]
		style(header)=[font_weight=bold vjust=middle font_size=&fs.pt];
	columns ("^S={just=l background=cxffffff}Table &tab: &product System Accuracy of GM vs. BG Reference (&accbreak mg/dL breakpoint)" high xwithin %do id=1 %to &nlotsacc; withinacc&id %end;);
	define high / order=internal noprint;
	define xwithin / display;
	%do id=1 %to &nlotsacc;
	define withinacc&id / display;
	%end;
	where &prodevt="&product";
	run;

%end;

/******************************************************************************************/
/*INSERT FIGURE 5 SYSTEM ACCURACY PLOT OF GM DIFFERENCE VS. BG REFERENCE (5.55 MMOL/L BREAKPOINT) HERE USING PUMA-PLOT*/
/******************************************************************************************/

/******************************************************************************************/
/*TABLE 12: OVERALL SLOPE AND TOTAL DRIFT AT DAY 14 - NOT CALCULATED BY PUMA-SUM*/
/******************************************************************************************/

/******************************************************************************************/
/*INSERT FIGURE 6 MEAN % BIAS BY DAY OF SENSOR WEAR HERE USING PUMA-PLOT*/
/******************************************************************************************/

/******************************************************************************************/
/*TABLE 13: ADVERSE EVENT CAUSALITY OCCURRENCES - NOT CALCULATED BY PUMA-SUM*/
/*TABLE 14: ADVERSE EVENT SEVERITY OCCURRENCES  - NOT CALCULATED BY PUMA-SUM*/
/*TABLE 15: ANTICIPATED SENSOR INSERTION SITE SIGNS AND SYMPTOMS - NOT CALCULATED BY PUMA-SUM*/
/******************************************************************************************/

/******************************************************************************************/
/*APPENDIX 1: DEVICE INCIDENTS AND MALFUNCTIONS*/
/******************************************************************************************/

data _null_;
call symput('edcstatus',upcase("&edcloc"));
run;

%if &edcstatus=FINAL %then %do;

	data _null_;
	call symputx('apx',&apx+1);
	run;

	options papersize=a4 orientation=portrait nocenter;
	ods rtf startpage=now;

	ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: Accountability and Operational Hours";

	proc report data=accountability style(report)=[outputwidth=18cm frame=void rules=none bordercolor=cxffffff];
	column ("^S={just=l font_weight=bold background=cxffffff}Sensor Insertions" acc);
	define acc / display '';
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	options center;
	ods rtf;

	proc report data=bucket_estimates split='~' spanrows missing
		style(report)=[bordercolor=cx000000 outputwidth=8cm]
		style(column)=[vjust=c just=c protectspecialchars=on just=c]
		style(header)=[font_weight=bold vjust=c just=c];
	column ("^S={just=l background=cxffffff}Table &tab: Operational Hours" timelist survivalpc);
	define timelist / display;
	define SurvivalPC / display;
	run;

	/*proc report data=wear style(report)=[outputwidth=18cm frame=void rules=none bordercolor=cxffffff];*/
	/*column ("^S={just=l font_weight=bold background=cxffffff}Operational Hours" wear);*/
	/*define wear / display '';*/
	/*run;*/

data _null_;
call symputx('apx',&apx+1);
run;

	options papersize=a4 orientation=portrait nocenter;
	ods rtf startpage=now;


ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: Device Incidents, Adverse Events and Protocol Deviations";

proc report data=disummary style(report)=[outputwidth=18cm frame=void rules=none bordercolor=cxffffff];
column ("^S={just=l font_weight=bold background=cxffffff}Device Incidents and Malfunctions" disum);
define disum / display '' style(column)=[url=$disum.];
run;

proc report data=aesummary style(report)=[outputwidth=18cm frame=void rules=none bordercolor=cxffffff];
column ("^S={just=l font_weight=bold background=cxffffff}Adverse Events" aesum);
define aesum / display '' style(column)=[url=$aesum.];
run;

proc report data=pdsummary style(report)=[outputwidth=18cm frame=void rules=none bordercolor=cxffffff];
column ("^S={just=l font_weight=bold background=cxffffff}Protocol Deviations" pdsum);
define pdsum / display '' style(column)=[url=$pdsum.];
run;

%end;



/******************************************************************************************/
/*APPENDIX 2: LIST OF EXCLUDED GM AND BG READINGS*/
/******************************************************************************************/


/******************************************************************************************/
/*TABLE M:  LISTING OF HIGH AND LOW READINGS IF APPLICABLE*/
/******************************************************************************************/

/******************************************************************************************/
/* TABLE A1: EXCLUDED FREESTYLE LIBRE GM LISTING - NOT CALCULATED BY PUMA-SUM*/
/* TABLE A2: EXCLUDED FREESTYLE LIBRE-PRO GM LISTING - NOT CALCULATED BY PUMA-SUM*/
/* TABLE A3: EXCLUDED BG REFERENCE LISTING - NOT CALCULATED BY PUMA-SUM*/
/******************************************************************************************/

	data _null_;
	call symputx('apx',&apx+1);
	run;

options papersize=a4 orientation=portrait nocenter;
ods rtf startpage=now;

ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: List of Excluded GM and BG Readings";

options center;

proc format;
	picture bg (round) 
		. = 'N/A'
		0-<1.1 ='LO'
		>27.8-high='HI'
		other='09.99' (mult=100);
run;

%if %eval(&hiloobs) > 0 %then %do;

	proc sql;
	create table prods6 as
	select distinct &prodevt 
	from HILO
	order by &prodevt;
	quit;

	data prods6;
	set prods6;
	x6+1;
	call symput('xlast6',x6);
	run;

	%do i=1 %to &xlast6;

	data _null_;
	set prods6;
	where x6=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=HILO nofs spanrows split='~' missing
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 outputwidth=18cm]
		style(column)=[vjust=middle textalign=center protectspecialchars=off font_size=9pt]
		style(header)=[font_weight=bold vjust=middle font_size=9pt];
	column ("^S={just=l background=cxffffff}Table &tab: Excluded &product GM Listing" subjectid lot dtm gl_hilo refdtm crefallmm crefallmmunadj consensus);
	define subjectid / display 'Participant';
	define lot / display;
	define dtm / display;
	define gl_hilo / display;
	define refdtm / display;
	define crefallmm / display format=bg6.2;
	define crefallmmunadj / display format=bg6.2;
	define consensus / display;
	where &prodevt="&product" and suitable='Yes';
	run;
	quit;

	%end;

%end;
%else %do;

options nocenter;
ods rtf text="^S={outputwidth=100% just=l}^{newline}No paired GM and BG readings were excluded.";
%end;

/******************************************************************************************/
/*TABLE N: LISTING OF EXCLUDED DUPLICATED AND NOT IN AGREEMENT BG REFERENCE IF APPLICABLE*/
/******************************************************************************************/

%if %eval(&CBGMDUPobs) > 0 %then %do;

	options center;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=CBGMDUP nofs spanrows split='~'
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 outputwidth=18cm]
		style(column)=[vjust=middle textalign=center protectspecialchars=off]
		style(header)=[font_weight=bold vjust=middle font_size=9pt];
	column ("^S={just=l background=cxffffff}Table &tab: Excluded Duplicated and Not in Agreement BG Reference Listing" subjectid reader_id refdtm refmm unadj_refmm);
	define subjectid / display 'Participant';
	define reader_id / display 'Reader ID';
	define refdtm / display 'BG Reference~Date and Time';
	define refmm / display 'BG Reference~(mmol/L)' format=bg6.2;
	define unadj_refmm / display 'Unadjusted BG~Reference (mmol/L)' format=bg6.2;
	run;
	quit;

%end;
%else %do;
options nocenter;
ods rtf text="^S={outputwidth=100% just=l}^{newline}There were no duplicated and not in agreement BG reference values.";
%end;

/******************************************************************************************/
/*APPENDIX 3: PERFORMANCE BY DAY OF WEAR*/
/******************************************************************************************/

/******************************************************************************************/
/*TABLES O: SUMMARY BY DAY OF SENSOR WEAR*/
/******************************************************************************************/

options orientation=portrait;

proc sql;
create table prods7 as
select distinct &prodevt 
from TABLEBYDAY
order by &prodevt;
quit;

data prods7;
set prods7;
x7+1;
call symput('xlast7',x7);
run;

%do i=1 %to &xlast7;

	%let dow=;
	data _null_;
	set prods7;
	where x7=&i;
	call symputx('product',&prodevt);
	if &nlotso le 4 then call symputx('dow','outputwidth=14cm');
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	ods rtf startpage=now;

	%if %eval(&i)=1 %then %do;
	data _null_;
	call symputx('apx',&apx+1);
	run;
	options nocenter;
	ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: Performance by Day of Wear (All Data)";
	%end;

	options center;
	proc report data=TABLEBYDAY nofs spanrows split='~'
	style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 &dow]
	style(column)=[vjust=middle textalign=center protectspecialchars=off]
	style(header)=[font_weight=bold vjust=middle];
	column ("^S={just=l background=cxffffff}Table &tab: &product Mean % Bias by Day of Sensor Wear"
	Day ('Mean % Bias' %do id=1 %to &nlotso; mpb_&id %end; ));
	define Day / id group order=data style(column)=[cellwidth=1.5cm];
	%do id=1 %to &nlotso;
	define mpb_&id /display f=5.1;
	%end;
	where &prodevt="&product";
	run;
	quit;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=TABLEBYDAY nofs spanrows split='~'
	style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 &dow]
	style(column)=[vjust=middle textalign=center protectspecialchars=off]
	style(header)=[font_weight=bold vjust=middle];
	column ("^S={just=l background=cxffffff}Table &tab: &product % in Zone A by Day of Sensor Wear"
	Day ('% in Zone A' %do id=1 %to &nlotso; ZoneA_&id %end;));
	define Day / id group order=data style(column)=[cellwidth=1.5cm];
	%do id=1 %to &nlotso;
	define zonea_&id /display f=5.1;
	%end;
	where &prodevt="&product";
	run;
	quit;

%end;

/******************************************************************************************/
/*APPENDIX 4: DISTRIBUTION OF DIFFERENCE, BY GLUCOSE LEVEL*/
/******************************************************************************************/

/******************************************************************************************/
/*TABLE O: SYSTEM ACCURACY OF GM VS. BG REFERENCE, GLUCOSE < 5.55 MMOL/L*/
/******************************************************************************************/

%let aow=;
%if %eval(&&nlotsacc) le 4 %then %do;
	options papersize=a4 orientation=portrait;

	data _null_;
	if &nlotsacc lt 3 then call symputx('aow','outputwidth=16cm');
	else if &nlotsacc ge 3 then call symputx('aow','outputwidth=18cm');
	run;

%end;
%else %do;
	options papersize=a4 orientation=landscape;
%end;

ods rtf startpage=now;

data _null_;
call symputx('apx',&apx+1);
run;
options nocenter;
ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: Distribution of Differences, by Glucose Level (&accbreak mg/dL breakpoint)";

proc sql;
create table prods8 as
select distinct &prodevt 
from TABLEACCR_BYLEV
order by &prodevt;
quit;

data prods8;
set prods8;
x8+1;
call symput('xlast8',x8);
run;

options center;
%do i=1 %to &xlast8;

	data _null_;
	set prods8;
	where x8=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=TABLEACCR_BYLEV nofs spanrows split='~'
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 &aow]
		style(column)=[vjust=middle textalign=center protectspecialchars=off]
		style(header)=[font_weight=bold vjust=middle];
	column ("^S={just=l background=cxffffff}Table &tab: &product System Accuracy of GM vs. BG Reference, Glucose < &accbreak mg/dL"
	high newlabel %do id=1 %to &nlotsacc; withinacc&id %end;);
	define high / order=internal noprint;
	define Newlabel / id display;
		%do id=1 %to &nlotsacc;
			define withinacc&id /display ;
		%end;
	where acclevel="Low" and &prodevt="&product";
	run;
	quit;

%end;

/******************************************************************************************/
/*TABLE Q: SYSTEM ACCURACY OF GM VS. BG REFERENCE, GLUCOSE GE 5.55 MMOL/L*/
/******************************************************************************************/

%if %eval(&&nlotsacc) gt 4 %then %do;
	ods rtf startpage=now;
%end;

%do i=1 %to &xlast8;

	data _null_;
	set prods8;
	where x8=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

	proc report data=TABLEACCR_BYLEV nofs spanrows split='~'
		style(report)=[cellpadding=3pt rules=all frame=box bordercolor=cx000000 &aow]
		style(column)=[vjust=middle textalign=center protectspecialchars=off]
		style(header)=[font_weight=bold vjust=middle protectspecialchars=off];
	column ("^S={just=l background=cxffffff protectspecialchars=off}Table &tab: &product System Accuracy of GM vs. BG Reference, Glucose ^{unicode 2265} &accbreak mg/dL" high newlabel
	%do id=1 %to &nlotsacc; withinacc&id %end;);
	define high / order=internal noprint;
	define Newlabel / id display;
	%do id=1 %to &nlotsacc;
		define withinacc&id /display ;
	%end;
	where acclevel="High" and &prodevt="&product";
	run;
	quit;

%end;

options papersize=a4 orientation=portrait nocenter;
ods rtf startpage=now;

data _null_;
call symputx('apx',&apx+1);
run;

proc sql noprint;
create table prods9 as
select distinct &prodevt 
from CEG_UNADJ 
order by &prodevt;
select distinct &prodevt into : apptitle separated by ' and '
from CEG_UNADJ;
quit;

ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: &apptitle Performance vs. Unadjusted BG Reference";

options center;
data prods9;
set prods9;
x9+1;
call symput('xlast9',x9);
run;

options center;

%do i=1 %to &xlast9;

	data _null_;
	set prods9;
	where x9=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

/******************************************************************************************/
/*TABLES R: UNADJUSTED CONSENSUS ERROR GRID ANALYSIS OF GM VS. BG REFERENCE*/
/******************************************************************************************/

	proc report data=CEG_UNADJ spanrows split='~'
		style(report)=[rules=group bordercolor=cx000000 outputwidth=19cm]
		style(header)=[font_weight=bold font_size=9pt protectspecialchars=off]
		style(column)=[just=c vjust=c font_size=9pt ];
	columns ("^S={just=l background=cxffffff}Table &tab: &product Consensus Error Grid Analysis of GM vs. Unadjusted BG Reference" bygrouporder lot
	("Consensus Error Grid Zone" ('A' na pca) ('B' nb pcb) ('A & B' nab pcab) ('C' nc pcc) ('D' nd pcd) ('E' ne pce)) consensus_total);
	define bygrouporder / group order=internal noprint;
	define lot / order=internal;
	define na / display style(column)=[cellwidth=1cm];
	define pca / display style(column)=[cellwidth=1cm];
	define nb / display style(column)=[cellwidth=1cm];
	define pcb / display style(column)=[cellwidth=1cm];
	define nab / display style(column)=[cellwidth=1cm];
	define pcab / display style(column)=[cellwidth=1.cm];
	define nc / display style(column)=[cellwidth=1cm];
	define pcc / display style(column)=[cellwidth=1cm];
	define nd / display style(column)=[cellwidth=1cm];
	define pcd / display style(column)=[cellwidth=1cm];
	define ne / display style(column)=[cellwidth=1cm];
	define pce / display style(column)=[cellwidth=1cm];
	define consensus_total / display 'Total';
	where &prodevt="&product" and suitable='Yes';
	run;

%end;

%mend;
%table9;

/******************************************************************************************/
/*INSERT FIGURE 3 ACCUARY PLOTS HERE USING PUMA-PLOT*/
/******************************************************************************************/

data _null_;
call symputx('apx',&apx+1);
run;

options papersize=a4 orientation=portrait nocenter;
ods rtf startpage=now nogtitle nogfootnote;

ods rtf text="^S={outputwidth=100% font_weight=bold just=l}Appendix &apx: System Accuracy Plots";
ods rtf text="^{newline}";

proc sql;
create table prods10 as
select distinct &prodevt 
from tableaccr 
order by &prodevt;
quit;

data prods10;
set prods10;
x10+1;
call symput('xlast10',x10);
run;

data _null_;
call symputx('fig',&fig+1);
run;

%macro accres;

	goptions hsize=7in vsize=7in;

	
	ods rtf text="^S={font_weight=bold}Figure &fig: System Accuracy Plot of GM Difference vs. BG Reference (&accbreak mg/dL breakpoint)";

	proc greplay igout=work.figureb nofs tc=sashelp.templt template=l2r2;
	%do pl=0 %to %eval(&nacc);
	treplay 1:%eval(1+(&pl*4)) 2:%eval(3+(&pl*4)) 3:%eval(2+(&pl*4)) 4:%eval(4+(&pl*4));
	%end;
	run;
	quit;
	
	ods rtf startpage=now;

%do i=1 %to &xlast10;

	data _null_;
	set prods10;
	where x10=&i;
	call symputx('product',&prodevt);
	run;

	data _null_;
	call symputx('tab',&tab+1);
	run;

/******************************************************************************************/
/*TABLES H: CONSENSUS ERROR GRID ANALYSIS OF GM VS. BG REFERENCE*/
/******************************************************************************************/

	proc report data=CEGPLOT spanrows split='~'
		style(report)=[rules=group bordercolor=cx000000 outputwidth=19cm]
		style(header)=[font_weight=bold font_size=9pt protectspecialchars=off]
		style(column)=[just=c vjust=c font_size=9pt ];
	columns ("^S={just=l background=cxffffff}Table &tab: System Accuracy Plot - GM Differences outside ±300 mg/dL" lot subjectid dtm glmm crefmm dif_glmm_crefmm);
	define lot / display;
	define subjectid / display 'Participant';
	define dtm / display 'Glucose Date and Time';
	define glmm / display 'Glucose (mmol/L)';
	define crefmm / display 'BG Reference (mmol/L)';
	define dif_glmm_crefmm / display;
	where &prodevt="&product" and adif_gl_cref > 300 and suitable='Yes';
	format glmm crefmm dif_glmm_crefmm 6.2;
	run;

%end;

%mend;

%accres;

ods rtf startpage=now;
proc report data=study_params split='~' spanrows  missing
	style(report)=[bordercolor=cx000000 outputwidth=19cm]
	style(column)=[vjust=c just=c protectspecialchars=on just=l]
	style(header)=[font_weight=bold vjust=c just=l];
column ("^S={just=l background=cxffffff}Parameters" parameter value);
define parameter / display style=[cellwidth=6cm];
define value / display style(column)=[url=$location.];
run;

ods rtf close;

%macro rtftopdf;

/******************************************************************************************/
/*VB script to convert RTF to PDF using MW WORD 2010 or later*/
/******************************************************************************************/

options papersize=a4 orientation=portrait pagesize=max linesize=max nocenter;
%let RTF=&outroot\&outputfile &fdtm..rtf;
%let PDF=&outroot\&outputfile &fdtm..pdf;
%let vbscript=c:\temp\puma2.vbs;

/** no changes below the line required */
%let rtf=%unquote(%str("&rtf"));
%let pdf=%unquote(%str("&pdf"));
%let vbscript=%unquote(%str("&vbscript"));

%put &rtf;

filename vbscript ""&vbscript"";
data _null_;
  file vbscript;
  put
      "Const WORD_PDF = 17"
    / "Const WORD_IN="&RTF""
    / "Const PDF_OUT="&PDF""
    / "Set objWord = CreateObject(""Word.Application"")"
    / "objWord.Visible = False"
    / "Set objDocument = objWord.Documents.Open(WORD_IN,,False)"
    / "objDocument.SaveAs PDF_OUT, WORD_PDF"
    / "objDocument.Close False"
    / "objWord.Quit"
    ;
run;
filename vbscript;

%put &vbscript;

options symbolgen;
data _null_;
  /* execute vbs */
  call system(""&vbscript"");
  /*wait 3 seconds to allow time for the conversion*/
  x=sleep(3);
  /*delete vb script file*/
  call system("del /q "&vbscript"");
  /*delete RTF file*/
/*  call system("del /q "&RTF"");*/
run;

%mend;

%rtftopdf;

/******************************************************************************************/
/* POWERPOINT SUMMARY */
/******************************************************************************************/

title;footnote;
options papersize=a4 orientation=landscape pagesize=max linesize=max center topmargin=1cm number date;
%macro power;

/*OUS*/%if "&actype"="A18023" %then %do;

	proc report data=AC_TABLE split='~' spanrows  missing
		style(report)=[bordercolor=cx000000 font_size=18pt outputwidth=25cm]
		style(column)=[bordercolor=cx000000 font_size=18pt vjust=c just=c protectspecialchars=off]
		style(header)=[bordercolor=cx000000 font_size=18pt font_weight=bold vjust=c];
	column ("^S={just=l background=cxffffff}Acceptance Criteria" &prodevt lot result ac);
	define &prodevt / group style(column)=[cellheight=1cm];
	define lot / group;
	define result / group;
	define ac / group ;
	where first(event) in (&acgluc) and suitable='Yes';
	run;

/*OUS*/%end;
/*US*/ %else %if "&actype"="A18023-001" %then %do;

	proc report data=AC_TABLE_US split='~' spanrows  missing
		style(report)=[bordercolor=cx000000 font_size=16pt outputwidth=25.5cm]
		style(column)=[bordercolor=cx000000 font_size=16pt vjust=c just=c protectspecialchars=off]
		style(header)=[bordercolor=cx000000 font_size=16pt font_weight=bold vjust=c];
	column ("^S={just=l background=cxffffff}Acceptance Criteria" &prodevt lot 
	("% sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result" percent ac1) 
	("Between sensor (within lot) SD of sensor glucose results within 20% / 20mg/dL of the capillary BG reference glucose result" sd ac2));
	define &prodevt / group style(column)=[cellheight=1cm];
	define lot / group style(column)=[vjust=c just=c protectspecialchars=off];
	define percent / group 'Percent' style(column)=[vjust=c just=c protectspecialchars=off cellwidth=2cm];
	define ac1 / group style=[bordercolor=cx000000];
	define sd / group 'S.D.' style(column)=[vjust=c just=c protectspecialchars=off cellwidth=1.75cm];
	define ac2 / group style=[bordercolor=cx000000];
	format percent 6. sd 6.1;
	where first(event) in (&acgluc) and suitable='Yes';
	run;
/*US*/ %end;

proc report data=SUM_TABLE split='~' spanrows missing
	style(report)=[bordercolor=cx000000 font_size=18pt outputwidth=25cm]
	style(column)=[bordercolor=cx000000 font_size=18pt vjust=c just=c]
	style(header)=[bordercolor=cx000000 font_size=18pt font_weight=bold vjust=c];
column ("^S={just=l background=cxffffff}Summary of the sensor lot performance" &prodevt lot pdif_gl_cref_mean apdif_gl_cref_mean);
define &prodevt / group style(column)=[cellheight=1cm];
define lot / group;
define pdif_gl_cref_mean / display 'Mean % Bias' format=6.1;
define apdif_gl_cref_mean / display 'Mean Absolute % Bias' format=6.1;
where suitable='Yes';
run;

/*CREATE MACRO VARIABLES FOR REPORTING*/
data _null_;
set pairedorder;
call symputx("PPVAR"||strip(ord),name);
call symputx("PPDEF"||strip(ord),def);
run;

proc report data=pairedpoints split='~' spanrows missing
	style(report)=[bordercolor=cx000000 font_size=18pt outputwidth=25cm]
	style(column)=[bordercolor=cx000000 font_size=18pt vjust=c just=c]
	style(header)=[bordercolor=cx000000 font_size=18pt font_weight=bold protectspecialchars=off];
column lot ("Number of Participants with ^{unicode 2265} &npaired Paired Points" %do i=1 %to &maxord; &&ppvar&i %end;);
define lot / group style(column)=[cellheight=1cm];
%do i=1 %to &maxord; 
define &&ppdef&i ;
%end;
where suitable='Yes';
run;

%if "&ACTYPE"="A18023-001" %then %do;

	data P6IN;
	set xsensor_accr;
	where first(event) in (&acgluc) and total ge 28;
	label percent ='% Within 20mg/dL/20%';
	run;

	title h=18pt bold "ADC-UK-PMS-14020 Study Event &eventid - &analysis";
	%histo(percent,2,&prodevt LOT,CornFlowerBlue);

%end;

title;footnote;
title h=18pt bold "ADC-UK-PMS-14020 Study Event &eventid - &analysis";
%cegplot;
%accplot;


%mend;

title h=18pt bold "ADC-UK-PMS-14020 Study Event &eventid - &analysis";
ods powerpoint file="&outroot\&eventid &analysis Summary &fdtm..pptx" gtitle gfootnote sasdate ; 
ods graphics on ; 

%power;

ods powerpoint close;

options nodate nonumber;
