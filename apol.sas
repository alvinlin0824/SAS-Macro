/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\014\AUU\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-21206\UploadData\AUU\AUU_DataFiles\*freestyle.csv""";*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\""";*/
/*data events_list apol_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path) then do;*/
/*	if  prxmatch("/(events.csv)/i",path) then output events_list;*/
/*    if  prxmatch("/(glucPlus.csv|gluc.csv)/i",path) then output apol_list;*/
/*	end;*/
/*run;

%macro apol(events_path = , gluc_path = , out = );
/*Loop events.csv Data*/
data events;
	set &events_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
		/*Extract Subject ID*/
		if prxmatch("/ApolADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/ApolADC/i",filepath) + 7,4));
		else if prxmatch("/Apol1/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol1/i",filepath) + 4,7));
		else if prxmatch("/Apol00/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol0/i",filepath) + 6,5));
		else if prxmatch("/Apol0/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol0/i",filepath) + 5,6));
		/*Extract Condition ID*/
    	condition_id = upcase(strip(substr(filepath,prxmatch("/_{7}/",filepath) + 7,3)));
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
data glucplus;
	set &gluc_path;
	infile dummy filevar = path length = reclen end = done missover dlm='2C'x dsd firstobs=4;
	do while(not done);
	    filepath = path;
		/*Extract Subject ID*/
		if prxmatch("/ApolADC/i",filepath) then subject = strip(substr(filepath,prxmatch("/ApolADC/i",filepath) + 7,4));
		else if prxmatch("/Apol1/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol1/i",filepath) + 4,7));
		else if prxmatch("/Apol00/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol0/i",filepath) + 6,5));
		else if prxmatch("/Apol0/i",filepath) then subject = strip(substr(filepath,prxmatch("/Apol0/i",filepath) + 5,6));
		/*Extract Condition ID*/
    	condition_id = upcase(strip(substr(filepath,prxmatch("/_{7}/",filepath) + 7,3)));
		input uid: $char16. date: yymmdd10. time: time8. type: $char56. gl: best8. st: best8. tr: best1. nonact: best1.;
        format date date9. time time8.;
		drop uid st--nonact;
        output;
	end;
run;

/*stack*/
data temp;
set events_start glucplus;
format dtm datetime16.;
dtm = dhms(date,0,0,time);
run;

/*Sort by dtm*/
proc sort data = temp; 
by subject condition_id dtm;
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
proc delete data = work.events work.events_start work.glucplus work.temp;
run;

%mend;

/*%apol(events_path = events_list , gluc_path = apol_list, out = ggg);*/