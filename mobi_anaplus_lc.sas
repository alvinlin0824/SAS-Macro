/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-21206\UploadData\AUU\AUU_DataFiles\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""D:\CUT""";*/
/*data ket_anaplus_events_list_lc ket_anaplus_list_lc*/
/*     gluc_anaplus_events_list_lc gluc_anaplus_list_lc;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path) and prxmatch("/(-244)/i",path) then do;*/
/*/*	ketone*/*/
/*		if  prxmatch("/(CrossChan.*?events\.csv)/i",path) and  prxmatch("/(keto)/i",path) then output ket_anaplus_events_list_lc;*/
/*    	if  prxmatch("/(CrossChan_LCTime_anaPlus.csv)/i",path) and prxmatch("/(keto)/i",path) then output ket_anaplus_list_lc;*/
/*/*	glucose*/*/
/*		if  prxmatch("/(CrossChan.*?events\.csv)/i",path) and  prxmatch("/(gluc)/i",path) then output gluc_anaplus_events_list_lc;*/
/*    	if  prxmatch("/(CrossChan_LCTime_anaPlus.csv)/i",path) and prxmatch("/(gluc)/i",path) then output gluc_anaplus_list_lc;*/
/*	end;*/
/*run;

%macro mobi_anaplus_lc(events_path = , anaplus_path = , out = );
/*Loop events.csv Data*/
data events;
	set &events_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=2;
	do while(not done);
	    filepath = path;
        input uid: $char256. date: yymmdd10. time:time8. type: $char56. col_4: $char3. col_5: $char11. col_6: $char4. col_7: best8. col_8: $char9. 
 snr: $char25.;
 		group_number = _N_;
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
data anaplus(drop =  uid);
	set &anaplus_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
        input uid: $char256. date: yymmdd10. time: time8. datelc: yymmdd10. timelc: time8. type: $char56. ana: best8. rate: best8. tr: best1. nonact: best1.;
        format date datelc date9. time timelc time8.;
		group_number = _N_;
		drop uid;
        output;
	end;
run;

/*stack*/
data temp;
set events_start anaplus;
format dtm dtm_lc datetime16.;
dtm = dhms(date,0,0,time);
if missing(dhms(datelc,0,0,timelc)) then dtm_lc = dhms(date,0,0,time);
else dtm_lc = dhms(datelc,0,0,timelc);
run;

/*Sort by dtm*/
proc sort data = temp; 
by group_number dtm_lc;
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
drop _snr date time _subject _condition_id datelc timelc;
format snr_start datetime16.;
run;

proc sql;
create table &out as 
select filepath, subject, condition_id ,type ,snr ,ana , dtm ,dtm_lc ,snr_start
from temp1
order by subject, condition_id, dtm_lc;
quit;

/*data &out;*/
/*retain filepath subject condition_id type snr ana dtm dtm_lc snr_start;*/
/*set temp1;*/
/*run;*/

/*Delete temporary data*/
proc delete data = work.events work.events_start work.anaplus work.temp work.temp1 work.events_id;
run;

%mend;

/*%mobi_anaplus_lc(events_path = ket_anaplus_events_list_lc , */
/*                 anaplus_path = ket_anaplus_list_lc, out = aaaa);*/

