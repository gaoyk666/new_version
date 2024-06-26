unit DLoadShape;

interface

function LoadShapeI(mode:longint; arg:longint):longint;cdecl;
function LoadShapeF(mode:longint; arg:double):double;cdecl;
function LoadShapeS(mode:longint; arg:pAnsiChar):pAnsiChar;cdecl;
procedure LoadShapeV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

implementation

uses Loadshape, DSSGlobals, PointerList, Variants, ExecHelper, ucomplex;

Var
    ActiveLSObject: TLoadshapeObj;

function LoadShapeI(mode:longint; arg:longint):longint;cdecl;

Var
   iElem : Integer;

begin
  Result := 0;   // Default return value
  case mode of
  0: begin  // LoadShapes.Count
     Result := 0;
     If ActiveCircuit[ActiveActor] <> Nil Then
        Result := LoadshapeClass[ActiveActor].ElementList.ListSize;
  end;
  1: begin  // LoadShapes.First
     Result := 0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     Begin
        iElem := LoadshapeClass[ActiveActor].First;
        If iElem <> 0 Then
        Begin
            ActiveLSObject := ActiveDSSObject[ActiveActor] as TLoadShapeObj;
            Result := 1;
        End
     End;
  end;
  2: begin  // LoadShapes.Next
     Result := 0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     Begin
        iElem := LoadshapeClass[ActiveActor].Next;
        If iElem <> 0 Then
        Begin
            ActiveLSObject := ActiveDSSObject[ActiveActor] as TLoadShapeObj;
            Result := iElem;
        End
     End;
  end;
  3: begin  // LoadShapes.Npts read
     Result := 0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       Result := ActiveLSObject.NumPoints;
  end;
  4: begin  // LoadShapes.Npts write
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
          ActiveLSObject.NumPoints := arg;
  end;
  5: begin  // LoadShapes.Normalize
       If ActiveCircuit[ActiveActor] <> Nil Then
       If ActiveLSObject <> Nil Then
          ActiveLSObject.Normalize;
  end;
  6: begin   // LoadShapes.UseActual read
       Result := 0;
       If ActiveCircuit[ActiveActor] <> Nil Then
       If ActiveLSObject <> Nil Then
         if ActiveLSObject.UseActual then Result:=1;
  end;
  7: begin   // LoadShapes.UseActual write
       If ActiveCircuit[ActiveActor] <> Nil Then
       If ActiveLSObject <> Nil Then begin
          if arg=1 then
              ActiveLSObject.UseActual  := TRUE
          else
              ActiveLSObject.UseActual  := FALSE
          end;
  end
  else
      Result:=-1;
  end;
end;

//**********************Floating point type properties***************************
function LoadShapeF(mode:longint; arg:double):double;cdecl;
begin
  Result := 0.0;    // Default return value
  case mode of
  0: begin  // LoadShapes.HrInterval read
       Result := 0.0;
       If ActiveCircuit[ActiveActor] <> Nil Then
       If ActiveLSObject <> Nil Then
         Result := ActiveLSObject.Interval ;
  end;
  1: begin  // LoadShapes.HrInterval write
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       ActiveLSObject.Interval := arg ;
  end;
  2: begin  // LoadShapes.MinInterval read
     Result := 0.0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       Result := ActiveLSObject.Interval * 60.0 ;
  end;
  3:begin  // LoadShapes.MinInterval write
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       ActiveLSObject.Interval := arg / 60.0 ;
  end;
  4: begin  // LoadShapes.PBase read
     Result := 0.0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       Result := ActiveLSObject.baseP ;
  end;
  5: begin  // LoadShapes.PBase write
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       ActiveLSObject.baseP := arg;
  end;
  6: begin  // LoadShapes.QBase read
     Result := 0.0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       Result := ActiveLSObject.baseQ ;
  end;
  7: begin  // LoadShapes.QBase write
       If ActiveCircuit[ActiveActor] <> Nil Then
       If ActiveLSObject <> Nil Then
         ActiveLSObject.baseQ := arg;
  end;
  8: begin  // LoadShapes.Sinterval read
     Result := 0.0;
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       Result := ActiveLSObject.Interval * 3600.0 ;
  end;
  9: begin  // LoadShapes.Sinterval write
     If ActiveCircuit[ActiveActor] <> Nil Then
     If ActiveLSObject <> Nil Then
       ActiveLSObject.Interval := arg / 3600.0 ;
  end
  else
      Result:=-1.0;
  end;
end;

//**********************String type properties***************************
function LoadShapeS(mode:longint; arg:pAnsiChar):pAnsiChar;cdecl;

Var
  elem: TLoadshapeObj;

begin
  Result := pAnsiChar(AnsiString(''));      // Default return value
  case mode of
  0: begin  // LoadShapes.Name read
      Result := pAnsiChar(AnsiString(''));
      elem := LoadshapeClass[ActiveActor].GetActiveObj;
      If elem <> Nil Then Result := pAnsiChar(AnsiString(elem.Name));
  end;
  1: begin  // LoadShapes.Name write
     If ActiveCircuit[ActiveActor] <> Nil Then
     Begin
          If LoadshapeClass[ActiveActor].SetActive(string(arg)) Then
          Begin
               ActiveLSObject := LoadshapeClass[ActiveActor].ElementList.Active ;
               ActiveDSSObject[ActiveActor]    := ActiveLSObject;
          End
          Else Begin
              DoSimpleMsg('Relay "'+ arg +'" Not Found in Active Circuit.', 77003);
          End;
     End;
  end
  else
      Result:= pAnsiChar(AnsiString('Error, parameter not valid'));
  end;
end;

//**********************Variant type properties***************************
procedure LoadShapeV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

Var
   i,
   k,
   LoopLimit    : Integer;
   elem         : TLoadshapeObj;
   pList        : TPointerList;
   Sample       : Complex;
   UseHour      : Boolean;
   PDouble      : ^Double;

begin
  case mode of
  0:begin  // LoadShapes.AllNames
      myType  :=  4;        // String
      setlength(myStrArray,0);
      IF ActiveCircuit[ActiveActor] <> Nil THEN
      Begin
        If LoadShapeClass[ActiveActor].ElementList.ListSize > 0 then
        Begin
          pList := LoadShapeClass[ActiveActor].ElementList;
          elem := pList.First;
          WHILE elem<>Nil DO Begin
              WriteStr2Array(elem.Name);
              WriteStr2Array(Char(0));
              elem := pList.next        ;
          End;
        End;
      End;
      if (length(myStrArray) = 0) then
        WriteStr2Array('None');
      myPointer :=  @(myStrArray[0]);
      mySize    :=  Length(myStrArray);
    end;
  1:begin  // LoadShapes.PMult read
      myType  :=  2;        // Double
      setlength(myDBLArray, 1);
      myDBLArray[0] := 0;
      If ActiveCircuit[ActiveActor] <> Nil Then
      Begin
        If ActiveLSObject <> Nil Then
        Begin
          setlength(myDBLArray, ActiveLSObject.NumPoints);
          UseHour   :=  ActiveLSObject.Interval = 0;
          For k:=1 to ActiveLSObject.NumPoints Do
          Begin
            if  UseHour then
              Sample        :=  ActiveLSObject.GetMult(ActiveLSObject.Hours^[k]) // For variable step
            else
              Sample      :=  ActiveLSObject.GetMult(k*ActiveLSObject.Interval);     // This change adds compatibility with MMF
            myDBLArray[k - 1]  :=  Sample.re;
          End;
        End Else
        Begin
           DoSimpleMsg('No active Loadshape Object found.',61001);
        End;
      End;
      myPointer :=  @(myDBLArray[0]);
      mySize    :=  SizeOf(myDBLArray[0]) * Length(myDBLArray);
    end;
  2:begin  // LoadShapes.PMult write
      myType  :=  2;        // Double
      k := 1;
      If ActiveCircuit[ActiveActor] <> Nil Then
      Begin
        If ActiveLSObject <> Nil Then With ActiveLSObject Do
        Begin
          // Only put in as many points as we have allocated
          If (mySize > NumPoints )  Then
            LoopLimit :=  NumPoints - 1
          else
            LoopLimit := mySize - 1;
          ReallocMem(PMultipliers, Sizeof(PMultipliers^[1]) * NumPoints);
          for i := 0 to LoopLimit do
          Begin
             PDouble                          :=  myPointer;
             ActiveLSObject.Pmultipliers^[k]  :=  PDOuble^;
             inc(k);
             inc(PByte(myPointer),8);
          End;
        End
        Else
        Begin
           DoSimpleMsg('No active Loadshape Object found.',61002);
        End;
      End;
      mySize  :=  k - 1;
    end;
  3:begin  // LoadShapes.QMult read
      myType  :=  2;        // Double
      setlength(myDBLArray, 1);
      myDBLArray[0] := 0;
      If ActiveCircuit[ActiveActor] <> Nil Then
      Begin
        If ActiveLSObject <> Nil Then
        Begin
          If assigned(ActiveLSObject.QMultipliers) Then
          Begin
            setlength(myDBLArray, ActiveLSObject.NumPoints);    // This change adds compatibility with MMF
            UseHour   :=  ActiveLSObject.Interval = 0;
            For k:=1 to ActiveLSObject.NumPoints Do
            Begin
              if  UseHour then
                Sample        :=  ActiveLSObject.GetMult(ActiveLSObject.Hours^[k]) // For variable step
              else
                Sample      :=  ActiveLSObject.GetMult(k*ActiveLSObject.Interval);
              myDBLArray[k - 1]  :=  Sample.im;
            End;
          End;
        End Else
        Begin
           DoSimpleMsg('No active Loadshape Object found.',61001);
        End;
      End;
      myPointer :=  @(myDBLArray[0]);
      mySize    :=  SizeOf(myDBLArray[0]) * Length(myDBLArray);
    end;
  4:begin  // LoadShapes.QMult write
      myType  :=  2;        // Double
      k := 1;
      If ActiveCircuit[ActiveActor] <> Nil Then
      Begin
        If ActiveLSObject <> Nil Then With ActiveLSObject Do Begin

          // Only put in as many points as we have allocated
          If (mySize > NumPoints )  Then
            LoopLimit :=  NumPoints - 1
          else
            LoopLimit :=  mySize - 1;

          ReallocMem(QMultipliers, Sizeof(QMultipliers^[1]) * NumPoints);
          for i := 0 to LoopLimit do
          Begin
            PDouble :=  myPointer;
            ActiveLSObject.Qmultipliers^[k] := PDouble^;
            inc(k);
            inc(PByte(myPointer),8);
          End;

        End Else Begin
           DoSimpleMsg('No active Loadshape Object found.',61002);
        End;
      End;
      mySize  :=  k - 1;
    end;
  5:begin   // LoadShapes.Timearray read
      myType  :=  2;        // Double
      setlength(myDBLArray, 1);
      myDBLArray[0] := 0;
      If ActiveCircuit[ActiveActor] <> Nil Then
      Begin
        If ActiveLSObject <> Nil Then Begin
          If ActiveLSObject.hours <> Nil Then  Begin
           setlength(myDBLArray, ActiveLSObject.NumPoints);
           For k:=0 to ActiveLSObject.NumPoints-1 Do
                myDBLArray[k] := ActiveLSObject.Hours^[k+1];
          End
        End
        Else
        Begin
           DoSimpleMsg('No active Loadshape Object found.',61001);
        End;
      End;
      myPointer :=  @(myDBLArray[0]);
      mySize    :=  SizeOf(myDBLArray[0]) * Length(myDBLArray);
    end;
  6:begin   // LoadShapes.Timearray write
      myType  :=  2;        // Double
      k := 1;
      If ActiveCircuit[ActiveActor] <> Nil Then
      Begin
        If ActiveLSObject <> Nil Then With ActiveLSObject Do Begin
          // Only put in as many points as we have allocated
          If (mySize > NumPoints)  Then
            LoopLimit :=  NumPoints - 1
          else
            LoopLimit :=  mySize - 1;
          ReallocMem(Hours, Sizeof(Hours^[1]) * NumPoints);
          k := 1;
          for i := 0 to LoopLimit do
          Begin
            PDouble                   :=  myPointer;
            ActiveLSObject.Hours^[k] := PDouble^;
            inc(k);
            inc(PByte(myPointer),8);
          End;
        End
        Else
        Begin
           DoSimpleMsg('No active Loadshape Object found.',61002);
        End;
      End;
      mySize  :=  k - 1;
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
