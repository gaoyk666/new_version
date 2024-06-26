unit Monitor;
{
  ----------------------------------------------------------
  Copyright (c) 2008-2021, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{$HINTS OFF}
{
   Change Log
   12-7-99 Modified Getcurrents override
   1-22-00 Derived from MeterElement Class
   5-30-00 Added test for positive sequence ckt model
           Fixed resetting of Nphases to match metered element
   10-27-00 Changed default to magnitude and angle instead of real and imag
   12-18-01 Added Transformer Tap Monitor Code
   12-18-02 Added Monitor Stream
   2-19-08 Added SampleCount
   01-19-13 Added flicker meter mode
   08-18-15 Added Solution monitor mode
   08-10-16 Added mode 6 for storing capacitor switching
   06-04-18 Added modes 7-9
   11-29-18 Added mode 10; revised mode 8
   12-4-18  Added link to AutoTransformer
   08-21-20 Added mode 11

}

{
  A monitor is a circuit element that is connected to a terminal of another
  circuit element.  It records the voltages and currents at that terminal as
  a function of time and can report those values upon demand.

  A Monitor is defined by a New commands:

  New Type=Monitor Name=myname Element=elemname Terminal=[1,2,...] Buffer=clear|save

  Upon creation, the monitor buffer is established.  There is a file associated
  with the buffer.  It is named "Mon_elemnameN.mon"  where N is the terminal no.
  The file is truncated to zero at creation or buffer clearing.

  The Monitor keeps results in the in-memory buffer until it is filled.  Then it
  appends the buffer to the associated file and resets the in-memory buffer.

  For buffer=save, the present in-memory buffer is appended to the disk file so
  that it is saved for later reference.

  The Monitor is a passive device that takes a sample whenever its "TakeSample"
  method is invoked.  The SampleAll method of the Monitor ckt element class will
  force all monitors elements to take a sample.  If the present time (for the most
  recent solution is greater than the last time entered in to the monitor buffer,
  the sample is appended to the buffer.  Otherwise, it replaces the last entry.

  Monitor Files are simple binary files of Singles.  The first record
  contains the number of conductors per terminal (NCond). (always use 'round' function
  when converting this to an integer). Then subsequent records consist of time and
  voltage and current samples for each terminal (all complex doubles) in the order
  shown below:

  <NCond>
           <--- All voltages first ---------------->|<--- All currents ----->|
  <hour 1> <sec 1> <V1.re>  <V1.im>  <V2.re>  <V2.im>  .... <I1.re>  <I1.im> ...
  <hour 2> <sec 1> <V1.re>  <V1.im>  <V2.re>  <V2.im>  .... <I1.re>  <I1.im> ...
  <hour 3> <sec 1> <V1.re>  <V1.im>  <V2.re>  <V2.im>  .... <I1.re>  <I1.im> ...

  The time values will not necessarily be in a uniform time step;  they will
  be at times samples or solutions were taken.  This could vary from several
  hours down to a few milliseconds.

  The monitor ID can be determined from the file name.  Thus, these values can
  be post-processed at any later time, provided that the monitors are not reset.

  Modes are:
   0: Standard mode - V and I,each phase, Mag and Angle
   1: Power each phase, complex (kw and kvars)
   2: Transformer Tap
   3: State Variables
   4: Flicker level and severity index by phase (no modifiers apply)
   5: Solution Variables (Iteration count, etc.)
   6: Capacitor Switching (Capacitors only)
   7: Storage Variables
   8: Transformer Winding Currents
   9: Losses (watts and vars)
  10: Transformer Winding Voltages (across winding)
  11: All terminal V and I, all conductors, mag and angle

   +16: Sequence components: V012, I012
   +32: Magnitude Only
   +64: Pos Seq only or Average of phases

}

interface

USES
     Command, MeterClass, Meterelement, DSSClass, Arraydef, ucomplex, utilities, Classes;

TYPE
    TMonitorStrBuffer = Array [1..256] of AnsiChar;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
   {This has to be named TDSSMonitor because Delphi has a TMonitor Class and the compiler will get confused}
   TDSSMonitor = class(TMeterClass)
     private

     protected
        Procedure DefineProperties;
        Function  MakeLike(const MonitorName:String):Integer;  Override;
     public
       constructor Create;
       destructor  Destroy; override;

       Function Edit(ActorID : Integer):Integer;                 override;     // uses global parser
       Function Init(Handle:Integer;ActorID : Integer):Integer; override;
       Function NewObject(const ObjName:String):Integer;  override;

       Procedure ResetAll(ActorID : Integer);   Override;
       Procedure SampleAll(ActorID : Integer);  Override;  // Force all monitors to take a sample
       Procedure SampleAllMode5(ActorID : Integer);  // Sample just Mode 5 monitors
       Procedure SaveAll(ActorID : Integer);    Override;   // Force all monitors to save their buffers to disk
       Procedure PostProcessAll(ActorID : Integer);
       Procedure TOPExport(Objname:String);

   end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
   TMonitorObj = class(TMeterElement)
     private
       BufferSize      :Integer;
       Hour            :Integer;
       Sec             :Double;    // last time entered in the buffer
       MonBuffer       :pSingleArray;
       Bufptr          :Integer;  // point to present (last) element in buffer must be incremented to add

       CurrentBuffer     :pComplexArray;
       VoltageBuffer     :pComplexArray;
       WdgCurrentsBuffer :pComplexArray;
       WdgVoltagesBuffer :pComplexArray;
       PhsVoltagesBuffer :pComplexArray;
       NumTransformerCurrents :Integer;
       NumWindingVoltages :Integer;

       NumStateVars    :Integer;
       StateBuffer     :pDoubleArray;

       FlickerBuffer   :pComplexArray; // store phase voltages in polar form
                                       // then convert to re=flicker level, update every time step
                                       //             and im=Pst, update every 10 minutes
       SolutionBuffer  :pDoubleArray;


       IncludeResidual :Boolean;
       VIpolar         :Boolean;
       Ppolar          :Boolean;

       FileSignature   :Integer;
       FileVersion     :Integer;

       BaseFrequency   :Double;

       BufferFile      :String;  // Name of file for catching buffer overflow

       IsFileOpen      :Boolean;
       ValidMonitor    :Boolean;
       IsProcessed     :Boolean;

       Procedure AddDblsToBuffer(Dbl:pDoubleArray; Ndoubles:Integer);
       Procedure AddDblToBuffer(const Dbl:Double);

       Procedure DoFlickerCalculations(ActorID : Integer);  // call from CloseMonitorStream
       // function  Get_FileName: String;



     public
       Mode           : Integer;
       MonitorStream  : TMemoryStream;
       SampleCount    : Integer;           // This is the number of samples taken
       myHeaderSize   : Integer;           // size of the header of this monitor
       StrBuffer      : Array of AnsiChar; // Header

       constructor Create(ParClass:TDSSClass; const MonitorName:String);
       destructor Destroy; override;

       PROCEDURE MakePosSequence(ActorID : Integer);    Override;  // Make a positive Sequence Model, reset nphases
       Procedure RecalcElementData(ActorID : Integer);  Override;
       Procedure CalcYPrim(ActorID : Integer);          Override;    // Always Zero for a monitor
       Procedure TakeSample(ActorID : Integer);         Override; // Go add a sample to the buffer
       Procedure ResetIt(ActorID : Integer);
       Procedure Save;     // Saves present buffer to file
       Procedure PostProcess(ActorID : Integer); // calculates Pst or other post-processing

       procedure Add2Header(myText : AnsiString);
       Procedure OpenMonitorStream;
       Procedure ClearMonitorStream(ActorID : Integer);
       Procedure CloseMonitorStream(ActorID : Integer);

       Procedure TranslateToCSV(Show:Boolean; ActorID : Integer);

       Procedure GetCurrents(Curr: pComplexArray; ActorID : Integer);                Override; // Get present value of terminal Curr
       Procedure GetInjCurrents(Curr: pComplexArray; ActorID : Integer);             Override;   // Returns Injextion currents
       PROCEDURE InitPropertyValues(ArrayOffset:Integer);         Override;
       Procedure DumpProperties(Var F:TextFile; Complete:Boolean);Override;
       function  Get_FileName(ActorID : Integer): String;
       //Property  MonitorFileName:String read BufferFile;

//       Property CSVFileName:String Read Get_FileName;
   end;

// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

VAR
    ActiveMonitorObj:TMonitorObj;

{--------------------------------------------------------------------------}
implementation

USES

    ParserDel, DSSClassDefs, DSSGlobals, Circuit, CktElement,Transformer, AutoTrans, PCElement,
    Sysutils, ucmatrix, showresults, mathUtil, PointerList, TOPExport, Dynamics, PstCalc,
    Capacitor, Storage;

CONST
    SEQUENCEMASK = 16;
    MAGNITUDEMASK = 32;
    POSSEQONLYMASK = 64;
    MODEMASK = 15;

    NumPropsThisClass = 7;
    NumSolutionVars = 12;

VAR
  dummyRec    : TMonitorStrBuffer;

{--------------------------------------------------------------------------}
constructor TDSSMonitor.Create;  // Creates superstructure for all Monitor objects
Begin
     Inherited Create;

     Class_name   := 'Monitor';
     DSSClassType := DSSClassType + MON_ELEMENT;

     DefineProperties;

     CommandList := TCommandList.Create(PropertyName, NumProperties);
     CommandList.Abbrev := TRUE;
End;

{--------------------------------------------------------------------------}
destructor TDSSMonitor.Destroy;

Begin
     Inherited Destroy;
End;

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Procedure TDSSMonitor.DefineProperties;
Begin

     Numproperties := NumPropsThisClass;
     CountProperties;   // Get inherited property count
     AllocatePropertyArrays;

     // Define Property names

     PropertyName^[1] := 'element';
     PropertyName^[2] := 'terminal';
     PropertyName^[3] := 'mode';
     PropertyName^[4] := 'action';  // buffer=clear|save
     PropertyName^[5] := 'residual';  // buffer=clear|save
     PropertyName^[6] := 'VIPolar';  // V I in mag and angle rather then re and im
     PropertyName^[7] := 'PPolar';  // Power in power PF rather then power and vars

     PropertyHelp^[1] := 'Name (Full Object name) of element to which the monitor is connected.';
     PropertyHelp^[2] := 'Number of the terminal of the circuit element to which the monitor is connected. '+
                    '1 or 2, typically. For monitoring states, attach monitor to terminal 1.';
     PropertyHelp^[3] := 'Bitmask integer designating the values the monitor is to capture: '+CRLF+
                    '0 = Voltages and currents at designated terminal' + CRLF+
                    '1 = Powers at designated terminal'+CRLF+
                    '2 = Tap Position (Transformer Device only)'+CRLF+
                    '3 = State Variables (PCElements only)' +CRLF+
                    '4 = Flicker level and severity index (Pst) for voltages. No adders apply.' +CRLF+
                    '    Flicker level at simulation time step, Pst at 10-minute time step.' +CRLF+
                    '5 = Solution variables (Iterations, etc).' +CRLF+
                    'Normally, these would be actual phasor quantities from solution.' + CRLF+
                    '6 = Capacitor Switching (Capacitors only)'+CRLF+
                    '7 = Storage state vars (Storage device only)'+CRLF+
                    '8 = All winding currents (Transformer device only)'+CRLF+
                    '9 = Losses, watts and var (of monitored device)'+CRLF+
                    '10 = All Winding voltages (Transformer device only)'+CRLF+
                    'Normally, these would be actual phasor quantities from solution.' + CRLF+
                    '11 = All terminal node voltages and line currents of monitored device' +CRLF+
                    '12 = All terminal node voltages LL and line currents of monitored device' +CRLF+
                    'Combine mode with adders below to achieve other results for terminal quantities:' + CRLF+
                    '+16 = Sequence quantities' + CRLF+
                    '+32 = Magnitude only' + CRLF+
                    '+64 = Positive sequence only or avg of all phases' + CRLF+
                     CRLF +
                    'Mix adder to obtain desired results. For example:' + CRLF+
                    'Mode=112 will save positive sequence voltage and current magnitudes only' + CRLF+
                    'Mode=48 will save all sequence voltages and currents, but magnitude only.';
     PropertyHelp^[4] := '{Clear | Save | Take | Process}' + CRLF +
                        '(C)lears or (S)aves current buffer.' + CRLF +
                        '(T)ake action takes a sample.'+ CRLF +
                        '(P)rocesses the data taken so far (e.g. Pst for mode 4).' + CRLF + CRLF +
                        'Note that monitors are automatically reset (cleared) when the Set Mode= command is issued. '+
                        'Otherwise, the user must explicitly reset all monitors (reset monitors command) or individual ' +
                        'monitors with the Clear action.';
     PropertyHelp^[5] := '{Yes/True | No/False} Default = No.  Include Residual cbannel (sum of all phases) for voltage and current. ' +
                        'Does not apply to sequence quantity modes or power modes.';
     PropertyHelp^[6] := '{Yes/True | No/False} Default = YES. Report voltage and current in polar form (Mag/Angle). (default)  Otherwise, it will be real and imaginary.';
     PropertyHelp^[7] := '{Yes/True | No/False} Default = YES. Report power in Apparent power, S, in polar form (Mag/Angle).(default)  Otherwise, is P and Q';

     ActiveProperty := NumPropsThisClass;
     inherited DefineProperties;  // Add defs of inherited properties to bottom of list

End;

{--------------------------------------------------------------------------}
Function TDSSMonitor.NewObject(const ObjName:String):Integer;
Begin
    // Make a new Monitor and add it to Monitor class list
    With ActiveCircuit[ActiveActor] Do
    Begin
      ActiveCktElement := TMonitorObj.Create(Self, ObjName);
      Result := AddObjectToList(ActiveDSSObject[ActiveActor]);
    End;
End;

{--------------------------------------------------------------------------}
Function TDSSMonitor.Edit(ActorID : Integer):Integer;
VAR
   ParamPointer:Integer;
   ParamName:String;
   Param:String;
   recalc: integer;

Begin

  // continue parsing with contents of Parser
  // continue parsing with contents of Parser
  ActiveMonitorObj := ElementList.Active;
  ActiveCircuit[ActorID].ActiveCktElement := ActiveMonitorObj;

  Result := 0;
  recalc:=0;

  WITH ActiveMonitorObj DO Begin

     ParamPointer := 0;
     ParamName := Parser[ActorID].NextParam;
     Param := Parser[ActorID].StrValue;
     WHILE Length(Param)>0 DO Begin
         IF Length(ParamName) = 0 THEN Inc(ParamPointer)
         ELSE ParamPointer := CommandList.GetCommand(ParamName);

         If (ParamPointer>0) and (ParamPointer<=NumProperties) Then PropertyValue[ParamPointer]:= Param;
         inc (recalc);

         CASE ParamPointer OF
            0: DoSimpleMsg('Unknown parameter "' + ParamName + '" for Object "' + Class_Name +'.'+ Name + '"', 661);
            1: Begin
                 ElementName := ConstructElemName(lowercase(param));   // subtitute @var values if any
                 PropertyValue[1] := ElementName;
               End;
            2: MeteredTerminal := Parser[ActorID].IntValue;
            3: Mode := Parser[ActorID].IntValue;
            4: Begin
                  param := lowercase(param);
                  Case param[1] of
                    's':Save;
                    'c','r':ResetIt(ActorID);
                    't': TakeSample(ActorID);
                    'p': begin PostProcess(ActorID); dec(recalc) end
                  End;
               End;  // buffer
            5: IncludeResidual := InterpretYesNo(Param);
            6: VIpolar := InterpretYesNo(Param);
            7: Ppolar := InterpretYesNo(Param);
         ELSE
           // Inherited parameters
           ClassEdit( ActiveMonitorObj, ParamPointer - NumPropsthisClass)
         End;

         ParamName := Parser[ActorID].NextParam;
         Param := Parser[ActorID].StrValue;
     End;

     if recalc > 0 then RecalcElementData(ActorID);
  End;

End;

{--------------------------------------------------------------------------}
Procedure TDSSMonitor.ResetAll(ActorID : Integer);  // Force all monitors in the circuit to reset

VAR
   Mon:TMonitorObj;

Begin
      Mon := ActiveCircuit[ActorID].Monitors.First;
      WHILE Mon<>Nil DO
      Begin
          If Mon.enabled Then Mon.ResetIt(ActorID);
          Mon := ActiveCircuit[ActorID].Monitors.Next;
      End;

End;

{--------------------------------------------------------------------------}
Procedure TDSSMonitor.SampleAll(ActorID : Integer);  // Force all monitors in the circuit to take a sample

VAR
   Mon:TMonitorObj;
// sample all monitors except mode 5 monitors
Begin
      Mon := ActiveCircuit[ActorID].Monitors.First;
      WHILE Mon<>Nil DO  Begin
          If Mon.enabled Then
             If Mon.Mode <> 5 then Mon.TakeSample(ActorID);
          Mon := ActiveCircuit[ActorID].Monitors.Next;
      End;
End;

{--------------------------------------------------------------------------}
Procedure TDSSMonitor.SampleAllMode5(ActorID : Integer);  // Force all mode=5 monitors in the circuit to take a sample

VAR
   Mon:TMonitorObj;
// sample all Mode 5 monitors except monitors
Begin
      Mon := ActiveCircuit[ActorID].Monitors.First;
      WHILE Mon<>Nil DO  Begin
          If Mon.enabled Then
             If Mon.Mode = 5 then Mon.TakeSample(ActorID);
          Mon := ActiveCircuit[ActorID].Monitors.Next;
      End;
End;

{--------------------------------------------------------------------------}
Procedure TDSSMonitor.PostProcessAll(ActorID : Integer);
VAR
   Mon:TMonitorObj;
Begin
   Mon := ActiveCircuit[ActorID].Monitors.First;
   WHILE Mon<>Nil DO Begin
       If Mon.Enabled Then Mon.PostProcess(ActorID);
       Mon := ActiveCircuit[ActorID].Monitors.Next;
   End;
End;

{--------------------------------------------------------------------------}
Procedure TDSSMonitor.SaveAll(ActorID : Integer);     // Force all monitors in the circuit to save their buffers to disk

VAR
   Mon:TMonitorObj;

Begin
   Mon := ActiveCircuit[ActorID].Monitors.First;
   WHILE Mon<>Nil DO Begin
       If Mon.Enabled Then Mon.Save;
       Mon := ActiveCircuit[ActorID].Monitors.Next;
   End;
End;

{--------------------------------------------------------------------------}
Function TDSSMonitor.MakeLike(const MonitorName:String):Integer;
VAR
   OtherMonitor:TMonitorObj;
   i:Integer;
Begin
   Result := 0;
   {See if we can find this Monitor name in the present collection}
   OtherMonitor := Find(MonitorName);
   IF OtherMonitor<>Nil THEN
   WITH ActiveMonitorObj DO Begin

       NPhases := OtherMonitor.Fnphases;
       NConds  := OtherMonitor.Fnconds; // Force Reallocation of terminal stuff

       Buffersize := OtherMonitor.Buffersize;
       ElementName:= OtherMonitor.ElementName;
       MeteredElement:= OtherMonitor.MeteredElement;  // Pointer to target circuit element
       MeteredTerminal:= OtherMonitor.MeteredTerminal;
       Mode := OtherMonitor.Mode;
       IncludeResidual := OtherMonitor.IncludeResidual;

       For i := 1 to ParentClass.NumProperties Do PropertyValue[i] := OtherMonitor.PropertyValue[i];

       BaseFrequency:= OtherMonitor.BaseFrequency;

   End
   ELSE  DoSimpleMsg('Error in Monitor MakeLike: "' + MonitorName + '" Not Found.', 662);

End;

{--------------------------------------------------------------------------}
Function TDSSMonitor.Init(Handle:Integer; ActorID : Integer):Integer;
VAR
   Mon:TMonitorObj;

Begin
      Result := 0;

      IF Handle>0  THEN Begin
         Mon := ElementList.Get(Handle);
         Mon.ResetIt(ActorID);
      End
      ELSE Begin  // Do 'em all
        Mon := ElementList.First;
        WHILE Mon<>Nil DO Begin
            Mon.ResetIt(ActorID);
            Mon := ElementList.Next;
        End;
      End;

End;


{==========================================================================}
{                    TMonitorObj                                           }
{==========================================================================}



{--------------------------------------------------------------------------}
constructor TMonitorObj.Create(ParClass:TDSSClass; const MonitorName:String);

Begin
     Inherited Create(ParClass);
     Name := LowerCase(MonitorName);

     Nphases := 3;  // Directly set conds and phases
     Fnconds := 3;
     Nterms  := 1;  // this forces allocation of terminals and conductors
                         // in base class

     {Current Buffer has to be big enough to hold all terminals}
     CurrentBuffer := Nil;
     VoltageBuffer := Nil;
     StateBuffer   := Nil;
     FlickerBuffer := Nil;
     SolutionBuffer:= Nil;
     WdgCurrentsBuffer := Nil;
     WdgVoltagesBuffer := Nil;
     PhsVoltagesBuffer := Nil;

     NumTransformerCurrents := 0;

     Basefrequency := 60.0;
     Hour          := 0;
     Sec           := 0.0;

     Mode := 0;  // Standard Mode: V & I, complex values

     BufferSize := 1024;       // Makes a 4K buffer
     MonBuffer  := AllocMem(Sizeof(MonBuffer^[1]) * BufferSize);
     BufPtr     := 0;

     ElementName    := TDSSCktElement(ActiveCircuit[ActiveActor].CktElements.Get(1)).Name; // Default to first circuit element (source)
     MeteredElement := nil;
     Bufferfile     := '';

     MonitorStream := TMemoryStream.Create; // Create memory stream

     IsFileOpen      := FALSE;
     MeteredTerminal := 1;
     IncludeResidual := FALSE;
     VIPolar         := TRUE;
     Ppolar          := TRUE;
     FileSignature   := 43756;
     FileVersion     := 1;
     SampleCount     := 0;
     IsProcessed     := FALSE;

     DSSObjType := ParClass.DSSClassType; //MON_ELEMENT;

     InitPropertyValues(0);

End;

destructor TMonitorObj.Destroy;
Begin
     MonitorStream.Free;
     ElementName := '';
     Bufferfile := '';
     ReAllocMem(MonBuffer,0);
     ReAllocMem(StateBuffer,0);
     ReAllocMem(CurrentBuffer,0);
     ReAllocMem(VoltageBuffer,0);
     ReAllocMem(FlickerBuffer,0);
     ReAllocMem(SolutionBuffer,0);
     ReAllocMem(WdgVoltagesBuffer,0);
     ReAllocMem(WdgCurrentsBuffer,0);
     ReAllocMem(PhsVoltagesBuffer,0);

     Inherited Destroy;
End;


{--------------------------------------------------------------------------}
Procedure ConvertBlanks(Var s:String);
VAR
    BlankPos:Integer;

Begin
     { Convert spaces to Underscores }
     BlankPos := Pos(' ', S);
     WHILE BlankPos>0 DO Begin
         S[BlankPos] := '_';
         BlankPos := Pos(' ', S);
     End;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.RecalcElementData(ActorID : Integer);

VAR
   DevIndex :Integer;

Begin
         ValidMonitor := FALSE;
         Devindex := GetCktElementIndex(ElementName);                   // Global function
         IF DevIndex>0 THEN Begin                                       // Monitored element must already exist
             MeteredElement := ActiveCircuit[ActorID].CktElements.Get(DevIndex);
             Case (Mode and MODEMASK) of
                2,8, 10: Begin                                                // Must be transformer
                          If (MeteredElement.DSSObjType And CLASSMASK) <> XFMR_ELEMENT Then
                          If (MeteredElement.DSSObjType And CLASSMASK) <> AUTOTRANS_ELEMENT Then
                          Begin
                            DoSimpleMsg(MeteredElement.Name + ' is not a transformer!', 663);
                            Exit;
                          End;
                   End;
                3: Begin                                                // Must be PCElement
                          If (MeteredElement.DSSObjType And BASECLASSMASK) <> PC_ELEMENT Then Begin
                            DoSimpleMsg(MeteredElement.Name + ' must be a power conversion element (Load or Generator)!', 664);
                            Exit;
                          End;
                   End;
                6: begin                                                // Checking Caps Tap
                          If (MeteredElement.DSSObjType And CLASSMASK) <> CAP_ELEMENT Then Begin
                            DoSimpleMsg(MeteredElement.Name + ' is not a capacitor!', 2016001);
                            Exit;
                          End;
                   end;
                7: begin                                                // Checking if the element is a storage device
                          If ((MeteredElement.DSSObjType And CLASSMASK) <> STORAGE_ELEMENT) {and ((MeteredElement.DSSObjType And CLASSMASK) <> STORAGE2_ELEMENT)}  Then Begin
                            DoSimpleMsg(MeteredElement.Name + ' is not a storage device!', 2016002);
                            Exit;
                          End;

                   end;
             End;

             IF MeteredTerminal>MeteredElement.Nterms THEN Begin
                 DoErrorMsg('Monitor: "' + Name + '"',
                                 'Terminal no. "' +'" does not exist.',
                                 'Respecify terminal no.', 665);
             End
             ELSE Begin
                 Nphases := MeteredElement.NPhases;
                 Nconds  := MeteredElement.NConds;

               // Sets name of i-th terminal's connected bus in monitor's buslist
               // This value will be used to set the NodeRef array (see TakeSample)
                 Setbus(1, MeteredElement.GetBus(MeteredTerminal));
               // Make a name for the Buffer File
                 BufferFile := {ActiveCircuit[ActiveActor].CurrentDirectory + }
                               CircuitName_[ActorID] + 'Mon_' + Name + '.mon';
                 // removed 10/19/99 ConvertBlanks(BufferFile); // turn blanks into '_'

                 {Allocate Buffers}

                 Case (Mode and MODEMASK) of
                      3: Begin
                          if TPCElement(MeteredElement).DynamicEqObj = nil then
                            NumStateVars := TPCElement(MeteredElement).Numvariables
                          else
                            NumStateVars := TPCElement(MeteredElement).DynamicEqObj.NumVars * length(TPCElement(MeteredElement).DynamicEqVals[0]);
                          ReallocMem(StateBuffer, Sizeof(StateBuffer^[1])*NumStatevars);
                         End;
                      4: Begin
                             ReallocMem(FlickerBuffer, Sizeof(FlickerBuffer^[1])*Nphases);
                         End;
                      5: Begin
                             ReallocMem(SolutionBuffer, Sizeof(SolutionBuffer^[1])*NumSolutionVars);
                         End;
                      8: Begin
                             If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
                             Then With  TAutoTransObj(MeteredElement) Do NumTransformerCurrents := 2* NumberOfWindings * nphases
                             Else With  TTransfObj(MeteredElement)    Do NumTransformerCurrents := 2* NumberOfWindings * nphases;
                             ReallocMem(WdgCurrentsBuffer, Sizeof(Complex)*NumTransformerCurrents);
                         End;
                     10: Begin
                             If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
                             Then With  TAutoTransObj(MeteredElement) Do NumWindingVoltages :=  NumberOfWindings * nphases
                             ELse With  TTransfObj(MeteredElement)    Do NumWindingVoltages :=  NumberOfWindings * nphases;
                             ReallocMem(WdgVoltagesBuffer, Sizeof(Complex)*NumWindingVoltages);   // total all phases, all windings
                             ReallocMem(PhsVoltagesBuffer, Sizeof(Complex)*nphases);
                         End;
                     11: Begin
                             ReallocMem(CurrentBuffer, SizeOf(CurrentBuffer^[1])*MeteredElement.Yorder);
                             ReallocMem(VoltageBuffer, SizeOf(VoltageBuffer^[1])*MeteredElement.Yorder);
                         End;
                     12: Begin
                             ReallocMem(CurrentBuffer, SizeOf(CurrentBuffer^[1])*MeteredElement.Yorder);
                             ReallocMem(VoltageBuffer, SizeOf(VoltageBuffer^[1])*(MeteredElement.Yorder + 1));
                         End;
                 Else
                     ReallocMem(CurrentBuffer, SizeOf(CurrentBuffer^[1])*MeteredElement.Yorder);
                     ReallocMem(VoltageBuffer, SizeOf(VoltageBuffer^[1])*MeteredElement.NConds);
                 End;

                 ClearMonitorStream(ActorID);

                 ValidMonitor := TRUE;

             End;

         End
         ELSE Begin
            MeteredElement := nil;   // element not found
            DoErrorMsg('Monitor: "' + Self.Name + '"', 'Circuit Element "'+ ElementName + '" Not Found.',
                            ' Element must be defined previously.', 666);
         End;
End;

procedure TMonitorObj.MakePosSequence(ActorID : Integer);
begin
  if MeteredElement <> Nil then begin
    Setbus(1, MeteredElement.GetBus(MeteredTerminal));
    Nphases := MeteredElement.NPhases;
    Nconds  := MeteredElement.Nconds;
    Case (Mode and MODEMASK) of
      3: Begin
            if TPCElement(MeteredElement).DynamicEqObj = nil then
            Begin
             NumStateVars := TPCElement(MeteredElement).Numvariables;
             ReallocMem(StateBuffer, Sizeof(StateBuffer^[1])*NumStatevars);
            End
            else
            Begin
             NumStateVars := TPCElement(MeteredElement).DynamicEqObj.NumVars * length(TPCElement(MeteredElement).DynamicEqVals[0]);
             ReallocMem(StateBuffer, Sizeof(StateBuffer^[1])*NumStatevars);
            End;
         End;
      4: Begin
            ReallocMem(FlickerBuffer, Sizeof(FlickerBuffer^[1])*Nphases);
         End;
      5: Begin
            ReallocMem(SolutionBuffer, Sizeof(SolutionBuffer^[1])*NumSolutionVars);
         End;
      Else
         ReallocMem(CurrentBuffer, SizeOf(CurrentBuffer^[1])*MeteredElement.Yorder);
         ReallocMem(VoltageBuffer, SizeOf(VoltageBuffer^[1])*MeteredElement.NConds);
      End;
    ClearMonitorStream(ActorID);
    ValidMonitor := TRUE;
  end;
  Inherited;
end;


{--------------------------------------------------------------------------}
Procedure TMonitorObj.CalcYPrim(ActorID : Integer);
Begin

  {A Monitor is a zero current source; Yprim is always zero.}
  // leave YPrims as nil and they will be ignored
  // Yprim is zeroed when created.  Leave it as is.
End;

{--------------------------------------------------------------------------
        Concatenates the given string into the header buffer
--------------------------------------------------------------------------}
procedure TMonitorObj.Add2Header(myText : AnsiString);
var
  i, j,
  myLen : integer;
Begin
  myLen   :=  length(StrBuffer);
  for i := 0 to High(myText) do
    if myText[i] <> AnsiChar(0) then
    Begin 
      setlength(StrBuffer,length(StrBuffer) + 1);      
      StrBuffer[high(StrBuffer)]  :=  myText[i];
    End;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.ClearMonitorStream(ActorID : Integer);

VAR
    PhaseLoc    : Array of Integer;
    i,j,
    iMax,
    NumVI,
    RecordSize,
    iMin        :Integer;
    IsPosSeq,
    IsPower     :Boolean;
    NameOfState,
    Str_Temp    :AnsiString;

Begin
  Try

    MonitorStream.Clear;
    IsProcessed := FALSE;
    SampleCount  :=  0;
    IsPosSeq := False;
    setlength(StrBuffer,0);
    If ActiveCircuit[ActorID].Solution.IsHarmonicModel Then 
      Add2header(pAnsiChar('Freq, Harmonic, '))
    Else Add2Header(pAnsiChar('hour, t(sec), '));
     
     CASE (Mode and MODEMASK) of

     2: Begin
              RecordSize := 1;     // Transformer Taps
              Add2header(pAnsiChar('Tap (pu)'));
        End;
     3: Begin
              RecordSize := NumStateVars;   // Statevariabes
              For i := 1 to NumStateVars Do Begin
                if TpcElement(MeteredElement).DynamicEqObj = nil then
                  NameofState := AnsiString(TpcElement(MeteredElement).VariableName(i) + ',')
                else
                  NameofState := AnsiString(TpcElement(MeteredElement).DynamicEqObj.Get_VarName(i - 1) + ',');
                Add2header(pAnsiChar(NameofState));
              End;
        End;
     4: Begin
              RecordSize := 2 * FnPhases;
              For i := 1 to FnPhases Do Begin  //AnsString and pAnsiChar replaced with AnsiString and pAnsiChar to make it compatible with Linux
                Add2header(pAnsiChar(AnsiString('Flk'+IntToStr(i)+', Pst'+IntToStr(i))));
                if i < FnPhases then Add2header(pAnsiChar(', '));
              End;
        End;
     5: Begin
             RecordSize := NumSolutionVars;
             Add2header(pAnsiChar('TotalIterations, '));
             Add2header(pAnsiChar('ControlIteration, '));
             Add2header(pAnsiChar('MaxIterations, '));
             Add2header(pAnsiChar('MaxControlIterations, '));
             Add2header(pAnsiChar('Converged, '));
             Add2header(pAnsiChar('IntervalHrs, '));
             Add2header(pAnsiChar('SolutionCount, '));
             Add2header(pAnsiChar('Mode, '));
             Add2header(pAnsiChar('Frequency, '));
             Add2header(pAnsiChar('Year, '));
             Add2header(pAnsiChar('SolveSnap_uSecs, '));
             Add2header(pAnsiChar('TimeStep_uSecs, '));
        End;
     6: Begin
              RecordSize := TCapacitorObj(MeteredElement).NumSteps;     // Capacitor Taps
              for i := 1 to RecordSize do
                begin
                  Str_Temp  :=  AnsiString('Step_' + inttostr(i) + ',');
                  Add2header(pAnsiChar(Str_Temp));
                end;

        End;
     7: Begin
              RecordSize := 5;     // Storage state vars
              Add2header(('kW output, '));
              Add2header(('kvar output, '));
              Add2header(('kW Stored, '));
              Add2header(('%kW Stored, '));
              Add2header(('State, '));
        End;
     8: Begin   // All winding Currents
              If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
              Then With TAutoTransObj(MeteredElement) Do
                Begin
                    RecordSize := NumTransformerCurrents;     // Transformer Winding Currents
                    for i := 1 to Nphases do
                      Begin
                        for j := 1 to NumberOfWindings do
                          begin
                            Str_Temp  :=  AnsiString(Format('P%dW%d,Deg, ', [i,j] ));
                            Add2header(pAnsichar(Str_Temp));
                          end;
                      End;
                End
              Else With TTransfObj(MeteredElement) Do
                Begin
                    RecordSize := NumTransformerCurrents;     // Transformer Winding Currents
                    for i := 1 to Nphases do
                      Begin
                        for j := 1 to NumberOfWindings do
                          begin
                            Str_Temp  :=  AnsiString(Format('P%dW%d,Deg, ', [i,j] ));
                            Add2header(pAnsichar(Str_Temp));
                          end;
                      End;
                End;
        End;
     9: Begin // watts vars of meteredElement
              RecordSize := 2;
              Add2header(pAnsichar('watts, vars'));
        End;
     10:Begin // All Winding Voltages
              If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
              Then With TAutoTransObj(MeteredElement) Do
                 Begin
                    RecordSize := 2 * NumberOfWindings * Nphases;     // Transformer Winding woltages
                    for i := 1 to Nphases do
                      Begin
                        for j := 1 to NumberOfWindings do
                          begin
                            Str_Temp  :=  AnsiString(Format('P%dW%d,Deg, ', [i,j] ));
                            Add2header(pAnsichar(Str_Temp));
                          end;
                      End;
                 End
              Else With TTransfObj(MeteredElement) Do
                 Begin
                    RecordSize := 2 * NumberOfWindings * Nphases;     // Transformer Winding woltages
                    for i := 1 to Nphases do
                      Begin
                        for j := 1 to NumberOfWindings do
                          begin
                            Str_Temp  :=  AnsiString(Format('P%dW%d,Deg, ', [i,j] ));
                            Add2header(pAnsichar(Str_Temp));
                          end;
                      End;
                 End;
        End;
     11:Begin {All terminal voltages and currents  *****}

            Recordsize := 2 * 2 * MeteredElement.Yorder;  // V and I

            {Voltages}
            For j := 1 to MeteredElement.NTerms Do
               For i := 1 to MeteredElement.NConds Do
               Begin
                    Str_Temp  :=  AnsiString(Format('V%dT%d,Deg, ', [i,j] ));
                    Add2header(pAnsichar(Str_Temp));
               End;

            {Currents}
            For j := 1 to MeteredElement.NTerms Do
               For i := 1 to MeteredElement.NConds Do
               Begin
                    Str_Temp  :=  AnsiString(Format('I%dT%d,Deg, ', [i,j] ));
                    Add2header(pAnsichar(Str_Temp));
               End;

        End;
     12:Begin {All terminal voltages LL and currents  *****}

            with MeteredElement do
            Begin
              Recordsize := 2 * ((NPhases * NTerms) + Yorder) ;  // V and I
              setlength(PhaseLoc, NPhases + 1);
            end;
            // Creates the map of phase combinations (LL)
            For j := 1 to MeteredElement.NPhases Do PhaseLoc[j - 1] :=  j;
            PhaseLoc[High(PhaseLoc)]  :=  1;

            {Voltages}
            For j := 1 to MeteredElement.NTerms Do
               For i := 1 to MeteredElement.NPhases Do
               Begin
                    Str_Temp  :=  AnsiString(Format('V%d-%dT%d,Deg, ', [PhaseLoc[i-1],PhaseLoc[i],j] ));
                    Add2header(pAnsichar(Str_Temp));
               End;

            {Currents}
            For j := 1 to MeteredElement.NTerms Do
               For i := 1 to MeteredElement.NConds Do
               Begin
                    Str_Temp  :=  AnsiString(Format('I%dT%d,Deg, ', [i,j] ));
                    Add2header(pAnsichar(Str_Temp));
               End;

        End

     Else Begin
         // Compute RecordSize
         // Use same logic as in TakeSample Method

          IF ((Mode AND SEQUENCEMASK)>0) And (Fnphases=3)
          THEN Begin  // Convert to Symmetrical components
              IsPosSeq := True;
              NumVI := 3;
          End
          ELSE Begin
              NumVI:=Fnconds;
          End;
          // Convert Voltage Buffer to power kW, kvar
          IF  ((Mode AND MODEMASK) = 1)
             THEN IsPower := TRUE
             ELSE IsPower := FALSE;

          CASE (Mode AND (MAGNITUDEMASK + POSSEQONLYMASK)) OF
            32:Begin // Save Magnitudes only
                 RecordSize := 0;
                 FOR i := 1 to NumVI DO Inc(RecordSize,1);
                 IF Not IsPower
                 THEN Begin
                      FOR i := 1 to NumVI DO Inc(RecordSize,1);
                      IF IncludeResidual Then Inc(RecordSize, 2);
                       For i := 1 to NumVI Do Begin
                           Add2header(pAnsiChar(AnsiString(Format('|V|%d (volts)',[i]))));
                           Add2header(pAnsiChar(', '));
                       End;
                       IF IncludeResidual Then Begin
                           Add2header(pAnsiChar('|VN| (volts)'));
                           Add2header(pAnsiChar(', '));
                       End;
                       For i := 1 to NumVI Do Begin
                           Add2header(pAnsiChar(AnsiString('|I|'+IntToStr(i)+' (amps)')));
                           If i<NumVI Then Add2header(pAnsiChar(', '));
                       End;
                       IF IncludeResidual Then Begin
                           Add2header(pAnsiChar(',|IN| (amps)'));
                       End;
                 End
                 Else Begin  // Power
                       For i := 1 to NumVI Do
                       Begin
                           If PPolar Then Add2header(pAnsiChar(AnsiString('S'+IntToStr(i)+' (kVA)')))
                                     Else Add2header(pAnsiChar(AnsiString('P'+IntToStr(i)+' (kW)')));
                           If i<NumVI Then Add2header(pAnsiChar(', '));
                       End;
                 End;
              End ;
            64:Begin // Save Pos Seq or Total of all Phases or Total power (Complex)
                     RecordSize := 2;
                     IF Not IsPower THEN Begin
                        RecordSize := RecordSize+ 2;
                        If VIPolar Then Add2header(pAnsiChar('V1, V1ang, I1, I1ang'))
                                   Else Add2header(pAnsiChar('V1.re, V1.im, I1.re, I1.im'));
                     End
                     Else Begin
                        If Ppolar Then Add2header(pAnsiChar('S1 (kVA), Ang '))
                                  Else Add2header(pAnsiChar('P1 (kW), Q1 (kvar)'));
                     End;
               End ;
            96:Begin  // Save Pos Seq or Aver magnitude of all Phases of total kVA (Magnitude)
                     RecordSize := 1;
                     IF Not IsPower
                     THEN Begin
                       RecordSize := RecordSize+ 1;
                       Add2header(pAnsiChar('V, I '));
                     End
                     Else Begin  // Power
                        If Ppolar Then Add2header(pAnsiChar('S1 (kVA)'))
                                  Else Add2header(pAnsiChar('P1 (kW)'));
                     End;
               End ;

          ELSE // save  V and I in mag and angle or complex kW, kvar
                RecordSize := NumVI*2;
                IF Not IsPower THEN Begin
                     If isPosSeq then Begin iMin := 0; iMax := NumVI-1; End
                     Else Begin iMin := 1; iMax := NumVI; End;
                     RecordSize := RecordSize + NumVI*2;
                     IF IncludeResidual Then Inc(RecordSize, 4);
                     For i := iMin to iMax Do Begin
                        If VIPolar Then Add2header(pAnsiChar(AnsiString('V'+IntToStr(i)+', VAngle'+IntToStr(i))))
                                   Else Add2header(pAnsiChar(AnsiString('V'+IntToStr(i)+'.re, V'+IntToStr(i)+'.im')));
                        Add2header(pAnsiChar(', '));
                     End;
                     IF IncludeResidual Then Begin
                        If VIPolar Then Add2header(pAnsiChar('VN, VNAngle'))
                                   Else Add2header(pAnsiChar('VN.re, VN.im'));
                        Add2header(pAnsiChar(', '));
                     End;
                     For i := iMin to iMax Do Begin
                        If VIPolar Then Add2header(pAnsiChar(AnsiString('I'+IntToStr(i)+', IAngle'+IntToStr(i))))
                                   Else Add2header(pAnsiChar(AnsiString('I'+IntToStr(i)+'.re, I'+IntToStr(i)+'.im')));
                        If i<NumVI Then Add2header(pAnsiChar(', '));
                     End;
                     IF IncludeResidual Then Begin
                        If VIPolar Then Add2header(pAnsiChar(', IN, INAngle'))
                        Else Add2header(pAnsiChar(', IN.re, IN.im'));
                     End;
                End
                Else Begin
                    If isPosSeq then Begin iMin := 0; iMax := NumVI-1; End
                    Else Begin iMin := 1; iMax := NumVI; End;
                    For i := iMin to iMax Do Begin
                        If Ppolar Then Add2header(pAnsiChar(AnsiString('S'+IntToStr(i)+' (kVA), Ang'+IntToStr(i))))
                                  Else Add2header(pAnsiChar(AnsiString('P'+IntToStr(i)+' (kW), Q'+IntToStr(i)+' (kvar)')));
                        If i<NumVI Then Add2header(pAnsiChar(', '));
                    End;
                End;
          END;
         End;
     END;  {CASE}


     // RecordSize is the number of singles in the sample (after the hour and sec)

     // Write Header to Monitor Stream
     // Write ID so we know it is a DSS Monitor file and which version in case we
     // change it down the road
     // Adds NULL character at the end of the header to note the end of the string

     setlength(StrBuffer,(length(StrBuffer) + 1));
     StrBuffer[High(StrBuffer)] :=  AnsiChar(0);
     myHeaderSize :=  length(StrBuffer);    // stores the size of the header for further use    

     With MonitorStream Do Begin
         Write(FileSignature, Sizeof(FileSignature) );
         Write(FileVersion,   Sizeof(FileVersion) );
         Write(RecordSize,    Sizeof(RecordSize) );
         Write(Mode,          Sizeof(Mode)       );
         Write(dummyRec,      Sizeof(TMonitorStrBuffer));       // adds the empty dummy record to avoid
                                                                // killing apps relying on this space
     End;

{    So the file now looks like: (update 05-18-2021)
       FileSignature (4 bytes)    32-bit Integers
       FileVersion   (4)
       RecordSize    (4)
       Mode          (4)
       String        (256) - > this is empty now
      
       hr   (4)       all singles
       Sec  (4)
       Sample  (4*RecordSize)
       ...

 }

  Except
      On E: Exception DO DoErrorMsg('Cannot open Monitor file.',
                    E.Message,
                    'Monitor: "' + Name + '"', 670)

  End;
End;


{--------------------------------------------------------------------------}
Procedure TMonitorObj.OpenMonitorStream;
Begin

    If NOT IsFileOpen then Begin
       MonitorStream.Seek(0, soFromEnd	);    // Positioned at End of Stream
       IsFileOpen := True;
    End;

End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.CloseMonitorStream(ActorID : Integer);
Begin
  Try
     If IsFileOpen THEN Begin  // only close open files
        PostProcess(ActorID);
        MonitorStream.Seek(0, soFromBeginning);   // just move stream position to the beginning
        IsFileOpen := false;
     End;
  Except
      On E: Exception DO DoErrorMsg('Cannot close Monitor stream.',
                    E.Message,
                    'Monitor: "' + Name + '"', 671)
  End;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.Save;

// Saves present buffer to monitor file, resets bufferptrs and continues

Begin

     If NOT IsFileOpen THEN OpenMonitorStream; // Position to end of stream

     {Write present monitor buffer to monitorstream}
     MonitorStream.Write(MonBuffer^, SizeOF(MonBuffer^[1]) * BufPtr);

     BufPtr := 0; // reset Buffer for next

End;



{--------------------------------------------------------------------------}
Procedure TMonitorObj.ResetIt(ActorID : Integer);
Begin
     BufPtr := 0;
     ClearMonitorStream(ActorID);
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.PostProcess(ActorID : Integer);
Begin
  if IsProcessed = FALSE then begin
    if (mode = 4) and (MonitorStream.Position > 0) then DoFlickerCalculations(ACtorID);
  end;
  IsProcessed := TRUE;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.TakeSample(ActorID : Integer);
VAR
    dHour             :Double;
    dSum              :Double;
    IsPower           :Boolean;
    IsSequence        :Boolean;
    BuffInit,
    BuffEnd,
    i,j,k,
    myRefIdx,
    CalcEnd,
    NumVI             :Integer;
    Offset            :Integer;
    ResidualCurr      :Complex;
    ResidualVolt      :Complex;
    Sum               :Complex;
    CplxLosses        :Complex;
    V012,I012         :Array[1..3] of Complex;


Begin

   If Not (ValidMonitor and Enabled) Then Exit;

   inc(SampleCount);

   Hour := ActiveCircuit[ActorID].Solution.DynaVars.intHour;
   Sec :=  ActiveCircuit[ActorID].Solution.Dynavars.t;

   Offset := (MeteredTerminal-1)  * MeteredElement.NConds;   // Used to index the CurrentBuffer array

   //Save time unless Harmonics mode and then save Frequency and Harmonic
   WITH ActiveCircuit[ActorID].Solution Do
     IF IsHarmonicModel Then Begin
         AddDblsToBuffer(@Frequency, 1);  // put freq in hour slot as a double
         AddDblsToBuffer(@Harmonic ,1);  // stick harmonic in time slot in buffer
     End
     ELSE Begin
         dHour := Hour;      // convert to double
         AddDblsToBuffer(@dHour, 1);  // put hours in buffer as a double
         AddDblsToBuffer(@Sec, 1);  // stick time in sec in buffer
     End;

   CASE  (Mode AND MODEMASK) of

     0,1:       // Voltage, current. Powers
       Begin
            // MeteredElement.GetCurrents(CurrentBuffer);
            // To save some time, call ComputeITerminal
            MeteredElement.ComputeIterminal(ActorID);   // only does calc if needed
            For i := 1 to MeteredElement.Yorder Do CurrentBuffer^[i] := MeteredElement.Iterminal^[i];

            TRY
              FOR i := 1 to Fnconds DO
              Begin
                // NodeRef is set by the main Circuit object
                // It is the index of the terminal into the system node list
                  VoltageBuffer^[i] := ActiveCircuit[ActorID].Solution.NodeV^[NodeRef^[i]];
              End;
            EXCEPT
               On E:Exception Do DoSimpleMsg(E.Message + CRLF + 'NodeRef is invalid. Try solving a snapshot or direct before solving in a mode that takes a monitor sample.', 672);
            END;
       End;

     2: Begin     // Monitor Transformer Tap Position
             If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
             Then With TAutoTransObj(MeteredElement) Do AddDblToBuffer(PresentTap[MeteredTerminal, ActorID ])
             Else With TTransfObj(MeteredElement)    Do AddDblToBuffer(PresentTap[MeteredTerminal, ActorID]);

              Exit;  // Done with this mode now.
        End;

     3: Begin   // Pick up device state variables
              TPCElement(MeteredElement).GetAllVariables(StateBuffer);
              AddDblsToBuffer(StateBuffer, NumStateVars);
              Exit; // Done with this mode now
        End;

     4: Begin   // RMS phase voltages for flicker evaluation
            TRY
              FOR i := 1 to Fnphases DO Begin
                  FlickerBuffer^[i] := ActiveCircuit[ActorID].Solution.NodeV^[NodeRef^[i]];
              End;
            EXCEPT
               On E:Exception Do DoSimpleMsg(E.Message + CRLF + 'NodeRef is invalid. Try solving a snapshot or direct before solving in a mode that takes a monitor sample.', 672);
            END;
        End;

     5: Begin
            (* Capture Solution Variables *)
            With ActiveCircuit[ActorID].Solution Do Begin
             SolutionBuffer^[1]   :=  Iteration;
             SolutionBuffer^[2]   :=  ControlIteration;
             SolutionBuffer^[3]   :=  MaxIterations;
             SolutionBuffer^[4]   :=  MaxControlIterations;
             If ConvergedFlag then SolutionBuffer^[5] := 1 else SolutionBuffer^[5] := 0;
             SolutionBuffer^[6]   :=  IntervalHrs;
             SolutionBuffer^[7]   :=  SolutionCount;
             SolutionBuffer^[8]   :=  Mode;
             SolutionBuffer^[9]   :=  Frequency;
             SolutionBuffer^[10]  :=  Year;
             SolutionBuffer^[11]  :=  Time_Solve;
             SolutionBuffer^[12]  :=  Time_Step;
            End;

        End;

     6: Begin     // Monitor Capacitor State

              With TCapacitorObj(MeteredElement) Do Begin
                  for i := 1 to NumSteps do
                    begin
                      AddDblToBuffer(States[i,ActorID]);
                    end;
              End;
              Exit;  // Done with this mode now.
        End;
     7: Begin     // Monitor Storage Device state variables
              If (MeteredElement.DSSObjType And CLASSMASK) = STORAGE_ELEMENT Then Begin  // Storage Element
                With TStorageObj(MeteredElement) Do Begin
                  AddDblToBuffer(PresentkW);
                  AddDblToBuffer(Presentkvar);
                  AddDblToBuffer(StorageVars.kWhStored);
                  AddDblToBuffer(((StorageVars.kWhStored)/(StorageVars.kWhRating))*100);
                  AddDblToBuffer(StorageState);
                End;
              {End
              Else if (MeteredElement.DSSObjType And CLASSMASK) = STORAGE2_ELEMENT Then Begin   // Storage2 Element
                With TStorageObj(MeteredElement) Do Begin
                  AddDblToBuffer(PresentkW);
                  AddDblToBuffer(Presentkvar);
                  AddDblToBuffer(StorageVars.kWhStored);
                  AddDblToBuffer(((StorageVars.kWhStored)/(StorageVars.kWhRating))*100);
                  AddDblToBuffer(StorageState);
                End; }
              End;
              Exit;  // Done with this mode now.
        End;

      8: Begin   // Winding Currents
              // Get all currents in each end of each winding
             If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
             Then With TAutoTransObj(MeteredElement) Do
                Begin
                  GetAllWindingCurrents(WdgCurrentsBuffer, ActorID);
                  ConvertComplexArrayToPolar( WdgCurrentsBuffer, NumTransformerCurrents);
                  // Put every other Current into buffer
                  // Current magnitude is same in each end
                  k := 1;
                  for i := 1 to Nphases*NumberOfWindings  do
                  Begin
                        AddDblsToBuffer(@WdgCurrentsBuffer^[k].re, 2);  // Add Mag, Angle
                        k := k + 2;
                  End;
                End
             Else With TTransfobj(MeteredElement) Do
                Begin
                  GetAllWindingCurrents(WdgCurrentsBuffer, ActorID);
                  ConvertComplexArrayToPolar( WdgCurrentsBuffer, NumTransformerCurrents);
                  // Put every other Current into buffer
                  // Current magnitude is same in each end
                  k := 1;
                  for i := 1 to Nphases*NumberOfWindings  do
                  Begin
                        AddDblsToBuffer(@WdgCurrentsBuffer^[k].re, 2);  // Add Mag, Angle
                        k := k + 2;
                  End;
                 // AddDblsToBuffer(@WdgCurrentsBuffer^[1].re, NumTransformerCurrents);
                End;
              Exit;
         End;

      9: Begin  // losses
             CplxLosses := MeteredElement.Losses[ActorID];
             AddDblToBuffer(CplxLosses.re);
             AddDblToBuffer(CplxLosses.im);
             Exit; // Done with this mode now.
         End;

     10: Begin   // Winding Voltages
              // Get all Voltages across each winding and put into buffer
             If (MeteredElement.DSSObjType And CLASSMASK) = AUTOTRANS_ELEMENT
             Then With TAutoTransObj(MeteredElement) Do
              Begin
                  For i := 1 to NumberOfWindings Do  Begin
                    GetAutoWindingVoltages(i, PhsVoltagesBuffer, ActorID);
                    For j := 1 to nphases Do
                       WdgVoltagesBuffer^[i + (j-1)*NumberofWindings] := PhsVoltagesBuffer^[j];
                  End;
                  ConvertComplexArrayToPolar( WdgVoltagesBuffer, NumWindingVoltages);
                  {Put winding Voltages into Monitor}
                  AddDblsToBuffer(@WdgVoltagesBuffer^[1].re, 2 * NumWindingVoltages);  // Add Mag, Angle each winding
              End

             Else With TTransfobj(MeteredElement) Do
              Begin
                  For i := 1 to NumberOfWindings Do  Begin
                    GetWindingVoltages(i, PhsVoltagesBuffer, ActorID);
                    For j := 1 to nphases Do
                       WdgVoltagesBuffer^[i + (j-1)*NumberofWindings] := PhsVoltagesBuffer^[j];
                  End;
                  ConvertComplexArrayToPolar( WdgVoltagesBuffer, NumWindingVoltages);
                  {Put winding Voltages into Monitor}
                  AddDblsToBuffer(@WdgVoltagesBuffer^[1].re, 2 * NumWindingVoltages);  // Add Mag, Angle each winding
              End;
              Exit;
         End;
     11: Begin    {Get all terminal voltages and currents of this device}

            {Get All node voltages at all terminals}
            MeteredElement.ComputeVterminal(ActorID);
            For i := 1 to MeteredElement.Yorder Do VoltageBuffer^[i] := MeteredElement.Vterminal^[i];
            ConvertComplexArrayToPolar( VoltageBuffer, MeteredElement.Yorder);
            {Put Terminal Voltages into Monitor}
            AddDblsToBuffer(@VoltageBuffer^[1].re, 2 * MeteredElement.Yorder);

            {Get all terminsl currents}
            MeteredElement.ComputeIterminal(ActorID);   // only does calc if needed
            For i := 1 to MeteredElement.Yorder Do CurrentBuffer^[i] := MeteredElement.Iterminal^[i];
            ConvertComplexArrayToPolar( CurrentBuffer, MeteredElement.Yorder);
            {Put Terminal currents into Monitor}
            AddDblsToBuffer(@CurrentBuffer^[1].re, 2 * MeteredElement.Yorder);
            Exit;
         End;
     12: Begin    {Get all terminal voltages LL and currents of this device - 05192021}
            With MeteredElement Do
            Begin
              {Get All node voltages at all terminals}
              ComputeVterminal(ActorID);
              for k := 1 to NTerms do   // Adds each term separately
              Begin
                BuffInit  :=  1 + NPhases * (k - 1);
                BuffEnd   :=  NPhases * k;
                For i := BuffInit to BuffEnd Do
                  VoltageBuffer^[i - (BuffInit - 1)] := Vterminal^[i];
                if NPhases = NConds then
                  myRefIdx                    :=  NPhases + 1
                else
                  myRefIdx                    :=  NConds;

                //Brings the first phase to the last place for calculations
                VoltageBuffer^[myRefIdx]      :=  VoltageBuffer^[1];
                // Calculates the LL voltages
                For i := 1 to NPhases Do
                  VoltageBuffer^[i] := csub(VoltageBuffer^[i],VoltageBuffer^[i+1]);
                ConvertComplexArrayToPolar( VoltageBuffer, Yorder);
                {Put Terminal Voltages into Monitor}
                AddDblsToBuffer(@VoltageBuffer^[1].re, 2 * NPhases);
              End;

              {Get all terminsl currents}
              ComputeIterminal(ActorID);   // only does calc if needed
              For i := 1 to Yorder Do CurrentBuffer^[i] := Iterminal^[i];
              ConvertComplexArrayToPolar( CurrentBuffer, Yorder);
              {Put Terminal currents into Monitor}
              AddDblsToBuffer(@CurrentBuffer^[1].re, 2 * Yorder);
              Exit;
            End;
         End
     Else Exit  // Ignore invalid mask

   End;


   IF ((Mode AND SEQUENCEMASK)>0) And (Fnphases=3)
   THEN Begin  // Convert to Symmetrical components
       Phase2SymComp(VoltageBuffer, @V012);
       Phase2SymComp(@CurrentBuffer^[Offset + 1], @I012);
       NumVI      := 3;
       IsSequence := TRUE;
       // Replace voltage and current buffer with sequence quantities
       FOR i := 1 to 3 DO VoltageBuffer^[i]         := V012[i];
       FOR i := 1 to 3 DO CurrentBuffer[Offset + i] := I012[i];
   End
   ELSE Begin
       NumVI      :=Fnconds;
       IsSequence := FALSE;
   End;

   IsPower := False;  // Init so compiler won't complain
   CASE  (Mode AND MODEMASK) of
     0: Begin        // Convert to Mag, Angle   and compute residual if required
          IsPower := FALSE;
          IF IncludeResidual THEN Begin
             If VIPolar Then Begin
                 ResidualVolt := ResidualPolar(@VoltageBuffer^[1], Fnphases);
                 ResidualCurr := ResidualPolar(@CurrentBuffer^[Offset+1], Fnphases);
             End Else Begin
                 ResidualVolt := Residual(@VoltageBuffer^[1], Fnphases);
                 ResidualCurr := Residual(@CurrentBuffer^[Offset+1], Fnphases);
             End;
          End;
          If VIPolar Then Begin
             ConvertComplexArrayToPolar(VoltageBuffer, NumVI);
             ConvertComplexArrayToPolar(@CurrentBuffer^[Offset+1], NumVI );    // Corrected 3-11-13
          End;
        End;
     1: Begin     // Convert Voltage Buffer to power kW, kvar or Mag/Angle
          CalckPowers(VoltageBuffer, VoltageBuffer, @CurrentBuffer^[Offset+1], NumVI);
          IF (IsSequence OR ActiveCircuit[ActorID].PositiveSequence) THEN  CmulArray(VoltageBuffer, 3.0, NumVI); // convert to total power
          If Ppolar Then ConvertComplexArrayToPolar(VoltageBuffer, NumVI);
          IsPower := TRUE;
        End;
     4: Begin
          IsPower := FALSE;
          ConvertComplexArrayToPolar(FlickerBuffer, Fnphases);
        End
   Else
   End;

   // Now check to see what to write to disk
   CASE (Mode AND (MAGNITUDEMASK + POSSEQONLYMASK)) OF
     32:Begin // Save Magnitudes only
          FOR i := 1 to NumVI DO AddDblToBuffer(VoltageBuffer^[i].re {Cabs(VoltageBuffer^[i])});
          IF IncludeResidual Then AddDblToBuffer(ResidualVolt.re);
          IF Not IsPower
          THEN  Begin
               FOR i := 1 to NumVI DO AddDblToBuffer(CurrentBuffer^[Offset+i].re {Cabs(CurrentBuffer^[Offset+i])});
               IF IncludeResidual Then AddDblToBuffer(ResidualCurr.re);
          End;
        End ;
     64:Begin // Save Pos Seq or Avg of all Phases or Total power (Complex)
           If isSequence THEN Begin
              AddDblsToBuffer(@VoltageBuffer^[2].re, 2);
              IF Not IsPower THEN AddDblsToBuffer(@CurrentBuffer^[Offset+2].re, 2);
           End
           ELSE Begin
              If IsPower Then Begin
                  Sum := cZero;
                  FOR i := 1 to Fnphases DO Caccum(Sum, VoltageBuffer^[i]);
                  AddDblsToBuffer(@Sum.re,2);
                End
              ELSE Begin  // Average the phase magnitudes and  sum angles
                   Sum := cZero;
                   FOR i := 1 to Fnphases DO Caccum(Sum, VoltageBuffer^[i]);
                   Sum.re := Sum.re / FnPhases;
                   AddDblsToBuffer(@Sum.re,2);
                   Sum := cZero;
                   FOR i := 1 to Fnphases DO Caccum(Sum, CurrentBuffer^[Offset+i]);   // Corrected 3-11-13
                   Sum.re := Sum.re / FnPhases;
                   AddDblsToBuffer(@Sum.re,2);
                End;
           End;
        End ;
     96:Begin  // Save Pos Seq or Aver magnitude of all Phases of total kVA (Magnitude)
           If isSequence THEN Begin
              AddDblToBuffer(VoltageBuffer^[2].Re);    // First double is magnitude
              IF Not IsPower THEN AddDblToBuffer(CurrentBuffer^[Offset+2].Re);
           End
           ELSE Begin
              dSum := 0.0;
              FOR i := 1 to Fnphases DO dSum := dSum + VoltageBuffer^[i].re; //Cabs(VoltageBuffer^[i]);
              If Not IsPower THEN dSum := dSum/Fnphases;
              AddDblToBuffer(dSum);
              IF Not IsPower THEN Begin
                dSum := 0.0;
                FOR i := 1 to Fnphases DO dSum := dSum + CurrentBuffer^[Offset+i].re; //Cabs(CurrentBuffer^[Offset+i]);
                dSum := dSum/Fnphases;
                AddDblToBuffer(dSum);
              End;
           End;
       End ;

   ELSE
     CASE Mode of
        4:   AddDblsToBuffer(@FlickerBuffer^[1].re, Fnphases*2);
        5:   AddDblsToBuffer(@SolutionBuffer^[1], NumSolutionVars);
       else begin
         AddDblsToBuffer(@VoltageBuffer^[1].re, NumVI*2);
         IF Not IsPower THEN Begin
            IF IncludeResidual THEN AddDblsToBuffer(@ResidualVolt, 2);
            AddDblsToBuffer(@CurrentBuffer^[Offset + 1].re, NumVI*2);
            IF IncludeResidual THEN AddDblsToBuffer(@ResidualCurr, 2);
         End;
     End;
     END;
   END;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.AddDblsToBuffer( Dbl:pDoubleArray; Ndoubles:Integer);

VAR
   i:Integer;

Begin
   FOR i := 1 to Ndoubles DO AddDblToBuffer(Dbl^[i]);
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.AddDblToBuffer(const Dbl:Double);

Begin
    // first check to see if there's enough room
    // if not, save to monitorstream first.
    IF BufPtr=BufferSize THEN Save;
    Inc(BufPtr);
    MonBuffer^[BufPtr]:=Dbl;
End;

Procedure TMonitorObj.DoFlickerCalculations(ActorID : Integer);
var
  FSignature  :Integer;
  Fversion    :Integer;
  RecordSize  :Cardinal;
  RecordBytes :Cardinal;
  SngBuffer   :Array[1..100] of Single;
  hr          :single;
  s           :single;
  N           :Integer;
  Npst        :Integer;
  i, p        :Integer;
  bStart      :Integer;
  data        :Array of pSingleArray; // indexed from zero (time) to FnPhases
  pst         :Array of pSingleArray; // indexed from zero to FnPhases - 1
  ipst        :integer;
  tpst        :single;
  defaultpst  :single;
  Vbase       :single;
  busref      :integer;
begin
  N := SampleCount;
  With MonitorStream Do Begin
    Seek(0, soFromBeginning);  // Start at the beginning of the Stream
    Read( Fsignature, Sizeof(Fsignature));
    Read( Fversion,   Sizeof(Fversion));
    Read( RecordSize, Sizeof(RecordSize));
    Read( Mode,       Sizeof(Mode));
    Read( dummyRec,   Sizeof(dummyRec));
    bStart := Position;
  End;
  RecordBytes := Sizeof(SngBuffer[1]) * RecordSize;
  Try
    // read rms voltages out of the monitor stream into arrays
    SetLength (data, Fnphases + 1);
    SetLength (pst, Fnphases);
    for p := 0 to FnPhases do data[p] := AllocMem (Sizeof(SngBuffer[1]) * N);
    i := 1;
    while Not (MonitorStream.Position>=MonitorStream.Size) do Begin
      With MonitorStream Do Begin
        Read( hr, SizeOf(hr));
        Read( s,  SizeOf(s));
        Read(SngBuffer, RecordBytes);
        data[0][i] := s + 3600.0 * hr;
        for p := 1 to FnPhases do data[p][i] := SngBuffer[2*p - 1];
        i := i + 1;
      End;
    End;

    // calculate the flicker level and pst
    Npst := 1 + Trunc (data[0][N] / 600.0); // pst updates every 10 minutes or 600 seconds
    for p := 0 to FnPhases-1 do begin
      pst[p] := AllocMem (Sizeof(SngBuffer[1]) * Npst);
      busref := MeteredElement.Terminals[MeteredTerminal].BusRef;
      Vbase := 1000.0 * ActiveCircuit[ActorID].Buses^[busref].kVBase;
      FlickerMeter (N, BaseFrequency, Vbase, data[0], data[p+1], pst[p]);
    end;

    // stuff the flicker level and pst back into the monitor stream
    with MonitorStream do begin
      Position := bStart;
      tpst:=0.0;
      ipst:=0;
      defaultpst:=0;
      for i := 1 to N do begin
        if (data[0][i] - tpst) >= 600.0 then begin
          inc(ipst);
          tpst:=data[0][i];
        end;
        Position:=Position + 2 * SizeOf(hr); // don't alter the time
        for p := 1 to FnPhases do begin
          Write (data[p][i], sizeof(data[p][i]));
          if (ipst > 0) and (ipst <= Npst) then
            Write (pst[p-1][ipst], sizeof(pst[p-1][ipst]))
          else
            Write (defaultpst, sizeof(defaultpst))
        end;
      end;
    end;
  Finally
    for p := 0 to FnPhases do ReAllocMem (data[p], 0);
    for p := 0 to FnPhases-1 do ReAllocMem (pst[p], 0);
  end;
end;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.TranslateToCSV(Show:Boolean; ActorID : Integer);


VAR
    CSVName       :String;
    F             :TextFile;
    FSignature    :Integer;
    Fversion      :Integer;
    hr            :single;
    i             :Cardinal;
    Mode          :Integer;
    Nread         :Cardinal;
    pStr          :pAnsiChar;
    RecordBytes   :Cardinal;
    RecordSize    :Cardinal;
    s             :single;
    sngBuffer     :Array[1..100] of Single;

Begin

     Save;  // Save present buffer
     CloseMonitorStream(ActorID);   // Position at beginning

     CSVName := Get_FileName(ActorID);

     TRY
      AssignFile(F, CSVName);    // Make CSV file
      if ConcatenateReports and (ActorID <> 1) then
        Append(F)
      else
        Rewrite(F);
     EXCEPT
      On E: Exception DO Begin
         DoSimpleMsg('Error opening CSVFile "'+CSVName+'" for writing' +CRLF + E.Message, 672);
         Exit
      End;
     End;

     With MonitorStream Do Begin
         Seek(0, soFromBeginning);  // Start at the beginning of the Stream
         Read( Fsignature, Sizeof(Fsignature));
         Read( Fversion,   Sizeof(Fversion));
         Read( RecordSize, Sizeof(RecordSize));
         Read( Mode,       Sizeof(Mode));
         Read( dummyRec,   Sizeof(dummyRec));
     End;
     pStr := @StrBuffer[0];
     if not ConcatenateReports or (ActorID=1) then
     Writeln(F, pStr);
     RecordBytes := Sizeof(SngBuffer[1]) * RecordSize;

     TRY
       TRY

           WHILE Not (MonitorStream.Position>=MonitorStream.Size) DO  Begin
              With MonitorStream Do Begin
                Read( hr, SizeOF(hr));
                Read( s,  SizeOf(s));
                Nread := Read( sngBuffer, RecordBytes);
              End;
              If Nread < RecordBytes then Break;
              Write(F, hr:0:0);          // hours
              Write(F, ', ', s:0:5);     // sec
              FOR i := 1 to RecordSize DO Begin
                 Write(F,', ', Format('%-.6g', [sngBuffer[i]]))
              End;
              Writeln(F);
           End;

       EXCEPT

           On E: Exception DO Begin
             DoSimpleMsg('Error Writing CSVFile "'+CSVName+'" ' +CRLF + E.Message, 673);
           End;

       END;

     FINALLY

       CloseMonitorStream(ActorID);
       CloseFile(F);

     END;

     IF (Show and AutoDisplayShowReport) Then FireOffEditor(CSVName);

     GlobalResult := CSVName;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.GetCurrents(Curr: pComplexArray; ActorID : Integer);  //Get present value of terminal Curr for reports
VAR
   i:Integer;
Begin

{
  Revised 12-7-99 to return Zero current instead of Monitored element current because
 it was messing up Newton iteration.
}

  For i := 1 to Fnconds Do Curr^[i] := CZERO;

End;

Procedure TMonitorObj.GetInjCurrents(Curr: pComplexArray; ActorID : Integer);
Var i:Integer;
Begin
     FOR i := 1 to Fnconds DO Curr^[i] := CZERO;
End;

{--------------------------------------------------------------------------}
Procedure TMonitorObj.DumpProperties(Var F:TextFile; Complete:Boolean);

VAR
   i, k:Integer;

Begin
    Inherited DumpProperties(F,Complete);

    With ParentClass Do
     For i := 1 to NumProperties Do
       Begin
          Writeln(F,'~ ',PropertyName^[i],'=',PropertyValue[i]);
       End;


    If Complete Then Begin
      Writeln(F);
      Writeln(F,'// BufferSize=',BufferSize:0);
      Writeln(F,'// Hour=',Hour:0);
      Writeln(F,'// Sec=',Sec:0);
      Writeln(F,'// BaseFrequency=',BaseFrequency:0:1);
      Writeln(F,'// Bufptr=',BufPtr:0);
      Writeln(F,'// Buffer=');
      k:=0;
      FOR i := 1 to BufPtr DO Begin
        Write(F, MonBuffer^[i]:0:1,', ');
        Inc(k);
        IF k=(2 + Fnconds*4) THEN Begin
          Writeln(F);
          k:=0;
        End;
      End;
      Writeln(F);
    End;

End;

procedure TMonitorObj.InitPropertyValues(ArrayOffset: Integer);
begin

     PropertyValue[1] := ''; //'element';
     PropertyValue[2] := '1'; //'terminal';
     PropertyValue[3] := '0'; //'mode';
     PropertyValue[4] := ''; // 'action';  // buffer=clear|save|take|process
     PropertyValue[5] := 'NO';
     PropertyValue[6] := 'YES';
     PropertyValue[7] := 'YES';

  inherited  InitPropertyValues(NumPropsThisClass);

end;


{--------------------------------------------------------------------------}

procedure TDSSMonitor.TOPExport(ObjName:String);

Var
   NameList, CNames:TStringList;
   Vbuf, CBuf:pDoubleArray;
   Obj:TMonitorObj;
   i: Integer;
   MaxTime :Double;
   ObjList:TPointerList;
   Hours:Boolean;
   StrBuffer:TMonitorStrBuffer;
   pStrBuffer:pAnsiChar;
   Fversion, FSignature, iMode:Integer;
   Nread, RecordSize, RecordBytes, PositionSave:Cardinal;
   sngBuffer:Array[1..100] of Single;
   time:Double;
   hr, s:single;
   TrialFileName,FileNumber:String;

begin
     // Create a unique file name
     TrialFileName := GetOutputDirectory + 'TOP_Mon_'+ObjName;
     FileNumber := '';
     i := 0;
     While FileExists(TrialFileName + FileNumber + '.STO') Do Begin
         Inc(i);
         FileNumber := IntToStr(i);
     End;
     TOPTransferFile.FileName := TrialFileName + Filenumber + '.STO';
     TRY                                 
         TOPTransferFile.Open;
     EXCEPT
        ON E:Exception Do
        Begin
          DoSimpleMsg('TOP Transfer File Error: '+E.message, 674);
          TRY
              TopTransferFile.Close;
          EXCEPT
              {OK if Error}
          End;
          Exit;
        End;
     END;

     {Send only fixed interval data}

     ObjList := TPointerList.Create(10);
     NameList := TStringList.Create;
     CNames := TStringList.Create;

     {Make a List of fixed interval data where the interval is greater than 1 minute}
     IF CompareText(ObjName, 'ALL')=0 Then Begin
        DoSimpleMsg('ALL option not yet implemented.', 675);
     {
       Obj := ElementList.First;
       While Obj <>  Nil Do Begin
          If Obj.Interval>(1.0/60.0) Then ObjList.Add(Obj);
          Obj := ElementList.Next;
       End;
     }
     End
     ELSE Begin
       Obj := Find(ObjName);
       If Obj <>  Nil Then  ObjList.Add(Obj)
       Else DoSimpleMsg('Monitor.'+ObjName+' not found.', 676);
     End;

     {If none found, exit}
     If ObjList.ListSize >0 Then Begin

     Obj := ObjList.First;  {And only}
     With Obj Do Begin

           Save;  // Save present buffer
           CloseMonitorStream(ActiveActor);

           pStrBuffer := @StrBuffer;
           With MonitorStream Do Begin
               Seek(0, soFromBeginning);  // Start at the beginning of the Stream
               Read( Fsignature, Sizeof(Fsignature));
               Read( Fversion,   Sizeof(Fversion));
               Read( RecordSize, Sizeof(RecordSize));
               Read( iMode,      Sizeof(iMode));
               Read( dummyRec,   Sizeof(dummyRec));
           End;

           {Parse off Channel Names}
           AuxParser[ActiveActor].Whitespace := '';
           AuxParser[ActiveActor].CmdString := String(pStrBuffer);
              AuxParser[ActiveActor].NextParam;  // pop off two
              AuxParser[ActiveActor].NextParam;
           For i := 1 to RecordSize Do Begin
              AuxParser[ActiveActor].NextParam;
              NameList.Add(AuxParser[ActiveActor].StrValue);
           End;
           AuxParser[ActiveActor].ResetDelims;

           {Write TOP Header}

          {Find Max number of points}
           RecordBytes := Sizeof(SngBuffer[1]) * RecordSize;
           VBuf := AllocMem(Sizeof(Double)* RecordSize);  // Put Everything in here for now
           CBuf := AllocMem(Sizeof(Double)* 1);   // just a dummy -- Cbuf is ignored here

           {Get first time value and set the interval to this value}
           hr:= 0.0;
           s := 0.0;
           If Not (MonitorStream.Position>=MonitorStream.Size) Then
             With MonitorStream Do Begin
                  Read( hr, 4);  // singles
                  Read( s, 4);
                  Read( sngBuffer, RecordBytes);
             End;
           {Set Hours or Seconds for Interval}
           Hours := TRUE;
           If (s > 0.0) and (s < 100.0) Then Hours := FALSE ;

           CASE ActiveCircuit[ActiveActor].Solution.DynaVars.SolutionMode of
             HARMONICMODE: Time := hr;
           ELSE
             If Hours Then Time := hr + s/3600.0 // in hrs
                      Else Time := Hr * 3600.0 + s; // in sec
           END;

           {Now find Maxtime in Monitor}
           PositionSave := MonitorStream.Position;
           MonitorStream.Seek(-(Recordbytes+8), soFromEnd);
           If Not (MonitorStream.Position>=MonitorStream.Size) Then
             With MonitorStream Do Begin
                  Read( hr, 4);  // singles
                  Read( s, 4);
                  Read( sngBuffer, RecordBytes);
             End;

           CASE ActiveCircuit[ActiveActor].Solution.DynaVars.SolutionMode of
             HARMONICMODE: MaxTime := hr;
           ELSE
             If Hours Then MaxTime := hr + s/3600.0 // in hrs
                      Else MaxTime := Hr * 3600.0 + s; // in sec
           END;

           {Go Back to where we were}
           MonitorStream.Seek(PositionSave, soFromBeginning);

           TopTransferFile.WriteHeader(Time, MaxTime, Time, RecordSize, 0, 16,  'DSS (TM), EPRI (R)');
           TopTransferFile.WriteNames(NameList, CNames);

           {Now Process rest of monitor file}

           If Not (MonitorStream.Position>=MonitorStream.Size) Then
           Repeat
              FOR i := 1 to RecordSize DO VBuf^[i] := SngBuffer[i];
              TopTransferFile.WriteData(Time, Vbuf, Cbuf);
              With MonitorStream Do Begin
                Read( hr, SizeOF(hr));
                Read( s, SizeOf(s));
                Nread := Read( sngBuffer, RecordBytes);
              End;
              If Nread < RecordBytes then Break;
              CASE ActiveCircuit[ActiveActor].Solution.DynaVars.SolutionMode of
                 HARMONICMODE: Time := hr;
               ELSE
                  If Hours Then Time := hr + s/3600.0 // in hrs
                           Else Time := hr * 3600.0 + s; // in sec
               END;
           Until (MonitorStream.Position>=MonitorStream.Size);

           CloseMonitorStream(ActiveActor);

           TopTransferFile.Close;
           TopTransferFile.SendToTop;
           Reallocmem(Vbuf,0);
           Reallocmem(Cbuf,0);
     End;

     End;
     
     ObjList.Free;
     NameList.Free;
     CNames.Free;

end;

function TMonitorObj.Get_FileName(ActorID : Integer): String;
begin
  if ConcatenateReports then
    Result := GetOutputDirectory +  CircuitName_[ActorID] + 'Mon_' + Name + '.csv'
  else
    Result := GetOutputDirectory +  CircuitName_[ActorID] + 'Mon_' + Name + '_' +inttostr(ActorID) + '.csv'
end;

end.
