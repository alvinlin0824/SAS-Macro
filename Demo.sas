/*dir: This is a command in the Windows Command Prompt (cmd) used to list directory contents*/
/*/b: This is a switch used with the dir command to display only the file names, without any additional information like file size, date, or attributes*/
/*/l: This is another switch used with the dir command to display file names in lowercase*/
/*/s: This switch makes the dir command search for files not only in the specified directory but also in all subdirectories*/
/* pipe: symbol |, which is used to take the output of one command and pass it as input to another command*/
filename dir pipe "dir /b/s  ""C:\Project\SAS-Macro\""";
/*filename dir pipe "dir /b/s  ""M:\ADC-US-RES-23241\SE02\UploadData\""";*/
data freestyle_list sino_list;
	infile dir truncover;
	input path $256.;
/*	Filter files*/
	if ^prxmatch("/(Transfer|Transfers|Archives|Archive)/i",path) then do;
    if  prxmatch("/(freestyle.csv)/i",path) then output freestyle_list;
	if  prxmatch("/(xls)/i",path) then output sino_list;
	end;
run;

/*options mautolocdisplay mautosource sasautos = ("\\oneabbott.com\dept\ADC\Technical_OPS\Clinical_Affairs\CDM_Statistics\Statistics\Alvin\SAS Programs\");*/
options mautolocdisplay mautosource sasautos = ("C:\Project\SAS-Macro\");

/*%sinocare(file_list = sino_list, out = sino);*/
/*%freestyle(free_path = freestyle_list, out = BG);*/
