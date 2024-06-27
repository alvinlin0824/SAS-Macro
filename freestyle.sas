/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-21206\UploadData\AUU\AUU_DataFiles\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\BG""";*/
/*data freestyle_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path) then do;*/
/*    if  prxmatch("/(freestyle.csv)/i",path) then output freestyle_list;*/
/*	end;*/
/*run;


%macro freestyle(free_path = , out = );
data temp;
	set &free_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=2;
	do while(not done);
	    filepath = path;
		input uid: $char256. date: yymmdd10. time: time8. bg: best8. st: best1.;
        format date date9. time time8.;
        output;
	end;
run;

/*Extract Subject and Condition ID*/
data &out(drop = uid date time st);
retain filepath subject fs_dtm bg;
set temp;
format fs_dtm datetime16.;
if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,3) = "ADC" then subject = strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4));
else if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,1) = "1" then subject = strip(catt(strip(substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,3)),strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4))));
else if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,2) = "00" then subject = strip(catt(strip(substr(uid,prxmatch("/(Site ID = 00)/i",uid) + 12,1)),strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4))));
else if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,1) = "0" then subject = strip(catt(strip(substr(uid,prxmatch("/(Site ID = 0)/i",uid) + 11,2)),strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4))));
fs_dtm = dhms(date,0,0,time);
if st = 0;
run;

proc sort data = &out;
by subject fs_dtm;
run;

proc delete data = work.temp;
run;

%mend;

/*%freestyle(free_path = freestyle_list, out = BG);*/