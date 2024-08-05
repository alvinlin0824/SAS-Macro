/*filename dir pipe "dir /b/s  ""C:\Project\ADC-US-VAL-24252\Randox\*.xls""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24252\UploadData\Ketone\Ketone_DataFiles\058\2024-08-01\*.xls""";*/
/*data randox_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive|UDP)/i",path);*/
/*run;

%macro import_randox(file_list = , out =);

proc sql noprint;
select path ,compress(substr(path,prxmatch("/(ADC-US-(VAL|RES)-\d{5}_)/i",path), prxmatch("/(.xls)/i",path) - prxmatch("/(ADC-US-VAL-\d{5}_)/i",path)))
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
    
    	data temp1;
		set temp;
		filepath = "&individual";
		if vtype("Date analyzed"n) = "C" then Date = input(strip("Date analyzed"n), MMDDYY10.);
		else Date = "Date analyzed"n;
        run;
         
        proc append base = out data = temp1 force;
		run;
%end;

proc sql;
create table &out(drop = J K L "Date analyzed"n) as 
select filepath, "Instrument ID"n as Instrument_ID , "Technician ID"n as Technician_ID,
Date format date9.,
"Sample Volume"n as Sample_Volume, "Round #"n as Round_Number,
"Sample ID"n as Sample_ID, SID, "Ranbut (mmoll/l"n as Result,
Notes
from out;
quit;

proc delete data = work.temp work.temp1 work.out;
run;

%mend;


/*%import_randox(file_list = randox_list, out = aaaa);*/

