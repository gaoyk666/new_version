unit AutoTrans;
{
  ----------------------------------------------------------
  Copyright (c) 2008-2018, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{$HINTS OFF}
{
   Change log
   7-14-2018  Created from Transformer
   9-19-2018  committed
   12-4-2018  Corrected indices for mapping into Yprim
   1-3-2019   Default last nphase nodes of X terminal (2) to same as first neutral node
   3-6-2021  Added code for readability
}

{ You can designate a AutoTrans to be a substation by setting the sub=yes parameter}


interface

USES
   Command, DSSClass, PDClass,Circuit, PDElement, uComplex, UcMatrix, ParserDel, Arraydef, math;


TYPE

   TAutoTrans = class(TPDClass)

     private

       PROCEDURE SetActiveWinding(w:Integer);
       PROCEDURE InterpretAutoConnection(const S:String);
       PROCEDURE InterpretAllConns(const S:String);
       PROCEDURE InterpretAllBuses(const S:String; ActorID:Integer);
       PROCEDURE InterpretAllTaps(const S:String);
       PROCEDURE InterpretAllkVRatings(const S:String);
       PROCEDURE InterpretAllkVARatings(const S:String);
       PROCEDURE InterpretAllRs(const S:String);
       FUNCTION  TrapZero(const Value:Double; DefaultValue:Double):Double;
       FUNCTION  InterpretLeadLag(const S:String):Boolean;

       {PROCEDURE MakeNewBusNameForNeutral(Var NewBusName:String; Nphases:Integer);}
     Protected
       PROCEDURE DefineProperties;
       FUNCTION MakeLike(Const AutoTransfName:String):Integer; Override;
     public
       constructor Create;
       destructor Destroy; override;

       FUNCTION Edit(ActorID : Integer):Integer; override;     // uses global parser
       FUNCTION Init(Handle:Integer; ActorID : Integer):Integer; override;
       FUNCTION NewObject(const ObjName:String):Integer; override;

   End;

   TAutoWinding = class(Tobject)
     Public
        Connection:Integer;
        kVLL,
        VBase,
        kVA,
        puTap   : Double;
        Rpu     : Double;    // on AutoTrans MVABase  (H-X Rating)
        Rdcpu   : Double;    // on AutoTrans MVABase  (H-X Rating)
        Rdcohms : Double;    // for GIC solutions; default to 85% of Rpu
        RdcSpecified : Boolean;

        Y_PPM:    Double;  // Anti Float reactance adder

        {Tap Changer Data}
        TapIncrement,
        MinTap,
        MaxTap:   Double;
        NumTaps:  Integer;

        Procedure ComputeAntiFloatAdder(PPM_Factor, VABase1ph:Double);

        Constructor Create(iWinding:Integer);
        destructor Destroy; Override;
   end;

   AutoWindingArray = Array[1..3] of TAutoWinding;
   pAutoWindingArray = ^AutoWindingArray;

   TAutoTransObj = class(TPDElement)
      Private

        DeltaDirection         :Integer;
        ppm_FloatFactor        :Double; //  parts per million winding float factor
        pctImag                :Double;
        XRConst                :Boolean;

        FUNCTION  Get_PresentTap(i: Integer; ActorID : Integer): double;
        PROCEDURE Set_PresentTap(i: Integer; ActorID : Integer ; const Value: double);
        FUNCTION  Get_MinTap(i: Integer): Double;
        FUNCTION  Get_MaxTap(i: Integer): Double;
        FUNCTION  Get_TapIncrement(i: Integer): Double;
        FUNCTION  Get_BaseVoltage(i: Integer): Double;
        FUNCTION  Get_BasekVLL(i: Integer): Double;
        // CIM accessors
        FUNCTION  Get_NumTaps(i: Integer): Integer;
        FUNCTION  Get_WdgResistance(i: Integer): Double;
        FUNCTION  Get_WdgConnection(i: Integer): Integer;
        FUNCTION  Get_WdgkVA(i: Integer): Double;
        FUNCTION  Get_Xsc(i: Integer): Double;
        FUNCTION  Get_WdgYPPM(i: Integer): Double;

        PROCEDURE CalcY_Terminal(FreqMult:Double; ActorID: Integer);
        PROCEDURE GICBuildYTerminal;

        PROCEDURE BuildYPrimComponent(YPrim_Component, Y_Terminal:TCMatrix);

        PROCEDURE FetchXfmrCode(Const Code:String);

        Function  GeTAutoWindingCurrentsResult(ActorID : Integer):String;

        PROCEDURE SetBusAuto(iwdg: Integer; const s: String; ActorID : Integer);

      Protected
        NumWindings     :Integer;
        MaxWindings     :Integer;
        TermRef         :pIntegerArray;  // keeps track of terminal connections

        puXHX, puXHT,
        puXXT           :Double;  // per unit
        Zbase           :Double;
        puXSC           :pDoubleArray;     // per unit SC measurements
        VABase          :Double;    // FOR impedances
        kVSeries        :Double;   // Rating for Series winding

        ZB              :TCMatrix;
        Y_1Volt         :TCMatrix;
        Y_Term          :TCMatrix;
        Y_1Volt_NL      :TCMatrix;   // No Load Y's
        Y_Term_NL       :TCMatrix;

        Y_Terminal_Freqmult:Double;

        NormMaxHkVA       :Double;
        EmergMaxHkVA      :Double;
        ThermalTimeConst  :Double;  {hr}
        n_thermal         :Double;
        m_thermal         :Double;  {Exponents}
        FLrise            :Double;
        HSrise            :Double;
        pctLoadLoss       :Double;
        pctNoLoadLoss     :Double;

        HVLeadsLV         :Boolean;

        XHXChanged        :Boolean;

        PROCEDURE SetTermRef;
      Public
        ActiveWinding   :Integer;  // public for COM interface

        IsSubstation       :Boolean;
        SubstationName     :String;
        Winding            :pAutoWindingArray;
        XfmrBank           :String;
        XfmrCode           :String;
        CoreType           :Integer; {0=Shell; 1=1ph; 3-3leg; 5=5-leg;4=4-Leg;9=Core-1-phase}
        strCoreType        :String;

        constructor Create(ParClass:TDSSClass; const TransfName:String);
        destructor  Destroy; override;

        PROCEDURE SetNumWindings(N:Integer);

        PROCEDURE RecalcElementData(ActorID : Integer);Override;
        PROCEDURE SetNodeRef(iTerm:Integer; NodeRefArray:pIntegerArray);Override;
        PROCEDURE CalcYPrim(ActorID : Integer);Override;

        {GetLosses override for AutoTrans}
        PROCEDURE GetLosses(Var TotalLosses, LoadLosses, NoLoadLosses:Complex; ActorID: Integer); Override;
        {Getcurrents Override for AutoTrans}
        PROCEDURE GetCurrents(Curr: pComplexArray; ActorID : Integer); Override; // Get present values of terminal

        FUNCTION  RotatePhases(iPhs:integer):Integer;
        FUNCTION  GetPropertyValue(Index:Integer):String;Override;
        PROCEDURE InitPropertyValues(ArrayOffset:Integer);Override;
        PROCEDURE DumpProperties(Var F:TextFile; Complete:Boolean);Override;
        PROCEDURE SaveWrite(Var F:TextFile);Override;
        PROCEDURE GetAutoWindingVoltages(iWind:Integer; VBuffer:pComplexArray; ActorID: Integer);
        PROCEDURE GetAllWindingCurrents(CurrBuffer: pComplexArray; ActorID: Integer);


        PROCEDURE MakePosSequence(ActorID : Integer);Override;  // Make a positive Sequence Model

        Property PresentTap[i:Integer;ActorID: Integer]:Double read Get_PresentTap write Set_PresentTap;
        Property Mintap[i:Integer]       :Double Read Get_MinTap;
        Property Maxtap[i:Integer]       :Double Read Get_MaxTap;
        Property TapIncrement[i:Integer] :Double Read Get_TapIncrement;
        Property BaseVoltage[i:Integer]  :Double Read Get_BaseVoltage;  // Winding VBase
        Property BasekVLL[i:Integer]     :Double Read Get_BasekVLL;  // Winding VBase

        // CIM accessors
        Property NumTaps[i:Integer]       :Integer Read Get_NumTaps;
        Property NumberOfWindings         :Integer Read NumWindings;
        Property WdgResistance[i:Integer] :Double  Read Get_WdgResistance;
        Property WdgkVA[i:Integer]        :Double  Read Get_WdgkVA;
        Property WdgConnection[i:Integer] :Integer Read Get_WdgConnection;
        Property WdgYPPM[i:Integer]       :Double  Read Get_WdgYPPM;
        Property XscVal[i:Integer]        :Double  Read Get_Xsc;
        Property XhlVal:Double Read puXHX;
        Property XhtVal:Double Read puXHT;
        Property XltVal:Double Read puXXT;
        Property NormalHkVA: Double Read NormMaxHkVA;
        Property EmergHkVA: Double Read EmergMaxHkVA;
        Property thTau: Double Read ThermalTimeConst;
        Property thN: Double Read n_thermal;
        Property thM: Double Read m_thermal;
        Property thFLRise: Double Read FLRise;
        Property thHSRise: Double Read HSRise;
        Property loadLossPct:Double Read pctLoadLoss;
        Property noLoadLossPct:Double Read pctNoLoadLoss;
        Property imagPct: Double Read pctImag;
        Property ppmFloatFac: Double Read ppm_FloatFactor;
        Property baseVA: Double Read VAbase;
   end;

VAR
   ActiveAutoTransObj :TAutoTransObj;
   AutoTransClass     :TAutoTrans;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
IMPLEMENTATION

{$DEFINE  NOAUTOTRANDEBUG} {NOAUTOTRANDEBUG AUTOTRANDEBUG}

USES    DSSClassDefs, DSSGlobals, Sysutils, Utilities, XfmrCode;

var
   XfmrCodeClass:TXfmrCode;

Const NumPropsThisClass = 42;
      WYE = 0;
      DELTA = 1;
      SERIES = 2;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
constructor TAutoTrans.Create;  // Creates superstructure for all AutoTrans objects
Begin
     Inherited Create;
     Class_Name   := 'AutoTrans';
     DSSClassType := DSSClassType + AUTOTRANS_ELEMENT; // override PDElement   (kept in both actually)

     ActiveElement := 0;
     XfmrCodeClass := Nil;

     DefineProperties;

     {Make space for AutoTrans property list}
     CommandList := TCommandList.Create(PropertyName, NumProperties);
     CommandList.Abbrev := TRUE;     {Allow property list abbreviations}

     AutoTransClass := Self;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Destructor TAutoTrans.Destroy;

Begin
    // ElementList and  CommandList freed in inherited destroy
    Inherited Destroy;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.DefineProperties;
Begin

     Numproperties := NumPropsThisClass;
     CountProperties;   // Get inherited property count
     AllocatePropertyArrays;

{ Define Property names  }

     PropertyName^[1] := 'phases';
     PropertyName^[2] := 'windings';

   // Winding Definition
     PropertyName^[3] := 'wdg';
     PropertyName^[4] := 'bus';
     PropertyName^[5] := 'conn';
     PropertyName^[6] := 'kV'; // FOR 2-and 3- phase always kVLL ELSE actual winding KV
     PropertyName^[7] := 'kVA';
     PropertyName^[8] := 'tap';
     PropertyName^[9] := '%R';
     PropertyName^[10] := 'Rdcohms';
     PropertyName^[11] := 'Core';

   // General Data
     PropertyName^[12] := 'buses';
     PropertyName^[13] := 'conns';
     PropertyName^[14] := 'kVs';
     PropertyName^[15] := 'kVAs';
     PropertyName^[16] := 'taps';
     PropertyName^[17] := 'XHX';
     PropertyName^[18] := 'XHT';
     PropertyName^[19] := 'XXT';
     PropertyName^[20] := 'XSCarray';  // x12 13 14... 23 24.. 34 ..
     PropertyName^[21] := 'thermal';
     PropertyName^[22] := 'n';
     PropertyName^[23] := 'm';
     PropertyName^[24] := 'flrise';
     PropertyName^[25] := 'hsrise';
     PropertyName^[26] := '%loadloss';
     PropertyName^[27] := '%noloadloss';
     PropertyName^[28] := 'normhkVA';
     PropertyName^[29] := 'emerghkVA';
     PropertyName^[30] := 'sub';  // =y/n
     PropertyName^[31] := 'MaxTap';
     PropertyName^[32] := 'MinTap';
     PropertyName^[33] := 'NumTaps';
     PropertyName^[34] := 'subname';
     PropertyName^[35] := '%imag';
     PropertyName^[36] := 'ppm_antifloat';
     PropertyName^[37] := '%Rs';

     PropertyName^[38] := 'bank';
     PropertyName^[39] := 'XfmrCode';
     PropertyName^[40] := 'XRConst';
     PropertyName^[41] := 'LeadLag';
     PropertyName^[42] := 'WdgCurrents';


     // define Property help values
     PropertyHelp^[1] := 'Number of phases this AutoTrans. Default is 3.';
     PropertyHelp^[2] := 'Number of windings, this AutoTranss. (Also is the number of terminals) '+
                        'Default is 2. This property triggers memory allocation for the AutoTrans and will cause other properties to revert to default values.';
   // Winding Definition
     PropertyHelp^[3] := 'Set this = to the number of the winding you wish to define.  Then set '+
                        'the values for this winding.  Winding 1 is always the Series winding. ' +
                        'Winding 2 is always Common winding (wye connected). ' +
                        'Repeat for each winding.  Alternatively, use '+
                        'the array collections (buses, kVAs, etc.) to define the windings.  Note: '+
                        'reactances are BETWEEN pairs of windings; they are not the property of a single winding.';
     PropertyHelp^[4] := 'Bus connection spec for this winding.';
     PropertyHelp^[5] := 'Connection of this winding {Series, wye*, Delta, LN, LL }. Default is "wye" with the neutral solidly grounded. ' + CRLF +
                        'For AutoTrans, Winding 1 is always Series and Winding 2 (the Common winding) is always Wye. ' + CRLF +
                        'If only 2 windings, no need to specify connections.';
     PropertyHelp^[6] := 'For 2-or 3-phase, enter phase-phase kV rating.  Otherwise, kV rating of the actual winding. '+
                        'Specify H terminal kV rating for Series winding.';
     PropertyHelp^[7] := 'Base kVA rating of the winding. Side effect: forces change of max normal and emerg kVA ratings.' +
                        'If 2-winding AutoTrans, forces other winding to same value. ' +
                        'When winding 1 is defined, all other windings are defaulted to the same rating ' +
                        'and the first two winding resistances are defaulted to the %loadloss value.';
     PropertyHelp^[8] := 'Per unit tap that this winding is on.';
     PropertyHelp^[9] := 'Percent ac resistance this winding.  This value is for the power flow model.'+
                        'Is derived from the full load losses in the transformer test report.';
     PropertyHelp^[10] := 'Winding dc resistance in OHMS. Specify this for GIC analysis. From transformer test report (divide by number of phases). ' +
                         'Defaults to 85% of %R property (the ac value that includes stray losses).';
     PropertyHelp^[11] := '{Shell*|5-leg|3-Leg|1-phase|core-1-phase|4-leg} Core Type. Used for GIC analysis in auxiliary programs. Not used inside OpenDSS.';

   // General Data
     PropertyHelp^[12] := 'Use this to specify all the bus connections at once using an array. Example:'+CRLF+CRLF+
                         'New AutoTrans.T1 buses=[Hbus, Xbus]';
     PropertyHelp^[13] := 'Use this to specify all the Winding connections at once using an array. Example:'+CRLF+CRLF+
                         'New AutoTrans.T1 buses=[Hbus, Xbus] '+
                         '~ conns=(series, wye)';
     PropertyHelp^[14] := 'Use this to specify the kV ratings of all windings at once using an array. Example:'+CRLF+CRLF+
                         'New AutoTrans.T1 buses=[Hbus, Xbus] '+CRLF+
                         '~ conns=(series, wye)'+CRLF+
                         '~ kvs=(115, 12.47)'+CRLF+CRLF+
                         'See kV= property for voltage rules.';
     PropertyHelp^[15] := 'Use this to specify the kVA ratings of all windings at once using an array.';
     PropertyHelp^[16] := 'Use this to specify the p.u. tap of all windings at once using an array.';
     PropertyHelp^[17] := 'Use this to specify the percent reactance, H-L (winding 1 to winding 2).  Use '+
                         'for 2- or 3-winding AutoTranss. On the kVA base of winding 1(H-X). ';
     PropertyHelp^[18] := 'Use this to specify the percent reactance, H-T (winding 1 to winding 3).  Use '+
                         'for 3-winding AutoTranss only. On the kVA base of winding 1(H-X). ';
     PropertyHelp^[19] := 'Use this to specify the percent reactance, L-T (winding 2 to winding 3).  Use '+
                         'for 3-winding AutoTranss only. On the kVA base of winding 1(H-X).  ';
     PropertyHelp^[20] := 'Use this to specify the percent reactance between all pairs of windings as an array. '+
                         'All values are on the kVA base of winding 1.  The order of the values is as follows:'+CRLF+CRLF+
                         '(x12 13 14... 23 24.. 34 ..)  '+CRLF+CRLF+
                         'There will be n(n-1)/2 values, where n=number of windings.';
     PropertyHelp^[21] := 'Thermal time constant of the AutoTrans in hours.  Typically about 2.';
     PropertyHelp^[22] := 'n Exponent for thermal properties in IEEE C57.  Typically 0.8.';
     PropertyHelp^[23] := 'm Exponent for thermal properties in IEEE C57.  Typically 0.9 - 1.0';
     PropertyHelp^[24] := 'Temperature rise, deg C, for full load.  Default is 65.';
     PropertyHelp^[25] := 'Hot spot temperature rise, deg C.  Default is 15.';
     PropertyHelp^[26] := 'Percent load loss at full load. The %R of the High and Low windings (1 and 2) are adjusted to agree at rated kVA loading.';
     PropertyHelp^[27] := 'Percent no load losses at rated excitatation voltage. Default is 0. Converts to a resistance in parallel with the magnetizing impedance in each winding.';
     PropertyHelp^[28] := 'Normal maximum kVA rating of H winding (winding 1+2).  Usually 100% - 110% of'+
                         'maximum nameplate rating, depending on load shape. Defaults to 110% of kVA rating of Winding 1.';
     PropertyHelp^[29] := 'Emergency (contingency)  kVA rating of H winding (winding 1+2).  Usually 140% - 150% of'+
                         'maximum nameplate rating, depending on load shape. Defaults to 150% of kVA rating of Winding 1.';
     PropertyHelp^[30] := '={Yes|No}  Designates whether this AutoTrans is to be considered a substation.'+
                         'Default is No.';  // =y/n

     PropertyHelp^[31] := 'Max per unit tap for the active winding.  Default is 1.10';
     PropertyHelp^[32] := 'Min per unit tap for the active winding.  Default is 0.90';
     PropertyHelp^[33] := 'Total number of taps between min and max tap.  Default is 32 (16 raise and 16 lower taps about the neutral position). The neutral position is not counted.';
     PropertyHelp^[34] := 'Substation Name. Optional. Default is null. If specified, printed on plots';
     PropertyHelp^[35] := 'Percent magnetizing current. Default=0.0. Magnetizing branch is in parallel with windings in each phase. Also, see "ppm_antifloat".';
     PropertyHelp^[36] := 'Default=1 ppm.  Parts per million of AutoTrans winding VA rating connected to ground to protect against accidentally floating a winding without a reference. ' +
                         'If positive then the effect is adding a very large reactance to ground.  If negative, then a capacitor.';
     PropertyHelp^[37] := 'Use this property to specify all the winding ac %resistances using an array. Example:'+CRLF+CRLF+
                         'New AutoTrans.T1 buses=[Hibus, lowbus] ' +
                         '~ %Rs=(0.2  0.3)';
     PropertyHelp^[38] := 'Name of the bank this transformer is part of, for CIM, MultiSpeak, and other interfaces.';
     PropertyHelp^[39] := 'Name of a library entry for transformer properties. The named XfmrCode must already be defined.';

     PropertyHelp^[40] := '={Yes|No} Default is NO. Signifies whether or not the X/R is assumed contant for harmonic studies.';
     PropertyHelp^[41] := '{Lead | Lag (default) | ANSI (default) | Euro } Designation in mixed Delta-wye connections the '+
                         'relationship between HV to LV winding. Default is ANSI 30 deg lag, e.g., Dy1 of Yd1 vector group. ' +
                         'To get typical European Dy11 connection, specify either "lead" or "Euro"';
     PropertyHelp^[42] := '(Read only) Makes winding currents available via return on query (? AutoTrans.TX.WdgCurrents). ' +
                         'Order: Phase 1, Wdg 1, Wdg 2, ..., Phase 2 ...';

     ActiveProperty := NumPropsThisClass;
     inherited DefineProperties;  // Add defs of inherited properties to bottom of list

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION TAutoTrans.NewObject(const ObjName:String):Integer;
Begin
   // create a new object of this class and add to list
   WITH ActiveCircuit[ActiveActor] Do Begin

      ActiveCktElement := TAutoTransObj.Create(Self, ObjName);
      Result           := AddObjectToList(ActiveDSSObject[ActiveActor]);  // Return index of AutoTrans in AutoTrans list

   End;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION TAutoTrans.Edit(ActorID : Integer):Integer;
{
  A Transf Defaults to 3-phases, 2-windings (both wye)
}
VAR
   ParamPointer,
   i             :Integer;
   ParamName     :String;  {For parsing property names}
   Param         :String;

Begin
  // continue parsing cmdline presently in Parser

  {Make this object the active circuit element}
  ActiveAutoTransObj := ElementList.Active;
  ActiveCircuit[ActorID].ActiveCktElement := ActiveAutoTransObj;  // use property to set this value

  Result := 0;

  WITH ActiveAutoTransObj Do
   Begin
     XHXChanged   := False;
     ParamPointer := 0;
     ParamName    := Parser[ActorID].NextParam;
     Param        := Parser[ActorID].StrValue;
     WHILE Length(Param)>0 Do Begin
         IF Length(ParamName) = 0 THEN Inc(ParamPointer)
         ELSE ParamPointer := CommandList.GetCommand(ParamName);

         IF (ParamPointer>0) and (ParamPointer<=NumProperties) THEN PropertyValue[ParamPointer]:= Param;

         CASE ParamPointer OF
            0: DoSimpleMsg('Unknown parameter "' + ParamName + '" for Object "AutoTrans.' + Name + '"', 100110);
            1: Nphases   := Parser[ActorID].IntValue;
            2: SetNumWindings(Parser[ActorID].IntValue); // Reallocate stuff if bigger
            3: SetActiveWinding(Parser[ActorID].IntValue);
            4: SetbusAuto(ActiveWinding, param, ActorID);
            5: InterpretAutoConnection(Param);
            6: Winding^[ActiveWinding].kVLL  := parser[ActorID].Dblvalue;
            7: Winding^[ActiveWinding].kVA   := parser[ActorID].Dblvalue;
            8: Winding^[ActiveWinding].puTap := parser[ActorID].Dblvalue;
            9: Winding^[ActiveWinding].Rpu   := parser[ActorID].Dblvalue * 0.01;  // %R
           10: Winding^[ActiveWinding].RdcOhms := Parser[ActorID].DblValue;
           11: strCoreType := Param;
           12: InterpretAllBuses(Param, ActorID);
           13: InterpretAllConns(Param);
           14: InterpretAllkVRatings(Param);
           15: InterpretAllkVARatings(Param);
           16: InterpretAllTaps(Param);
           17: puXHX :=  TrapZero(parser[ActorID].Dblvalue, 7.0) * 0.01;
           18: puXHT :=  TrapZero(parser[ActorID].Dblvalue, 35.0) * 0.01;
           19: puXXT :=  TrapZero(parser[ActorID].Dblvalue, 30.0) * 0.01;
           20: Parser[ActorID].ParseAsVector(((NumWindings - 1) * NumWindings div 2), puXsc);
           21: ThermalTimeConst := Parser[ActorID].DblValue;
           22: n_thermal        := Parser[ActorID].DblValue;
           23: m_thermal        := Parser[ActorID].DblValue;
           24: FLrise           := Parser[ActorID].DblValue;
           25: HSRise           := Parser[ActorID].DblValue;
           26: pctLoadLoss      := Parser[ActorID].DblValue;
           27: pctNoLoadLoss    := Parser[ActorID].DblValue;
           28: NormMaxHkVA      := Parser[ActorID].Dblvalue;
           29: EmergMaxHkVA     := Parser[ActorID].Dblvalue;
           30: IsSubstation     := InterpretYesNo(Param);
           31: Winding^[ActiveWinding].MaxTap  := Parser[ActorID].DblValue;
           32: Winding^[ActiveWinding].MinTap  := Parser[ActorID].DblValue;
           33: Winding^[ActiveWinding].NumTaps := Parser[ActorID].IntValue;
           34: SubstationName   := Param;
           35: pctImag          := Parser[ActorID].DblValue;
           36: ppm_FloatFactor  := Parser[ActorID].DblValue * 1.0e-6;
           37: InterpretAllRs(Param);
           38: {XfmrBank := Param};
           39: FetchXfmrCode (Param);    // Do nothing until we define auto code
           40: XRConst := InterpretYesNo(Param);
           41: HVLeadsLV := InterpretLeadLag(Param);
           42: PropertyValue[45] := '';  // placeholder, do nothing just throw value away if someone tries to set it.
         ELSE
           // Inherited properties
              ClassEdit(ActiveAutoTransObj, ParamPointer - NumPropsThisClass)
         End;

         {Take care of properties that require some additional work,}
         CASE ParamPointer OF
           1: NConds := 2 * Fnphases;  // Force redefinition of number of conductors and reallocation of matrices
         // YPrim is built with windings not connected.  Connected in NodeRef
          // default all winding kVAs to first winding so latter Donot have to be specified
           7:IF (ActiveWinding = 1) THEN
              Begin
                 FOR i := 2 to NumWindings Do Winding^[i].kVA := Winding^[1].kVA;
                 NormMaxHkVA     := 1.1 * Winding^[1].kVA;    // Defaults for new winding rating.
                 EmergMaxHkVA    := 1.5 * Winding^[1].kVA;
              End Else If NumWindings=2 Then
              Begin
                  Winding^[1].kVA := Winding^[2].kVA;  // For 2-winding, force both kVAs to be same
              End;
           // Update LoadLosskW if winding %r changed. Using only windings 1 and 2
           9: pctLoadLoss := (Winding^[1].Rpu + Winding^[2].Rpu) * 100.0;
          10: Winding^[ActiveWinding].RdcSpecified := TRUE;
          11: CoreType    := InterpretCoreType(Param); // Assign integer number
          15: Begin
               NormMaxHkVA  := 1.1 * Winding^[1].kVA;    // Defaults for new winding rating.
               EmergMaxHkVA := 1.5 * Winding^[1].kVA;
              End;
          17..19: XHXChanged := True;
          20: For i := 1 to ((NumWindings - 1) * NumWindings div 2) Do puXSC^[i] := puXSC^[i]*0.01;  // Convert to per unit

          26: Begin    // Assume load loss is split evenly  between windings 1 and 2
                 Winding^[1].Rpu := pctLoadLoss/2.0/100.0;
                 Winding^[2].Rpu := Winding^[1].Rpu;
              End;
          37: pctLoadLoss := (Winding^[1].Rpu + Winding^[2].Rpu) * 100.0;  // Update
          38: DoSimpleMsg('Bank Property not used with AutoTrans object.', 100130);
          39: DoSimpleMsg('XFmrCode Property not used with AutoTrans object.', 100131);
         ELSE
         End;

         //YPrim invalidation on anything that changes impedance values
         CASE ParamPointer OF
           5..19  : YprimInvalid[ActorID] := TRUE;
           26..27 : YprimInvalid[ActorID] := TRUE;
           35..37 : YprimInvalid[ActorID] := TRUE;
         ELSE
         End;

         {Advance to next property on input line}
         ParamName := Parser[ActorID].NextParam;
         Param     := Parser[ActorID].StrValue;
     End;

     RecalcElementData(ActorID);
  End;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.SetActiveWinding(w:Integer);

Begin
   WITH ActiveAutoTransObj DO
    IF   (w > 0) And (w <= NumWindings) THEN ActiveWinding := w
    ELSE DoSimpleMsg('Wdg parameter invalid for "' + ActiveAutoTransObj.Name + '"', 100112);
End;

function TAutoTrans.TrapZero(const Value: Double; DefaultValue: Double): Double;
begin
     if Value=0.0 then
     Begin
       Dosimplemsg('Zero Reactance specified for AutoTrans.' + ActiveAutoTransObj.Name, 10011201);
       Result := DefaultValue;
     End
     else Result := Value;
end;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAutoConnection(const S:String);

// Accepts
//    delta or LL           (Case insensitive)
//    Y, wye, or LN

Begin
        WITH ActiveAutoTransObj Do  Begin
            WITH Winding^[ActiveWinding] Do
            Begin
                 Case ActiveWinding of
                   1: Connection := SERIES;  // First Winding always Series
                   2: Connection := WYE;  // Second Winding is always Common and Wye
                 Else
                     CASE lowercase(S)[1] OF
                       'y','w': Connection := WYE;  {Wye}
                       'd': Connection := DELTA;  {Delta or line-Line}
                       'l': CASE lowercase(s)[2] OF
                            'n': Connection := WYE;
                            'l': Connection := DELTA;
                            End;
                     End;
                 End;
            End;
            Yorder := fNConds * fNTerms;
            YPrimInvalid[ActiveActor] := True;
        End;
End;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAllConns(const S:String);
//  routine expecting all winding connections expressed in one array of strings
VAR
    S1,
    S2  :String;
    i   :Integer;
Begin

    AuxParser[ActiveActor].CmdString := S;  // Load up Parser

    {Loop for no more than the expected number of windings}
    WITH ActiveAutoTransObj DO
    FOR i := 1 to Numwindings Do
      Begin
         ActiveWinding := i;
         S1 := AuxParser[ActiveActor].NextParam; // ignore any parameter name  not expecting any
         S2 := AuxParser[ActiveActor].StrValue;
         IF Length(S2)>0 THEN InterpretAutoConnection(S2);
      End;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAllBuses(const S:String; ActorID:Integer);
//  routine expecting all winding bus connections expressed in one array of strings
VAR
    BusNam  :String;
    i       :Integer;
Begin

    AuxParser[ActorID].CmdString := S;  // Load up Parser

    {Loop for no more than the expected number of windings;  Ignore omitted values}
    WITH ActiveAutoTransObj DO
      FOR i := 1 to Numwindings Do Begin
           ActiveWinding := i;
           AuxParser[ActorID].NextParam; // ignore any parameter name  not expecting any
           BusNam := AuxParser[ActorID].StrValue;
           IF Length(BusNam)>0 THEN SetBusAuto(ActiveWinding, BusNam, ActorID);
      End;

End;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION TAutoTrans.InterpretLeadLag(const S:String):Boolean;
//  routine expecting all winding bus connections expressed in one array of strings
Begin

    Result := FALSE;   // default to ANSI 30 Deg Lag if can't understand S

    if CompareTextShortest(S, 'lead')=0       then Result := TRUE
    Else if CompareTextShortest(S, 'euro')=0  then Result := TRUE;

End;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAllkVRatings(const S:String);
//  routine expecting all winding kV ratings expressed in one array of strings
VAR
    DataStr:String;
    i:Integer;
Begin

    AuxParser[ActiveActor].CmdString := S;  // Load up Parser

    {Loop for no more than the expected number of windings;  Ignore omitted values}
    WITH ActiveAutoTransObj DO
      For i := 1 to Numwindings Do  Begin
           ActiveWinding := i;
           AuxParser[ActiveActor].NextParam; // ignore any parameter name  not expecting any
           DataStr := AuxParser[ActiveActor].StrValue;
           IF Length(DataStr) > 0 THEN Winding^[ActiveWinding].kVLL := AuxParser[ActiveActor].Dblvalue;
      End;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAllkVARatings(const S:String);
//  routine expecting all winding ratings expressed in one array of strings
VAR
    DataStr  :String;
    i        :Integer;
Begin

    AuxParser[ActiveActor].CmdString := S;  // Load up Parser

    {Loop for no more than the expected number of windings;  Ignore omitted values}
    WITH ActiveAutoTransObj DO
      For i := 1 to Numwindings Do Begin
         ActiveWinding := i;
         AuxParser[ActiveActor].NextParam; // ignore any parameter name  not expecting any
         DataStr := AuxParser[ActiveActor].StrValue;
         IF Length(DataStr) > 0 THEN Winding^[ActiveWinding].kVA := AuxParser[ActiveActor].Dblvalue;
      End;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAllRs(const S:String);
//  routine expecting all winding ratings expressed in one array of strings
VAR
    DataStr  :String;
    i        :Integer;
Begin

    AuxParser[ActiveActor].CmdString := S;  // Load up Parser

    {Loop for no more than the expected number of windings;  Ignore omitted values}
    WITH ActiveAutoTransObj DO
      FOR i := 1 to Numwindings Do Begin
         ActiveWinding := i;
         AuxParser[ActiveActor].NextParam; // ignore any parameter name  not expecting any
         DataStr := AuxParser[ActiveActor].StrValue;
         IF Length(DataStr) > 0 THEN Winding^[ActiveWinding].Rpu := AuxParser[ActiveActor].Dblvalue * 0.01;
      End;

End;



//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTrans.InterpretAllTaps(const S:String);
//  routine expecting all winding taps expressed in one array of strings
VAR
    DataStr  :String;
    i        :Integer;
Begin

    AuxParser[ActiveActor].CmdString := S;  // Load up Parser

    {Loop for no more than the expected number of windings;  Ignore omitted values}
    WITH ActiveAutoTransObj DO
      FOR i := 1 to Numwindings Do Begin
           ActiveWinding := i;
           AuxParser[ActiveActor].NextParam; // ignore any parameter name,  not expecting any
           DataStr := AuxParser[ActiveActor].StrValue;
           IF Length(DataStr) > 0 THEN Winding^[ActiveWinding].puTap := AuxParser[ActiveActor].Dblvalue;
      End;

End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION TAutoTrans.MakeLike(Const AutoTransfName:String):Integer;
VAR
   OtherTransf :TAutoTransObj;
   i           :Integer;

Begin
   Result := 0;
   {See if we can find this Transf name in the present collection}
   OtherTransf := Find(AutoTransfName);
   IF OtherTransf<>Nil THEN
   WITH ActiveAutoTransObj Do
     Begin
       Nphases := OtherTransf.Fnphases;
       SetNumWindings(OtherTransf.NumWindings);
       NConds := 2 * Fnphases; // forces reallocation of terminals and conductors

       Yorder := fNConds*fNTerms;
       YPrimInvalid[ActiveActor] := True;

       FOR i := 1 to NumWindings DO
       WITH Winding^[i] Do
         Begin
             Connection := OtherTransf.Winding^[i].Connection;
             kVLL       := OtherTransf.Winding^[i].kVLL;
             kVSeries   := OtherTransf.kVSeries;
             VBase      := OtherTransf.Winding^[i].VBase;
             kVA        := OtherTransf.Winding^[i].kVA;
             puTAP      := OtherTransf.Winding^[i].puTAP;
             Rpu        := OtherTransf.Winding^[i].Rpu;
             RdcOhms    := OtherTransf.Winding^[i].RdcOhms;
             RdcSpecified  := OtherTransf.Winding^[i].RdcSpecified;
             // copy the taps
             TapIncrement := OtherTransf.Winding^[i].TapIncrement;
             MinTap       := OtherTransf.Winding^[i].MinTap;
             MaxTap       := OtherTransf.Winding^[i].MaxTap;
             NumTaps      := OtherTransf.Winding^[i].NumTaps;
         End;

       SetTermRef;

       puXHX := OtherTransf.puXHX;
       puXHT := OtherTransf.puXHT;
       puXXT := OtherTransf.puXXT;

       FOR i := 1 to (NumWindings*(NumWindings-1) div 2) DO puXSC^[i] := OtherTransf.puXSC^[i];

       ZB.CopyFrom(OtherTransf.ZB);
       Y_1Volt.CopyFrom(OtherTransf.Y_1Volt);
       Y_Term.CopyFrom(OtherTransf.Y_Term);
       Y_1Volt_NL.CopyFrom(OtherTransf.Y_1Volt_NL);
       Y_Term_NL.CopyFrom(OtherTransf.Y_Term_NL);

       ThermalTimeConst := OtherTransf.ThermalTimeConst;
       n_thermal        := OtherTransf.n_thermal;
       m_thermal        := OtherTransf.m_thermal;
       FLrise           := OtherTransf.FLrise;
       HSrise           := OtherTransf.HSrise;
       pctLoadLoss      := OtherTransf.pctLoadLoss;
       pctNoLoadLoss    := OtherTransf.pctNoLoadLoss;
       NormMaxHkVA      := OtherTransf.NormMaxHkVA;
       EmergMaxHkVA     := OtherTransf.EmergMaxHkVA;
       XRConst          := OtherTransf.XRConst;

       XfmrBank         := OtherTransf.XfmrBank;
       XfmrCode         := OtherTransf.XfmrCode;

       ClassMakeLike(OtherTransf);

       For i := 1 to ParentClass.NumProperties Do
          // skip read only properties
          if i<> 45 then PropertyValue[i] := OtherTransf.PropertyValue[i];
       Result := 1;
   End
   ELSE  DoSimpleMsg('Error in AutoTrans MakeLike: "' + AutoTransfName + '" Not Found.', 100113);



End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FUNCTION TAutoTrans.Init(Handle:Integer; ActorID : Integer):Integer;

Begin
   DoSimpleMsg('Need to implement TAutoTrans.Init', -1);
   Result := 0;
End;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//      TAutoTrans Obj
//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TAutoTransObj.Create(ParClass:TDSSClass; const TransfName:String);
VAR
  i:Integer;
Begin
  Inherited Create(ParClass);
  Name       := LowerCase(TransfName);
  DSSObjType := ParClass.DSSClassType; //DSSObjType + XFMR; // override PDElement   (kept in both actually)

  Nphases := 3;  // Directly set conds and phases
  fNConds := 2 * Fnphases; // 2 conductors per phase; let NodeRef connect neutral, etc.
  SetNumWindings (2);  // must do this after setting number of phases
  ActiveWinding := 1;

  Nterms  := NumWindings;  // Force allocation of terminals and conductors

  puXHX := 0.10;
  puXHT := 0.35;
  puXXT := 0.30;
  XHXChanged := True;  // Set flag to for calc of XSC array from XHL, etc.

  DeltaDirection := 1;
  SubstationName := '';
  XfmrBank := '';
  XfmrCode := '';

  VABase           := Winding^[1].kVA*1000.0;
  ThermalTimeconst := 2.0;
  n_thermal        := 0.8;
  m_thermal        := 0.8;
  FLrise           := 65.0;
  HSrise           := 15.0;  // Hot spot rise
  NormMaxHkVA      := 1.1 * Winding^[1].kVA;
  EmergMaxHkVA     := 1.5 * Winding^[1].kVA;
  pctLoadLoss      := 2.0 * Winding^[1].Rpu * 100.0; //  assume two windings for init'ing
  ppm_FloatFactor  := 0.000001;
  {Compute antifloat added for each winding    }
  for i := 1 to NumWindings do  Winding^[i].ComputeAntiFloatAdder(ppm_FloatFactor, VABase/FNPhases);

  {Default the no load properties to zero}
  pctNoLoadLoss    := 0.0;
  pctImag          := 0.0;

  {Basefrequency := 60.0;   set in base class to circuit fundamental freq; Do not reset here}
  FaultRate     := 0.007;
  IsSubstation  := FALSE;
  XRConst       := FALSE;

  HVLeadsLV     := FALSE; // Defaults to ANSI connection

  Y_Terminal_FreqMult := 0.0;

  Yorder := fNTerms * fNconds;
  InitPropertyValues(0);
  RecalcElementData(ActiveActor);
End;

procedure TAutoTransObj.SetBusAuto(iwdg: Integer; const s: String; ActorID : Integer);
// Added Jan 3, 2019
Var
    NNodes    : Array[1..50] of Integer; // big integer buffer
    NumNodes  : Integer;
    DotPos    : Integer;
    FirstNeut : Integer; // First Neutral Node
    ii        : Integer;
    strBusName,
    strNewBusName : String;
begin
// For winding 2 set all nodes on second end of winding to same as 1st value
// so all neutral ends of common winding get connected to same neutral node

    case iwdg of

        2: Begin

              For ii := 1 to nphases DO NNodes[ii] := ii; // set up buffer with defaults
               // Default all other conductors to a ground connection
               // If user wants them ungrounded, must be specified explicitly!
              For ii := nphases + 1 to NConds DO NNodes[ii] := 0;

              Auxparser[ActorID].Token := s; // load up AuxParser
              strBusName := AuxParser[ActorID].ParseAsBusName(NumNodes, @NNodes, ActorID);

              // Check for non-zero neutral specification
              if NNodes[nphases+1]>0 then  Begin
                  // Reconstruct new bus name
                  strNewBusName := strBusName;
                  for ii := 1         to Nphases do strNewBusName := strNewBusName + Format('.%d', [NNodes[ii]]);
                  for ii := nphases+1 to Nconds  do strNewBusName := strNewBusName + Format('.%d', [NNodes[nphases+1]]);
                  SetBus(iwdg, strNewBusName);
              End
              Else SetBus(iwdg, s);

           End;
    Else
        Setbus(iwdg, s);  // all other windings
    end;

end;

procedure TAutoTransObj.SetNodeRef(iTerm: Integer; NodeRefArray: pIntegerArray);
// Overrides standard function
Var
   i : Integer;
begin
  inherited SetNodeRef(iTerm, NodeRefArray);

  // Now fixup noderefs for series winding of AutoTrans
  // Warning **** Magic happens here
  // Redefine 2nd node of Series winding to same as first node of 2nd winding (common winding)

      If iTerm=2 Then
        if Winding^[1].Connection = SERIES then    // If series winding
        Begin
            For i := 1 to Fnphases do Begin
                NodeRef^[Fnphases+i] := NodeRef^[i+Fnconds];
                Terminals^[iTerm].TermNodeRef^[Fnphases+i] := NodeRef^[i+Fnconds];
            End;
        End;
end;

PROCEDURE TAutoTransObj.SetNumWindings(N:Integer);
VAR
  i          :Integer;
  OldWdgSize :Integer;
  NewWdgSize :Integer;
Begin

  IF N > 1 THEN
  begin
      FOR i := 1 to NumWindings Do Winding^[i].Free;  // Free old winding objects
      OldWdgSize  := (NumWindings-1) * NumWindings div 2;
      NumWindings := N;
      MaxWindings := N;
      NewWdgSize  := (NumWindings-1) * NumWindings div 2;
      FNconds     := 2 * Fnphases;
      Nterms      := NumWindings;
      Reallocmem(Winding,  Sizeof(Winding^[1])*MaxWindings);  // Reallocate collector array
      FOR i := 1 to MaxWindings DO Winding^[i] := TAutoWinding.Create(i);

      // array of short circuit measurements between pairs of windings
      ReAllocmem(puXSC, SizeOF(puXSC^[1]) * NewWdgSize);
      FOR i := OldWdgSize+1 to NewWdgSize Do  puXSC^[i] := 0.30;
      Reallocmem(TermRef, SizeOf(TermRef^[1]) * 2 * NumWindings*Fnphases);

      {Reallocate impedance matrices}
      ZB.Free;
      Y_1Volt.Free;
      Y_1Volt_NL.Free;
      Y_Term.Free;
      Y_Term_NL.Free;

      ZB         := TCMatrix.CreateMatrix(NumWindings - 1);
      Y_1Volt    := TCMatrix.CreateMatrix(NumWindings);
      Y_1Volt_NL := TCMatrix.CreateMatrix(NumWindings);
      Y_Term     := TCMatrix.CreateMatrix(2 * NumWindings);
      Y_Term_NL  := TCMatrix.CreateMatrix(2 * NumWindings);
  end
  Else
    Dosimplemsg('Invalid number of windings: (' + IntToStr(N) + ') for AutoTrans.' + Name, 100111);
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
destructor TAutoTransObj.Destroy;

VAR i:Integer;
Begin
    {Throw away stuff allocated for this object}
    FOR i := 1 to NumWindings Do Winding^[i].Free;
    Reallocmem(Winding, 0);
    Reallocmem(puXSC, 0);
    Reallocmem(TermRef, 0);
    ZB.Free;
    Y_1Volt.Free;
    Y_1Volt_NL.Free;
    Y_Term.Free;
    Y_Term_NL.Free;
    Inherited Destroy;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTransObj.RecalcElementData(ActorID : Integer);
VAR
   i,
   ihvolt   :Integer;
   VFactor  :Double;

Begin

  // Determine Delta Direction
   // If high voltage is delta, delta leads y
   // If high voltage is wye, delta lags wye
   If Winding^[1].connection = Winding^[2].connection Then DeltaDirection := 1
   Else If Winding^[1].connection = SERIES Then DeltaDirection := 1  // Auto
   Else Begin
     If Winding^[1].kVLL >= Winding^[2].kVLL Then iHvolt:=1 else iHVolt := 2;
     CASE Winding^[iHvolt].Connection of
       WYE:  If HVLeadsLV then DeltaDirection := -1 Else DeltaDirection := 1;
       DELTA:  If HVLeadsLV then DeltaDirection := 1  Else DeltaDirection := -1;
     ELSE
         // ---old code --- If Winding^[2].Connection = 0 Then DeltaDirection := -1 Else DeltaDirection := 1;
     END;
   End;
   
   SetTermRef;   // Re-establish TermRef IF num windings or connection changed

   FOR i := 1 to NumWindings Do Begin
      WITH Winding^[i] Do
        IF (NumTaps > 0) THEN TapIncrement := (MaxTap - MinTap)/NumTaps
                         ELSE TapIncrement := 0.0;
   End;

   IF XHXChanged THEN Begin
     {should only happen for 2- and 3-winding AutoTranss}
      IF NumWindings <=3 THEN
        FOR i := 1 to (NumWindings*(NumWindings-1) div 2) DO
         CASE i of
             1: puXSC^[1] := puXHX;
             2: puXSC^[2] := puXHT;
             3: puXSC^[3] := puXXT;
         ELSE
         End;
      XHXChanged := false;
     End;

   // Set winding voltage bases (in volts)
   FOR i := 1 to NumWindings Do
    WITH Winding^[i] Do  // Get the actual turns voltage base for each winding
      CASE Connection of
        WYE:Case Fnphases of   // Wye
            2,3:VBase := kVLL * InvSQRT3x1000;   // assume 3-phase for 2-phase designation
          ELSE
                VBase := kVLL * 1000.0;
          End;
        DELTA:  VBase := kVLL * 1000.0;     // delta
        SERIES: Begin                            // Series winding for Auto  Should be Winding[1]
             case Fnphases of
                  2,3: kVseries := (kVLL - Winding^[2].kVLL) / SQRT3;
             Else
                     kVseries := kVLL - Winding^[2].kVLL;
             end;
             if kVSeries=0.0 then kVSeries := kVLL * 0.0001; // In case series has same voltage as common
             VBase    := kVseries * 1000.0;
           End;
      END;

   {Base rating of Winding 1 }
     VABase := Winding^[1].kVA * 1000.0;

   // Set Rdc parameters for each winding.
     For i := 1 to NumWindings Do
       With Winding^[i] Do Begin
           if RdcSpecified then
              Rdcpu := RdcOhms/(SQR(VBase)/ VABase)
           Else Begin
              Rdcpu := 0.85 * Rpu; // default to 85% of the ac value (does not include stray loss)
              RdcOhms := Rdcpu * SQR(VBase)/ VABase;
           End;
       End;

     For i := 1 to NumWindings do Winding^[i].ComputeAntiFloatAdder(ppm_FloatFactor, VABase/FNPhases);

   { Normal and Emergency terminal current Rating for UE check}
     Vfactor := 1.0;  // ensure initial values
     Case Winding^[1].connection Of
        WYE:   VFactor := Winding^[1].VBase * 0.001;   // wye
        DELTA: Case Fnphases of
             1:   VFactor := Winding^[1].VBase * 0.001;
             2,3: VFactor := Winding^[1].VBase * 0.001 / SQRT3;
             Else
                  VFactor := Winding^[1].VBase * 0.001 * 0.5 / sin(pi/Fnphases);
          End;
        2:        VFactor := Winding^[1].VBase * 0.001;   // Series Winding
     End;

     {Divide per phase kVA by voltage to neutral}
     NormAmps  := NormMaxHkVA  / Fnphases / Vfactor;
     EmergAmps := EmergMaxHkVA / Fnphases / Vfactor;

     CalcY_Terminal(1.0, ActorID);   // Calc Y_Terminal at base frequency
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
procedure TAutoTransObj.SaveWrite(var F: TextFile);
{Override standard SaveWrite}
{AutoTrans structure not conducive to standard means of saving}
var
   iprop :Integer;
   i     :Integer;
begin
   {Write only properties that were explicitly set in the
   final order they were actually set}
   iProp := GetNextPropertySet(0); // Works on ActiveDSSObject
   While iProp >0 Do
   Begin
      With ParentClass Do
       {Trap wdg= and write out array properties instead}
        CASE RevPropertyIdxMap^[iProp] of
            3:  Begin   // if WDG= was ever used write out arrays ...
                 For i := 12 to 16 Do
                   Write(F, Format(' %s=%s', [PropertyName^[i], GetPropertyValue(i) ]));
                 For i := 1 to Numwindings do
                   Write(F, Format(' wdg=%d %sR=%.7g', [i, '%', Winding^[i].Rpu *100.0]));
            End;
            4..9: {do Nothing}; // Ignore these properties; use arrays instead

        ELSE
        If Length(PropertyValue[iProp])>0 Then
          Write(F,Format(' %s=%s', [PropertyName^[RevPropertyIdxMap^[iProp]],CheckForBlanks(PropertyValue[iProp])] ));
        END;
      iProp := GetNextPropertySet(iProp);
   End;
end;

PROCEDURE TAutoTransObj.SetTermRef;

// sets an array which maps the two conductors of each winding to the
// phase and neutral conductors of the AutoTrans according to the winding connection

VAR i, j, k, NumCondPerPhase:Integer;

Begin
   k := 0;

   CASE Fnphases of
      1: FOR j := 1 to NumWindings Do Begin
             Inc(k); TermRef^[k] := (j - 1) * fNconds + 1;  // fNconds = 2
             Inc(k); TermRef^[k] :=  j * fNconds;
         End;
   ELSE


(***  Typical array for 3-phase auto
This builds the YPrim and the NodeRef array maps it into Y
       TermRef^[1] := 1;
       TermRef^[2] := 4;
       TermRef^[3] := 7;
       TermRef^[4] := 10;
       TermRef^[5] := 2;
       TermRef^[6] := 5;
       TermRef^[7] := 8;
       TermRef^[8] := 11;
       TermRef^[9] := 3;
       TermRef^[10] := 6;
       TermRef^[11] := 9;
       TermRef^[12] := 12;

********)

       FOR i := 1 to Fnphases Do  Begin
          FOR  j := 1 to NumWindings Do Begin
              Inc(k);
              CASE Winding^[j].Connection OF
                WYE: Begin  // Wye
                               TermRef^[k] := (j-1)*FNConds + i;
                      Inc(k);  TermRef^[k] := TermRef^[k-1] + Fnphases;
                     End;
  {**** WILL THIS WORK for 2-PHASE OPEN DELTA ???? Need to check this sometime}

              DELTA: Begin  // Delta
                               TermRef^[k] := (j-1) * fNconds + i;
                      Inc(k);  TermRef^[k] := (j-1) * fNconds + RotatePhases(i);  // connect to next phase in sequence
                     End;
            SERIES: Begin // Series Winding for Auto Transfomer
                               TermRef^[k] :=  i;
                      Inc(k);  TermRef^[k] :=  i + Fnphases;
                    End;
              END; {CASE connection}
          End;
       End;

   END; {CASE Fnphases}
End;


//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
PROCEDURE TAutoTransObj.CalcYPrim(ActorID : Integer);

VAR
   FreqMultiplier :Double;

Begin

    IF   YPrimInvalid[ActorID] THEN Begin
         // Reallocate YPrim if something has invalidated old allocation
         IF YPrim_Series<>nil THEN  YPrim_Series.Free;
         IF YPrim_Shunt<>nil  THEN  YPrim_Shunt.Free;
         IF YPrim<>nil        THEN  YPrim.Free;

         YPrim_Series := TcMatrix.CreateMatrix(Yorder);
         YPrim_Shunt  := TcMatrix.CreateMatrix(Yorder);
         YPrim        := TcMatrix.CreateMatrix(Yorder);
    End
    ELSE Begin  {Same size as last time; just zero out to start over}
         YPrim_Series.Clear; // zero out YPrim
         YPrim_Shunt.Clear; // zero out YPrim
         Yprim.Clear;
    End;

    // Set frequency multipliers for this calculation
    FYprimFreq     := ActiveCircuit[ActorID].Solution.Frequency ;
    FreqMultiplier := FYprimFreq / BaseFrequency;
    // Check for rebuilding Y_Terminal; Only rebuild if freq is different than last time
    If   FreqMultiplier <> Y_Terminal_Freqmult Then CalcY_Terminal(FreqMultiplier, ActorID);

    BuildYPrimComponent(YPrim_Series, Y_Term);
    BuildYPrimComponent(YPrim_Shunt,  Y_Term_NL);


    {Combine the two Yprim components into Yprim}
    YPrim.CopyFrom(YPrim_Series);
    Yprim.AddFrom(Yprim_Shunt);

    {Now Account for Open Conductors}
    {For any conductor that is open, zero out row and column}
    Inherited CalcYPrim(ActorID);

    YprimInvalid[ActorID] := False;
End;

PROCEDURE TAutoTransObj.DumpProperties(Var F:TextFile;Complete:Boolean);

VAR
   i,j:Integer;
   ZBtemp: Tcmatrix;

Begin
    Inherited DumpProperties(F,Complete);

    {Basic Property Dump}

    Writeln(F, '~ ', 'NumWindings=', NumWindings:0);
    Writeln(F, '~ ', 'phases=', Fnphases:0);

    FOR i := 1 to NumWindings Do Begin
       WITH Winding^[i] Do Begin
            IF i=1 THEN  Writeln(F,'~ ','Wdg=', i:0, ' bus=',firstbus)
                   ELSE  Writeln(F,'~ ','Wdg=', i:0, ' bus=',nextbus);
            CASE Connection of
                WYE:    Writeln(f,'~ conn=wye');
                DELTA:  Writeln(f,'~ conn=delta');
                SERIES: Writeln(f,'~ conn=Series');
            End;
            Writeln(f,Format('~ kv=%.7g', [kVLL]));
            Writeln(f,Format('~ kVA=%.7g', [kVA]));
            Writeln(f,Format('~ tap=%.7g', [putap]));
            Writeln(f,Format('~ %%r=%.7g', [Rpu*100.0]));
            Writeln(f,Format('~ Rdcohms=%.7g', [ Rdcohms]));

        End;
    End;

    Writeln(F,'~ ','XHL=',puXHX*100.0:0:3);
    Writeln(F,'~ ','XHT=',puXHT*100.0:0:3);
    Writeln(F,'~ ','XLT=',puXXT*100.0:0:3);
    Writeln(F,'~ ','X12=',puXHX*100.0:0:3);
    Writeln(F,'~ ','X13=',puXHT*100.0:0:3);
    Writeln(F,'~ ','X23=',puXXT*100.0:0:3);
    Write(F,'~ Xscmatrix= "');
    FOR i := 1 to (NumWindings-1)*NumWindings div 2 Do Write(F, puXSC^[i]*100.0:0:2,' ');
    Writeln(F,'"');
    Writeln(F,'~ ','NormMAxHkVA=',NormMAxHkVA:0:0);
    Writeln(F,'~ ','EmergMAxHkVA=',EmergMAxHkVA:0:0);
    Writeln(F,'~ ','thermal=',thermalTimeConst:0:1);
    Writeln(F,'~ ','n=',n_thermal:0:1);
    Writeln(F,'~ ','m=',m_thermal:0:1);
    Writeln(F,'~ ','flrise=',flrise:0:0);
    Writeln(F,'~ ','hsrise=',hsrise:0:0);
    Writeln(F,'~ ','%loadloss=',pctLoadLoss:0:0);
    Writeln(F,'~ ','%noloadloss=',pctNoLoadLoss:0:0);

    For i := 28 to NumPropsThisClass Do
       Writeln(F,'~ ', ParentClass.PropertyName^[i],'=',PropertyValue[i]);

    WITH ParentClass Do Begin
         For i := NumPropsthisClass+1 to NumProperties Do
               Writeln(F,'~ ',PropertyName^[i],'=',PropertyValue[i]);
    End;

    IF Complete THEN Begin
        Writeln(F);
        ZBTemp := TCmatrix.CreateMatrix(NumWindings-1);
        ZBTemp.CopyFrom(ZB);
        ZBTemp.Invert;

        Writeln(F,'ZB:');
        WITH ZBTemp Do Begin
           FOR i := 1 to NumWindings-1 Do Begin
               FOR j := 1 to i Do Write(F, format('%g ',[GetElement(i,j).re]));
               Writeln(F);
           End;
           FOR i := 1 to NumWindings-1 Do Begin
               FOR j := 1 to i Do Write(F, format('%g ',[GetElement(i,j).im]));
               Writeln(F);
           End;
        End;  {WITH}

        ZBTemp.Free;

        Writeln(F);
        Writeln(F,'ZB: (inverted)');
        WITH ZB Do Begin
           FOR i := 1 to NumWindings-1 Do Begin
               FOR j := 1 to i Do Write(F, GetElement(i,j).re:0:4,' ');
               Writeln(F);
           End;
           FOR i := 1 to NumWindings-1 Do Begin
               FOR j := 1 to i Do Write(F, GetElement(i,j).im:0:4,' ');
               Writeln(F);
           End;
        End;  {WITH}

        Writeln(F);
        Writeln(F,'Y_OneVolt');
        WITH Y_1Volt Do Begin
           FOR i := 1 to NumWindings Do Begin
               FOR j := 1 to i Do Write(F, GetElement(i,j).re:0:4,' ');
               Writeln(F);
           End;
           FOR i := 1 to NumWindings Do Begin
               FOR j := 1 to i Do Write(F, GetElement(i,j).im:0:4,' ');
               Writeln(F);
           End;
        End;

        Writeln(F);
        Writeln(F,'Y_Terminal');
        WITH Y_Term Do Begin
           FOR i := 1 to 2*NumWindings Do Begin
               FOR j := 1 to i Do Write(F, GetElement(i,j).re:0:4,' ');
               Writeln(F);
           End;
           FOR i := 1 to 2*NumWindings Do Begin
               FOR j := 1 to i Do Write(F, GetElement(i,j).im:0:4,' ');
               Writeln(F);
           End;
        End;
        Writeln(F);
        Write(F,'TermRef= ');
        FOR i := 1 to 2*NumWindings*Fnphases Do Write(F,TermRef^[i]:0,' ');
        Writeln(F);

    End;
End;

Procedure TAutoWinding.ComputeAntiFloatAdder(PPM_Factor, VABase1ph:Double);
begin
       Y_PPM := -PPM_Factor/(SQR(VBase)/VABase1ph) /2.0;  //12-11-12 divided by two
       // put half on each terminal of the winding.
end;

Constructor TAutoWinding.Create(iWinding:Integer);
{
   Make a new winding
}
Begin
     Inherited Create;

     Case iWinding of
         1: Begin
               Connection := SERIES;  // First Winding is Series Winding
               kVLL := 115.0;
            End
     Else
         Connection := WYE;
         kVLL       := 12.47;
     End;


     VBase      := kVLL/SQRT3*1000.0;
     kVA        := 1000.0;
     puTap      := 1.0;
     Rpu        := 0.002;
     Rdcpu      := Rpu * 0.85;  // default value
     RdcOhms    := Sqr(kVLL)/ (kVA/1000.0) * Rdcpu;
     RdcSpecified := FALSE;
     ComputeAntiFloatAdder(1.0e-6, kVA/3.0/1000.0);     //  1 PPM

     TapIncrement := 0.00625;
     NumTaps      := 32;
     MaxTap       := 1.10;
     MinTap       := 0.90;
     
End;

destructor TAutoWinding.Destroy;
Begin
    Inherited Destroy;
End;

FUNCTION TAutoTransObj.Get_PresentTap(i: Integer; ActorID : Integer): double;
Begin
     IF (i > 0) and (i <= NumWindings)
         THEN Result := Winding^[i].puTap
         ELSE Result := 0.0;
end;

PROCEDURE TAutoTransObj.Set_PresentTap(i: Integer; ActorID : Integer; const Value: double);

Var
   TempVal :Double;

Begin
     IF (i > 0) and (i <= NumWindings) THEN
       WITH Winding^[i] Do Begin
           {Range Checking}
           TempVal := Value;
           IF      (TempVal < MinTap) THEN TempVal := MinTap
           ELSE IF (TempVal > MaxTap) THEN TempVal := MaxTap;

           IF TempVal <> puTap THEN Begin    {Only if there's been a change}
              puTap        := TempVal;
              YPrimInvalid[ActorID] := True;  // this property triggers setting SystemYChanged=true
              RecalcElementData(ActorID);
           End;
       End;
end;

FUNCTION TAutoTransObj.Get_WdgResistance(i: Integer): Double;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].Rpu
     ELSE Result := 0.0;
end;

FUNCTION TAutoTransObj.Get_WdgkVA(i: Integer): Double;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].kVA
     ELSE Result := 0.0;
end;


FUNCTION TAutoTransObj.Get_WdgYPPM(i: Integer): Double;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].Y_PPM
     ELSE Result := 0.0;
end;

FUNCTION TAutoTransObj.Get_Xsc(i: Integer): Double;
var
  imax: Integer;
Begin
  imax := (NumWindings - 1) * NumWindings div 2;
  IF (i > 0) and (i <= imax)
  THEN Result := puXSC^[i]
  ELSE Result := 0.0;
end;



FUNCTION TAutoTransObj.Get_WdgConnection(i: Integer): Integer;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].Connection
     ELSE Result := 0;
end;

FUNCTION TAutoTransObj.Get_MinTap(i: Integer): Double;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].MinTap
     ELSE Result := 0.0;
end;

FUNCTION TAutoTransObj.Get_MaxTap(i: Integer): Double;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].MaxTap
     ELSE Result := 0.0;
end;

FUNCTION TAutoTransObj.Get_NumTaps(i: Integer): Integer;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].NumTaps
     ELSE Result := 0;
end;

FUNCTION TAutoTransObj.Get_TapIncrement(i: Integer): Double;
Begin
     IF (i > 0) and (i <= NumWindings)
     THEN Result := Winding^[i].TapIncrement
     ELSE Result := 0.0;
end;

PROCEDURE TAutoTransObj.GetAllWindingCurrents(CurrBuffer: pComplexArray; ActorID: Integer);

{
  Return a vector of complex currents for each Winding of all phases

  Iterm = Yterm * Vterm

  Yterm order is 2*NumWindings.  Each phase has same Yterm.
  Vterm order is 2*NumWindings .

  Calculate Iterm phase-by-phase and concatenate into CurrBuffer.
}

VAR
  jphase, k, iPhase, iWind, i   : Integer;
  VTerm : pComplexArray;
  ITerm : pComplexArray;
  ITerm_NL : pComplexArray;

Begin

  TRY
     Vterm    := Allocmem(SizeOf(Complex)*2*NumWindings);
     Iterm    := Allocmem(SizeOf(Complex)*2*NumWindings);
     ITerm_NL := Allocmem(SizeOf(Complex)*2*NumWindings);

     {Load up Vterminal - already allocated for all cktelements}
     WITH ActiveCircuit[ActorID].Solution DO
       if Assigned (NodeV) then
         FOR i := 1 TO Yorder DO
         Begin
           if not ADiakoptics or (ActorID = 1) then
             Vterminal^[i] := NodeV^[NodeRef^[i]]
           else
             Vterminal^[i] := VoltInActor1(NodeRef^[i]);
         End
       Else FOR i := 1 TO Yorder DO  Vterminal^[i] := CZERO;


     k := 0;
     For iPhase := 1 to Fnphases do
     Begin
        For iWind := 1 to NumWindings do
        Begin
           i := 2 * iWind -1;
           CASE Winding^[iWind].Connection OF
              WYE:Begin   // Wye  (Common winding usually)
                      VTerm^[i]   := Vterminal^[iphase + (iWind-1)*FNconds];
                      VTerm^[i+1] := Vterminal^[iphase + (iWind-1)*FNconds + FNphases];
                  End;
            DELTA:Begin   // Delta
                    jphase := RotatePhases(iphase);      // Get next phase in sequence
                    VTerm^[i]   := Vterminal^[iphase + (iWind-1)*FNconds];
                    VTerm^[i+1] := Vterminal^[jphase + (iWind-1)*FNconds];
                  End ;
            SERIES:Begin    // Series Winding
                    VTerm^[i]   := Vterminal^[iphase + (iWind-1)*FNconds];
                    VTerm^[i+1] := Vterminal^[iphase + Fnphases];
                   End;
           End; {CASE}

        End;
        Y_Term.MVmult(ITerm, VTerm);  // ITerm = Y_Term Vterm
        Y_Term_NL.MVmult(ITerm_NL, Vterm);// no load part
        // Add into Currbuffer
        for i := 1 to 2*NumWindings do
          Begin
              k := k + 1;
              CurrBuffer^[k] := Cadd(ITerm^[i], ITerm_NL^[i]);
          End;
     End;

     ReallocMem(Vterm, 0);
     ReallocMem(Iterm, 0);
     ReallocMem(Iterm_NL, 0);


  EXCEPT
     On E:Exception Do
        DoSimpleMsg('Error filling voltage buffer in GetAllWindingCurrents for Circuit Element:AutoTrans.'+Name+CRLF+
                    'Probable Cause: Invalid definition of element.'+CRLF+
                    'System Error Message: '+E.Message, 100115);
  END;

End;


function TAutoTransObj.GeTAutoWindingCurrentsResult(ActorID : Integer): String;

// Returns string mag, angle
Var
    WindingCurrents:pComplexArray;
    i, j, k :Integer;

begin

    WindingCurrents := AllocMem(Sizeof(Complex)*2*FNPhases*NumWindings);

    GetAllWindingCurrents(WindingCurrents, ActorID);

    Result := '';
    k := 0;
    For  i := 1 to Fnphases Do
    Begin
       For j := 1 to NumWindings do
       Begin
           k := k+1;
           Result := Result + Format('%.7g, (%.5g), ', [Cabs(WindingCurrents^[k]), Cdang(WindingCurrents^[k])]);
           k := k+1;
           // Skip currents from other end of the winding
       End;
    End;

    Reallocmem(WindingCurrents,0);  // throw away temp array

end;

PROCEDURE TAutoTransObj.GeTAutoWindingVoltages(iWind: Integer;  VBuffer: pComplexArray; ActorID: Integer);

//  Voltages across indicated winding
// Fill Vbuffer array which must be adequately allocated by calling routine
// Order is Number of Phases

VAR
  i, ii,k,  NeutTerm:Integer;

Begin

  TRY

     {return Zero if winding number improperly specified}
     If (iWind<1) OR (iWind > NumWindings) THEN  Begin
          FOR i := 1 to FNconds DO VBuffer^[i] := CZERO;
          Exit;
     End;

     {Load up VTerminal - already allocated for all cktelements}
     WITH ActiveCircuit[ActorID].Solution DO
     FOR i := 1 TO Yorder DO
     Begin
      if not ADiakoptics or (ActorID = 1) then
         Vterminal^[i] := NodeV^[NodeRef^[i]]
      else
         Vterminal^[i] := VoltInActor1(NodeRef^[i]);

     End;


     k := (iWind-1)*FNconds;    // Offset for winding
     NeutTerm := Fnphases+k+1;
     FOR i := 1 to Fnphases Do
         CASE Winding^[iWind].Connection OF
            WYE:  Begin      // Wye
                    VBuffer^[i] := Csub(Vterminal^[i+k], Vterminal^[NeutTerm]);
                  End;
            DELTA:Begin   // Delta
                    ii := RotatePhases(i);      // Get next phase in sequence
                    VBuffer^[i] := CSub(Vterminal^[i+k], Vterminal^[ii+k]);
                  End;
            SERIES:Begin      // Series   (winding 1)
                   VBuffer^[i] := Csub(Vterminal^[i+k], Vterminal^[i+Fnconds]);
                   End;
         End; {CASE}

  EXCEPT
     On E:Exception Do
        DoSimpleMsg('Error filling voltage buffer in GeTAutoWindingVoltages for Circuit Element:AutoTrans.'+Name+CRLF+
                    'Probable Cause: Invalid definition of element.'+CRLF+
                    'System Error Message: '+E.Message, 100114);
  END;
end;


FUNCTION TAutoTransObj.Get_BaseVoltage(i: Integer): Double;
begin
     If   (i<1) OR (i > NumWindings)
     THEN Result := Winding^[1].VBase
     ELSE Result := Winding^[i].VBase;
end;

{============================== GetLosses Override ===============================}

procedure TAutoTransObj.GetCurrents(Curr: pComplexArray; ActorID : Integer);
Var
   i, j : Integer;

begin
  inherited GetCurrents(Curr, ActorID);

  // Combine Series (wdg 1) and Common winding (2) Currents to get X Terminal Currents

   For i := 1 to Fnphases Do Begin

        Caccum(Curr^[i + FnConds], Curr^[i + Fnphases ]);
   End;


end;

procedure TAutoTransObj.GetLosses(var TotalLosses, LoadLosses,   NoLoadLosses: Complex; ActorID : Integer);
VAR
   cTempIterminal  :pComplexArray;
   i               :Integer;
begin
  {inherited;}

  {Calculates losses in watts, vars}
  TotalLosses := Losses[ActorID];   // Side effect: computes Iterminal

  {Compute No load losses in Yprim_Shunt}
  cTempIterminal := AllocMem(Sizeof(Complex)* Yorder);
  ComputeVterminal(ActorID);
  Yprim_Shunt.MVmult(cTempIterminal, Vterminal) ;
  {No Load Losses are sum of all powers coming into YPrim_Shunt from each terminal}
  NoLoadLosses := CZERO;
  for i := 1 to Yorder do Caccum(NoLoadLosses, Cmul(VTerminal^[i], conjg(cTempIterminal^[i])));

  LoadLosses :=CSub(TotalLosses, NoLoadLosses);

  Reallocmem(cTempIterminal, 0);

end;

FUNCTION TAutoTransObj.GetPropertyValue(Index: Integer): String;

{ gets the property for the active winding ; Set the active winding before calling}

VAR
   i: Integer;

begin
        Case Index of
            12..16,20, 37: Result := '[';
        Else
            Result := '';
        End;

        CASE Index of
            1: Result := IntToStr(nPhases);
            2: Result := IntToStr(NumWindings);
            3: Result := IntToStr(ActiveWinding);  // return active winding
            4: Result := Getbus(ActiveWinding);    // return bus spec for active winding
            5: CASE Winding^[ActiveWinding].Connection  of
                   0: Result := 'wye ';
                   1: Result := 'Delta ';
                   2: Result := 'Series';
               ELSE
               END;
            6: Result := Format('%.7g',[Winding^[ActiveWinding].kVLL]);
            7: Result := Format('%.7g',[Winding^[ActiveWinding].kVA]);
            8: Result := Format('%.7g',[Winding^[ActiveWinding].puTap]);
            9: Result := Format('%.7g',[Winding^[ActiveWinding].Rpu * 100.0]);   // %R
           10: Result := Format('%.7g',[Winding^[ActiveWinding].Rdcohms]);
           11: Case CoreType of
                   0: Result := 'shell';
                   1: Result := '1-phase';
                   3: Result := '3-leg';
                   4: Result := '4-leg';
                   5: Result := '5-Leg';
                   9: Result := 'core-1-phase';
               End;
           12: FOR i := 1 to NumWindings Do Result := Result + GetBus(i) + ', ';
           13: FOR i := 1 to NumWindings Do
                 CASE Winding^[i].Connection of
                     0: Result := Result + 'wye, ';
                     1: Result := Result + 'delta, ';
                     2: Result := Result + 'Series, ';
                ELSE
                 END;
           14: FOR i := 1 to NumWindings Do Result := Result + Format('%.7g, ',[Winding^[i].kVLL]);
           15: FOR i := 1 to NumWindings Do Result := Result + Format('%.7g, ',[Winding^[i].kVA]);
           16: FOR i := 1 to NumWindings Do Result := Result + Format('%.7g, ',[Winding^[i].puTap]);// InterpretAllTaps(Param);
           17: Result := Format('%.7g', [puXHX * 100.0]);
           18: Result := Format('%.7g', [puXHT * 100.0]);
           19: Result := Format('%.7g', [puXXT * 100.0]);
           20: FOR i := 1 to (NumWindings-1)*NumWindings div 2 Do Result := Result + Format('%-g, ',[ puXSC^[i]*100.0]);// Parser.ParseAsVector(((NumWindings - 1)*NumWindings div 2), Xsc);
           26: Result := Format('%.7g',[pctLoadLoss]);
           27: Result := Format('%.7g',[pctNoLoadLoss]);
           28: Result := Format('%.7g',[NormMaxHkVA]);
           29: Result := Format('%.7g',[EmergMaxHkVA]);
           31: Result := Format('%.7g',[Winding^[ActiveWinding].MaxTap]);
           32: Result := Format('%.7g',[Winding^[ActiveWinding].MinTap]);
           33: Result := Format('%-d',[Winding^[ActiveWinding].NumTaps]);
           35: Result := Format('%.7g', [pctImag]);
           36: Result := Format('%.7g', [ppm_FloatFactor / 1.0e-6]);
           37: FOR i := 1 to NumWindings Do Result := Result + Format('%.7g, ',[Winding^[i].rpu * 100.0]);
           40: If XRconst Then  Result := 'YES' Else Result := 'NO';

           42: Result := GeTAutoWindingCurrentsResult(ActiveActor);

        ELSE
          Result := Inherited GetPropertyValue(index);
        END;

        // Overrides
        Case (Index-NumPropsThisClass) of
          1: Result :=  Format('%-.5g', [normamps]);  //Normamps
          2: Result :=  Format('%-.5g', [emergamps]);  //emergamps
        End;

        Case Index of
            12..16,20, 37: Result := Result + ']';
        Else
        End;

end;

procedure TAutoTransObj.InitPropertyValues(ArrayOffset: Integer);
begin

     PropertyValue[1] := '3'; //'phases';
     PropertyValue[2] := '2'; //'windings';
   // Winding Definition
     PropertyValue[3] := '1'; //'wdg';
     PropertyValue[4] := Getbus(1); //'bus';
     PropertyValue[5] := 'Series'; // 'conn';
     PropertyValue[6] := '115'; // IF 2or 3-phase:  phase-phase    ELSE actual winding
     PropertyValue[7] := '100000';
     PropertyValue[8] := '1.0';
     PropertyValue[9] := '0.2';
     PropertyValue[10] := '0.2645'; // 0.002 pu @ 115 kV, 100 MVA
     PropertyValue[11] := 'shell';

   // General Data
     PropertyValue[12] := '';
     PropertyValue[13] := '';
     PropertyValue[14] := ''; // IF 1-phase: actual winding rating; ELSE phase-phase
     PropertyValue[15] := ''; // IF 1-phase: actual winding rating; ELSE phase-phase
     PropertyValue[16] := '';
     PropertyValue[17] := '7';
     PropertyValue[18] := '35';
     PropertyValue[19] := '30';
     PropertyValue[20] := '';  // x12 13 14... 23 24.. 34 ..
     PropertyValue[21] := '2';
     PropertyValue[22] := '.8';
     PropertyValue[23] := '.8';
     PropertyValue[24] := '65';
     PropertyValue[25] := '15';
     PropertyValue[26] := Format('%.7g', [pctLoadLoss]);
     PropertyValue[27] := Format('%.7g', [pctNoLoadLoss]);    // Defaults to zero
     PropertyValue[28] := '';
     PropertyValue[29] := '';
     PropertyValue[30] := 'n';  // =y/n
     PropertyValue[31] := '1.10';
     PropertyValue[32] := '0.90';
     PropertyValue[33] := '32';
     PropertyValue[34] := '';
     PropertyValue[35] := '0';
     PropertyValue[36] := '1';
     PropertyValue[37] := '';
     PropertyValue[38] := '';
     PropertyValue[39] := '';
     PropertyValue[40] := 'NO';
     PropertyValue[41] := 'Lag';
     PropertyValue[42] := '0';


  inherited  InitPropertyValues(NumPropsThisClass);

      // Override some Inherited properties
     PropertyValue[NumPropsThisClass + 1] := '400';  //Normamps
     PropertyValue[NumPropsThisClass + 2] := '600';  //emergamps
     PropertyValue[NumPropsThisClass + 3] := '0.007';  //Fault rate
     PropertyValue[NumPropsThisClass + 4] := '100';   // Pct Perm
     PropertyValue[NumPropsThisClass + 5] := '36';    // Hrs to repair

   ClearPropSeqArray;    // so the overrides don't show up on save

end;

function TAutoTransObj.RotatePhases(iPhs: integer): Integer;
// For Delta connections or Line-Line voltages
begin
     Result := iPhs + DeltaDirection;

     // make sure result is within limits
     IF FnPhases > 2 Then  Begin
         // Assumes 2 phase delta is open delta
          If Result > Fnphases Then Result := 1;
          If Result < 1        Then Result := Fnphases;
     End
     ELSE If Result < 1 Then Result := 3;    // For 2-phase delta, next phase will be 3rd phase

end;

procedure TAutoTransObj.MakePosSequence(ActorID : Integer);
{
  Converts default 3-phase AutoTrans model into equivalent positive-sequence
  using scripting
}
Var
        iW,
        i,
        N         :Integer;
        S         :String;
        Nodes     :Array[1..50] of Integer; // big integer buffer
        OnPhase1  :Boolean;
begin

  {First, determine if we can convert this one.}
   IF (FnPhases =1) or (FNphases=2) Then Begin //disable if any terminal not connected to phase one
     For iW := 1 to NumWindings Do Begin
       OnPhase1 := FALSE;
       {Load up auxiliary parser}
       AuxParser[ActorID].CmdString  := GetBus(iW);
       AuxParser[ActorID].NextParam;
       S := AuxParser[ActorID].ParseAsBusName(N, @Nodes, ActorID);
       If N =0 then OnPhase1 := TRUE;
       For i := 1 to N Do If Nodes[i]=1 Then OnPhase1 := TRUE;
       If Not OnPhase1 Then Begin
         Enabled := FALSE;   // We won't use this one
         Exit;
       End;
     End;
   End;

   {Construct AutoTrans definition string }
   S := 'Phases=1  Conns=(';
   For i := 1 to NumWindings Do S := S + 'Wye ';
   S := S + ')  buses=(';

   For i := 1 to NumWindings Do S := S + Getbus(i) + ' ';
   S := S + ')  kVS=(';

   For i := 1 to NumWindings Do
     With Winding^[i] Do
        If (NPhases>1) or (Connection<>WYE) Then S := S + Format(' %-.5g',[kVLL/SQRT3])
                                            Else S := S + Format(' %-.5g',[kVLL]);
   S := S + ')  kVAs=(';

   For i := 1 to NumWindings Do
     With Winding^[i] Do
        S := S + Format(' %-.5g',[kVA/FNPhases]);
   S := S + ')';

   S := S + ' NormHkVA='+Format(' %-.5g %-.5g',[NormMaxHkVA/FNPhases, EmergMaxHkVA/FNPhases]);

  Parser[ActorID].CmdString := S;
  Edit(ActorID);

  inherited;

end;



procedure TAutoTransObj.BuildYPrimComponent(YPrim_Component, Y_Terminal:TCMatrix);
var
  NW2: Integer;
  i: Integer;
  k: Integer;
  Value: complex;
  j: Integer;

begin
  with YPrim_Component do begin
    { Now, Put in Yprim matrix }
    {have to add every element of Y_terminal into Yprim somewhere}
    NW2 := 2 * NumWindings;
    for i := 1 to NW2 do  begin
      for j := 1 to i do begin
        Value := Y_Terminal.GetElement(i, j);
        // This value goes in Yprim nphases times
        for k := 0 to Fnphases - 1 do
          AddElemSym(TermRef^[i + k * NW2], TermRef^[j + k * NW2], Value);
      end;
    end;
  end;
end;

function TAutoTransObj.Get_BasekVLL(i: Integer): Double;
begin
        Result := Winding^[i].kVLL;
end;


procedure TAutoTransObj.GICBuildYTerminal;
// Build YTerminal considering only resistance and no coupling to other winding.

Var
   i, j, idx :Integer;
   yR     :Complex;
   F      :TextFile;
   Yadder :Complex;

begin

     Y_Term.Clear;
     Y_Term_NL.Clear;

     For i := 1 to NumWindings do  Begin
         yR := Cmplx(1.0/(Winding^[i].Rdcohms), 0.0); // convert to Siemens
         With Y_Term Do Begin
             idx := 2*i-1;
             SetElement(idx,   idx,   yR);
             SetElement(idx+1, idx+1, yR);
             SetElemSym(idx,   idx+1, Cnegate(yR));   // set off-diagonals
         End;
     End;

    {For GIC add a small *Conductance* to both conductors of each winding so that
    the matrix will always invert even if the user neglects to define a voltage
    reference on all sides}
   If ppm_FloatFactor <> 0.0 Then
     WITH Y_Term DO
       FOR i := 1 to NumWindings Do Begin
           Yadder := cmplx(-Winding^[i].Y_PPM , 0.0);    // G + j0
           For j := (2 * i - 1) to (2 * i)  do
           SetElement(j, j, Cadd(GetElement(j, j) , Yadder));
{           SetElement(j, j, CmulReal_im(GetElement(j, j) , ppm_FloatFactorPlusOne));}
       End;

 {$IFDEF AUTOTRANDEBUG}
       AssignFile(F, CircuitName_[ActiveActor] + 'AutoTrans_'+Name+'.TXT');
       Rewrite(F);
       Writeln(F,'Y_Term after building...');
       DumpComplexMatrix(F, Y_Term);
       CloseFile(F);
 {$ENDIF}

end;

procedure TAutoTransObj.CalcY_Terminal(FreqMult: Double; ActorID : Integer);

Var
    i,
    j,
    k          :Integer;
    A          :pComplexArray;
    ctempArray1,
    ctempArray2 :pComplexArray;
    cMinusOne  :Complex;
    AT         :TcMatrix;
    Yadder     :Complex;
    Rmult      :Double;
    ZCorrected     :Double;
     puXst, Vs, Vc: Double;
{$IFDEF AUTOTRANDEBUG}
   F        :Textfile;
{$ENDIF}
    {Function to fix a specification of a pu tap of 0.0}
    {Regcontrol can attempt to force zero tap position in some models}
    function ZeroTapFix(const tapvalue:Double):Double;
    Begin
         If TapValue=0.0 Then  Result := 0.0001 Else Result := Tapvalue;
    End;

begin

    // check for GIC build
    If ActiveCircuit[ActorID].Solution.Frequency < 0.51   Then
         {Build Yterminal for GIC ~dc simulation}

         GICBuildYTerminal

    Else Begin  {Normal Y matrix build}

       If XRConst Then  RMult := FreqMult Else RMult := 1.0;


  // Construct ZBMatrix;
       ZB.Clear;
       ZBase := 1.0/(VABase/Fnphases); // base ohms on 1.0 volt basis, as in Dommel (6.46) for Zct or puXSC^[3]
       // Adjust specified XSC by SQR(1 + Vcommon/Vseries)
       ZCorrected := ZBase * SQR(1.0 + Winding^[2].vbase/Winding^[1].Vbase); // Correction factor for Series, as in Dommel (6.45) for Zsc or puXSC^[1]
       // since the losses are correct as they are, mimic Dommel (6.50) for Zst or puXSC^[2], without disturbing Zbase or Zcorrected
       // Dommel: Xst = Xhl*Vh*Vl/(Vh-Vl)^2 + Xht*Vh/(Vh-Vl) - Xlt*Vl/(Vh-Vl)
       //             = Xhl*(Vs+Vc)*Vc/Vs^2 + Xht*(Vs+Vc)/Vs - Xlt*Vc/Vs
       if NumWindings > 2 then begin
         Vc := Winding^[2].VBase;
         Vs := Winding^[1].VBase;
         puXst := puXSC^[1]*(Vs+Vc)*Vc/Vs/Vs + puXSC^[2]*(Vs+Vc)/Vs - puXSC^[3]*Vc/Vs;
       end else puXst := 0.0;

       FOR i := 1 to Numwindings-1 Do Begin
            if i=1 then
              ZB.SetElement(i, i, CmulReal(Cmplx(Rmult * (Winding^[1].Rpu + Winding^[i+1].Rpu), Freqmult*puXSC^[i]), ZCorrected))
          Else if i=2 then
              ZB.SetElement(i, i, CmulReal(Cmplx(Rmult * (Winding^[1].Rpu + Winding^[i+1].Rpu), Freqmult*puXst), Zbase))
          Else
              ZB.SetElement(i, i, CmulReal(Cmplx(Rmult * (Winding^[1].Rpu + Winding^[i+1].Rpu), Freqmult*puXSC^[i]), Zbase));
      End;

       // Off diagonals
       k := NumWindings;
       WITH ZB DO
         FOR  i := 1 to Numwindings-1 Do Begin
          FOR j := i+1 to Numwindings-1 Do  Begin
              SetElemSym(i,j,
                CmulReal(
                    Csub(CAdd(GetElement(i, i), GetElement(j, j)),
                    CmulReal(Cmplx(Rmult * (Winding^[i+1].Rpu + Winding^[j+1].Rpu), Freqmult*puXSC^[k]), ZBase))
                            ,  0.5) );
              Inc(k);
          End;
         End;

  {******************************DEBUG******************************************************}
  {$IFDEF AUTOTRANDEBUG}
       AssignFile(F, CircuitName_[ActiveActor] + 'AutoTrans_'+Name+'.TXT');
       Rewrite(F);
       Writeln(F, Format('Zbase=%g, Zcorrected=%g, VABase=%g, Nphases=%d, Rpu=%g ', [Zbase, Zcorrected, VABase, Fnphases, Winding^[1].Rpu ]));
       Writeln(F,'ZB before inverting...');
       DumpComplexMatrix(F, ZB);
  {$ENDIF}
  {*****************************************************************************************}

       ZB.Invert;   // mhos on one volt base

       IF ZB.InvertError > 0 Then Begin
         DoErrorMsg('TAutoTransObj.CalcYPrim', 'Matrix Inversion Error for AutoTrans "' + Name + '"',
                    'Invalid impedance specified. Replaced with tiny conductance to ground.', 117);
         ZB.Clear;
         For i := 1 to ZB.Order Do ZB.SetElement(i, i, Cmplx(EPSILON, 0.0));
       End;

  {******************************DEBUG******************************************************}
  {$IFDEF AUTOTRANDEBUG}
       Writeln(F,'ZB after inverting...');
       DumpComplexMatrix(F, ZB);
  {$ENDIF}
  {*****************************************************************************************}

   // Now construct Y_Oneturn = AT * ZB.Invert * A
   {     -1 1 0 ...
     A = -1 0 1 ..   order:  N-1 x N   N = NumWindings
         ...
                           -1 -1 ...
     AT = Transpose of A =  1  0 ...    N X N-1
                            0  1 ..
   }

     Y_1Volt.Clear;
     Y_1Volt_NL.Clear;

     {Allocate temp complex arrays}
     ctempArray1 := AllocMem(SizeOf(Complex) * NumWindings * 2);
     ctempArray2 := AllocMem(SizeOf(Complex) * NumWindings * 2);

     A          := AllocMem(SizeOf(Complex) * NumWindings * 2);
     cMinusOne  := cmplx(-1.0, 0.0);
     AT         := TcMatrix.Creatematrix(NumWindings);
     FOR i := 1 to NumWindings-1 Do AT.SetElement(i+1, i, cONE);
     FOR i := 1 to NumWindings-1 Do AT.SetElement(1,   i, cMinusOne);
     ctemparray1^[NumWindings] := CZERO;
     FOR i := 1 TO Numwindings Do Begin
       IF i=1 THEN FOR k := 1 to NumWindings-1 Do A^[k] := cMinusOne
              ELSE FOR k := 1 to NumWindings-1 Do IF k=(i-1) THEN A^[k] := cONE
                                                             ELSE A^[k] := cZERO;
       ZB.MVmult(ctemparray1, A); {Zb.invert * A}
       AT.MVmult(ctempArray2, ctemparray1); {AT * Result}
       FOR j := 1 to NumWindings Do Y_1Volt.SetElement(j, i, ctempArray2^[j]);
     End;

   {Add magnetizing Reactance to 2nd winding, assuming it is closest to the core
    Add both resistive element representing core losses and a reactive element representing
    magnetizing current
   }
    Y_1Volt_NL.AddElement(2, 2, Cmplx((pctNoLoadLoss/100.0/Zbase), -pctImag/100.0/Zbase/Freqmult));

  {******************************DEBUG******************************************************}
  {$IFDEF AUTOTRANDEBUG}
       Writeln(F,'Y_OneVolt ...');
       DumpComplexMatrix(F, Y_1Volt);
       Writeln(F,'Y_OneVolt_NL ...');
       DumpComplexMatrix(F, Y_1Volt_NL);
  {$ENDIF}
  {*****************************************************************************************}
     // should have admittance of one phase of the AutoTrans on a one-volt, wye-connected base

     // Now make into terminal admittance matrix and correct for actual voltage ratings
     // Y_Terminal = AT * Y_onevolt * A  where V_onevolt = A * V_terminal

     AT.Free;

     Y_Term.Clear;
     Y_Term_NL.Clear;
     AT := TcMatrix.Creatematrix(NumWindings * 2);

     // 8/22/2013 Added ZeroTapFix so that regcontrol can set a tap to zero

     FOR i := 1 to   NumWindings Do With Winding^[i] Do AT.SetElement(2*i-1, i, Cmplx( 1.0/(VBase*ZeroTapFix(puTap)), 0.0));
     FOR i := 1 to   NumWindings Do With Winding^[i] Do AT.SetElement(2*i,   i, Cmplx(-1.0/(VBase*ZeroTapFix(puTap)), 0.0));
     FOR i := 1 to 2*Numwindings Do ctemparray1^[i] := CZERO;

     FOR i := 1 TO 2*Numwindings Do Begin
       FOR k := 1 to NumWindings Do
       With Winding^[k] Do
       Begin
           IF i=(2*k-1)  THEN A^[k] := Cmplx(( 1.0/(VBase*ZeroTapFix(puTap))), 0.0)
           ELSE IF i=2*k THEN A^[k] := Cmplx((-1.0/(VBase*ZeroTapFix(puTap))), 0.0)
                         ELSE A^[k] := cZERO;
       End;
       {Main AutoTrans part}
       Y_1Volt.MVmult(ctemparray1, A);
       AT.MVmult(ctemparray2, ctemparray1);    {AT * Result}
       FOR j := 1 to 2 * NumWindings Do Y_Term.SetElement(j, i, ctemparray2^[j]);
       {No Load part}
       Y_1Volt_NL.MVmult(ctemparray1, A);
       AT.MVmult(ctemparray2, ctemparray1);    {AT * Result}
       FOR j := 1 to 2 * NumWindings Do Y_Term_NL.SetElement(j, i, ctemparray2^[j]);
     End;

  {******************************DEBUG******************************************************}
  {$IFDEF AUTOTRANDEBUG}
       Writeln(F,'Y_Terminal before adding small element to diagonals ...');
       DumpComplexMatrix(F, Y_Term);
       Writeln(F,'Y_Terminal_NL before adding small element to diagonals ...');
       DumpComplexMatrix(F, Y_Term_NL);
  {$ENDIF}
  {*****************************************************************************************}

     {Add a small Admittance to both conductors of each winding so that
    the matrix will always invert even if the user neglects to define a voltage
    reference on all sides}
   If ppm_FloatFactor <> 0.0 Then
     WITH Y_Term DO
       FOR i := 1 to NumWindings Do Begin
           Yadder := cmplx(0.0, Winding^[i].Y_PPM );
           For j := (2 * i - 1) to (2 * i)  do
           SetElement(j, j, Cadd(GetElement(j, j) , Yadder));
{           SetElement(j, j, CmulReal_im(GetElement(j, j) , ppm_FloatFactorPlusOne));}
       End;

{******************************DEBUG******************************************************}
  {$IFDEF AUTOTRANDEBUG}
       Writeln(F,'Y_Terminal after adding small element to diagonals ...');
       DumpComplexMatrix(F, Y_Term);
       Writeln(F,'Y_Terminal_NL after adding small element to diagonals ...');
       DumpComplexMatrix(F, Y_Term_NL);
       CloseFile(F);
  {$ENDIF}
  {*****************************************************************************************}
     AT.Free;
     Reallocmem(A, 0);
     Reallocmem(ctemparray1, 0);
     Reallocmem(ctemparray2, 0);

   End;

     Y_Terminal_FreqMult := Freqmult;

end;

PROCEDURE TAutoTransObj.FetchXfmrCode(Const Code:String);
// Uses strandard Xfmrcode, but forces connection of first two windings.
var
  Obj: TXfmrCodeObj;
  i: Integer;
begin
  if XfmrCodeClass=Nil then XfmrCodeClass := DSSClassList[ActiveActor].Get(ClassNames[ActiveActor].Find('xfmrcode'));

  if XfmrCodeClass.SetActive(Code) then begin
    Obj := XfmrCodeClass.GetActiveObj;
    XfmrCode := LowerCase(Code);
    // set sizes and copy parameters
    Nphases := Obj.Fnphases;
    SetNumWindings(Obj.NumWindings);
    NConds := Fnphases + 1; // forces reallocation of terminals and conductors
    for i := 1 to NumWindings do
      with Winding^[i] do begin
        Case i of
            1: Connection := SERIES;  // No Choice for 1st two
            2: Connection := WYE;  // Wye
        ELSE
            Connection   := Obj.Winding^[i].Connection;
        End;
        kVLL         := Obj.Winding^[i].kVLL;
        VBase        := Obj.Winding^[i].VBase;
        kVA          := Obj.Winding^[i].kVA;
        puTAP        := Obj.Winding^[i].puTAP;
        Rpu          := Obj.Winding^[i].Rpu;
        RdcOhms      := Obj.Winding^[i].RdcOhms; RdcSpecified := TRUE; //This will force calc of Rdcpu
        TapIncrement := Obj.Winding^[i].TapIncrement;
        MinTap       := Obj.Winding^[i].MinTap;
        MaxTap       := Obj.Winding^[i].MaxTap;
        NumTaps      := Obj.Winding^[i].NumTaps;
      end;
    SetTermRef;
    puXHX := Obj.XHL;
    puXHT := Obj.XHT;
    puXXT := Obj.XLT;
    for i := 1 to (NumWindings*(NumWindings-1) div 2) do puXSC^[i] := Obj.XSC^[i];
    ThermalTimeConst := Obj.ThermalTimeConst;
    n_thermal        := Obj.n_thermal;
    m_thermal        := Obj.m_thermal;
    FLrise           := Obj.FLrise;
    HSrise           := Obj.HSrise;
    pctLoadLoss      := Obj.pctLoadLoss;
    pctNoLoadLoss    := Obj.pctNoLoadLoss;
    pctImag          := Obj.pctImag;  // Omission corrected 12-14-18
    NormMaxHkVA      := Obj.NormMaxHkVA;
    EmergMaxHkVA     := Obj.EmergMaxHkVA;
    ppm_FloatFactor  := Obj.ppm_FloatFactor;
    Yorder := fNConds*fNTerms;
    YPrimInvalid[ActiveActor] := True;
    Y_Terminal_FreqMult := 0.0;

    RecalcElementData(ActiveActor)
  end else
    DoSimpleMsg('Xfmr Code:' + Code + ' not found.', 100180);
End;

end.
