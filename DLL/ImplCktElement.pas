unit ImplCktElement;
{
  ----------------------------------------------------------
  Copyright (c) 2008-2015, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{
   5-17-00 Fixed bug in SeqCurrents and SeqPowers with location of Reallocmem
   9-1-13 Added NodeOrder  array that corresponds to voltages, currents, powers
}

interface

uses
  ComObj, ActiveX, OpenDSSEngine_TLB, StdVcl;

type
  TCktElement = class(TAutoObject, ICktElement)
  protected
    function Get_BusNames: OleVariant; safecall;
    function Get_Name: WideString; safecall;
    function Get_NumConductors: Integer; safecall;
    function Get_NumPhases: Integer; safecall;
    function Get_NumTerminals: Integer; safecall;
    function Get_Properties(Index: OleVariant): IDSSProperty; safecall;
    procedure Set_BusNames(Value: OleVariant); safecall;
    
    function Get_Currents: OleVariant; safecall;
    function Get_Voltages: OleVariant; safecall;
    function Get_EmergAmps: Double; safecall;
    function Get_Enabled: WordBool; safecall;
    function Get_Losses: OleVariant; safecall;
    function Get_NormalAmps: Double; safecall;
    function Get_PhaseLosses: OleVariant; safecall;
    function Get_Powers: OleVariant; safecall;
    function Get_SeqCurrents: OleVariant; safecall;
    function Get_SeqPowers: OleVariant; safecall;
    function Get_SeqVoltages: OleVariant; safecall;
    procedure Close(Term, Phs: Integer); safecall;
    procedure Open(Term, Phs: Integer); safecall;
    procedure Set_EmergAmps(Value: Double); safecall;
    procedure Set_Enabled(Value: WordBool); safecall;
    procedure Set_NormalAmps(Value: Double); safecall;
    function IsOpen(Term, Phs: Integer): WordBool; safecall;
    function Get_AllPropertyNames: OleVariant; safecall;
    function Get_NumProperties: Integer; safecall;
    function Get_Residuals: OleVariant; safecall;
    function Get_Yprim: OleVariant; safecall;
    function Get_DisplayName: WideString; safecall;
    function Get_GUID: WideString; safecall;
    function Get_Handle: Integer; safecall;
    procedure Set_DisplayName(const Value: WideString); safecall;
    function Get_Controller(idx: Integer): WideString; safecall;
    function Get_EnergyMeter: WideString; safecall;
    function Get_HasVoltControl: WordBool; safecall;
    function Get_HasSwitchControl: WordBool; safecall;
    function Get_CplxSeqVoltages: OleVariant; safecall;
    function Get_CplxSeqCurrents: OleVariant; safecall;
    function Get_AllVariableNames: OleVariant; safecall;
    function Get_AllVariableValues: OleVariant; safecall;
    function Get_Variable(const MyVarName: WideString; out Code: Integer): Double; safecall;
    function Get_Variablei(Idx: Integer; out Code: Integer): Double; safecall;
    function Get_NodeOrder: OleVariant; safecall;
    function Get_HasOCPDevice: WordBool; safecall;
    function Get_NumControls: Integer; safecall;
    function Get_OCPDevIndex: Integer; safecall;
    function Get_OCPDevType: Integer; safecall;
    function Get_CurrentsMagAng: OleVariant; safecall;
    function Get_VoltagesMagAng: OleVariant; safecall;
    function Get_TotalPowers: OleVariant; safecall;
    function Get_VariableByName(const MyVarName: WideString; out Code: Integer): Double;
          safecall;
    procedure Set_VariableByName(const MyVarName: WideString; out Code: Integer; Value: Double);
          safecall;
    function Get_VariableByIndex(Idx: Integer; out Code: Integer): Double; safecall;
    procedure Set_VariableByIndex(Idx: Integer; out Code: Integer; Value: Double); safecall;
    function Get_VariableName: WideString; safecall;
    procedure Set_VariableName(const Value: WideString); safecall;
    function Get_VariableValue: Double; safecall;
    procedure Set_VariableValue(Value: Double); safecall;
    function Get_VariableIdx: Integer; safecall;
    procedure Set_VariableIdx(Value: Integer); safecall;

  end;

implementation

uses ComServ, DSSClassDefs, DSSGlobals, UComplex, Sysutils,
     PDElement, PCElement, MathUtil, ImplGlobals, Variants, CktElement, Utilities;

var
  VarIdx        : Integer;        // Stores the index of the active state variable

{ - - - - - - - - - - - - -Helper Function- - - - - - - - - - - - - - - - - - -}
FUNCTION IsPDElement : Boolean;
Begin
    Result :=  ((ActiveCircuit[ActiveActor].ActiveCktElement.DSSObjType and 3) = PD_ELEMENT)
End;
{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_BusNames: OleVariant;

Var
   i :Integer;
begin

     If ActiveCircuit[ActiveActor] <> Nil Then
     Begin
       With ActiveCircuit[ActiveActor] Do Begin
         Result := VarArrayCreate([0, ActiveCktElement.Nterms-1], varOleStr);
         For i := 1 to  ActiveCktElement.Nterms Do Begin
             Result[i-1] := ActiveCktElement.GetBus(i);
         End;
       End;
     End
     Else
         Result := VarArrayCreate([0, 0], varOleStr);

end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Name: WideString;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
      WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
      Begin
        Result := ParentClass.Name + '.' + Name;
      End
   Else
      Result := '';
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_NumConductors: Integer;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
        Result := ActiveCircuit[ActiveActor].ActiveCktElement.NConds
   Else Result := 0;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_NumPhases: Integer;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
        Result := ActiveCircuit[ActiveActor].ActiveCktElement.NPhases
   Else Result := 0;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_NumTerminals: Integer;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
        Result := ActiveCircuit[ActiveActor].ActiveCktElement.NTerms
   Else Result := 0;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Properties(Index: OleVariant): IDSSProperty;

Var
   Str:String;
   i :Integer;
begin

  If ActiveCircuit[ActiveActor] <> Nil Then
  Begin

     Case (Vartype(Index) and VarTypeMask) of
         VarSmallint, VarInteger: FPropIndex := Integer(Index) + 1;    // INdex is zero based to match arrays
         VarOleStr:
           Begin
              FPropClass := ActiveDSSObject[ActiveActor].ParentClass;
              FPropIndex := 0;
              Str := Index;
              If FPropClass <> Nil Then
               With FPropClass Do
               For i := 1 to NumProperties Do Begin
                   If CompareText(Str, PropertyName^[i]) = 0 Then Begin
                       FPropIndex := i;
                       Break;
                   End;
               End;
           End;
     Else
         DoSimpleMsg('Illegal Var Type Passed to Properties Interface: '+ Format('$%x',[VarType(Index)]), 5011);
     End;

  End;

  // DoSimpleMsg('Properties: FPropIndex ='+ IntToStr(FPropIndex));

  Result := FDSSProperty As IDSSProperty;

end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
procedure TCktElement.Set_BusNames(Value: OleVariant);
Var
   i :Integer;
   Count, Low :Integer;
begin

     If ActiveCircuit[ActiveActor] <> Nil Then
     Begin
       With ActiveCircuit[ActiveActor] Do Begin
         Low := VarArrayLowBound(Value, 1);
         Count := VarArrayHighBound(Value, 1) - Low + 1;
         If Count >  ActiveCktElement.NTerms Then Count := ActiveCktElement.NTerms;
         For i := 1 to Count Do Begin
             ActiveCktElement.SetBus(i, Value[i-1 + Low]);
         End;
       End;
     End;
end;



{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Currents: OleVariant;
VAR
  cBuffer: pComplexArray;
  NValues, iV ,i: Integer;

Begin
  If ActiveCircuit[ActiveActor] <> Nil Then
     WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
     Begin
         NValues := NConds*NTerms;
         Result := VarArrayCreate([0, 2*NValues-1], varDouble);
         cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
         GetCurrents(cBuffer, ActiveActor);
         iV :=0;
         For i := 1 to  NValues DO
         Begin
            Result[iV] := cBuffer^[i].re;
            Inc(iV);
            Result[iV] := cBuffer^[i].im;
            Inc(iV);
         End;
         Reallocmem(cBuffer,0);
     End
  Else
     Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Voltages: OleVariant;

// Bus Voltages at active terminal

VAR
  numcond, i,n,iV:Integer;
  Volts:Complex;

Begin

// Return voltages for all terminals

     IF ActiveCircuit[ActiveActor] <> Nil THEN
      WITH ActiveCircuit[ActiveActor] DO
      Begin
        If ActiveCktElement<>Nil THEN
        WITH ActiveCktElement DO
        Begin
         numcond := NConds*Nterms;
         Result := VarArrayCreate([0, 2*numcond-1], varDouble);
         // k := (Terminal-1)*numcond;    // RCD 8-30-00 Changed
         iV :=0;
         FOR i := 1 to  numcond DO
         Begin
            n := ActiveCktElement.NodeRef^[i];
            Volts := Solution.NodeV^[n]; // ok if =0
            Result[iV] := Volts.re;
            Inc(iV);
            Result[iV] := Volts.im;
            Inc(iV);
         End;
        End;
      End
    ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_EmergAmps: Double;
begin
     If ActiveCircuit[ActiveActor] <> Nil Then
     With ActiveCircuit[ActiveActor] Do
     Begin
         If (ActiveCktElement.DSSObjType and 3) = PD_ELEMENT Then
         Begin
             With ActiveCktElement As TPDElement Do Result := EmergAmps ;
         End
         Else Result := 0.0;
     End;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Enabled: WordBool;
Begin

   If ActiveCircuit[ActiveActor] <> Nil Then
      Result := ActiveCircuit[ActiveActor].ActiveCktElement.Enabled
   Else
       Result := False;

end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Losses: OleVariant;

Var
   LossValue :complex;
begin

     IF ActiveCircuit[ActiveActor] <> Nil THEN
      WITH ActiveCircuit[ActiveActor] DO
      Begin
        If ActiveCktElement<>Nil THEN
        Begin
         Result    := VarArrayCreate([0, 1], varDouble);
         LossValue := ActiveCktElement.Losses[ActiveActor];
         Result[0] := LossValue.re;
         Result[1] := LossValue.im;
        End;
      End
    ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_NormalAmps: Double;
begin
     If ActiveCircuit[ActiveActor] <> Nil Then
     With ActiveCircuit[ActiveActor] Do
     Begin
         If (ActiveCktElement.DSSObjType and 3) = PD_ELEMENT Then
         Begin
             With ActiveCktElement As TPDElement Do Result := NormAmps ;
         End
         Else Result := 0.0;
     End;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_PhaseLosses: OleVariant;

// Returns Phase losses in kW, kVar

VAR
  cBuffer:pComplexArray;
  NValues,  i, iV : Integer;

Begin


 IF ActiveCircuit[ActiveActor] <> Nil THEN

  WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
  Begin
      NValues := NPhases;
      Result := VarArrayCreate([0, 2*NValues-1], varDouble);
      cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
      GetPhaseLosses( NValues, cBuffer, ActiveActor);
      iV :=0;
      For i := 1 to  NValues DO Begin
           Result[iV] := cBuffer^[i].re*0.001;
           Inc(iV);
           Result[iV] := cBuffer^[i].im*0.001;
           Inc(iV);
      End;
      Reallocmem(cBuffer,0);
  End
 ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_Powers: OleVariant;

// Return complex kW, kvar in each conductor for each terminal

VAR
   cBuffer:pComplexArray;
   NValues,
   i,
   iV : Integer;

Begin

 IF ActiveCircuit[ActiveActor] <> Nil THEN
  WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
  Begin
      NValues := NConds*Nterms;
      Result := VarArrayCreate([0, 2*NValues-1], varDouble);
      cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
      GetPhasePower(cBuffer, Activeactor);
      iV :=0;
      For i := 1 to  NValues DO Begin
           Result[iV] := cBuffer^[i].re*0.001;
           Inc(iV);
           Result[iV] := cBuffer^[i].im*0.001;
           Inc(iV);
      End;
      Reallocmem(cBuffer,0);
  End
 ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
Procedure CalcSeqCurrents(pActiveElement:TDSSCktElement; i012:pComplexArray);
{Assumes V012 is properly allocated before call.}
VAR
    Nvalues,i,j,k,iV  :Integer;
    IPh, I012a        :Array[1..3] of Complex;
    cBuffer:pComplexArray;

BEGIN
    With pActiveElement, ActiveCircuit[ActiveActor] Do BEGIN
      Nvalues := NPhases;
      IF Nvalues <> 3 THEN Begin
        {Handle non-3 phase elements}
           IF (Nphases = 1) and PositiveSequence THEN
           Begin
                NValues := NConds*NTerms;
                cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
                GetCurrents(cBuffer, ActiveActor);

                For i := 1 to  3*NTerms DO i012^[i] := CZERO;   // Initialize Result
                iV := 2;  // pos seq is 2nd element in array
                {Populate only phase 1 quantities in Pos seq}
                FOR j := 1 to NTerms Do Begin
                    k := (j - 1) * NConds;
                    i012^[iV] := cBuffer^[1 + k];
                    Inc(iV, 3);  // inc to pos seq of next terminal
                End;
                Reallocmem(cBuffer, 0);
           END
           // if neither 3-phase or pos seq model, just put in -1.0 for each element
           ELSE  For i := 1 to  3*NTerms Do i012^[i] := Cmplx(-1.0, 0.0);  // Signify n/A
      End
      ELSE Begin    // for 3-phase elements
           iV := 1;
           NValues := NConds * NTerms;
           cBuffer := Allocmem(sizeof(cBuffer^[1]) * NValues);
           GetCurrents(cBuffer, ActiveActor);
           FOR j := 1 to NTerms Do
           Begin
                k := (j-1)*NConds;
                For i := 1 to  3 DO Iph[i] := cBuffer^[k+i];
                Phase2SymComp(@Iph, @I012a);

                For i := 1 to 3 DO  Begin     // Stuff it in the result array
                   i012^[iV] := i012a[i];
                   Inc(iV);
                End;
           End;
           Reallocmem(cBuffer, 0);
      End;
    END;
END;


{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_SeqCurrents: OleVariant;

// All sequence currents of active ciruit element
// returns magnitude only.

VAR
    i  :Integer;
    i012 :pComplexArray;
    S :String;

Begin
  IF   ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     If Enabled Then
     Begin
         TRY
            Result := VarArrayCreate([0, 3*NTerms-1], varDouble);

            i012 := Allocmem(Sizeof(i012^[1]) * 3 * Nterms);
            // get complex seq voltages
            CalcSeqCurrents(ActiveCktElement, i012);
            // return 0 based array
            For i := 1 to 3*Nterms do Result[i-1] := Cabs(i012^[i]);  // return mag only

            Reallocmem(i012, 0);  // throw away temp memory

          EXCEPT
             On E:Exception Do
             Begin
                S:= E.message + CRLF +
                    'Element='+ ActiveCktElement.Name + CRLF+
                    'Nphases=' + IntToStr(Nphases) + CRLF +
                    'NTerms=' + IntToStr(NTerms) + CRLF +
                    'NConds =' + IntToStr(NConds);
                DoSimpleMsg(S, 5012);
              End;
          END;
     End
     Else
         Result := VarArrayCreate([0, 0], varDouble);  // Disabled

   End
  ELSE Result := VarArrayCreate([0, 0], varDouble);

end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_SeqPowers: OleVariant;


// All seq Powers of active 3-phase ciruit element
// returns kW + j kvar

VAR
  Nvalues,i,j,k,n, icount:Integer;
  S:Complex;
  VPh, V012 : Array[1..3] of Complex;
  IPh, I012 : Array[1..3] of Complex;
  cBuffer:pComplexArray;

Begin

 IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO Begin
      Result := VarArrayCreate([0, 2*3*NTerms-1], varDouble); // allocate for kW and kvar
      IF NPhases <> 3 THEN
      Begin
           IF (Nphases = 1) and PositiveSequence THEN
           Begin
                NValues := NConds*NTerms;
                cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
                GetCurrents(cBuffer, ActiveActor);

                For i := 0 to  2*3*NTerms-1 DO Result[i] := 0.0;   // Initialize Result
                iCount := 2;  // Start with kW1
                {Put only phase 1 quantities in Pos seq}
                FOR j := 1 to NTerms Do
                Begin
                    k := (j-1)*NConds;
                    n := NodeRef^[k+1];
                    Vph[1] := Solution.NodeV^[n];  // Get voltage at node
                    S := Cmul(Vph[1], conjg(cBuffer^[k+1]));   // Compute power per phase
                    Result[icount] := S.re*0.003; // 3-phase kW conversion
                    inc(icount);
                    Result[icount] := S.im*0.003; // 3-phase kvar conversion
                    inc(icount, 6);
                End;
                Reallocmem(cBuffer,0);
           END

           ELSE  For i := 0 to  2*3*NTerms-1 DO Result[i] := -1.0;  // Signify n/A
      END
      ELSE Begin
          NValues := NConds*NTerms;
          cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
          GetCurrents(cBuffer, ActiveActor);
          icount := 0;
          FOR j := 1 to NTerms Do Begin
             k :=(j-1)*NConds;
             FOR i := 1 to  3 DO Vph[i] := Solution.NodeV^[NodeRef^[i+k]];
             For i := 1 to  3 DO Iph[i] := cBuffer^[k+i];
             Phase2SymComp(@Iph, @I012);
             Phase2SymComp(@Vph, @V012);
             For i := 1 to 3 DO  Begin
                 S := Cmul(V012[i], conjg(I012[i]));
                 Result[icount] := S.re*0.003; // 3-phase kW conversion
                 inc(icount);
                 Result[icount] := S.im*0.003; // 3-phase kW conversion
                 inc(icount);
             End;
          End;
          Reallocmem(cBuffer,0);
      End;
     End;
   End
 ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
Procedure CalcSeqVoltages(pActiveElement:TDSSCktElement; V012:pComplexArray);
{Assumes V012 is properly allocated before call.}
VAR
    Nvalues,i,j,k,iV  :Integer;
    VPh, V012a        :Array[1..3] of Complex;
BEGIN
    With pActiveElement, ActiveCircuit[ActiveActor] Do BEGIN
      Nvalues := NPhases;
      IF Nvalues <> 3 THEN Begin
        {Handle non-3 phase elements}
           IF (Nphases = 1) and PositiveSequence THEN
           Begin
                For i := 1 to  3*NTerms DO V012^[i] := CZERO;   // Initialize Result
                iV := 2;  // pos seq is 2nd element in array
                {Populate only phase 1 quantities in Pos seq}
                FOR j := 1 to NTerms Do Begin
                    k := (j - 1) * NConds;
                    V012^[iV] := Solution.NodeV^[NodeRef^[1 + k]];
                    Inc(iV, 3);  // inc to pos seq of next terminal
                End;
           END
           // if neither 3-phase or pos seq model, just put in -1.0 for each element
           ELSE  For i := 1 to  3*NTerms Do V012^[i] := Cmplx(-1.0, 0.0);  // Signify n/A
      End
      ELSE Begin    // for 3-phase elements
           iV := 1;
           FOR j := 1 to NTerms Do
           Begin
                k :=(j-1)*NConds;
                FOR i := 1 to  3 DO Vph[i] := Solution.NodeV^[NodeRef^[i+k]];
                Phase2SymComp(@Vph, @V012a);   // Compute Symmetrical components

                For i := 1 to 3 DO  Begin     // Stuff it in the result array
                   V012^[iV] := V012a[i];
                   Inc(iV);
                End;
           End;
      End;
    END;
END;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
function TCktElement.Get_SeqVoltages: OleVariant;
// All voltages of active ciruit element
// magnitude only
// returns a set of seq voltages (3) for each terminal
// 0, 1, 2 sequence  (0, +, -)

VAR
    i  :Integer;
    V012 :pComplexArray;
    S :String;

Begin
  IF   ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     If Enabled Then
     Begin
         TRY
            Result := VarArrayCreate([0, 3*NTerms-1], varDouble);

            V012 := Allocmem(Sizeof(V012^[1]) * 3 * Nterms);
            // get complex seq voltages
            CalcSeqVoltages(ActiveCktElement, V012);
            // return 0 based array
            For i := 1 to 3*Nterms do Result[i-1] := Cabs(V012^[i]);  // return mag only

            Reallocmem(V012, 0);  // throw away temp memory

          EXCEPT
             On E:Exception Do
             Begin
                S:= E.message + CRLF +
                    'Element='+ ActiveCktElement.Name + CRLF+
                    'Nphases=' + IntToStr(Nphases) + CRLF +
                    'NTerms=' + IntToStr(NTerms) + CRLF +
                    'NConds =' + IntToStr(NConds);
                DoSimpleMsg(S, 5012);
              End;
          END;
     End
     Else
         Result := VarArrayCreate([0, 0], varDouble);  // Disabled

   End
  ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
procedure TCktElement.Close(Term, Phs: Integer);

Begin

   IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
      If ActiveCktElement<>nil THEN
      WITH ActiveCktElement DO
      Begin
        ActiveTerminal := Terminals^[Term];
        Closed[Phs,ActiveActor] := TRUE;
      End;
   End;

end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
procedure TCktElement.Open(Term, Phs: Integer);

Begin
   IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
      If ActiveCktElement<>nil THEN
      WITH ActiveCktElement DO
      Begin
        ActiveTerminal := Terminals^[Term];
        Closed[Phs,ActiveActor] := FALSE;
      End;
   End;

end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
procedure TCktElement.Set_EmergAmps(Value: Double);

begin

     If ActiveCircuit[ActiveActor] <> Nil Then
     With ActiveCircuit[ActiveActor] Do
     Begin
         If IsPDElement Then
         Begin
             With ActiveCktElement As TPDElement Do EmergAmps := Value;
         End;  {Else Do Nothing}
     End;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
procedure TCktElement.Set_Enabled(Value: WordBool);
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
      ActiveCircuit[ActiveActor].ActiveCktElement.Enabled := Value;
end;

{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -}
procedure TCktElement.Set_NormalAmps(Value: Double);
begin
     If ActiveCircuit[ActiveActor] <> Nil Then
     Begin
         If IsPDElement Then
         Begin
             With ActiveCircuit[ActiveActor] Do With ActiveCktElement As TPDElement Do NormAmps := Value;
         End;  {Else Do Nothing}
     End;
end;


function TCktElement.IsOpen(Term, Phs: Integer): WordBool;

Var
   i  :Integer;

begin
     If ActiveCircuit[ActiveActor] <> Nil Then
     With ActiveCircuit[ActiveActor] Do
     Begin
         With ActiveCktElement Do ActiveTerminal := Terminals^[Term];
         If Phs=0 Then // At least one must be open
         Begin
             Result := False;
             For i := 1 to ActiveCktElement.NConds Do
                 If not ActiveCktElement.Closed[i,ActiveActor] Then
                 Begin
                    Result :=  True;
                    Exit;
                 End;
         End
         Else // Check a specific phase or conductor
         Begin
             Result := Not ActiveCktElement.Closed[Phs,ActiveActor];
         End;
     End;
end;

function TCktElement.Get_AllPropertyNames: OleVariant;

VAR
   k:Integer;
begin
  Result := VarArrayCreate([0, 0], varOleStr);
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin
          WITH ParentClass Do
          Begin
              Result := VarArrayCreate([0, NumProperties-1], varOleStr);
              For k := 1 to NumProperties DO Begin
                  Result[k-1] := PropertyName^[k];
              End;
          End;
     End
   End;
end;

function TCktElement.Get_NumProperties: Integer;
begin
  Result := 0;
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin
          Result := ParentClass.NumProperties ;
     End
   End;


end;

function TCktElement.Get_Residuals: OleVariant;
VAR
  cBuffer       :pComplexArray;
  iV ,i, j, k   :Integer;
  cResid        :Complex;

Begin

  If ActiveCircuit[ActiveActor] <> Nil Then
     WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
     Begin
         Result := VarArrayCreate([0, 2*NTerms-1], varDouble);    // 2 values per terminal
         cBuffer := Allocmem(sizeof(cBuffer^[1])*Yorder);
         GetCurrents(cBuffer, ActiveActor);
         iV :=0;
         For i := 1 to  NTerms DO
         Begin
            cResid := CZERO;
            k :=(i-1)*Nconds;
            For j := 1 to Nconds Do Begin
                inc(k);
                Caccum(cResid, CBuffer^[k]);
            End;
            Result[iV] := Cabs(cResid);
            Inc(iV);
            Result[iV] := CDang(cResid);
            Inc(iV);
         End;
         Reallocmem(cBuffer,0);
     End
  Else
     Result := VarArrayCreate([0, 0], varDouble);

end;

function TCktElement.Get_Yprim: OleVariant;
{ Return the YPrim matrix for this element }

Var
   iV      : Integer;
   i       : Integer;
   NValues : Integer;
   cValues : pComplexArray;

begin
   IF ActiveCircuit[ActiveActor] = nil Then Begin
        Result := VarArrayCreate([0, 0], varDouble);
   End
   ELSE With ActiveCircuit[ActiveActor] Do
      If ActiveCktElement<>Nil THEN
      WITH ActiveCktElement Do  Begin
          NValues := SQR(Yorder);
          cValues := GetYprimValues(ALL_YPRIM);  // Get pointer to complex array of values
          If cValues=Nil Then Begin   // check for unassigned array
                            Result := VarArrayCreate([0, 0], varDouble);  // just return null array
                            Exit;  // Get outta here
                         End;
          Result := VarArrayCreate( [0, 2*NValues -1], varDouble);  // Make variant array
          iV := 0;

          FOR i := 1 to  NValues DO  Begin    // Plunk the values in the variant array
              Result[iV] := cValues^[i].re;
              Inc(iV);
              Result[iV] := cValues^[i].im;
              Inc(iV);
          End;
      End
      ELSE Result := VarArrayCreate([0, 0], varDouble);  // just return null array

end;

function TCktElement.Get_DisplayName: WideString;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
      Result := ActiveCircuit[ActiveActor].ActiveCktElement.DisplayName
   Else
      Result := '';
end;

function TCktElement.Get_GUID: WideString;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
      Result := ActiveCircuit[ActiveActor].ActiveCktElement.ID
   Else
      Result := '';
end;

function TCktElement.Get_Handle: Integer;
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
      Result := ActiveCircuit[ActiveActor].ActiveCktElement.Handle
   Else
      Result := 0;
end;

procedure TCktElement.Set_DisplayName(const Value: WideString);
begin
   If ActiveCircuit[ActiveActor] <> Nil Then
      ActiveCircuit[ActiveActor].ActiveCktElement.DisplayName := Value;
end;

function TCktElement.Get_Controller(idx: Integer): WideString;
var
  ctrl: TDSSCktElement;
begin
  Result := '';
  If ActiveCircuit[ActiveActor] <> Nil Then With ActiveCircuit[ActiveActor] Do begin
    If (idx>0) and (idx <= ActiveCktElement.ControlElementList.Listsize) Then
    Begin
      ctrl := ActiveCktElement.ControlElementList.Get(idx);
      If ctrl <> Nil Then
        Result := Format('%s.%s', [ctrl.ParentClass.Name, ctrl.Name]);
    End;
  end;
end;

function TCktElement.Get_EnergyMeter: WideString;
var
  pd: TPDElement;
begin
  Result := '';
  If ActiveCircuit[ActiveActor] <> Nil Then begin
    if ActiveCircuit[ActiveActor].ActiveCktElement.HasEnergyMeter then begin
      pd := ActiveCircuit[ActiveActor].ActiveCktElement as TPDElement;
      Result := pd.MeterObj.Name;
    end;
  end;
end;

function TCktElement.Get_HasVoltControl: WordBool;

// Returns true if any of the controls is a capcontrol or a regcontrol
var
  ctrl: TDSSCktElement;
begin
  Result := FALSE;
  If ActiveCircuit[ActiveActor] <> Nil Then begin
    ctrl := ActiveCircuit[ActiveActor].ActiveCktElement.ControlElementlist.First;
    While ctrl <> Nil Do Begin
      case (ctrl.DSSObjType And CLASSMASK) of
        CAP_CONTROL,
        REG_CONTROL: Result := True;
      else
        Result := False;
      end;
      If Result Then  Exit;

      ctrl := ActiveCircuit[ActiveActor].ActiveCktElement.ControlElementlist.Next;
    End;
  end;
end;

function TCktElement.Get_HasSwitchControl: WordBool;
var
  ctrl: TDSSCktElement;
begin
  Result := FALSE;
  If ActiveCircuit[ActiveActor] <> Nil Then begin
    ctrl := ActiveCircuit[ActiveActor].ActiveCktElement.ControlElementList.First;
    While ctrl <> Nil Do
    Begin
      case (ctrl.DSSObjType And CLASSMASK) of
        SWT_CONTROL: Result := True;
      else
        Result := False;
      end;
      If Result Then  Exit;

      ctrl := ActiveCircuit[ActiveActor].ActiveCktElement.ControlElementlist.Next;
    End;
  end;
end;

function TCktElement.Get_CplxSeqVoltages: OleVariant;
{returns Seq Voltages as array of complex values}
VAR
    i, iV  :Integer;
    V012 :pComplexArray;
    S :String;

Begin

  IF   ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     If Enabled Then
     Begin
         TRY
            Result := VarArrayCreate([0, 2*3*NTerms-1], varDouble);

            V012 := Allocmem(Sizeof(V012^[1]) * 3 * Nterms);
            // get complex seq voltages
            CalcSeqVoltages(ActiveCktElement, V012);
            // return 0 based array
            iV := 0;
            For i := 1 to 3*Nterms do Begin
                Result[iV] := V012^[i].re;
                inc(iV);
                Result[iV] := V012^[i].im;
                inc(iV);
            End;

            Reallocmem(V012, 0);  // throw away temp memory

          EXCEPT
             On E:Exception Do
             Begin
                S:= E.message + CRLF +
                    'Element='+ ActiveCktElement.Name + CRLF+
                    'Nphases=' + IntToStr(Nphases) + CRLF +
                    'NTerms=' + IntToStr(NTerms) + CRLF +
                    'NConds =' + IntToStr(NConds);
                DoSimpleMsg(S, 5012);
              End;
          END;
     End
     Else
         Result := VarArrayCreate([0, 0], varDouble);  // Disabled

   End
  ELSE Result := VarArrayCreate([0, 0], varDouble);

end;

function TCktElement.Get_CplxSeqCurrents: OleVariant;
{returns Seq Voltages as array of complex values}
VAR
    i, iV  :Integer;
    i012 :pComplexArray;
    S :String;

Begin

  IF   ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     If Enabled Then
     Begin
         TRY
            Result := VarArrayCreate([0, 2*3*NTerms-1], varDouble);

            i012 := Allocmem(Sizeof(i012^[1]) * 3 * Nterms);
            // get complex seq voltages
            CalcSeqCurrents(ActiveCktElement, i012);
            // return 0 based array
            iV := 0;
            For i := 1 to 3*Nterms do Begin
                Result[iV] := i012^[i].re;
                inc(iV);
                Result[iV] := i012^[i].im;
                inc(iV);
            End;

            Reallocmem(i012, 0);  // throw away temp memory

          EXCEPT
             On E:Exception Do
             Begin
                S:= E.message + CRLF +
                    'Element='+ ActiveCktElement.Name + CRLF+
                    'Nphases=' + IntToStr(Nphases) + CRLF +
                    'NTerms=' + IntToStr(NTerms) + CRLF +
                    'NConds =' + IntToStr(NConds);
                DoSimpleMsg(S, 5012);
              End;
          END;
     End
     Else
         Result := VarArrayCreate([0, 0], varDouble);  // Disabled

   End
  ELSE Result := VarArrayCreate([0, 0], varDouble);


end;

function TCktElement.Get_AllVariableNames: OleVariant;
VAR
   k:Integer;
   pPCElem :TPCElement;

begin

  Result := VarArrayCreate([0, 0], varOleStr);
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              Result := VarArrayCreate([0, pPCElem.NumVariables-1], varOleStr);
              For k := 1 to pPCElem.NumVariables DO
              Begin
                  Result[k-1] := pPCElem.VariableName(k);
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_AllVariableValues: OleVariant;

{Return array of doubles with values of all variables if PCElement}
VAR
   k:Integer;
   pPCElem :TPCElement;

begin

  Result := VarArrayCreate([0, 0], varDouble);
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              Result := VarArrayCreate([0, pPCElem.NumVariables-1], varDouble);
              For k := 1 to pPCElem.NumVariables DO
              Begin
                  Result[k-1] := pPCElem.Variable[k];
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_Variable(const MyVarName: WideString; out Code: Integer): Double;

Var
      pPCElem:TPCElement;
      VarIndex :Integer;

begin
  Result := 0.0; Code := 1; // Signifies an error; no value set
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              VarIndex := pPCElem.LookupVariable(MyVarName);
              If (VarIndex>0) and (VarIndex <= pPCElem.NumVariables) Then
              Begin
                   Result := pPCElem.Variable[VarIndex];
                   Code := 0;  // Signify result is OK.
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_Variablei(Idx: Integer; out Code: Integer): Double;

{Get Value of a variable by index}
Var
      pPCElem:TPCElement;

begin
  Result := 0.0; Code := 1; // Signifies an error; no value set
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              If (Idx>0) and (Idx <= pPCElem.NumVariables) Then
              Begin
                   Result := pPCElem.Variable[Idx];
                   Code := 0;  // Signify result is OK.
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_NodeOrder: OleVariant;
VAR
   k : Integer;
   i : Integer;
   j : Integer;
begin

      Result := VarArrayCreate([0, 0], varInteger);
      If ActiveCircuit[ActiveActor] <> Nil Then With ActiveCircuit[ActiveActor] Do
      Begin

         If ActiveCktElement<>Nil THEN
         WITH ActiveCktElement DO
         Begin
              k := 0;
              Result := VarArrayCreate([0, NTerms*Nconds-1], varInteger);

              for i := 1 to Nterms do
              Begin
                  for j := (i-1)*NConds+1 to i*Nconds do
                  Begin
                       Result[k] := GetNodeNum(NodeRef^[j]);
                       inc(k);
                  End;
              End;
         End
      End;


end;

function TCktElement.Get_HasOCPDevice: WordBool;

// Check for presence of a fuse, recloser, etc.
begin
  Result := FALSE;
  If ActiveCircuit[ActiveActor] <> Nil Then begin
    Result := ActiveCircuit[ActiveActor].ActiveCktElement.HasOCPDevice;
  end;
end;

function TCktElement.Get_NumControls: Integer;
begin
  Result := 0;
  If ActiveCircuit[ActiveActor] <> Nil Then begin
    Result := ActiveCircuit[ActiveActor].ActiveCktElement.ControlElementList.listSize;
  end;
end;

function TCktElement.Get_OCPDevIndex: Integer;
Var
   iControl : integer;
   pCktElement : TDSSCktElement;

begin
     Result := 0;
     If ActiveCircuit[ActiveActor] <> Nil Then  With ActiveCircuit[ActiveActor] Do
     Begin
         iControl := 1;
         Repeat
           // cycle through the list of controls until we find a fuse, recloser, or relay
              pCktElement :=  ActiveCktElement.ControlElementList.Get(iControl);
              If pCktElement <> Nil Then
              Case (pCktElement.DSSObjType and CLASSMASK) of

                  FUSE_CONTROL     : Result := iControl;
                  RECLOSER_CONTROL : Result := iControl;
                  RELAY_CONTROL    : Result := iControl;

              End;
              inc(iControl);
         Until (iControl > ActiveCktElement.ControlElementList.listSize) or (Result > 0);
     End;
end;

function TCktElement.Get_OCPDevType: Integer;
begin
     Result := 0;
     If ActiveCircuit[ActiveActor] <> Nil Then  With ActiveCircuit[ActiveActor] Do
         Result := GetOCPDeviceType(ActiveCktElement);     // see Utilities.pas
end;

function TCktElement.Get_CurrentsMagAng: OleVariant;
// return currents in magnitude, angle array
VAR
  cBuffer: pComplexArray;
  CMagAng: polar;
  NValues, iV ,i: Integer;

Begin

  If ActiveCircuit[ActiveActor] <> Nil Then
     WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
     Begin
         NValues := NConds*NTerms;
         Result := VarArrayCreate([0, 2*NValues-1], varDouble);
         cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
         GetCurrents(cBuffer, ActiveActor);
         iV :=0;
         For i := 1 to  NValues DO
         Begin
            CMagAng := ctopolardeg(cBuffer^[i]); // convert to mag/angle
            Result[iV] := CMagAng.mag ;
            Inc(iV);
            Result[iV] := CMagAng.ang ;
            Inc(iV);
         End;
         Reallocmem(cBuffer,0);
     End
  Else
     Result := VarArrayCreate([0, 0], varDouble);

end;

function TCktElement.Get_VoltagesMagAng: OleVariant;

// Bus Voltages in magnitude, angle at all terminal

VAR
  numcond, i,n,iV:Integer;
  Volts:Polar;

Begin

// Return voltages for all terminals

     IF ActiveCircuit[ActiveActor] <> Nil THEN
      WITH ActiveCircuit[ActiveActor] DO
      Begin
        If ActiveCktElement<>Nil THEN
        WITH ActiveCktElement DO
        Begin
         numcond := NConds*Nterms;
         Result := VarArrayCreate([0, 2*numcond-1], varDouble);
         // k := (Terminal-1)*numcond;    // RCD 8-30-00 Changed
         iV :=0;
         FOR i := 1 to  numcond DO
         Begin
            n := ActiveCktElement.NodeRef^[i];
            Volts := ctopolardeg(Solution.NodeV^[n]); // ok if =0
            Result[iV] := Volts.mag;
            Inc(iV);
            Result[iV] := Volts.ang;
            Inc(iV);
         End;
        End;
      End
    ELSE Result := VarArrayCreate([0, 0], varDouble);

end;

function TCktElement.Get_TotalPowers: OleVariant;
VAR
  cBuffer     : pComplexArray;
  NValues,
  myInit,
  myEnd,
  j,
  i,
  iV          : Integer;
  myBuffer    : Array of Complex;

Begin

 IF ActiveCircuit[ActiveActor] <> Nil THEN
  WITH ActiveCircuit[ActiveActor].ActiveCktElement DO
  Begin
    NValues := NConds*Nterms;
    Result := VarArrayCreate([0, 2*Nterms-1], varDouble);
    cBuffer := Allocmem(sizeof(cBuffer^[1])*NValues);
    GetPhasePower(cBuffer, Activeactor);
    iV :=0;
    setlength(myBuffer,Nterms);
    for j := 1 to Nterms do
    Begin
      myBuffer[j - 1] :=  cmplx(0.0, 0.0);
      myInit          :=  (j - 1) * NConds + 1;
      myEnd           :=  NConds * j;
      For i := myInit to myEnd DO
      Begin
        myBuffer[j - 1] :=  cadd(myBuffer[j - 1], cBuffer^[i]);
      End;
      Result[iV]  :=  myBuffer[j - 1].re*0.001;
      inc(iV);
      Result[iV]  :=  myBuffer[j - 1].im*0.001;
      inc(iV);
    End;
    Reallocmem(cBuffer,0);
  End
  ELSE Result := VarArrayCreate([0, 0], varDouble);

end;

function TCktElement.Get_VariableByName(const MyVarName: WideString; out Code: Integer): Double;

Var
      pPCElem:TPCElement;
      VarIndex :Integer;

begin
  Result := 0.0; Code := 1; // Signifies an error; no value set
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              VarIndex := pPCElem.LookupVariable(MyVarName);
              If (VarIndex>0) and (VarIndex <= pPCElem.NumVariables) Then
              Begin
                   Result := pPCElem.Variable[VarIndex];
                   Code := 0;  // Signify result is OK.
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

procedure TCktElement.Set_VariableByName(const MyVarName: WideString; out Code: Integer;
          Value: Double);
Var
      pPCElem:TPCElement;
      VarIndex :Integer;

begin
  Code := 1; // Signifies an error; no value set
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              VarIndex := pPCElem.LookupVariable(MyVarName);
              If (VarIndex>0) and (VarIndex <= pPCElem.NumVariables) Then
              Begin
                   pPCElem.Variable[VarIndex] := Value;
                   Code := 0;  // Signify value is set
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_VariableByIndex(Idx: Integer; out Code: Integer): Double;

{Get Value of a variable by index}
Var
      pPCElem:TPCElement;

begin
  Result := 0.0; Code := 1; // Signifies an error; no value set
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              If (Idx>0) and (Idx <= pPCElem.NumVariables) Then
              Begin
                   Result := pPCElem.Variable[Idx];
                   Code := 0;  // Signify result is OK.
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

procedure TCktElement.Set_VariableByIndex(Idx: Integer; out Code: Integer; Value: Double);

{Set Value of a variable by index}
Var
      pPCElem:TPCElement;

begin
  Code := 1; // Signifies an error; no value set
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement<>Nil THEN
     WITH ActiveCktElement DO
     Begin

         If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
          Begin
              pPCElem := (ActiveCktElement as TPCElement);
              If (Idx>0) and (Idx <= pPCElem.NumVariables) Then
              Begin
                   pPCElem.Variable[Idx] := Value;
                   Code := 0;  // Signify operation executed OK.
              End;
          End;

         {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_VariableName: WideString;
Var
      pPCElem:TPCElement;
begin
  Result  :=  '';
  IF ActiveCircuit[ActiveActor] <> Nil THEN
  Begin
    WITH ActiveCircuit[ActiveActor] DO
    Begin
      If ActiveCktElement <> Nil THEN
      WITH ActiveCktElement DO
      Begin
        If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
        Begin
            pPCElem := (ActiveCktElement as TPCElement);
            If (VarIdx>=0) or (VarIdx <= pPCElem.NumVariables) Then
              Result :=  pPCElem.VariableName(VarIdx);
        End
        else
          DoSimpleMsg('The active circuit element is not a PC Element', 100004)
       {Else zero-length array null string}
      End
    End;
  End;
end;

procedure TCktElement.Set_VariableName(const Value: WideString);
Var
      pPCElem:TPCElement;
begin
  VarIdx    :=  -1;
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     Begin
        If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
        Begin
            pPCElem := (ActiveCktElement as TPCElement);
            VarIdx := pPCElem.LookupVariable(Value);
            If (VarIdx<=0) or (VarIdx > pPCElem.NumVariables) Then
              DoSimpleMsg('The variable ' + Value + 'does not exist', 100001);
        End
        else
          DoSimpleMsg('The active circuit element is not a PC Element', 100004)
       {Else zero-length array null string}
     End
   End;

end;

function TCktElement.Get_VariableValue: Double;
Var
      pPCElem:TPCElement;
begin
  IF ActiveCircuit[ActiveActor] <> Nil THEN
  Begin
    Result  :=  0.0;
    WITH ActiveCircuit[ActiveActor] DO
    Begin
      If ActiveCktElement <> Nil THEN
      WITH ActiveCktElement DO
      Begin
        If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
        Begin
            pPCElem := (ActiveCktElement as TPCElement);
            If (VarIdx<=0) or (VarIdx > pPCElem.NumVariables) Then
              DoSimpleMsg('There is no state variable active for the active circuit element', 100002)
            else
              Result :=  pPCElem.Variable[VarIdx];
        End
        else
          DoSimpleMsg('The active circuit element is not a PC Element', 100004)
       {Else zero-length array null string}
      End
    End;
  End;
end;

procedure TCktElement.Set_VariableValue(Value: Double);
Var
      pPCElem:TPCElement;
begin
  IF ActiveCircuit[ActiveActor] <> Nil THEN
  Begin
    WITH ActiveCircuit[ActiveActor] DO
    Begin
      If ActiveCktElement <> Nil THEN
      WITH ActiveCktElement DO
      Begin
        If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
        Begin
            pPCElem := (ActiveCktElement as TPCElement);
            If (VarIdx<=0) or (VarIdx > pPCElem.NumVariables) Then
              DoSimpleMsg('There is no state variable active for the active circuit element', 100002)
            else
              pPCElem.Variable[VarIdx]  :=  Value;
        End
        else
          DoSimpleMsg('The active circuit element is not a PC Element', 100004)
       {Else zero-length array null string}
      End
    End;
  End;

end;

function TCktElement.Get_VariableIdx: Integer;
Var
      pPCElem:TPCElement;
begin
  VarIdx    :=  -1;
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     Begin
        If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
        Begin
            Result  :=  VarIdx;
        End
        else
          DoSimpleMsg('The active circuit element is not a PC Element', 100004)
     End;
   End

end;

procedure TCktElement.Set_VariableIdx(Value: Integer);
Var
      pPCElem:TPCElement;
begin
  VarIdx    :=  -1;
  IF ActiveCircuit[ActiveActor] <> Nil THEN
   WITH ActiveCircuit[ActiveActor] DO
   Begin
     If ActiveCktElement <> Nil THEN
     WITH ActiveCktElement DO
     Begin
        If (DSSObjType And BASECLASSMASK) = PC_ELEMENT Then
        Begin
            pPCElem := (ActiveCktElement as TPCElement);
            VarIdx := -1;
            If (Value > pPCElem.NumVariables) Then
              DoSimpleMsg('The index provided exceeds the number of state variables for the active circuit element or is invalid', 100003)
            else
              Varidx  :=  Value;
        End
        else
          DoSimpleMsg('The active circuit element is not a PC Element', 100004)
     End;
   End
End;

initialization
  TAutoObjectFactory.Create(ComServer, TCktElement, Class_CktElement, ciInternal, tmApartment);
end.
