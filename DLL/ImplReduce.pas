unit ImplReduce;

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  ComObj, ActiveX, OpenDSSengine_TLB, StdVcl;

type
  TReduceCkt = class(TAutoObject, IReduceCkt)
  protected
    function Get_Zmag: Double; safecall;
    procedure Set_Zmag(Value: Double); safecall;
    function Get_KeepLoad: WordBool; safecall;
    procedure Set_KeepLoad(Value: WordBool); safecall;
    function Get_EditString: WideString; safecall;
    procedure Set_EditString(const Value: WideString); safecall;
    function Get_StartPDElement: WideString; safecall;
    procedure Set_StartPDElement(const Value: WideString); safecall;
    function Get_EnergyMeter: WideString; safecall;
    procedure SaveCircuit(const CktName: WideString); safecall;
    procedure Set_EnergyMeter(const Value: WideString); safecall;
    procedure DoDefault; safecall;
    procedure DoShortLines; safecall;
    procedure Do1phLaterals; safecall;
    procedure DoBranchRemove; safecall;
    procedure DoDangling; safecall;
    procedure DoLoopBreak; safecall;
    procedure DoParallelLines; safecall;
    procedure DoSwitches; safecall;

  end;

implementation

uses Circuit, DSSGlobals, ComServ, Executive, EnergyMeter, ReduceAlgs, PDElement;

Var  ReduceEditString : String;
     EnergyMeterName  : String;
     FirstPDelement   : String;  // Full name

function TReduceCkt.Get_Zmag: Double;
begin
     if Assigned(ActiveCircuit) then
        Result := ActiveCircuit[ActiveActor].ReductionZmag
end;

procedure TReduceCkt.Set_Zmag(Value: Double);
begin
     if Assigned(ActiveCircuit[ActiveActor]) then
        ActiveCircuit[ActiveActor].ReductionZmag := Value;
end;

function TReduceCkt.Get_KeepLoad: WordBool;
begin
     if Assigned(ActiveCircuit[ActiveActor]) then
        Result := ActiveCircuit[ActiveActor].ReduceLateralsKeepLoad;
end;

procedure TReduceCkt.Set_KeepLoad(Value: WordBool);
begin
     if Assigned(ActiveCircuit[ActiveActor]) then
        ActiveCircuit[ActiveActor].ReduceLateralsKeepLoad := Value;
end;

function TReduceCkt.Get_EditString: WideString;
begin
     Result := ReduceEditString;
end;

procedure TReduceCkt.Set_EditString(const Value: WideString);
begin
     ReduceEditString := Value;
end;

function TReduceCkt.Get_StartPDElement: WideString;
begin
     Result := FirstPDelement;
end;

procedure TReduceCkt.Set_StartPDElement(const Value: WideString);
begin
     FirstPDelement := Value;
end;

function TReduceCkt.Get_EnergyMeter: WideString;
begin
    Result := EnergyMeterName;
end;

procedure TReduceCkt.SaveCircuit(const CktName: WideString);
begin
      DSSExecutive[ActiveActor].Command := 'Save Circuit Dir=' + CktName;
   // Master file name is returned in DSSText.Result
end;

procedure TReduceCkt.Set_EnergyMeter(const Value: WideString);
begin
      EnergyMeterName := Value;
end;

procedure TReduceCkt.DoDefault;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
       If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoReduceDefault(BranchList );
       End;
end;

procedure TReduceCkt.DoShortLines;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoReduceShortLines(BranchList );
       End;
end;

procedure TReduceCkt.Do1phLaterals;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoRemoveAll_1ph_Laterals(BranchList );
       End;
end;

procedure TReduceCkt.DoBranchRemove;
begin
     if Assigned(ActiveCircuit[ActiveActor]) then Begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           With ActiveCircuit[ActiveActor] Do Begin
               If SetElementActive(FirstPDelement)>= 0 Then // element was found  0-based array
               DoRemoveBranches(BranchList, ActiveCktElement as TPDElement, ReduceLateralsKeepLoad, ReduceEditString);
           End;
       End;
     End;
end;

procedure TReduceCkt.DoDangling;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoReduceDangling(BranchList );
       End;
end;

procedure TReduceCkt.DoLoopBreak;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoBreakLoops(BranchList );
       End;
end;

procedure TReduceCkt.DoParallelLines;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoMergeParallelLines(BranchList );
       End;
end;

procedure TReduceCkt.DoSwitches;
begin
       If EnergyMeterClass[ActiveActor].SetActive(EnergyMeterName) Then ActiveEnergyMeterObj:= EnergyMeterClass[ActiveActor].ElementList.Active;
       if Assigned(ActiveEnergyMeterObj) then
       With ActiveEnergyMeterObj Do   Begin
           If not assigned(BranchList) Then MakeMeterZoneLists(ActiveActor);
           DoRemoveAll_1ph_Laterals(BranchList );
       End;
end;

initialization
  TAutoObjectFactory.Create(ComServer, TReduceCkt, Class_ReduceCkt,
    ciInternal, tmApartment);

  ReduceEditString := ''; // Init to null string
  EnergyMeterName  := '';
  FirstPDelement := '';
end.
