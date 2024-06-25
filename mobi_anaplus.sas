/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-21206\UploadData\AUU\AUU_DataFiles\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\""";*/
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
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
		/*Extract Subject ID*/
		if prxmatch("/MobiADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/MobiADC/i",filepath) + 7,4));
        else if prxmatch("/L3_ADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/L3_ADC/i",filepath) + 6,4));
/*        else if prxmatch("/GK_0{3}/i",filepath) then subject = strip(substr(filepath,prxmatch("/GK_0{3}/i",filepath) + 6,5));*/
        else if prxmatch("/GK/i",filepath) then subject = strip(substr(filepath,prxmatch("/GK_/i",filepath) + 4,6));
		else if prxmatch("/Mobi/i",filepath) then subject = strip(substr(filepath,prxmatch("/Mobi/i",filepath) + 4,7));
		else if prxmatch("/L3_\d*/i",filepath) then subject = strip(substr(filepath,prxmatch("/L3_/i",filepath) + 4,6));
		/*Extract Condition ID*/
    	if prxmatch("/MobiADC/i",filepath) then condition_id = upcase(strip(substr(filepath,prxmatch("/MobiADC\d{10}_/i",filepath) + 18,3)));
		else if prxmatch("/L3_ADC/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/L3_ADC\d{4}/i",filepath) + 11,3));
/*		else if prxmatch("/GK_0{3}/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/GK_\d{8}_/i",filepath) + 12,3));*/
        else if prxmatch("/GK/i",filepath) then condition_id = upcase(strip(substr(filepath,prxmatch("/GK_\d{7}_/i",filepath) + 11,3)));
		else if prxmatch("/Mobi/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/_{7}/",filepath) + 7,3));
		else if prxmatch("/L3_\d*/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/L3_\d{7}_/i",filepath) + 11,3));
        input uid: $char256. date: yymmdd10. time:time8. type: $char56. col_4: $char3. col_5: $char11. col_6: $char4. col_7: best8. col_8: $char9. 
 snr: $char11.;
        format date date9. time time8.;
		drop uid col_4-col_8;
        output;
	end;
run;

/*Multiple Sensor Start*/
data events_start;
	set events (where = (type ="SENSOR_STARTED (58)"));
run;

/*Loop gluc.csv or glucplus.csv*/
data anaplus;
	set &anaplus_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
		/*Extract Subject ID*/
		if prxmatch("/MobiADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/MobiADC/i",filepath) + 7,4));
        else if prxmatch("/L3_ADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/L3_ADC/i",filepath) + 6,4));
/*        else if prxmatch("/GK_0{3}/i",filepath) then subject = strip(substr(filepath,prxmatch("/GK_0{3}/i",filepath) + 6,5));*/
        else if prxmatch("/GK/i",filepath) then subject = strip(substr(filepath,prxmatch("/GK_/i",filepath) + 4,6));
		else if prxmatch("/Mobi/i",filepath) then subject = strip(substr(filepath,prxmatch("/Mobi/i",filepath) + 4,7));
		else if prxmatch("/L3_\d*/i",filepath) then subject = strip(substr(filepath,prxmatch("/L3_/i",filepath) + 4,6));
		/*Extract Condition ID*/
    	if prxmatch("/MobiADC/i",filepath) then condition_id = upcase(strip(substr(filepath,prxmatch("/MobiADC\d{10}_/i",filepath) + 18,3)));
		else if prxmatch("/L3_ADC/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/L3_ADC\d{4}/i",filepath) + 11,3));
/*		else if prxmatch("/GK_0{3}/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/GK_\d{8}_/i",filepath) + 12,3));*/
        else if prxmatch("/GK/i",filepath) then condition_id = upcase(strip(substr(filepath,prxmatch("/GK_\d{7}_/i",filepath) + 11,3)));
		else if prxmatch("/Mobi/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/_{7}/",filepath) + 7,3));
		else if prxmatch("/L3_\d*/i",filepath) then condition_id = strip(substr(filepath,prxmatch("/L3_\d{7}_/i",filepath) + 11,3));
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
by descending filepath subject condition_id dtm;
run;

/*Fill the sensor serial number*/
data &out;
set temp;
/*Pseudo snr column*/
retain _snr snr_start;
if ^missing(snr) then do; 
_snr = snr;
snr_start = dtm; 
end;
else do; 
snr = _snr; 
end;
drop _snr date time filename;
format snr_start datetime16.;
run;

/*Delete temporary data*/
proc delete data = work.events work.events_start work.anaplus work.temp;
run;

%mend;

/*%mobi_anaplus(events_path = events_list , anaplus_path = anaplus_list, out = aaaa);*/