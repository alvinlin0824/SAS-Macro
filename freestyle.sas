/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-21206\UploadData\AUU\AUU_DataFiles\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\""";*/
/*data freestyle_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path) then do;*/
/*    if  prxmatch("/(freestyle.csv)/i",path) then output freestyle_list;*/
/*	end;*/
run;


%macro freestyle(free_path = , out = );
data temp;
	set &free_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
		input uid: $char16. date: yymmdd10. time: time8. bg: best8. st: best1.;
        format date date9. time time8.;
		drop uid;
        output;
	end;
run;

data &out;
retain filepath subject fs_dtm bg;
set temp(where = (st = 0));
format fs_dtm datetime16.;
/*ApolADC InHouse*/
if prxmatch("/ApolADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/ApolADC/i",filepath) + 7,4));
else if prxmatch("/Apol1/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol1/i",filepath) + 4,7));
else if prxmatch("/Apol00/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol0/i",filepath) + 6,5));
else if prxmatch("/Apol0/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol0/i",filepath) + 5,6));
fs_dtm = dhms(date,0,0,time);
drop date time st;
run;

proc sort data = &out;
by subject fs_dtm;
run;

proc delete data = work.temp;
run;

%mend;

/*%freestyle(free_path = freestyle_list, out = BG);*/