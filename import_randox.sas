/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24251\UploadData\Ketone\Ketone_DataFiles\*.xls""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24252\UploadData\Ketone\Ketone_DataFiles\058\2024-08-01\*.xls""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-23244\UploadData\Ketone\Ketone_DataFiles\*.xls""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\*.xls""";*/
/*data randox_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path);*/
/*run;

%macro import_randox(file_list = , out =);

proc sql noprint;
select path ,compress(substr(path,prxmatch("/(ADC-US-(VAL|RES)-\d{5}_)/i",path), prxmatch("/(?<=Box\s[0-9])(\.|_)|(?<=Box\s[0-9][0-9])(\.|_)/i",path) - prxmatch("/(ADC-US-(VAL|RES)-\d{5}_)/i",path)))
       into: randoxpath separated by ',',
           : sheet separated by ','
from &file_list;
quit;

%do i = 1 %to %SYSFUNC(countw(%quote(&randoxpath), %str(,)));
    	%let individual = %scan(%quote(&randoxpath),&i,%str(,)); 
		%let sheet_name = %scan(%quote(&sheet),&i,%str(,)); 

        proc import
  		datafile = "&individual"
  		out = temp
  		dbms = xls
  		replace;
		sheet = "&sheet_name";
		run;
    
    	data temp1(drop = Result);
		length Notes $50. filepath $256.;
		set temp(rename = ("Ranbut (mmoll/l"n = Result Notes = Notes1));
		filepath = "&individual";
		if vtype("Date analyzed"n) = "C" then Date = input(strip("Date analyzed"n), MMDDYY10.);
		else Date = input(put("Date analyzed"n,ddmmyy10.),MMDDYY10.);
        if vtype(Result) = "C" and prxmatch("/[0-9]/",Result) then "Ranbut (mmoll/l"n = input(Result,best8.);
		else "Ranbut (mmoll/l"n = Result;
		Notes = Notes1;
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
create table &out(drop = J K L "Date analyzed"n) as 
select filepath, 
	    substr(filepath,prxmatch("/(?<=(VAL|RES)-)[0-9]{5}/i",filepath),5) as SE, 
		create_siteID(filepath) as Site,
		"Instrument ID"n as Instrument_ID , 
		"Technician ID"n as Technician_ID,
		Date format date9.,
		compress("Sample Volume"n) as Sample_Volume, 
	    "Round #"n as Round_Number,
		"Sample ID"n as Sample_ID, 
	    SID, 
	    "Ranbut (mmoll/l"n as Result,
		Notes
from out;
quit;

proc delete data = work.temp work.temp1 work.out;
run;

proc fcmp outlib = work.function.dev;
      deletefunc create_siteID;
run;

%mend;


/*%import_randox(file_list = randox_list, out = aaaa);*/






