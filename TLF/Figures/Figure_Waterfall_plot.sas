**********************************************************************;
* Project           : Sample Drug, Sample Indication,Study1
*
* Program name      : Figure_Waterfall_plot.sas
*
* Author            : H Patel
*
* Date created      : 20230122
*
* Purpose           : Create Waterfall plot for PCHG PSA paramater
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* *
***********************************************************************;


/* Example Waterfall plot */
data adpsa;
	format USUBJID z4. ;
	input  USUBJID PCHG TRT01PN;
datalines;
1001 -86.56  1
1001 -86.56  1
1001 -83.21  1
1002 -95.23  1
1002 -93.28  1
1002 -94.59  1
1002 -96.74  1
1003 -10.34  1
1003 -39.57  1
1004 -93.31  2
1004 -91.73  2
1005 -68.67  1
1006 -57.72  1
1006 -52.73  1
1007 -99.23  1
1007 -98.54  1
1007 -95.35  1
1008 -76.29  2
1009 -68.14  2
1010 -93.21  2
1010 -92.57  2
;
run;

/*preparing dataset*/
proc sort data = adpsa;
	by usubjid pchg;
	where PCHG ne . ;
run;


data adpsa;
   set adpsa;
   by usubjid pchg;
   if first.usubjid;
run;
proc sort; 
	by trt01pn descending pchg;
run;

data bestpsa_;
	set adpsa;
	n = _n_;
run;

/*creating graph*/
ods listing close;
ods rtf style=basic file='/home/u58162301/pgm/dev/psa_waterfall.rtf' style=styles.statistical;
ods graphics on;
proc sgplot data = bestpsa_;
	vbar n/ 
	response = pchg 
	group = trt01pn;
	xaxis label = 'Number of Subject' 
	fitpolicy=thin; 
	yaxis label = 'Best Percentage Change from Baseline'; 
	keylegend / location=inside down=2;
	title "PSA Percent Change Waterfall Plot";
run;
ods graphics off;
ods tagsets.rtf close;
ods listing;
