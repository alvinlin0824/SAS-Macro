/*dir: This is a command in the Windows Command Prompt (cmd) used to list directory contents*/
/*/b: This is a switch used with the dir command to display only the file names, without any additional information like file size, date, or attributes*/
/*/l: This is another switch used with the dir command to display file names in lowercase*/
/*/s: This switch makes the dir command search for files not only in the specified directory but also in all subdirectories*/
/* pipe: symbol |, which is used to take the output of one command and pass it as input to another command*/
/*filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\BG""";*/
filename dir pipe "dir /b/s  ""\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_23238\019\AUU""";

data freestyle_list;
	infile dir truncover;
	input path $256.;
/*	Filter files*/
	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path) then do;
    if  prxmatch("/(freestyle.csv)/i",path) then output freestyle_list;
/*	if  prxmatch("/(xls)/i",path) then output sino_list;*/
	end;
run;

/*data apol_events_list apol_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive|UDP)/i",path) then do;*/
/*	if  prxmatch("/(events.csv)/i",path) then output apol_events_list;*/
/*    if  prxmatch("/(glucPlus.csv)/i",path) then output apol_list;*/
/*	end;*/
/*run;

/*data ana_plus_events_list anaplus_list;*/
/*	infile dir truncover;*/
/*	input path $256.;*/
/*/*	Filter files*/*/
/*	if ^prxmatch("/(Transfer|Transfers|Archives|Archive|Apol|LifeCountTimeStamp)/i",path) then do;*/
/*	if  prxmatch("/(events.csv)/i",path) then output ana_plus_events_list;*/
/*    if  prxmatch("/(anaPlus.csv)/i",path) then output anaplus_list;*/
/*	end;*/
/*run;

/*The MAUTOLOCDISPLAY option controls whether to display the source location of autocall macros in the log when the autocall macro is invoked*/
/*MAUTOSOURCE is turned on, SAS searches the libraries specified in the SASAUTOS system option for macros when a macro name is encountered but not defined in the current session*/
/*The SASAUTOS system option specifies the location of one or more autocall libraries.*/


/*filename dir pipe "dir /b/s  ""C:\Project\ADC-US-VAL-24252\Randox\*.xls""";*/
filename dir pipe "dir /b/s  ""M:\ADC-US-VAL-24251\UploadData\Ketone\Ketone_DataFiles\RCR - 009\2023-07-30_1758\*.xls""";
data randox_list;
	infile dir truncover;
	input path $256.;
/*	Filter files*/
	if ^prxmatch("/(Transfer|Transfers|Archives|Archive|UDP)/i",path);
run;

options mautolocdisplay mautosource sasautos = ("\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_Statistics\Statistics\Alvin\SAS Programs\");
%import_randox(file_list = randox_list, out = aaaa);

/*options mautolocdisplay mautosource sasautos = ("C:\Project\SAS-Macro\");*/

/*%sinocare(file_list = sino_list, out = sino);*/
/*%freestyle(free_path = freestyle_list, out = BG);*/
/*%apol_fsl3(events_path = apol_events_list , gluc_path = apol_list, out = aaaabbb);*/
/*%mobi_anaplus(events_path = ana_plus_events_list , anaplus_path = anaplus_list, out = iiiiii);*/

