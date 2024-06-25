%macro sinocare(file_list = , out =);

proc sql noprint;
select path into: sinopath separated by ','
from &file_list;
quit;


%do i = 1 %to %SYSFUNC(countw(%quote(&sinopath), %str(,)));
    	%let individual = %scan(%quote(&sinopath),&i,%str(,)); 

        proc import
  		datafile = "&individual"
  		out = temp
  		dbms = xls
  		replace;
		run;
    
    	data glucose(keep = B C filepath subject condition_id) snr(keep = B filepath rename = (B = snr)) start(keep = B filepath subject condition_id) end(keep = B filepath subject condition_id);
		rowNo = _N_;
		set temp;
		filepath = "&individual";
		subject = substr(filepath,find(filepath,".xls") - 10,6);
		condition_id = upcase(substr(filepath,find(filepath,".xls") - 3,3));
        if rowNo >= 9 then output glucose;
		if rowNo = 5 then output snr;
		if rowNo = 3 then output start;
		if rowNo = 4 then output end;
        run;
         
        data glucose_start_end;
		set glucose start end;
		run;

		proc sql;
		create table temp1 as 
		select * from glucose_start_end as a
        left join snr as b
		on a.filepath = b.filepath;
		quit;
        
        proc append base = out data = temp1 force;
		run;	
     %end;


data &out (keep = filepath subject condition_id dtm snr gl);
retain filepath subject condition_id dtm snr gl;
set out;
format dtm datetime16.;
y = scan(B,5);
m = scan(B,3);
d = compress(scan(B,4),"","A");
if length(d) = 1 then d = cats("0",d);
dt = input(cats(d,m,y),date9.);
t = input(scan(B,1),time5.);
p = scan(B,2);
if p ^= "AM" and substr(B,1,2) ^= "12" then t = t + "12:00"t;
if p = "AM" and substr(B,1,2) = "12" then t = t - "12:00"t;
dtm = dhms(dt,0,0,t);
gl = input(C,best4.);
run;

proc sort data = &out;
by subject dtm;
run;

proc delete data = work.glucose work.snr work.start work.end work.glucose_start_end work.temp work.out work.temp1;
run;

%mend;