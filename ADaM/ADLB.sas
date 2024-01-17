**********************************************************************;
* Project           : Sample Drug, Sample Indication,Study1
*
* Program name      : adlb.sas
*
* Author            : H Patel
*
* Date created      : 20230117
*
* Purpose           : Create ADLB sample dataset with various methods for creating ADLB BDS dataset
*
* Revision History  :
*
* Date        Author      Ref    Revision (Date in YYYYMMDD format) 
* *
***********************************************************************;

/* Majority of the conepts required to genearted ADaM.ADLB dataset are presneted below */
/* A robust ADaM specificaiton should be created prior to programming */
/* Programming Workflow step by step for building BDS ADaM finding dataset [ADLB]*/
/*
	Read in Data
	Derive/impute numeric date/time and analysis day (adt, adtm, ady, adtf, atmf)
	Assign PARAMCD (PARAM, PARAMN, PARCAT1 etc.)
	Derive Results (AVAL, AVALC)
	Derive specific parameters (derived based on SAP)
	Derive timing variables (AVISIT,AVISTN, APHASE, APHASEN, APERIOD, APERIODN)
	Timing flag variables (ONTRTFL)
	Assign reference range indicator (ANRIND, BNRIND)
	Derive Baseline (BASE, BASEC, ABLFL, BASETYPE)
	Derive change from baseline (CHG, PCHG)
	Derive shift (SHIFT1, SHIFT2)
	Derive analysis flags (ANL01FL, ANL02FL etc.)
	Assign treatment from DM/ADSL (TRTA, TRTP, TRTAN, TRTPN, TRT01A, TRT01AN etc.)
	Derive catagory variables (AVALCAT1, AVALCATx)
	Assign ASEQ (analysis sequence number)
	Add ADSL variables (based on ADSL subject level variable. Compound/Study specific from ADaM sepcification)
	Derive new rows (additional paramters based SAP and TLF shells)
	Final: Assign attributes (standard variable names, lables, lengths) manual or dataset shell from ADaM spec
*/
/*	End of Programming workflow */
%include "/home/u58162301/Oncology/pgm/setup.sas"; 

/* Sample code for BDS domains */
/* Create new Parameter */
/* Used when creating ADLB from SDTM.LB dataset */
/* Macro can be created if multiple PRAMCD's (lab tests) need to be convered */ 



/*Begin writing SAS program merge SDTM.LB and ADAM.ADSL.sas*/
data ADLB1;
  merge SDTM.LB(in=a) ADAM.ADSL(in=b drop=STUDYID);
  by USUBJID;
  if a and b;
run;
 data ADLB2;
  set ADLB1;
 /*Derive ADT, ATM, ADTM*/
  length PARAMCD $8. PARAM AVALC $40. AVAL 8;
    if length(LBDTC)=10 then do;ADT=input(LBDTC,yymmdd10.);ATM=.;ADTM=.;end;
	if length(LBDTC)>10 then do;ADTM=input(LBDTC,is8601dt.);ADT=datepart(ADTM);ATM=timepart(ADTM);end;
    format ADTM is8601dt. ADT yymmdd10. ATM time5.; 
  
  /*Derive ADY*/
	if nmiss(ADT,TRTSDT)=0 then ADY=ADT-TRTSDT+(ADT>=TRTSDT);

  
/*Derive APHASE, EMDESC*/

	if (ADT<=TRTSDT and ATM=.) or (ADT^=. and ATM^=. and ADTM<=TRT01SDTM) then do;
        APHASE="Screening";
		EMDESC="P";
	end;
	if (ADT > TRTSDT and ATM =.) or (ADT^=. and ATM^=. and ADTM>TRT01SDTM) then do;
	    APHASE="Treatment";
		EMDESC="T";
	 end;
	 if (ADT > TRTEDT and ATM =.) or (ADT^=. and ATM^=. and ADTM>TRT01EDTM) then do ;
	    APHASE="Follow-Up";
		EMDESC="A";
	end;
	

/*Derive PARAM, PARAMCD*/
  PARAM=strip(LBTEST)||" ("||strip(LBORRESU)||")";
  PARAMCD=strip(LBTESTCD);


  
/*Derive AVAL, AVALC, DTYPE*/

   if ^missing(LBSTRESN) then do; 
       AVAL=LBSTRESN;
	   DTYPE="";
	 end;
   else if LBSTRESN=. and ^missing(LBSTRESC) then do;
     if index(LBSTRESC,"<") or index(LBSTRESC,"<=") then do;
	   AVAL=input(compress(LBSTRESC,"<="),best.);
	   DTYPE="IMPUTE";
	 end;
	 if index(LBSTRESC,">") or index(LBSTRESC,">=") then do;
	   AVAL=input(compress(LBSTRESC,">="),best.);
	   DTYPE="IMPUTE";
	 end;
	end;
     
   AVALC=strip(LBSTRESC);

/*Derive TRTP, TRTA*/
	TRTP=TRT01P; 
    TRTA=TRT01A; 
 
run;
/*Derive ABLFL*/
data ADLB2;
  set ADLB2;
  NUMBER=_n_;
run;

proc sort data=ADLB2;
  by USUBJID PARAMCD ADT ADTM;
run;
/*Filter the condition of baseline flag */
data BASE;
  set ADLB2(where=(EMDESC="P" and (AVAL ne . or AVALC ne '')  and (.<ADT<=TRTSDT)));
  by USUBJID PARAMCD ADT ADTM;
run;

 /*if the last PARAMCD then ABLFL sets to �Y� */
data ABLFL;
	set BASE;
	by USUBJID PARAMCD ADT ADTM;
	if last.PARAMCD; ABLFL="Y";
run;
/*Left Join ADLB2 with ABLFL */
proc sql;
	create table ADLB3 as select a.*,b.ABLFL from ADLB2 as a left join ABLFL as b on a.NUMBER=b.NUMBER;
quit;
/*Derive variable Base */
proc sql;
	create table ADLB4 as select a.*,b.AVAL as BASE from ADLB3 as a
    left join ADLB3(where=(ABLFL='Y')) as b on a.USUBJID=b.USUBJID and a.PARAMCD=b.PARAMCD;
quit;
/*Derive variable CHG*/
data ADLB5;
	set ADLB4;
    if n(AVAL,BASE)=2 and ABLFL ne "Y"  then CHG=AVAL-BASE;
	if ABLFL^="Y" and EMDESC="P" then do; CHG=.;end;
run;


/*Derive variable AVISIT and AVISITN*/

data ADLB6;
  set ADLB5;
  length AVISIT $40. AVISITN 8. ;
   if ABLFL="Y" then do; 
         AVISIT="Baseline";
         AVISITN=0;
        end;

	else if index(VISIT,"FOLLOW-UP") then do; 
        AVISIT="Follow-up"; 
        AVISITN=100;
        end;
       else do;
	     AVISIT=strip(VISIT);
		 AVISITN=input(compress(AVISIT,,"kd"),best.);
	   end;

run;

/* Derive rows */

data adlb7;
	set adam.adlb6;
	
   	if PARAMCD = 'CREAT' then do;
*OUTPUT RECORD IN ORIGINAL UNITS;
	output; /* The first output statement is for the original Creatinine (in units of umol/L) */
* UPDATE VARIABLES AND OUTPUT NEW RECORD;
	PARAMCD = 'CREATCV';
	PARAM   = 'Creatinine (mg/dL)';
	PARAMN = 14;
	if AVAL NE . then do;
	AVAL = AVAL / 88.4;
	if BASE NE . then do;
	BASE = BASE / 88.4;
	CHG  = AVAL - BASE;
		end;
			end;
		output; /*The second output statement is for the new Creatinine (in units of mg/dL) */
	end;
	
* OUTPUT ALL OTHER PARAMETERS;
	else output; /*The third output statement is for all the other (non-Creatinine) parameters.*/

run;



proc sort data=ADLB7; by USUBJID PARAMCD ADT ATM DTYPE LBSEQ;run;
/*Derive ASEQ*/
data Final; 
   set ADLB7;
     by USUBJID PARAMCD ADT ATM DTYPE LBSEQ; 
     if first.USUBJID then ASEQ = 0;
     ASEQ+1;
  output;
run;


/* Add libname adam.adlb when outputting final dataset */

data ADLB(label="Lab Test Results Analysis Datasets");
/*Assign variable attributes such as label and length to conform with 
ADAM.ADSL Specification (these will also be the same attributes as the ADAM IG).*/ 
   attrib
	STUDYID		label = "Study Identifier"                   length = $20
	USUBJID		label = "Unique Subject Identifier"          length = $40
	SUBJID		label = "Subject Identifier for the Study"   length = $20
	LBSEQ		label = "Sequence Number"                    length = 8
    ASEQ		label = "Analysis Sequence Number"           length = 8
	TRTP		label = "Planned Treatment"                  length = $40
	TRTA		label = "Actual Treatment"                   length = $40
	ADT			label = "Analysis Date"                      length = 8
	ATM		    label = "Analysis Time"                      length = 8
	ADTM		label = "Analysis Date and Time"             length = 8
	ADY		    label = "Analysis Relative Day"              length = 8
	AVISIT		label = "Analysis Visit"                    length = $40
	AVISITN     label = "Analysis Visit (N)"                length = 8
	APHASE      label = "PHASE"                             length = $40
	PARAM		label = "Parameter"                         length = $40
	PARAMCD		label = "Parameter Code"                   length = $8
	AVAL	    label = "Analysis Value"                    length = 8
	AVALC		label = "Analysis Value (C)"                length = $40
	ABLFL		label = "Baseline Record Flag"              length = $1
	BASE		label = "Baseline Value"                    length = 8
	CHG		    label = "Change from Baseline"              length = 8
	DTYPE 	    label = "Derivation Type"                   length = $20
	EMDESC      label = "Description of Treatment Emergent" length = $20
	LBORRES     label = "Result of Finding in Original Units" length = $100
    LBORRESU    label = "Original Units"                       length = $40
	LBORNRLO    label = "Reference Range Lower Limit in Orig Unit" length = $40
	LBORNRHI    label = "Reference Range Higher Limit in Orig Unit" length = $40
	LBSTNRLO    label = "Reference Range Lower Limit-Std Units"  length = 8
	LBSTNRHI    label = "Reference Range Upper Limit-Std Units"  length = 8
	LBSTRESC    label = "Character Result/ Finding in Std Format" length = $100
	VISIT       label = "Visit Name"                         length = $40
	VISITNUM    label = "Visit Number"                       length = 8
    LBDTC       label = "Date/Time of Lab"                   length = $40
	

	;
  set Final;
   keep STUDYID USUBJID SUBJID LBSEQ ASEQ TRTP TRTA ADT ATM ADTM ADY AVISIT AVISITN APHASE PARAM PARAMCD
        AVAL AVALC ABLFL BASE CHG DTYPE EMDESC LBORRES LBORRESU LBORNRLO LBSTNRHI LBSTNRLO LBSTNRHI 
        LBSTRESC VISIT VISITNUM LBDTC	
	;
run;
