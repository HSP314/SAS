**********************************************************************;
* Project           : Sample Drug, Sample Indication,Study1
*
* Program name      : t_14.1.1.sas
*
* Author            : H Patel
*
* Date created      : 20230103
*
* Purpose           : Summarize demographics data for the study.
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* *
***********************************************************************;

/********Good Programming Practice by PhUSE******/
/*https://advance.phuse.global/display/WEL/Good+Programming+Practice+Project+Team*/

****Created Statistics based on Demog table for AGE, SEX, and RACE***;
****Each contain similar coding approach***
****Next step append AGE, SEX, RACE datasets create N numbers using macro variable****;
****Lastly use Proc Report to print Demog Table****;
****TLF shells and programming templates are avaiable based on Data standards****;
****Following Good Programming practice from end to end study programming is crucial****;
****Macros can be created to make this process efficient****;
****For QC purpose outputting final dataset prior to Proc Reprot is one approach****;

****Having a TLF management system using macros is important since a study an have numerious 
	deliveralbes (DMC, Safety, Efficacy, CSR, DSUR etc.)****;
****White Paper: Quality Control and Validation – More than Just PROC COMPARE****;
****https://www.lexjansen.com/phuse/2019/pp/PP08.pdf****;

/*This program is created in SAS OnDemand for Academics*/
/* Sample data obtained from SAS Programming in the Pharmaceutical Industry, Second Edition 2nd Edition
by Jack Shostak (Author)*/
%include "/home/u58162301/Oncology/pgm/setup.sas"; 

****Analysis Results metadata information also used from ADaM spec file****;

****Formats****;
*Having a single Global / Compound / Study level format file is useful for managing formats catalog;
*Below is standalone example;
proc format;
	value trtpn
	1 = "Active"
	0 = "Placebo";
	value sexn
	. = "Missing"
	1 = "Male"
	2 = "Female"
	99 = "Unknown";
	value racen
	1 = "ASIAN"
	2 = "BLACK OR AFRICAN AMERICAN"
	3 = "WHITE"
	4 = "AMERICAN INDIAN OR ALASKA NATIVE"
	5 = "MULTIPLE"
	6 = "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER";
	value ethnicn
	1 = "NOT REPORTED"
	2 = "HISPANIC OR LATINO"
	3 = "NOT HISPANIC OR LATINO"
	99 = "UNKNOWN";
	
****Create Total column****;
data adsl;
	set adam.adsl;
	output;
	trt01pn = 2; /*Create total column where trtpn 2 = Total (Active + Placebo) and append to adsl*/
	output;
run;

****Age Stat****;
****P-value from non-parametric comparison of age means based on SAP/TLF Spec/Shells****;
****https://support.sas.com/documentation/onlinedoc/stat/142/npar1way.pdf****;

***Creates output dataset pvalue***;
proc npar1way 
	data = adsl wilcoxon noprint;
	where trt01pn in (0,1); /*Only include Active and Plecebo. Exclude total (trtp01n=2)*/
	class trt01pn; /*Use class statement to identify group (Active and Plecebo)*/
	var age; /*identify age variable*/
	output out=pvalue wilcoxon;
run;

***Sort ADSL by TRT01PN***;
proc sort data = adsl; by trt01pn; run;

***Geneate Age descriptive statistics***;
***Can use Proc Means or Proc Univariate***; 
***https://documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/procstat/procstat_univariate_details03.htm**/;

***2 straightforward procedures to create descriptive statistics***;

proc univariate 
	data = adsl noprint; *noprint will supress Results window output. 
	/*For data review purpose keeping output in results can be helpfu*/; 
	by trt01pn; *Catagory;
	var age; *Analysis Variable;
	output out = age /*output dataset with descriptive statistics*/
		n = _n
		mean = _mean
		std = _std
		min = _min
		max = _max;
run;
	
****Geneate Age descriptive statistic using Proc Means****;
proc means data =adsl nonobs n mean std min max noprint; /*Use nonobs opiton to supress total (all) records stats*/
	class trt01pn;
	var age;
	output out = agepm n = _n mean = _mean std = _std min = _min max = _max;
run;

****Format Age statistics values -formats should be based on TLF standards Global or Compound****;
data age;
	format n mean std min max $12.; /*create char columns with 12 length*/
	set age;
	n = put (_n, 5.); /*assign formats for char column from statistics colums*/
	mean = put(_mean, 7.1); 
	std = put(_min, 8.2);
	min = put(_min,7.1);
	max = put(_max,7.1);
	drop _n _mean _std _min _max; /*drop statistics column no longer required*/
run;

****Transpose Age Stat into Column for table display****;
proc transpose data = age out = age1
	prefix = col; /*creates col0,col1,col2 (Pacebo, Active, Total)*/;
	var n mean std min max; /*variable to be transposed*/
	id trt01pn; /*transpose catagory var in this case TRTs*/
run;

****Create 1st row for Age statistics - capture p-value****;
data label;
	length label $85; 
	set pvalue(keep=p2_wil rename=(p2_wil = pvalue));
	label = "#S={ font_weight=bold } Age (years)"; 
	/*#S={ font_weight=bold } will be used during report output*/
run;

****Create Age statistics row labels****;
   *This may include text such as "# {nbspace 6} for proc report and pdf/rtf outputs*;
   *TLF shells and programming standards should cover text/format to be displayed in a well thougtout manner*/;
data age2;
length label $85 col0 col1 col2 $25; /*label column, col0 (placebo) col1 (Active), col2 Tot)*/;
	set label age1; /*append label for pvalue and age stat dataset*/
	
*note another option is to use [if then else] statements can be used instead of select*;
	if _n_ > 1 then /*conditional check if records present in dataset*/
	select ;
	when (_NAME_ = 'n') label = "#{nbspace 6}N";
	when (_NAME_ = 'mean') label = "#{nbspace 6}Mean";
	when (_NAME_ = 'std') label = "#{nbspace 6}Standard Deviation";
	when (_NAME_ = 'min') label = "#{nbspace 6}Minimum";
	when (_NAME_ = 'max') label = "#{nbspace 6}Maximum";
	otherwise;
	end;
	

 keep label col0 col1 col2 pvalue; 
run;

**** End of AGE Statistics ****;

****Sex Stat****;
**For counts use Prof Freq**;
proc freq data = adsl noprint;
	where trt01pn ne .; /*include all treated subjects*/
	tables trt01pn * sex / missing outpct out=sexn;
run;

**** Format Sex N and % ****;
data sexn;
	length value $25. sexn 3;
	set sexn;
	where sex ne "";
 	value = put(count,4.) || ' (' || put(pct_row,5.1)||'%)'; 
 	if sex = 'M' then sexn=1; else
 	if sex = 'F' then sexn=2; else
 	if sex = 'U' then sexn=99; 
 	/*count and pct_row are standard var from proc freq*/
run;

proc sort data = sexn; by sexn; run;

**** Transpose Sex Stats ****;
proc transpose data = sexn out = sexn(drop = _name_)
	prefix = col; 
 	by sexn;
 	var value;
 	id trt01pn;
run;

****Chi-square test on Sex compring active and placebo trts****;
/*Statistics test are defined in SAP/TLF Specs*/
proc freq data = adsl noprint ;
	where sex ne "" and trt01pn not in (.,99,2);
	table sex*trt01pn / chisq;
	output out = pvalue pchi;
run;

**** Create Sex first row ****;
data label;
	set pvalue(keep = p_pchi rename=(p_pchi = pvalue));
	length label $85;
	label = "#S={font_weight=bold} Sex";
run;

****Append Sex Desc Stat to Sex P-value and create Sex row labels****;
data sexn;
	length label $85 col0 col1 col2 $25;
	set label sexn;
	if _n_ >1 then label = "#{nbspace 6}" || put(sexn, sexn.);
	keep label col0 col1 col2 pvalue;
run;
	
**** End of SEX Stats ****;

****RACE Stats *****;
*Get freq counts from adsl;
proc freq data=adsl noprint;
	where race ne "";
	tables trt01pn*race / missing outpct out = racen;
run;

**** Format RACE N and % ****;
data racen;
	length value $25;
	set racen;
	where race ne "";
	value = put(count, 4.) || ' (' || put(pct_row,5.1) || '%)';
run;

proc sort data = racen; by race trt01pn; run;

**** Transpose RACE Stats ****;
proc transpose data=racen out=racen(drop=_name_)
	prefix = col;
	by race;
	var value;
	id trt01pn;
run;

****Fishers Exact Test on RACE for TRT -Active / Placebo****;
proc freq data = adsl noprint;
	where race ne "" and trt01pn not in(.,2,99);
	tables race*trt01pn / exact fisher; *exact or exact fisher has been used;
	output out = pvalue exact fisher;
run;

****Create RACE first row ****;
data racen;
	length label $85 col0 col1 col2 $25;
	set label racen;
	if _n_ > 1 then label = "#{nbspace 6}" || put(race, racen.);
	keep label col0 col1 col2 pvalue;
run;

********Append Age, Sex, Race stats datasets/create final dataset prior to Proc Report*****;
data demog;

	set age2 (in=a) sexn (in = b) racen (in=c);
		
	group = sum(a*1, b*2, c*3);/*assigns group number to each section in table*/
	format col0-col2 $25.; /*Possible truncation can occure when appending cols. Assing full format lenght*/
run;

****Geneate N counts used in header****;
****The macro variables can be created start of program as denominotrs for % calculations****;
data _null_;
	set adsl end=eof;
	***Create counter***;
	if trt01pn = 0 then n0+1;
	if trt01pn = 1 then n1+1;
	***Create total counter***;
	if trt01pn in (0,1) then nt+1; /*add condition to ensure only Placebo, Active records considered
	earlier total trt was also created that would double the N for Total*/
	
	***Create macro variables***;
	if eof then do;
	/*use call symput to create macro variable*/
	call symput("n0", compress('(N='||put(n0,4.) ||')'));
	call symput("n1", compress('(N='||put(n1,4.) ||')'));
	call symput("nt", compress('(N='||put(nt,4.) ||')'));
	end;
run;

%put &n0 &n1 &nt; /*check macro var values in log*/

/*Template for report can also be created depending on requirement*/
/*Generally the template is called in using the ODS*/

***Final Step - Proc Report to generate output***;
options nodate nonumber missing=''; /*supress date and page number*/
ods escapechar='#'; /*earlier we added # in text. Now identify as escape char*/
proc report data = demog /*nowindows*/ spacing =1 headline headskip split = "|"; /*output header display options*/
	column (group label col0 col1 col2 pvalue); /*identify display columns*/
	/*define each column and its characteristics*/
	define group / order order = internal noprint; /*group column is used for ordering and will not be printed*/
	define label / display "";
	define col0	 / display style(column)=[asis=on]"Placebo|&n0"; 
	/*use style as is provide label spacing can also be added. Proc Report has many options to display columns*/
	define col1  / display style(column)=[asis=on]"Active|&n1";
	define col2  / display style(column)=[asis=on]"Total|&nt";
	define pvalue / display center " |P-value**" f = pvalue6.4;
	
	compute after group; /*use compuate after to add new line. Additional calculations can also be added*/
		line '#{newline}';
	endcomp;
/*Add titles and footnotes based on TLF shells and TLF metadata*/
	title1 j=l 'Company/Trial Name' j=r 'Page 1 of 1';
	title2 j=c 'Table 14.1.1';
	title3 j=c 'Summary of Demographic and Baseline Characteristics';
	title3 j=c 'ITT Population';
	
	footnote1 j=l "**P-values: Age = Wilcoxon rank-sum, Sex = Pearson's"
				  "chi-square, Race = Fisher's exact test.";
	footnote2 j=l "Created by &sysfunc(getoption(sysin)) on &sysdate9..";
run;
