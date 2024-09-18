/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24251\UploadData\Ketone\Ketone_DataFiles\*.xlsx""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24252\UploadData\Ketone\Ketone_DataFiles\058\2024-08-01\*.xls""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-23244\UploadData\Ketone\Ketone_DataFiles\*.xlsx""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\*.xlsx""";*/
/*data randox_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive|receiptlog)/i",path);*/
/*run;
/*\\wf00168p\DATA1\CDM\ADC-US-VAL-23244\UploadData\Ketone\Ketone_DataFiles\117-ERA\11JUL2024\ADC-US-VAL-23244_Box 1_Corrected format.xls*/

%macro import_randox(file_list = , out =);

proc sql noprint;
select path 
         into: randoxpath separated by ','
from &file_list;
quit;

%do i = 1 %to %SYSFUNC(countw(%quote(&randoxpath), %str(,)));
    	%let individual = %scan(%quote(&randoxpath),&i,%str(,)); 

        libname myexcel xlsx "&individual";
		proc contents data = myexcel._all_ noprint out = sheet_names (keep = memname);
		run;


		 data _null_;
            set sheet_names;
            if _n_ = 2 then call symputx('sheet_name', compress(memname));
        run;
       
        proc import
	  		datafile = "&individual"
	  		out = temp
	  		dbms = xlsx
	  		replace;
			sheet = "&sheet_name";
			getnames = No;
		run;

		libname myexcel clear;

		data temp1;
		length Notes $50. filepath $256.;
		set temp(rename = (A = Instrument_ID B = Technician_ID C = Date 
                   		   D = Sample_Volume E = Round_Number F = Sample_ID
                   		   G = SIDN H = Result1 I = Notes1));
/*		set temp(rename = (Notes = Notes1 SID = SIDN));*/
		filepath = "&individual";
/*		if vtype(Date1) = "C" then Date = input(strip(Date1), MMDDYY10.);*/
/*		else Date = input(put(Date1,ddmmyy10.),MMDDYY10.);*/
		if vtype(Result1) = "C" and prxmatch("/[0-9]/",Result1) then Result = input(Result1,best32.);
		else Result = .;
		Notes = Notes1;
        if vtype(SIDN) = "N" then SID = strip(put(SIDN,8.));
		else SID = strip(SIDN);
		if _N_ = 1 then delete;
        run;
  
        proc append base = out data = temp1 force;
		run;
%end;

proc fcmp outlib = work.function.dev;
	function create_siteID(var $) $;
	length site_id $10;
	if (prxmatch("/009/", var)) then site_id = "RCR";
	else if (prxmatch("/041/", var)) then site_id = "ADA";
	else if (prxmatch("/057/", var)) then site_id = "RMCR";
	else if (prxmatch("/058/", var)) then site_id = "SDRI";
	else if (prxmatch("/081/", var)) then site_id = "DGD";
	else if (prxmatch("/082/", var)) then site_id = "TDE";
	else if (prxmatch("/083/", var)) then site_id = "IDR";
	else if (prxmatch("/117/", var)) then site_id = "ERA";
	else if (prxmatch("/133/", var)) then site_id = "YALE";
	else site_id = "Unknown";
	return(site_id);
	endsub;
run;

options cmplib = work.function;

proc sql;
create table &out as 
select filepath, 
	    substr(filepath,prxmatch("/(?<=(VAL|RES)-)[0-9]{5}/i",filepath),5) as SE, 
		create_siteID(filepath) as Site,
		Instrument_ID , 
		Technician_ID,
		compress(Sample_Volume) as Sample_Volume, 
	    Round_Number,
		Sample_ID, 
	    SID, 
	    Result,
		Notes
from out;
quit;

proc delete data = work.temp work.temp1 work.out work.sheet_names;
run;

proc fcmp outlib = work.function.dev;
      deletefunc create_siteID;
run;

%mend;

/*%import_randox(file_list = randox_list, out = aaaa);*/






