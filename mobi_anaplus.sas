/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-21206\UploadData\AUU\AUU_DataFiles\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\UDP""";*/
/*data events_list anaplus_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive|Apol|LifeCountTimeStamp)/i",path) then do;*/
/*	if  prxmatch("/(events.csv)/i",path) then output events_list;*/
/*    if  prxmatch("/(anaPlus.csv)/i",path) then output anaplus_list;*/
/*	end;*/
/*run;

%macro mobi_anaplus(events_path = , anaplus_path = , out = );
/*Loop events.csv Data*/
data events;
	set &events_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=2;
	do while(not done);
	    filepath = path;
        input uid: $char256. date: yymmdd10. time:time8. type: $char56. col_4: $char3. col_5: $char11. col_6: $char4. col_7: best8. col_8: $char9. 
 snr: $char25.;
        format date date9. time time8.;
		drop col_4-col_8;
        output;
	end;
run;


/*Extract Subject and Condition ID*/
data events_ID(keep = filepath subject condition_id);
set events(where=(prxmatch("/(Subject)/i",uid)));
if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,3) = "ADC" then subject = strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4));
else if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,1) = "1" then subject = strip(catt(strip(substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,3)),strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4))));
else if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,2) = "00" then subject = strip(catt(strip(substr(uid,prxmatch("/(Site ID = 00)/i",uid) + 12,1)),strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4))));
else if substr(uid,prxmatch("/(Site ID = )/i",uid) + 10,1) = "0" then subject = strip(catt(strip(substr(uid,prxmatch("/(Site ID = 0)/i",uid) + 11,2)),strip(substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,4))));
else subject = substr(uid,prxmatch("/(Subject ID = )/i",uid) + 13,6);
condition_id = upcase(strip(substr(uid,prxmatch("/Condition ID = /i",uid) + 15,3)));
run;
/*Multiple Sensor Start*/
proc sql;
create table events_start(drop = uid) as 
select *
from (select * from events where type = "SENSOR_STARTED (58)") as x 
left join events_ID as y 
on x.filepath = y.filepath;
quit;

/*Loop gluc.csv or glucplus.csv*/
data anaplus;
	set &anaplus_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
        input uid: $char16. date: yymmdd10. time: time8. type: $char56. ana: best8. st: best8. tr: best1. nonact: best1.;
        format date date9. time time8.;
		drop uid st--nonact;
        output;
	end;
run;

/*stack*/
data temp;
set events_start anaplus;
format dtm datetime16.;
dtm = dhms(date,0,0,time);
run;

/*Sort by dtm*/
proc sort data = temp; 
by descending filepath dtm;
run;

/*Fill the sensor serial number subject condition_id*/
data temp1;
set temp;
/*Pseudo snr column*/
retain _snr snr_start _subject _condition_id;
if ^missing(snr) then do; 
_snr = snr;
snr_start = dtm; 
_subject = subject;
_condition_id = condition_id;
end;
else do; 
snr = _snr;
subject = _subject;
condition_id = _condition_id;
end;
drop _snr date time _subject _condition_id;
format snr_start datetime16.;
run;

data &out;
retain filepath subject condition_id type snr ana dtm snr_start;
set temp1;
run;

/*Delete temporary data*/
proc delete data = work.events work.events_start work.anaplus work.temp work.temp1 work.events_id;
run;

%mend;

/*%mobi_anaplus(events_path = events_list , anaplus_path = anaplus_list, out = aaaa);*/