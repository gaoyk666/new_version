unit DTransformers;

interface

function TransformersI(mode: longint; arg: longint):longint; cdecl;
function TransformersF(mode: longint; arg: double):double; cdecl;
function TransformersS(mode: longint; arg: pAnsiChar):pAnsiChar; cdecl;
procedure TransformersV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

implementation

uses DSSGlobals, Executive, Transformer, Variants, SysUtils, PointerList, ucomplex;

function ActiveTransformer: TTransfObj;
begin
  Result := nil;
  if ActiveCircuit[ActiveActor] <> Nil then Result := ActiveCircuit[ActiveActor].Transformers.Active;
end;

procedure Set_Parameter(const parm: string; const val: string);
var
  cmd: string;
begin
  if not Assigned (ActiveCircuit[ActiveActor]) then exit;
  SolutionAbort := FALSE;  // Reset for commands entered from outside
  cmd := Format ('transformer.%s.%s=%s', [ActiveTransformer.Name, parm, val]);
  DSSExecutive[ActiveActor].Command := cmd;
end;

function TransformersI(mode: longint; arg: longint):longint; cdecl;

var
  elem: TTransfObj;
  lst: TPointerList;

begin
  Result:=0; // Default return value
  case mode of
  0: begin  // Transformers.NumWindings read
      Result := 0;
      elem := ActiveTransformer;
      if elem <> nil then Result := elem.NumberOfWindings;
  end;
  1: begin  // Transformers.NumWindings write
      elem := ActiveTransformer;
      if elem <> nil then
        elem.SetNumWindings (arg);
  end;
  2: begin  // Transformers.Wdg read
      Result := 0;
      elem := ActiveTransformer;
      if elem <> nil then Result := elem.ActiveWinding;
  end;
  3: begin  // Transformers.Wdg write
      elem := ActiveTransformer;
      if elem <> nil then
        if (arg > 0) and (arg <= elem.NumberOfWindings) then
          elem.ActiveWinding := arg;
  end;
  4: begin  // Transformers.NumTaps read
      Result := 0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.NumTaps[elem.ActiveWinding];
  end;
  5: begin  // Transformers.NumTaps write
      Set_Parameter ('NumTaps', IntToStr (arg));
  end;
  6: begin  // Transformers.IsDelta read
      Result := 0;
      elem := ActiveTransformer;
      if elem <> nil then
        if elem.WdgConnection[elem.ActiveWinding] > 0 then Result := 1;
  end;
  7:begin  // Transformers.IsDelta write
      if arg = 1 then
        Set_Parameter ('Conn', 'Delta')
      else
        Set_Parameter ('Conn', 'Wye')
  end;
  8: begin  // Transformers.First
      Result := 0;
      If ActiveCircuit[ActiveActor] <> Nil Then begin
        lst := ActiveCircuit[ActiveActor].Transformers;
        elem := lst.First;
        If elem <> Nil Then Begin
          Repeat
            If elem.Enabled Then Begin
              ActiveCircuit[ActiveActor].ActiveCktElement := elem;
              Result := 1;
            End
            Else elem := lst.Next;
          Until (Result = 1) or (elem = nil);
        End;
      End;
  end;
  9: begin  // Transformers.Next
      Result := 0;
      If ActiveCircuit[ActiveActor] <> Nil Then Begin
        lst := ActiveCircuit[ActiveActor].Transformers;
        elem := lst.Next;
        if elem <> nil then begin
          Repeat
            If elem.Enabled Then Begin
              ActiveCircuit[ActiveActor].ActiveCktElement := elem;
              Result := lst.ActiveIndex;
            End
            Else elem := lst.Next;
          Until (Result > 0) or (elem = nil);
        End
      End;
  end;
  10: begin  // Transformers.Count
     If Assigned(ActiveCircuit[ActiveActor]) Then
          Result := ActiveCircuit[ActiveActor].Transformers.ListSize;
  end;
  11: begin  // Transformers.CoreType read
    elem := ActiveTransformer;
    if elem <> nil then
      Result := elem.CoreType ;
  end;
  12: begin  // Transformers.CoreType write
    elem := ActiveTransformer;
    if elem <> nil then
    Begin
      elem.CoreType := arg;
      Case arg of
         1: elem.strCoreType := '1-phase';
         3: elem.strCoreType := '3-leg';
         4: elem.strCoreType := '4-leg';
         5: elem.strCoreType := '5-leg';
         9: elem.strCoreType := 'core-1-phase';
      Else
          elem.strCoreType := 'shell';
      End;
    End;
  end
  else
      Result:=-1;
  end;
end;

//*****************************Floating point type properties************************
function TransformersF(mode: longint; arg: double):double; cdecl;

var
  elem: TTransfObj;

begin
  Result:=0.0;     // Default return value
  case mode of
  0: begin  // Transformers.R read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.WdgResistance[elem.ActiveWinding] * 100.0;
  end;
  1: begin  // Transformers.R write
      Set_Parameter ('%R', FloatToStr (arg));
  end;
  2: begin  // Transformers.Tap read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.PresentTap[elem.ActiveWinding,ActiveActor];
  end;
  3: begin  // Transformers.Tap write
      Set_Parameter ('Tap', FloatToStr (arg));
  end;
  4: begin  // Transformers.MinTap read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.Mintap[elem.ActiveWinding];
  end;
  5: begin  // Transformers.MinTap write
      Set_Parameter ('MinTap', FloatToStr (arg));
  end;
  6: begin  // Transformers.MaxTap read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.Maxtap[elem.ActiveWinding];
  end;
  7: begin  // Transformers.MaxTap write
      Set_Parameter ('MaxTap', FloatToStr (arg));
  end;
  8: begin  // Transformers.kV read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.Winding^[elem.ActiveWinding].kvll;
  end;
  9: begin  // Transformers.kV write
      Set_Parameter ('kv', FloatToStr (arg));
  end;
  10: begin  // Transformers.kVA read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.WdgKVA[elem.ActiveWinding];
  end;
  11: begin  // Transformers.kVA write
      Set_Parameter ('kva', FloatToStr (arg));
  end;
  12: begin  // Transformers.Xneut read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.WdgXneutral[elem.ActiveWinding];
  end;
  13: begin  // Transformers.Xneut write
      Set_Parameter ('Xneut', FloatToStr (arg));
  end;
  14: begin  // Transformers.Rneut read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.WdgRneutral[elem.ActiveWinding];
  end;
  15: begin  // Transformers.Rneut write
      Set_Parameter ('Rneut', FloatToStr (arg));
  end;
  16: begin  // Transformers.Xhl read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then Result := elem.XhlVal * 100.0;
  end;
  17: begin  // Transformers.Xhl write
      Set_Parameter ('Xhl', FloatToStr (arg));
  end;
  18: begin  // Transformers.Xht read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then Result := elem.XhtVal * 100.0;
  end;
  19: begin  // Transformers.Xht write
      Set_Parameter ('Xht', FloatToStr (arg));
  end;
  20: begin  // Transformers.Xlt read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then Result := elem.XltVal * 100.0;
  end;
  21: begin  // Transformers.Xlt write
      Set_Parameter ('Xlt', FloatToStr (arg));
  end;
  22: begin  // Transformers.RdCOhms read
      Result := 0.0;
      elem := ActiveTransformer;
      if elem <> nil then
        Result := elem.WdgRdc[elem.ActiveWinding];
  end;
  23: begin  // Transformers.RdCOhms write
      Set_Parameter ('RdcOhms', FloatToStr (arg));
  end
  else
      Result:=-1.0;
  end;
end;

//*******************************String type properties****************************
function TransformersS(mode: longint; arg: pAnsiChar):pAnsiChar; cdecl;

var
  elem: TTransfObj;
  ActiveSave : Integer;
  S: String;
  Found :Boolean;
  lst: TPointerList;

begin
  Result:=pAnsiChar(AnsiString('0'));   // Default return value
  case mode of
  0: begin  // Transformers.XfmrCode read
      Result := pAnsiChar(AnsiString(''));
      elem := ActiveTransformer;
      if elem <> nil then Result := pAnsiChar(AnsiString(elem.XfmrCode));
  end;
  1: begin  // Transformers.XfmrCode write
      Set_Parameter ('XfmrCode', string(arg));
  end;
  2: begin  // Transformers.Name read
      Result := pAnsiChar(AnsiString(''));
      If ActiveCircuit[ActiveActor] <> Nil Then Begin
        elem := ActiveCircuit[ActiveActor].Transformers.Active;
        If elem <> Nil Then Result := pAnsiChar(AnsiString(elem.Name));
      End;
  end;
  3: begin  // Transformers.Name write
      IF ActiveCircuit[ActiveActor] <> NIL THEN Begin
        lst := ActiveCircuit[ActiveActor].Transformers;
        S := string(arg);  // Convert to Pascal String
        Found := FALSE;
        ActiveSave := lst.ActiveIndex;
        elem := lst.First;
        While elem <> NIL Do Begin
          IF (CompareText(elem.Name, S) = 0) THEN Begin
            ActiveCircuit[ActiveActor].ActiveCktElement := elem;
            Found := TRUE;
            Break;
            End;
            elem := lst.Next;
        End;
        IF NOT Found THEN Begin
          DoSimpleMsg('Transformer "'+S+'" Not Found in Active Circuit.', 5003);
          elem := lst.Get(ActiveSave);    // Restore active Load
          ActiveCircuit[ActiveActor].ActiveCktElement := elem;
        End;
     End;
  end;
  4: begin // Transformers.StrWdgVoltages
        elem := ActiveTransformer;
        if elem <> nil then
        Begin
            Result := pAnsiChar(AnsiString(elem.GetWindingCurrentsResult(ActiveActor)));
        End;
  end
  else
      Result:=pAnsiChar(AnsiString('Error, parameter not valid'));
  end;
end;

//*****************************Variant ype properties*****************************
procedure TransformersV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

Var
  elem              : TTransfObj;
  lst               : TPointerList;
  i,
  iV,
  NumCurrents       : Integer;
  TempCurrentBuffer,
  TempVoltageBuffer : pComplexArray;

begin
  case mode of
  0:begin  // Transformers.AllNames
      myType  :=  4;        // String
      setlength(myStrArray,0);
      IF ActiveCircuit[ActiveActor] <> Nil THEN
      Begin
        WITH ActiveCircuit[ActiveActor] DO
        Begin
          If Transformers.ListSize > 0 Then
          Begin
            lst := Transformers;
            elem := lst.First;
            WHILE elem<>Nil DO
            Begin
              WriteStr2Array(elem.Name);
              WriteStr2Array(Char(0));
              elem := lst.Next;
            End;
          End;
        End;
      End;
      if (length(myStrArray) = 0) then
        WriteStr2Array('None');
      myPointer :=  @(myStrArray[0]);
      mySize    :=  Length(myStrArray);
    end;
  1: begin // Transformers.WdgVoltages
      myType  :=  3;        // Complex
      setlength(myCmplxArray, 1);
      myCmplxArray[0] := CZero;
      elem := ActiveTransformer;
      if elem <> nil then
      Begin
      if (elem.ActiveWinding > 0) and (elem.ActiveWinding <= elem.NumberOfWindings) Then
        Begin
          setlength(myCmplxArray, elem.nphases);
          TempVoltageBuffer := AllocMem(Sizeof(Complex)*elem.nphases );
          elem.GetWindingVoltages( elem.ActiveWinding, TempVoltageBuffer, ActiveActor);
          iV :=0;
          For i := 1 to  elem.Nphases DO
          Begin
            myCmplxArray[iV] := TempVoltageBuffer^[i];
            Inc(iV);
          End;
          Reallocmem(TempVoltageBuffer, 0);
        End
      End;
      myPointer :=  @(myCmplxArray[0]);
      mySize    :=  SizeOf(myCmplxArray[0]) * Length(myCmplxArray);
    end;
  2: begin  // Transformers.WdgCurrents
      myType  :=  3;        // Complex
      setlength(myCmplxArray, 1);
      myCmplxArray[0] := CZero;
      elem := ActiveTransformer;
      if elem <> nil then
      Begin
        NumCurrents := 2*elem.NPhases*elem.NumberOfWindings; // 2 currents per winding
        setlength(myCmplxArray, NumCurrents);
        TempCurrentBuffer := AllocMem(Sizeof(Complex) * NumCurrents );;
        elem.GetAllWindingCurrents(TempCurrentBuffer, ActiveActor);
        iV :=0;
        For i := 1 to  NumCurrents DO
        Begin
          myCmplxArray[iV] := TempCurrentBuffer^[i];
          Inc(iV);
        End;
         Reallocmem(TempCurrentBuffer, 0);
      End;
      myPointer :=  @(myCmplxArray[0]);
      mySize    :=  SizeOf(myCmplxArray[0]) * Length(myCmplxArray);
    end
  else
    Begin
      myType  :=  4;        // String
      setlength(myStrArray, 0);
      WriteStr2Array('Error, parameter not recognized');
      myPointer :=  @(myStrArray[0]);
      mySize    :=  Length(myStrArray);
    End;
  end;
end;

end.
