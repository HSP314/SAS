**********************************************************************;
* Project           : Sample Drug, Sample Indication,Study1
*
* Program name      : ae_tbl_macros.sas
*
* Author            : H Patel
*
* Date created      : 20230111
*
* Purpose           : Create Adverse Events table
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* *
***********************************************************************;
/* Reference: A Practical and Efficient Approach in Generating AE  */
/* 	(Adverse Events) Tables within a Clinical Study Environment */
/* https://www.lexjansen.com/nesug/nesug11/cc/cc13.pdf */

/*Macros adapted from referece paper. Common ADSL variables used may be updated*/

Options symbolgen mprint; /*resolve macros parameter and print sas statement from macro code*/

/* Modularize Macros  */

%macro getPopulationDs(inDs=, outDs=) ;
***************Created data for the column subtotal and total;
data &outDs;
	set &inDs;
	output;
	trtan = 5;
	trta = "Total";
	output;
	run;
%mend getPopulation;

%let colNum = &colNum;;

**************************get denominators -- number for each group;
%macro getNum(inDs=);
proc sql;
	select count(distinct trtan) into: colNum from &inDs where trtan
	ne .;
	%let colNum = &colNum;
	select trta into: col1 - : col&colNum from (select distinct trta,
	trtan from &inDs) order by trtan;
	select count(usubjid) into: dcol1 - : dcol&colNum from &inDs
	group by trtan;
quit;


**************create the column header;
%do i = 1 %to &colNum;
%end;
%global count&i;
%let count&i = %str((N=&&dcol&i));
%mend getNum;

/* Frequency Table by Most Severe AE Macro */

%macro getCountPerc(inDs=, inVar=);
proc freq data = &inDs noprint;
	table trtan*&inVar/out=sevCount;
run;

proc sort data = sevCount;
	by trtan &inVar;
run;

proc transpose data=sevCount out=sevCountT prefix=col_;;
	by &inVar;
	var count;
	id trtan ;
run;

data final;
	set sevCountT;
	array arr1(*) col_1 col_2 col_3 col_3_1 col_4 col_5;
	array arr2(*) $12 col_1c col_2c col_3c col_3_1c col_4c col_5c;
	array arr3(6) _temporary_ (&dcol1 &dcol2 &dcol3 &dcol4 &dcol5 &dcol6);
	
	do i = 1 to 6;
		if arr1(i) = . then arr2(i) = "-"; else
		arr2(i) = cat(arr1(i), 3.), " (", put(arr1(i)/arr3(i)*100, 5.1), ")");
	end; 
run;

%mend getCountPerc;


/* Frequency Table by SOC, Preferred Term, and Treatment Group Macro */
%macro aeRepData(adsl=, inDs=, eventCond=, aeDesc=, aeOutcome=,
outDs=report);

********************create pooled data for counting;
%if &eventCond ne %then %let eventCond = %str(and &eventCond);

data aeFin(keep = usubjid aedecod aebodsys &aeOutcome trta trtan);
	set &inDs;
	where aedecod ne "" &eventCond;
	if missing(aebodsys) then aebodsys="Uncoded";
run;

******************************************count statistics;

*********************This data is to count the unique subjects;
*********************It is required in the table;
proc sql ;
	create table aeSubj as select distinct usubjid, trtan, trta,
	max(&aeOutcome) as maxVal from aeFin group by usubjid;
	
	create table aeSoc as select usubjid, trtan, trta, aebodsys,
	set aeSoc;
	max(&aeOutcome) as maxVal from aeFin group by trtan,
	trta, usubjid, aebodsys;
	
	create table aePt as select usubjid, trtan, trta, aebodsys,
	quit;
	aedecod, max(&aeOutcome) as maxVal from aeFin
	group by trtan, trta, usubjid, aebodsys, aedecod;
quit;

****************************************Count number of subjects;
proc freq data = aeSubj noprint;
	table trtan*trta*maxVal/out=subjCount;
run;
proc transpose data=subjCount out=subjCountT prefix=col_;;
	by trtan trta;
	var count;
	id maxVal ;
run;

***************************************************Count SOC;
***get total;
***99 is used to represent the total category;
data aeSocFin;
	output;
	maxVal = 99;
	output;
run;
proc freq data = aeSocFin noprint;
	table trtan*trta*aebodsys*maxVal /out=socCount;
run;
proc sort data = socCount;
	by trtan trta aebodsys;
run;

proc transpose data=socCount out=socCountT prefix=col_;;
	by trtan trta aebodsys;
	var count;
	id maxVal ;
run;

*****************sort SOC;
proc sort data = socCountT;
	by trtan trta descending col_99;
run;
data socCountT;
	set socCountT;
	by trtan trta descending  col_99;
	retain ind 0;
	ind + 1;
run;

**************************************************Count PT;
***get total;
data aePtFin;
	set aePt;
	output;
	maxVal = 99;
	output;
run;
proc freq data = aePtFin noprint;
	table trtan*trta*aebodsys*aedecod*maxVal /out=ptCount;
run;
proc transpose data=ptCount out=ptCountT prefix=col_;;
	by trtan trta aebodsys aedecod;
	var count;
	id maxVal ;
run;

*************Sort the preferred term;
proc sort data = ptCountT;
	by trtan trta aebodsys descending col_99;
run;

data ptCountT;
	set ptCountT;
	by trtan trta aebodsys;
	retain indPt;
	if first.aebodsys then indPt = 1;
	else indPt + 1;
run;

********************************************************stack together;
*********The three parts in the table;

data ae4Count;
set subjCountT(in=a) socCountT(in=b) ptCountT(in=c);
length cat $200;
	if a then do;
	ind = 0;
	cat = "&aeDesc";
	aebodsys = "";
	end;

	if b then cat = aebodsys;
	else if c then cat = cat("  ", strip(aedecod));
run;

*******Populated the sorting key;
proc sql;
	create table countFin as select * from
	(select *, max(ind) as indSoc from ae4Count group by
	trtan, aebodsys ) order by trtan, indSoc, indPt;
	quit;
	
*******************************************get final report data;
********get denominators for each column;
proc sql;
	create table test as (select distinct trta, trtan from &adsl) order by trtan;
quit;

data test2;
	set test;
	length trtaq $200;
	trtaq = quote(strip(trta));
run;

proc sql;
	select trtaq into: trtArr separated by " " from test2;
	select count(usubjid) into: denomArr separated by " "  from
	&adsl group by trtan;
quit;


data &outDs;
	set countFin;
	array trtArr(4) $20 _temporary_ (&trtArr);
	array denomArr(4) _temporary_ (&denomArr);
	array arr1(*) col_1 col_2 col_3 col_4;
	array arr2(*) $12 col_1c col_2c col_3c col_4c;
	drop i j _label_ _name_; do j = 1 to dim(trtArr);
	if trta = trtArr(j) then do;
	do i = 1 to 4;
	if arr1(i) = . then arr2(i) = "-";
	else
	arr2(i) = cat(put(arr1(i), 3.), " (",
	end;
	put(arr1(i)/denomArr(j)*100, 5.1), ")");
	leave;
	end;
	end; 
run;
%mend aeRepData;


*******make the report;

***********************************************************report part;
%macro report(inDs=, width= );
%do i = 1 %to 6;
title9 "&col&i (N=&&dcol&i)";

proc report list nowd missing headline headskip split = '*'
	data=&inDs(where = (trta = "&&col&i"));
	column ("_____" ( indSoc indPt  cat ("Relationship"("________" (col_1c col_2c col_3c col_4c)))));
	define indSoc    /order noprint;
	define indPt     /order noprint;
	define cat       /display width=&width "System Organ Class*
	Preferred Term" left flow;
	define col_1c /display width=14 center "Not Related*n (%)";
	define col_2c /display width=14 center "Unlikely*Related*n (%)";
	define col_3c /display width=14 center "Possibly*Related*n (%)";
	define col_4c /display width=14 center "Related*n (%)";

	break after indSoc/skip;
run;
	%end;
%mend report;