/*filename dir pipe "dir /b/s  ""C:\Project\ADC-US-VAL-24252\Randox\*.xls""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24251\UploadData\Ketone\Ketone_DataFiles\RCR - 009\2023-07-30_1758\*.xls""";*/
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
    
    	data randox;
		set temp;
		filepath = "&individual";
        run;
         
        proc append base = out data = randox force;
		run;
%end;

proc sql;
create table &out(drop = J K L "Date analyzedC"n) as 
select filepath, "Instrument ID"n as Instrument_ID , "Technician ID"n as Technician_ID,
input(strip("Date analyzedC"n),MMDDYY10.) as Date  format date9.,
"Sample Volume"n as Sample_Volume, "Round #"n as Round_Number,
"Sample ID"n as Sample_ID, SID, "Ranbut (mmoll/l"n as Result,
Notes
from out(rename = ("Date analyzed"n = "Date analyzedC"n));
quit;

proc delete data = work.temp;
run;

%mend;


/*%import_randox(file_list = randox_list, out = aaaa);*/

