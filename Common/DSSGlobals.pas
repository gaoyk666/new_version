unit DSSGlobals;
{
  ----------------------------------------------------------
  Copyright (c) 2008-2019, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{$HINTS OFF}

{ Change Log
 8-14-99  SolutionAbort Added

 10-12-99 AutoAdd constants added;
 4-17-00  Added IsShuntCapacitor routine, Updated constants
 10-08-02 Moved Control Panel Instantiation and show to here
 11-6-02  Removed load user DLL because it was causing a conflict
}

{$WARN UNIT_PLATFORM OFF}

interface

Uses Classes, DSSClassDefs, DSSObject, DSSClass, ParserDel, Hashlist, PointerList, PDELement,
     UComplex, Arraydef, CktElement, Circuit, IniRegSave, DynamicExp,
     {$IFNDEF FPC}
      System.IOUtils,
      {$IFNDEF CONSOLE}
        Graphics,
      {$ELSE}
        CmdForms,
      {$ENDIF}
     {$ENDIF} inifiles,

     {Some units which have global vars defined here}
     solution,
     Spectrum,
     LoadShape,
     TempShape,
     PriceShape,
     XYCurve,
     GrowthShape,
     Monitor,
     EnergyMeter,
     Sensor,
     TCC_Curve,
     Feeder,
     WireData,
     CNData,
     TSData,
     LineSpacing,
     Storage,
     PVSystem,
     InvControl,
     ExpControl,
     variants,
     {$IFNDEF FPC}
       ShellApi,
       {$IFNDEF CONSOLE}
         ProgressForm,
         vcl.dialogs,
         WinAPI.UrlMon,
       {$ELSE}
         UrlMon,
       {$ENDIF}
     {$ENDIF}
     Strutils,
     Types,
     SyncObjs,
     YMatrix,
     fMonitor,     // by Dahei
     VSource,
     Executive,
     ExecOptions,
//     Parallel_Lib
//   TCP Indy libraries
{$IFNDEF FPC}
     IdBaseComponent,
     IdComponent,
     IdTCPConnection,
     IdTCPClient,
     IdThreadComponent,
{$ENDIF}
     NumCPULib,
     Command,
     ISource;


CONST
      CRLF = sLineBreak; // cross-platform

      PI =  system.Pi;

      TwoPi = 2.0 * PI;

      RadiansToDegrees = 180.0 / PI;

      EPSILON = 1.0e-12;   // Default tiny floating point
      EPSILON2 = 1.0e-3;   // Default for Real number mismatch testing

      POWERFLOW  = 1;  // Load model types for solution
      ADMITTANCE = 2;

      // For YPrim matrices
      ALL_YPRIM = 0;
      SERIES = 1;
      SHUNT  = 2;

      {Control Modes}
      CONTROLSOFF = -1;
      EVENTDRIVEN =  1;
      TIMEDRIVEN  =  2;
      MULTIRATE   =  3;
      CTRLSTATIC  =  0;

      {Randomization Constants}
      GAUSSIAN  = 1;
      UNIFORM   = 2;
      LOGNORMAL = 3;

      {Autoadd Constants}
      GENADD = 1;
      CAPADD = 2;

      {ERRORS}
      SOLUTION_ABORT = 99;

      {For General Sequential Time Simulations}
      USEDAILY  = 0;
      USEYEARLY = 1;
      USEDUTY   = 2;
      USENONE   =-1;

      {Earth Model}
      SIMPLECARSON  = 1;
      FULLCARSON    = 2;
      DERI          = 3;

      {Profile Plot Constants}
      PROFILE3PH = 9999; // some big number > likely no. of phases
      PROFILEALL = 9998;
      PROFILEALLPRI = 9997;
      PROFILELLALL = 9996;
      PROFILELLPRI = 9995;
      PROFILELL    = 9994;
      PROFILEPUKM = 9993;  // not mutually exclusive to the other choices 9999..9994
      PROFILE120KFT = 9992;  // not mutually exclusive to the other choices 9999..9994

TYPE
  TProgressActor   =   class(TThread)     // Global actor for progress form
      Constructor Create();overload;
      procedure Execute; override;
      procedure Doterminate; override;
      destructor Destroy; override;

//*******************************Private components*****************************
    protected
      FMessage,
      Msg_Cmd       : string;
//*******************************Public components******************************
    Public

   end;

VAR
//   LibParallel    : TParallel_Lib;
   DLLFirstTime   :Boolean=TRUE;
   DLLDebugFile   :TextFile;
   ProgramName    :String;
   DSS_Registry   :TIniRegSave; // Registry   (See Executive)

   // Global variables for the OpenDSS Viewer
   DSS_Viz_installed   :Boolean=False; // OpenDSS viewer (flag to mark a local installation)
   DSS_Viz_path: String;
   DSS_Viz_enable: Boolean=False;

   // Global variables for OpenDSS-GIS
   DSS_GIS_installed   :Boolean=False; // OpenDSS-GIS (flag to mark a local installation)
   DSS_GIS_path: String;

   IsDLL,
   NoFormsAllowed  :Boolean;

   ActiveCircuit   :Array of TDSSCircuit;
   ActiveDSSClass  :Array of TDSSClass;
   LastClassReferenced:Array of Integer;  // index of class of last thing edited
   ActiveDSSObject :Array of TDSSObject;
   NumCircuits     :Integer;
   MaxCircuits     :Integer;
   MaxBusLimit     :Integer; // Set in Validation
   MaxAllocationIterations :Integer;
   Circuits        :TPointerList;
   DSSObjs         :Array of TPointerList;

   AuxParser       :Array of TParser;  // Auxiliary parser for use by anybody for reparsing values

//{****} DebugTrace:TextFile;


   ErrorPending       :Boolean;
   CmdResult,
   ErrorNumber        :Integer;
   LastErrorMessage   :String;

   DefaultEarthModel  :Integer;
   ActiveEarthModel   :Array of Integer;

   LastFileCompiled   :String;
   LastCommandWasCompile :Boolean;

   CALPHA             :Complex;  {120-degree shift constant}
   SQRT2              :Double;
   SQRT3              :Double;
   InvSQRT3           :Double;
   InvSQRT3x1000      :Double;
   SolutionAbort      :Boolean;
   InShowResults      :Boolean;
   Redirect_Abort     :Boolean;
   In_Redirect        :Boolean;
   DIFilesAreOpen     :array of Boolean;
   AutoShowExport     :Boolean;
   AutoDisplayShowReport     :Boolean;
   EventLogDefault    :Boolean;
   SolutionWasAttempted : Array of Boolean;

   GlobalHelpString   :String;
   GlobalPropertyValue:String;
   GlobalResult       :String;
   LastResultFile     :String;
   VersionString      :String;

   LogQueries         :Boolean;
   QueryFirstTime     :Boolean;
   QueryLogFileName   :String;
   QueryLogFile       :TextFile;

   DefaultEditor    :String;     // normally, Notepad
   DefaultFontSize  :Integer;
   DefaultFontName  :String;
   DefaultFontStyles :{$IFNDEF FPC}{$IFNDEF CONSOLE}TFontStyles{$ELSE}Integer{$ENDIF}{$ELSE}Integer{$ENDIF};
   DSSFileName      :String;     // Name of current exe or DLL
   DSSDirectory     :String;     // where the current exe resides
   StartupDirectory :String;     // Where we started
   DataDirectory    :array of String;     // used to be DSSDataDirectory
   OutputDirectory  :array of String;     // output files go here, same as DataDirectory if writable
   CircuitName_     :array of String;     // Name of Circuit with a "_" appended
   ActiveYPrim      :Array of pComplexArray; // Created to solve the problems

   DefaultBaseFreq  :Double;
   DaisySize        :Double;

   // Some commonly used classes   so we can find them easily
   LoadShapeClass     :Array of TLoadShape;
   TShapeClass        :Array of TTshape;
   PriceShapeClass    :Array of TPriceShape;
   XYCurveClass       :Array of TXYCurve;
   GrowthShapeClass   :Array of TGrowthShape;
   SpectrumClass      :Array of TSpectrum;
   SolutionClass      :Array of TDSSClass;
   EnergyMeterClass   :Array of TEnergyMeter;
   FMonitorClass      :Array of TDSSFMonitor;      // By dahei UCF
   TDynamicExpClass   :Array of TDynamicExp;
   // FeederClass        :TFeeder;
   MonitorClass       :Array of TDSSMonitor;
   SensorClass        :Array of TSensor;
   TCC_CurveClass     :Array of TTCC_Curve;
   WireDataClass      :Array of TWireData;
   CNDataClass        :Array of TCNData;
   TSDataClass        :Array of TTSData;
   LineSpacingClass   :Array of TLineSpacing;
   StorageClass       :Array of TStorage;
   PVSystemClass      :Array of TPVSystem;
   InvControlClass    :Array of TInvControl;
   ExpControlClass    :Array of TExpControl;
   ActiveVSource      :Array of TVsource;   // created on 01/14/2019 to facilitate actors to modify VSources while simulating

   EventStrings       :Array of TStringList;
   SavedFileList      :Array of TStringList;
   ErrorStrings       :Array of TStringList;

   DSSClassList       :Array of TPointerList; // pointers to the base class types
   ClassNames         :Array of THashList;

   UpdateRegistry     :Boolean;  // update on program exit
   CPU_Freq           : int64;          // Used to store the CPU frequency
   CPU_Cores          : int32;
   NumNUMA            : integer;        // To store the number of NUMA nodes (should be the same as sockets)
   CPU_Physical       : int32;
   ActiveActor        : integer;
   NumOfActors        : integer;
   ActorCPU           : Array of integer;
   ActorStatus        : Array of integer;
   ActorProgressCount : Array of integer;
   {$IFNDEF FPC}
   {$IFNDEF CONSOLE}
   ActorProgress      : Array of TProgress;
   {$ENDIF}
   {$ENDIF}
   ActorPctProgress   : Array of integer;
   ActorHandle        : Array of TSolver;

//***********************A-Diakoptics suite globals*****************************

   AllActors,
   ADiakoptics,
   ADiak_Init,
   ADiak_PCInj,
   UseUserLinks,   // To indicate if the tearing process will take place using the link branches given by the user
   Parallel_enabled,
   ConcatenateReports,

   ProgressCmd,
   IncMat_Ordered     : Boolean;
   Parser             : Array of TParser;
   ActorMA_Msg        : Array of TEvent;  // Array to handle the events of each actor

   // Default ports
   DSSPrgPort,
   DSSGISPort         : Integer;


{*******************************************************************************
*    Nomenclature:                                                             *
*                  OV_ Overloads                                               *
*                  VR_ Voltage report                                          *
*                  DI_ Demand interval for each meter. Moved to EnergyMeter.pas*
*                  SDI_ System Demand interval                                 *
*                  TDI_ DI Totals                                              *
*                  FM_  Meter Totals                                           *
*                  SM_  System Meter                                           *
*                  EMT_  Energy Meter Totals                                   *
*                  PHV_  Phase Voltage Report. Moved to EnergyMeter.pas        *
*     These prefixes are applied to the variables of each file mapped into     *
*     Memory using the MemoryMap_Lib                                           *
********************************************************************************
}
   OV_MHandle             : array of TBytesStream;  // a. Handle to the file in memory
   VR_MHandle             : array of TBytesStream;
   SDI_MHandle            : array of TBytesStream;
   TDI_MHandle            : array of TBytesStream;
   SM_MHandle             : array of TBytesStream;
   EMT_MHandle            : array of TBytesStream;
   FM_MHandle             : array of TBytesStream;

//*********** Flags for appending Files*****************************************
   OV_Append              : array of Boolean;
   VR_Append              : array of Boolean;
   DI_Append              : array of Boolean;
   SDI_Append             : array of Boolean;
   TDI_Append             : array of Boolean;
   SM_Append              : array of Boolean;
   EMT_Append             : array of Boolean;
   PHV_Append             : array of Boolean;
   FM_Append              : array of Boolean;

//***********************Seasonal QSTS variables********************************
   SeasonalRating         : Boolean;    // Tells the energy meter if the seasonal rating feature is active
   SeasonSignal           : String;     // Stores the name of the signal for selecting the rating dynamically

   DSSExecutive: Array of TExecutive;

   DSSClasses             : TDSSClasses;

   IsourceClass           : array of TISource;
   VSourceClass           : array of TVsource;

//************************ Progress actor Global defs***************************
  DSSProgressFrm,
  IsProgressON            : Boolean;
  Progress_Actor          : TProgressActor;
  DSSProgressPath         : String;

//************************ OpenDSS-GIS Global defs***************************
  IsGISON                 : Boolean;
  GISThickness,
  GISColor                : String;
  GISCoords               : pDoubleArray;



//************************ Line related Global defs***************************
  LineTypeList            : TCommandList;

//********************* Globals for DirectDLL Interface ***********************

  myStrArray  : Array of Byte;
  myDBLArray  : Array of double;
  myCmplxArray: Array of Complex;
  myPolarArray: Array of Polar;
  myIntArray  : Array of integer;

procedure WriteStr2Array(myStr  : string);
Function BArray2Str(myPtr: Pointer; var idx: integer): String;

//*****************************************************************************

PROCEDURE DoErrorMsg(Const S, Emsg, ProbCause :String; ErrNum:Integer);
PROCEDURE DoSimpleMsg(Const S :String; ErrNum:Integer);
PROCEDURE DoThreadSafeMsg(Const S :String; ErrNum:Integer);

PROCEDURE ClearAllCircuits;

PROCEDURE SetObject(const param :string);
FUNCTION  SetActiveBus(const BusName:String):Integer;
PROCEDURE SetDataPath(const PathName:String);

PROCEDURE SetLastResultFile(Const Fname:String);

PROCEDURE MakeNewCircuit(Const Name:String);

PROCEDURE AppendGlobalResult(Const s:String);
PROCEDURE AppendGlobalResultCRLF(const S:String);  // Separate by CRLF

PROCEDURE ResetQueryLogFile;
PROCEDURE WriteQueryLogFile(Const Prop, S:String);

PROCEDURE WriteDLLDebugFile(Const S:String);

PROCEDURE ReadDSS_Registry;
PROCEDURE WriteDSS_Registry;

FUNCTION IsDSSDLL(Fname:String):Boolean;

Function GetOutputDirectory:String;

Procedure MyReallocMem(Var p:Pointer; newsize:integer);
Function MyAllocMem(nbytes:Cardinal):Pointer;

procedure New_Actor_Slot();
procedure New_Actor(ActorID:  Integer);
procedure Wait4Actors(WType : Integer);

procedure DoClone();

procedure Delay(TickTime : Integer);

procedure GetDefaultPorts();
procedure Show_COM_Help();

Function Check_DSS_WebVersion(myDialog: boolean):String;

Function GetLineTypes(): String;




implementation



USES  {Forms,   Controls,}

     {$IFNDEF FPC}
     Windows,
     {$IFDEF MSWINDOWS}
     SHFolder,
     {$ENDIF}
     {$IFNDEF CONSOLE}
     ScriptEdit,
     DSSForms,
     {$ENDIF}
     {$ELSE}
     resource, versiontypes, versionresource, dynlibs, CMDForms,
     {$ENDIF}
     {$IFDEF UNIX}
     BaseUnix,
     {$ENDIF}
     djson,
     SysUtils, 
     ExceptionTrace;
     {Intrinsic Ckt Elements}

TYPE

   THandle = Integer;

   TDSSRegister = function(var ClassName: pchar):Integer;  // Returns base class 1 or 2 are defined
   // Users can only define circuit elements at present

VAR

   LastUserDLLHandle: THandle;
   DSSRegisterProc:TDSSRegister;        // of last library loaded
{$IFNDEF FPC}
   idTCPClient         : TIdTCPClient;  // ... TIdThreadComponent
   idThreadComponent   : TIdThreadComponent;
{$ENDIF}
{$IFDEF FPC}
FUNCTION GetDefaultDataDirectory: String;
Begin
{$IFDEF UNIX}
  Result := GetEnvironmentVariable('HOME') + '/Documents';
{$ENDIF}
{$IF (defined(Windows) or defined(MSWindows))}
  Result := GetEnvironmentVariable('HOMEDRIVE') + GetEnvironmentVariable('HOMEPATH') + '\Documents';
{$ENDIF}
end;

FUNCTION GetDefaultScratchDirectory: String;
Begin
  {$IFDEF UNIX}
  Result := '/tmp';
  {$ENDIF}
  {$IF (defined(Windows) or defined(MSWindows))}
  Result := GetEnvironmentVariable('LOCALAPPDATA');
  {$ENDIF}
End;
{$ELSE}
FUNCTION GetDefaultDataDirectory: String;
Var
  ThePath:Array[0..MAX_PATH] of char;
Begin
  FillChar(ThePath, SizeOF(ThePath), #0);
  {$IFDEF MSWINDOWS}
  SHGetFolderPath (0, CSIDL_PERSONAL, 0, 0, ThePath);
  {$ENDIF}
  Result := ThePath;
End;

FUNCTION GetDefaultScratchDirectory: String;
Var
  ThePath:Array[0..MAX_PATH] of char;
Begin
  FillChar(ThePath, SizeOF(ThePath), #0);
  {$IFDEF MSWINDOWS}
  SHGetFolderPath (0, CSIDL_LOCAL_APPDATA, 0, 0, ThePath);
  {$ENDIF}
  Result := ThePath;
End;
{$ENDIF}

function GetOutputDirectory:String;
begin
  Result := OutputDirectory[ActiveActor];
end;

{--------------------------------------------------------------}
FUNCTION IsDSSDLL(Fname:String):Boolean;

Begin
    Result := FALSE;

    // Ignore if "DSSLIB.DLL"
    If CompareText(ExtractFileName(Fname),'dsslib.dll')=0 Then Exit;

   LastUserDLLHandle := LoadLibrary(pchar(Fname));
   IF LastUserDLLHandle <> 0 then BEGIN

   // Assign the address of the DSSRegister proc to DSSRegisterProc variable
    @DSSRegisterProc := GetProcAddress(LastUserDLLHandle, 'DSSRegister');
    IF @DSSRegisterProc <> nil THEN Result := TRUE
    ELSE FreeLibrary(LastUserDLLHandle);

  END;

End;

//----------------------------------------------------------------------------
PROCEDURE DoErrorMsg(Const S, Emsg, ProbCause:String; ErrNum:Integer);

VAR
    Msg:String;
    Retval:Integer;
Begin

     Msg := Format('Error %d Reported From OpenDSS Intrinsic Function: ', [Errnum])+ CRLF  + S
             + CRLF   + CRLF + 'Error Description: ' + CRLF + Emsg
             + CRLF   + CRLF + 'Probable Cause: ' + CRLF+ ProbCause;

     If Not NoFormsAllowed Then Begin

         If In_Redirect Then
         Begin
           RetVal := DSSMessageDlg(Msg, FALSE);
           If RetVal = -1 Then Redirect_Abort := True;
         End
         Else
           DSSMessageDlg(Msg, TRUE);

     End;

     LastErrorMessage := Msg;
     ErrorNumber := ErrNum;
     AppendGlobalResultCRLF(Msg);
     SolutionAbort  :=  True;
End;

//----------------------------------------------------------------------------
PROCEDURE AppendGlobalResultCRLF(const S:String);

Begin
    If Length(GlobalResult) > 0
    THEN GlobalResult := GlobalResult + CRLF + S
    ELSE GlobalResult := S;

    ErrorStrings[ActiveActor].Add(Format('(%d) %s' ,[ErrorNumber, S]));  // Add to Error log
End;

//----------------------------------------------------------------------------
PROCEDURE DoSimpleMsg(Const S:String; ErrNum:Integer);

VAR
    Retval:Integer;
Begin

      IF Not NoFormsAllowed Then Begin
       IF   In_Redirect
       THEN Begin
         RetVal := DSSMessageDlg(Format('(%d) OpenDSS %s%s', [Errnum, CRLF, S]), FALSE);
         IF   RetVal = -1
         THEN Redirect_Abort := True;
       End
       ELSE
         DSSInfoMessageDlg(Format('(%d) OpenDSS %s%s', [Errnum, CRLF, S]));
      End;

     LastErrorMessage := S;
     ErrorNumber := ErrNum;
     AppendGlobalResultCRLF(S);
End;

//----------------------------------------------------------------------------
PROCEDURE DoThreadSafeMsg(Const S :String; ErrNum:Integer);
// generates a dialog window thread safe using windows API
VAR
    Retval:Integer;
Begin
{$IFDEF FPC}
     DSSMessageDlg (Format('(%d) OpenDSS %s', [Errnum, S]), True);
{$ELSE}
      IF Not NoFormsAllowed Then Begin
       IF   In_Redirect
       THEN Begin
         RetVal := Windows.MessageBox(0,pChar(Format('(%d) OpenDSS %s%s', [Errnum, CRLF, S])), 'Error', MB_ABORTRETRYIGNORE);
         IF   RetVal = 3
         THEN Redirect_Abort := True;
       End
       ELSE
         Windows.MessageBox(0, PChar(Format('(%d) OpenDSS %s%s', [Errnum, CRLF, S])), 'Warning', MB_OK);
      End;
{$ENDIF}
     LastErrorMessage := S;
     ErrorNumber := ErrNum;
     AppendGlobalResultCRLF(S);
End;
//----------------------------------------------------------------------------
PROCEDURE SetObject(const param :string);

{Set object active by name}

VAR
   dotpos :Integer;
   ObjName, ObjClass :String;

Begin

      // Split off Obj class and name
      dotpos := Pos('.', Param);
      CASE dotpos OF
         0:ObjName := Copy(Param, 1, Length(Param));  // assume it is all name; class defaults
      ELSE Begin
           ObjClass := Copy(Param, 1, dotpos-1);
           ObjName  := Copy(Param, dotpos+1, Length(Param));
           End;
      End;

      IF Length(ObjClass) > 0 THEN SetObjectClass(ObjClass);

      ActiveDSSClass[ActiveActor] := DSSClassList[ActiveActor].Get(LastClassReferenced[ActiveActor]);
      IF ActiveDSSClass[ActiveActor] <> Nil THEN
      Begin
        IF Not ActiveDSSClass[ActiveActor].SetActive(Objname) THEN
        Begin // scroll through list of objects untill a match
          DoSimpleMsg('Error! Object "' + ObjName + '" not found.'+ CRLF + parser[ActiveActor].CmdString, 904);
        End
        ELSE
        With ActiveCircuit[ActiveActor] Do
        Begin
           CASE ActiveDSSObject[ActiveActor].DSSObjType OF
                DSS_OBJECT: ;  // do nothing for general DSS object

           ELSE Begin   // for circuit types, set ActiveCircuit Element, too
                 ActiveCktElement := ActiveDSSClass[ActiveActor].GetActiveObj;
                End;
           End;
        End;
      End
      ELSE
        DoSimpleMsg('Error! Active object type/class is not set.', 905);

End;

//----------------------------------------------------------------------------
FUNCTION SetActiveBus(const BusName:String):Integer;


Begin

   // Now find the bus and set active
   Result := 0;

   WITH ActiveCircuit[ActiveActor] Do
     Begin
        If BusList.ListSize=0 Then Exit;   // Buslist not yet built
        ActiveBusIndex := BusList.Find(BusName);
        IF   ActiveBusIndex=0 Then
          Begin
            Result := 1;
            AppendGlobalResult('SetActiveBus: Bus ' + BusName + ' Not Found.');
          End;
     End;

End;

PROCEDURE ClearAllCircuits;
var
  I : integer;
Begin

    for I := 1 to NumOfActors do
    begin
      if ActiveCircuit[I] <> nil then
      begin
        ActiveActor   :=  I;
        ActiveCircuit[I].NumCircuits := 0;
        FreeAndNil(ActiveCircuit[I]);

        // In case the actor hasn't been destroyed
        if ActorHandle[I] <> nil then
        Begin
          ActorHandle[I].Send_Message(EXIT_ACTOR);
          ActorHandle[I].WaitFor;
          FreeAndNil(ActorHandle[I]);
        End;
      end;
    end;
    FreeAndNil (Circuits);
    Circuits              := TPointerList.Create(2);   // Make a new list of circuits
    // Revert on key global flags to Original States
    DefaultEarthModel     := DERI;
    LogQueries            := FALSE;
    MaxAllocationIterations := 2;
    ActiveActor           :=  1;
End;



PROCEDURE MakeNewCircuit(Const Name:String);

//Var
//   handle :Integer;
Var
    S:String;

Begin

    if ActiveActor <= CPU_Cores then
    begin
       If ActiveCircuit[ActiveActor] = nil Then
       Begin
           ActiveCircuit[ActiveActor]   := TDSSCircuit.Create(Name);
           ActiveDSSObject[ActiveActor] := ActiveSolutionObj;
           {*Handle := *}
           Circuits.Add(ActiveCircuit[ActiveActor]);
           Inc(ActiveCircuit[ActiveActor].NumCircuits);
           S                          := Parser[ActiveActor].Remainder;    // Pass remainder of string on to vsource.
           {Create a default Circuit}
           SolutionABort              := FALSE;
           {Voltage source named "source" connected to SourceBus}
           DSSExecutive[ActiveActor].Command       := 'New object=vsource.source Bus1=SourceBus ' + S;  // Load up the parser as if it were read in
           // Creates the thread for the actor if not created before
           If ActorHandle[ActiveActor]  = nil then New_Actor(ActiveActor);


       End
       Else
       Begin
           DoErrorMsg('MakeNewCircuit',
                      'Cannot create new circuit.',
                      'Max. Circuits Exceeded.'+CRLF+
                      '(Max no. of circuits='+inttostr(Maxcircuits)+')', 906);
       End;
    end
    else
    begin
           DoErrorMsg('MakeNewCircuit',
                      'Cannot create new circuit.',
                      'All the available CPUs have being assigned', 7000);

    end;
End;


PROCEDURE AppendGlobalResult(Const S:String);

// Append a string to Global result, separated by commas

Begin
    If Length(GlobalResult)=0 Then
        GlobalResult := S
    Else
        GlobalResult := GlobalResult + ', ' + S;
End;


{$IFDEF FPC}
FUNCTION GetDSSVersion: String;
BEGIN
  RESULT:= VersionStringFpc;
End;
{$ELSE}
FUNCTION GetDSSVersion: String;
var
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  FI: PVSFixedFileInfo;
  VerSize: DWORD;
  MajorVer, MinorVer, BuildNo, RelNo :DWORD;
  iLastError: DWord;
Begin
    Result := 'Unknown.' ;
    {$IFDEF MSWINDOWS}
    InfoSize := GetFileVersionInfoSize(PChar(DSSFileName), Wnd);
    if InfoSize <> 0 then
    begin
      GetMem(VerBuf, InfoSize);
      try
        if GetFileVersionInfo(PChar(DSSFileName), Wnd, InfoSize, VerBuf) then
          if VerQueryValue(VerBuf, '\', Pointer(FI), VerSize) then  Begin
            MinorVer := FI.dwFileVersionMS and $FFFF;
            MajorVer := (FI.dwFileVersionMS and $FFFF0000) shr 16;
            BuildNo :=  FI.dwFileVersionLS and $FFFF;
            RelNo := (FI.dwFileVersionLS and $FFFF0000) shr 16;
            Result := Format('%d.%d.%d.%d',[MajorVer, MinorVer, RelNo, BuildNo]);
            End;
      finally
        FreeMem(VerBuf);
      end;
    end
    else
    begin
      iLastError := GetLastError;
      Result := Format('GetFileVersionInfo failed: (%d) %s',
               [iLastError, SysErrorMessage(iLastError)]);
    end;
    {$ELSE}
      // Adds the version info as a constant (for now)
      Result := '9.4.0.2';
    {$ENDIF}
End;
{$ENDIF}

PROCEDURE WriteDLLDebugFile(Const S:String);

Begin

        AssignFile(DLLDebugFile, OutputDirectory[ActiveActor] + 'DSSDLLDebug.TXT');
        If DLLFirstTime then Begin
           Rewrite(DLLDebugFile);
           DLLFirstTime := False;
        end
        Else Append( DLLDebugFile);
        Writeln(DLLDebugFile, S);
        CloseFile(DLLDebugFile);

End;

{$IFDEF UNIX}
function IsDirectoryWritable(const Dir: String): Boolean;
begin
  Result := (FpAccess(PChar(Dir), X_OK or W_OK) = 0);
end;
{$ELSE}
function IsDirectoryWritable(const Dir: String): Boolean;
var
  TempFile: array[0..MAX_PATH] of Char;
begin
  if GetTempFileName(PChar(Dir), 'DA', 0, TempFile) <> 0 then
    {$IFDEF FPC}Result := DeleteFile(TempFile){$ELSE}
      {$IFDEF MSWINDOWS}
      Result := Windows.DeleteFile(TempFile)
      {$ENDIF}
    {$ENDIF}
  else
    Result := False;
end;
{$ENDIF}

PROCEDURE SetDataPath(const PathName:String);
var
  ScratchPath: String;
// Pathname may be null
BEGIN
  if (Length(PathName) > 0) and not DirectoryExists(PathName) then Begin
  // Try to create the directory
    if not CreateDir(PathName) then Begin
      DosimpleMsg('Cannot create ' + PathName + ' directory.', 907);
      Exit;
    End;
  End;

  DataDirectory[ActiveActor] := PathName;

  // Put a \ on the end if not supplied. Allow a null specification.
  If Length(DataDirectory[ActiveActor]) > 0 Then Begin
    ChDir(DataDirectory[ActiveActor]);   // Change to specified directory
    {$IF (defined(Windows) or defined(MSWindows))}
    If DataDirectory[ActiveActor][Length(DataDirectory[ActiveActor])] <> '\' Then DataDirectory[ActiveActor] := DataDirectory[ActiveActor] + '\';
    {$ENDIF}
    {$IFDEF UNIX}
    If DataDirectory[ActiveActor][Length(DataDirectory[ActiveActor])] <> '/' Then DataDirectory[ActiveActor] := DataDirectory[ActiveActor] + '/';
    {$ENDIF}
  End;

  // see if DataDirectory is writable. If not, set OutputDirectory to the user's appdata
  if IsDirectoryWritable(DataDirectory[ActiveActor]) then begin
    OutputDirectory[ActiveActor] := DataDirectory[ActiveActor];
  end else begin
    {$IF (defined(Windows) or defined(MSWindows))}
    ScratchPath := GetDefaultScratchDirectory + '\' + ProgramName + '\';
    {$ENDIF}
    {$IFDEF UNIX}
    ScratchPath := GetDefaultScratchDirectory + '/' + ProgramName + '/';
    {$ENDIF}
    if not DirectoryExists(ScratchPath) then CreateDir(ScratchPath);
    OutputDirectory[ActiveActor] := ScratchPath;
  end;
END;

PROCEDURE ReadDSS_Registry;
Var  TestDataDirectory:string;
Begin
  DSS_Registry.Section := 'MainSect';
  {$IFDEF Darwin}
     DefaultEditor    := DSS_Registry.ReadString('Editor', 'open -t');
     DefaultFontSize  := StrToInt(DSS_Registry.ReadString('ScriptFontSize', '12'));
     DefaultFontName  := DSS_Registry.ReadString('ScriptFontName', 'Geneva');
  {$ENDIF}
  {$IFDEF Linux}
     DefaultEditor    := DSS_Registry.ReadString('Editor', 'xdg-open');
     DefaultFontSize  := StrToInt(DSS_Registry.ReadString('ScriptFontSize', '10'));
     DefaultFontName  := DSS_Registry.ReadString('ScriptFontName', 'Arial');
  {$ENDIF}
  {$IF (defined(Windows) or defined(MSWindows))}
     DefaultEditor    := DSS_Registry.ReadString('Editor', 'Notepad.exe' );
     DefaultFontSize  := StrToInt(DSS_Registry.ReadString('ScriptFontSize', '8' ));
     DefaultFontName  := DSS_Registry.ReadString('ScriptFontName', 'MS Sans Serif' );
  {$ENDIF}
  {$IFDEF FPC}
     DefaultFontStyles := 1;
  {$ELSE}
  {$IFDEF CONSOLE}
     DefaultFontStyles := 1;
  {$ELSE}
     DefaultFontStyles := [];
     If DSS_Registry.ReadBool('ScriptFontBold', TRUE)    Then DefaultFontStyles := DefaultFontStyles + [fsbold];
     If DSS_Registry.ReadBool('ScriptFontItalic', FALSE) Then DefaultFontStyles := DefaultFontStyles + [fsItalic];
  {$ENDIF}
  {$ENDIF}
  DefaultBaseFreq  := StrToInt(DSS_Registry.ReadString('BaseFrequency', '60' ));
  LastFileCompiled := DSS_Registry.ReadString('LastFile', '' );
  TestDataDirectory :=   DSS_Registry.ReadString('DataPath', DataDirectory[ActiveActor]);
  If SysUtils.DirectoryExists (TestDataDirectory) Then SetDataPath (TestDataDirectory)
                                        Else SetDataPath (DataDirectory[ActiveActor]);
End;


PROCEDURE WriteDSS_Registry;
Begin
  If UpdateRegistry and Assigned(DSS_Registry) Then  Begin
      DSS_Registry.Section := 'MainSect';
      DSS_Registry.WriteString('Editor',        DefaultEditor);
      DSS_Registry.WriteString('ScriptFontSize', Format('%d',[DefaultFontSize]));
      DSS_Registry.WriteString('ScriptFontName', Format('%s',[DefaultFontName]));
      DSS_Registry.WriteBool('ScriptFontBold', {$IFDEF FPC}False{$ELSE}{$IFDEF CONSOLE}False{$ELSE}(fsBold in DefaultFontStyles){$ENDIF}{$ENDIF});
      DSS_Registry.WriteBool('ScriptFontItalic', {$IFDEF FPC}False{$ELSE}{$IFDEF CONSOLE}False{$ELSE}(fsItalic in DefaultFontStyles){$ENDIF}{$ENDIF});
      DSS_Registry.WriteString('BaseFrequency', Format('%d',[Round(DefaultBaseFreq)]));
      DSS_Registry.WriteString('LastFile',      LastFileCompiled);
      DSS_Registry.WriteString('DataPath', DataDirectory[ActiveActor]);
  End;
End;

PROCEDURE ResetQueryLogFile;
Begin
     QueryFirstTime := TRUE;
End;


PROCEDURE WriteQueryLogfile(Const Prop, S:String);

{Log file is written after a query command if LogQueries is true.}

Begin

  TRY
        QueryLogFileName :=  OutputDirectory[ActiveActor] + 'QueryLog.CSV';
        AssignFile(QueryLogFile, QueryLogFileName);
        If QueryFirstTime then
        Begin
             Rewrite(QueryLogFile);  // clear the file
             Writeln(QueryLogFile, 'Time(h), Property, Result');
             QueryFirstTime := False;
        end
        Else Append( QueryLogFile);

        Writeln(QueryLogFile,Format('%.10g, %s, %s',[ActiveCircuit[ActiveActor].Solution.DynaVars.dblHour, Prop, S]));
        CloseFile(QueryLogFile);
  EXCEPT
        On E:Exception Do DoSimpleMsg('Error writing Query Log file: ' + E.Message, 908);
  END;

End;

PROCEDURE SetLastResultFile(Const Fname:String);

Begin
      LastResultfile := Fname;
      ParserVars.Add('@lastfile', Fname);
End;

Function MyAllocMem(nbytes:Cardinal):Pointer;
Begin
    Result := AllocMem(Nbytes);
    WriteDLLDebugFile(Format('Allocating %d bytes @ %p',[nbytes, Result]));
End;

Procedure MyReallocMem(Var p:Pointer; newsize:Integer);

Begin
     WriteDLLDebugFile(Format('Reallocating @ %p, new size= %d', [p, newsize]));
     ReallocMem(p, newsize);
End;

// Function to validate the installation and path of the OpenDSS Viewer
function GetIni(s,k: string; d: string; f: string=''): string; overload;
var
  ini: TMemIniFile;
begin
  Result := d;
  if f = '' then
  begin
    ini := TMemIniFile.Create(lowercase(ChangeFileExt(ParamStr(0),'.ini')));
  end
  else
  begin
    if not FileExists(f) then Exit;
    ini := TMemIniFile.Create(f);
  end;
  if ini.ReadString(s,k,'') = '' then
  begin
    ini.WriteString(s,k,d);
    ini.UpdateFile;
  end;
  Result := ini.ReadString(s,k,d);
  FreeAndNil(ini);
end;

//***********************DirectDLL interfacing globals**************************

procedure WriteStr2Array(myStr  : string);
var
  i : Integer;
Begin
// Writes the given string into an array of Bytes char by char
  for i := 1 to High(myStr) do
  Begin
    setlength(myStrArray, Length(myStrArray) + 1);
    myStrArray[High(myStrArray)]  :=  Byte(myStr[i]);
  End;
End;

Function BArray2Str(myPtr: Pointer; var idx: integer): String;
  var
    S     : String;
    PChar : ^Byte;
Begin
// Returns the first string found in the pointed Byte array (until a NULL char is found)
  Result  :=  '';
  S := '';
  pChar   :=  myPtr;
  inc(PByte(pChar), idx);
  while pChar^ <> 0 do
  Begin
    S     :=  S + Char(pChar^);
    inc(PByte(pChar),1);
    inc(idx);
  End;
  inc(idx);
  Result  :=  S;
End;

//******************************************************************************

// Waits for all the actors running tasks
procedure Wait4Actors(WType : Integer);
var
  i       : Integer;
  Flag    : Boolean;

Begin
// WType defines the starting point in which the actors will be evaluated,
// modification introduced in 01-10-2019 to facilitate the coordination
// between actors when a simulation is performed using A-Diakoptics
  for i := (WType +1) to NumOfActors do
  Begin
    Try
      while ActorStatus[i] = 0 do
      Begin
        Flag  :=  true;
//        while Flag do
//          Flag  := ActorMA_Msg[i].WaitFor(1) = TWaitResult.wrTimeout;
      End;
    Except
      On EOutOfMemory Do
          Dosimplemsg('Exception Waiting for the parallel thread to finish a job"', 7006);
    End;
  End;
end;

// Clones the active Circuit as many times as requested if possible
procedure DoClone();
var
  i,
  NumClones   : Integer;
  Ref_Ckt     : String;
Begin
    Ref_Ckt             := LastFileCompiled;
    Parser[ActiveActor].NextParam;
    NumClones           := Parser[ActiveActor].IntValue;
    Parallel_enabled    := False;
    if ((NumOfActors + NumClones) <= CPU_Cores) and (NumClones > 0) then
    Begin
      for i := 1 to NumClones do
      Begin
        New_Actor_Slot;
        DSSExecutive[ActiveActor].Command          :=  'compile "' + Ref_Ckt + '"';
        // sets the previous maxiterations and controliterations
        ActiveCircuit[ActiveActor].solution.MaxIterations         :=  ActiveCircuit[1].solution.MaxIterations;
        ActiveCircuit[ActiveACtor].solution.MaxControlIterations  :=  ActiveCircuit[1].solution.MaxControlIterations;
        // Solves the circuit
        CmdResult   :=  ExecOptions.DoSetCmd(1);
      End;

    End
    else
    Begin
      if NumClones > 0 then
        DoSimpleMsg('There are no more CPUs available', 7001)
      else
        DoSimpleMsg('The number of clones requested is invalid', 7004)
    End;
End;

// Prepares memory to host a new actor
procedure New_Actor_Slot();
Begin
  if NumOfActors < CPU_Cores then
  begin
    inc(NumOfActors);
    GlobalResult              :=  inttostr(NumOfActors);
    ActiveActor               :=  NumOfActors;
    ActorCPU[ActiveActor]     :=  -1;       // By default, the actor will have affinity to all processors (-1)
    DSSExecutive[ActiveActor] :=  TExecutive.Create;  // Make a DSS object
    Parser[ActiveActor]       :=  TParser.Create;
    AuxParser[ActiveActor]    :=  TParser.Create;
    DSSExecutive[ActiveActor].CreateDefaultDSSItems;
  end
  else DoSimpleMsg('There are no more CPUs available', 7001)
End;

// Creates a new actor
procedure New_Actor(ActorID:  Integer);
{$IFDEF FPC}
Begin
 ActorHandle[ActorID] :=  TSolver.Create(True,ActorCPU[ActorID],ActorID,nil,ActorMA_Msg[ActorID]); // TEMC: TODO: text-mode callback
 ActorHandle[ActorID].Priority :=  tpTimeCritical;
 ActorHandle[ActorID].Start; // Resume;
 ActorStatus[ActorID] :=  1;
End;
{$ELSE}
{$IFDEF CONSOLE}
Begin
 ActorHandle[ActorID] :=  TSolver.Create(True,ActorCPU[ActorID],ActorID,nil,ActorMA_Msg[ActorID]); // TEMC: TODO: text-mode callback
 ActorHandle[ActorID].Priority :=  tpTimeCritical;
 ActorHandle[ActorID].Resume;  // TEMC: TODO: this reportedly does nothing on Unix and Mac
 ActorStatus[ActorID] :=  1;
End;
{$ELSE}
var
 ScriptEd    : TScriptEdit;
Begin
 ScriptEd := TScriptEdit.Create;
 ActorHandle[ActorID] :=  TSolver.Create(True,ActorCPU[ActorID],ActorID,ScriptEd.UpdateSummaryform,ActorMA_Msg[ActorID]);
 ActorHandle[ActorID].Priority  :=  {$IFDEF MSWINDOWS}tptimecritical{$ELSE}6{$ENDIF};
 ActorHandle[ActorID].Start; // Resume;
 ActorStatus[ActorID] :=  1;
 FreeAndNil (ScriptEd);
End;
{$ENDIF}
{$ENDIF}

{$IFNDEF FPC}
// Validates the installation and path of the OpenDSS Viewer
function CheckOpenDSSViewer(App_Folder :  string): Boolean;
var FileName: string;
begin
  // to make it compatible with the function
  App_Folder    :=  LowerCase(App_Folder);

  // Stores the
  if App_Folder = 'opendss_viewer' then
  Begin
    DSS_Viz_path:=GetIni('Application','path','', TPath.GetHomePath+'\' + App_Folder + '\settings.ini');
    FileName  :=  stringreplace(DSS_Viz_path, '\\' ,'\',[rfReplaceAll, rfIgnoreCase])
  End
  else
  Begin
    DSS_GIS_path:=GetIni('Application','path','', TPath.GetHomePath+'\' + App_Folder + '\settings.ini');
    FileName  :=  stringreplace(DSS_GIS_path, '\\' ,'\',[rfReplaceAll, rfIgnoreCase]);
  End;

  FileName  :=  stringreplace(FileName, '"' ,'',[rfReplaceAll, rfIgnoreCase]);
  // returns true only if the executable exists
  Result:=fileexists(FileName);
end;
{$ENDIF}

//{$IFDEF MSWINDOWS}
procedure Delay(TickTime : Integer);
 var
 Past: longword;
 begin
 Past := GetTickCount64;
 repeat

 Until (GetTickCount64 - Past) >= longint(TickTime);
end;
//{$ENDIF}

//*********Downloads a file from the internet into the folder specified*********
function DownLoadInternetFile(Source, Dest : String): Boolean;
begin
{$IFNDEF FPC}
  try
    Result := URLDownloadToFile(nil,PChar(Source),PChar(Dest),0,nil) = 0
  except
    Result := False;
  end;
{$ELSE}
  Result := False;
{$ENDIF}
end;

//******Verifies the OpenDSS version using the reference at Sourceforge*********
Function Check_DSS_WebVersion(myDialog: boolean):String;
{$IFDEF FPC}
begin
  DSSMessageDlg ('Check_DSS_Webversion() not implemented on FPC; needs Indy', False);
  Result := '';
{$ELSE}
var
  myVersion,
  myText,
  myWebSrc,
  myPath    : String;
  myFile    : TextFile;
  myIdx     : Integer;

Begin
  myIdx := 0;
  myPath    :=  TPath.GetTempPath + '\myDSSVersion.txt';
  myWebSrc  :=  'https://sourceforge.net/p/electricdss/code/HEAD/tree/trunk/Version8/Source/Current_ver.txt';
  // Download the file into the Windows temporary folder
  if DownLoadInternetFile(myWebSrc,myPath) then
  Begin
    AssignFile(myFile, myPath);
    Reset(myFile);
    while not Eof(myFile) do
    begin
      ReadLn(myFile, myText);
      myIdx     :=  pos('mydssversion=',lowercase(myText));
      if myIdx > 0 then
        break;
    end;
    CloseFile(myFile);
  End;
  myText    :=  myText.Substring(myIdx + 12);
  myVersion :=  VersionString.Substring(8);
  myIdx     :=  pos(' ',myVersion);
  myVersion :=  myVersion.Substring(0,myIdx - 1);

  if myText <> myVersion then
  Begin
    myPath    :=  'There is a new version of OpenDSS available for download' + CRLF +
                'The new version can be located at:' + CRLF + CRLF +
                'https://sourceforge.net/projects/electricdss/';

    if myDialog then
    Begin
      {$IFNDEF CONSOLE}
        ShowMessage(myPath);
      {$ELSE}
        DSSMessageDlg(myPath, TRUE);
      {$ENDIF}
    End;

  End
  else
    myPath    := 'OpenDSS is up-to-date';

  Result  := myPath;

{$ENDIF}
End;

//**********************Launches the COM Help file******************************
procedure Show_COM_Help();
var
  BaseDir : string;

begin
{$IFDEF FPC}
  DSSMessageDlg ('Show_COM_Help() not implemented on FPC', False);
{$ELSE}
  BaseDir := TPath.GetDirectoryName(DSSDirectory.Substring(0, length(DSSDirectory) - 1));   // temporary for redirecting the path outside x64/86
  ShellExecute(0, 'open',pWidechar(BaseDir + '\Doc\OpenDSS Documentation.chm'), nil, nil, SW_SHOWNORMAL);
{$ENDIF}
End;

//*********************Gets the processor information***************************
procedure Get_Processor_Info();
Begin
  NumNUMA          :=  1;
  CPU_Physical     :=  TNumCPULib.GetPhysicalCPUCount();
  CPU_Cores        :=  TNumCPULib.GetLogicalCPUCount();
End;

constructor TProgressActor.Create();
var
  J           : integer;
begin
{$IFNDEF FPC}
  ShellExecute(Handle, 'open',pWidechar(DSSProgressPath), nil, nil, SW_SHOWNORMAL) ;
  sleep(200);
  // ... create TIdTCPClient
  idTCPClient                 := TIdTCPClient.Create();
  // ... set properties
  idTCPClient.Host            := 'localhost';
  idTCPClient.Port            := DSSPrgPort;
  idThreadComponent           := TIdThreadComponent.Create();

  if ADiakoptics and (ActiveActor = 1) then J := 1
  else J := NumOfActors;
  try
    IdTCPClient.Connect;
    IdTCPClient.IOHandler.WriteLn('num' + inttostr(J));
    IsProgressON      :=  True;
  except
    on E: Exception do begin
      IsProgressON      :=  False;
      raise;
    end;
  end;
{$ENDIF}
  Inherited Create(False);
end;

procedure TProgressActor.Execute;
{$IFDEF FPC}
begin
end;
{$ELSE}
var
  I, J    : Integer;
  AbortBtn,
  progStr : String;
  RunFlag : Boolean;
Begin

  if IsProgressON then
  Begin
    RunFlag :=  True;
    while RunFlag do
    Begin
      sleep(100);
      progStr   :=  '';
      RunFlag :=  False;
      if ADiakoptics and (ActiveActor = 1) then J := 1
      else J := NumOfActors;

      for I := 1 to J do
      Begin
        progStr :=  progStr  +  Format('%.*d',[3,ActorPctProgress[I]]);
        RunFlag :=  RunFlag or (ActorStatus[I] = 0);
      End;
      IdTCPClient.IOHandler.WriteLn('prg' + progStr);
      AbortBtn  :=  IdTCPClient.IOHandler.ReadLn;
      if AbortBtn.Substring(0,1) = 'T' then
        SolutionAbort :=  True;
    End;
    IdTCPClient.IOHandler.WriteLn('ext');
  End;
End;
{$ENDIF}

procedure TProgressActor.DoTerminate;        // Is the end of the thread
begin
  IsProgressON      :=  False;
  inherited;
End;

destructor TProgressActor.Destroy;
Begin
  inherited destroy;
End;

procedure GetDefaultPorts();
var
  F             : TextFile;
  JSONCfg       : TdJSON;
  JSONStr,
  iniFilePath   : String;
Begin
  iniFilePath   :=  DSSDirectory + 'ComPorts.ini';
  if  fileexists(iniFilePath) then
  Begin
    AssignFile(F, iniFilePath);
    Reset(F);
    ReadLn(F, JSONStr);
    CloseFile(F);
    // parse the JSON string and extract the values
    JSONCfg       :=  TdJSON.Parse(JSONStr);
    DSSPrgPort    :=  JSONCfg['dssprogress'].AsInteger;
    DSSGISPort    :=  JSONCfg['dssgis'].AsInteger;
  End
  else
  begin                                      // Since the Cfg file is missing, use the defaults
    DSSPrgPort    :=  20010;
    DSSGISPort    :=  20011;
  end;

End;

Function GetLineTypes(): String;
// Returns a string containing the line types
// the string format is the standard DSS array format (comma separated)
var
  idx       : integer;
  separator : string;
begin

  Result      :=  '[';
  separator   :=  '';
  for idx := 1 to LineTypeList.NumCommands do
  Begin
    Result    := Result + separator + LineTypeList.Get(idx);
    separator :=  ',';
  End;

  Result  :=  Result + ']';

End;

procedure LocalFinalization;
var
  Actor: Integer;
begin
  for Actor := 1 to NumOfActors do
  Begin
    With DSSExecutive[Actor] Do If RecorderOn Then Recorderon := FALSE;
    FreeAndNil (DSSExecutive[Actor]);  {Writes to Registry}
    FreeAndNil (EventStrings[Actor]);
    FreeAndNil (SavedFileList[Actor]);
    FreeAndNil (ErrorStrings[Actor]);
    FreeAndNil (ActorHandle[Actor]);
    FreeAndNil (Auxparser[Actor]);
  End;
  FreeAndNil (DSS_Registry);  {Close Registry}
end;

initialization
  {$IFDEF FPC_TRACE_INIT}writeln(format ('init %s:%s', [{$I %FILE%}, {$I %LINE%}]));{$ENDIF}
  Try
//***************Initialization for Parallel Processing*************************

   Get_processor_info();


   setlength(ActiveCircuit,CPU_Cores + 1);
   {$IFNDEF FPC}{$IFNDEF CONSOLE}setlength(ActorProgress,CPU_Cores + 1);{$ENDIF}{$ENDIF}
   setlength(ActorCPU,CPU_Cores + 1);
   setlength(ActorProgressCount,CPU_Cores + 1);
   setlength(ActiveDSSClass,CPU_Cores + 1);
   setlength(DataDirectory,CPU_Cores + 1);
   setlength(OutputDirectory,CPU_Cores + 1);
   setlength(CircuitName_,CPU_Cores + 1);
   setlength(ActorPctProgress,CPU_Cores + 1);
   setlength(ActiveDSSObject,CPU_Cores + 1);
   setlength(LastClassReferenced,CPU_Cores + 1);
   setlength(DSSObjs,CPU_Cores + 1);
   setlength(ActiveEarthModel,CPU_Cores + 1);
   setlength(DSSClassList,CPU_Cores + 1);
   setlength(ClassNames,CPU_Cores + 1);
   setlength(MonitorClass,CPU_Cores + 1);
   setlength(LoadShapeClass,CPU_Cores + 1);
   setlength(TShapeClass,CPU_Cores + 1);
   setlength(PriceShapeClass,CPU_Cores + 1);
   setlength(XYCurveClass,CPU_Cores + 1);
   setlength(GrowthShapeClass,CPU_Cores + 1);
   setlength(SpectrumClass,CPU_Cores + 1);
   setlength(SolutionClass,CPU_Cores + 1);
   setlength(EnergyMeterClass,CPU_Cores + 1);
   setlength(SensorClass,CPU_Cores + 1);
   setlength(TCC_CurveClass,CPU_Cores + 1);
   setlength(WireDataClass,CPU_Cores + 1);
   setlength(CNDataClass,CPU_Cores + 1);
   setlength(TSDataClass,CPU_Cores + 1);
   setlength(LineSpacingClass,CPU_Cores + 1);
   setlength(StorageClass,CPU_Cores + 1);
   setlength(PVSystemClass,CPU_Cores + 1);
   setlength(InvControlClass,CPU_Cores + 1);
   setlength(ExpControlClass,CPU_Cores + 1);
   setlength(EventStrings,CPU_Cores + 1);
   setlength(SavedFileList,CPU_Cores + 1);
   setlength(ErrorStrings,CPU_Cores + 1);
   setlength(ActorHandle,CPU_Cores + 1);
   setlength(Parser,CPU_Cores + 1);
   setlength(AuxParser,CPU_Cores + 1);
   setlength(ActiveYPrim,CPU_Cores + 1);
   SetLength(SolutionWasAttempted,CPU_Cores + 1);
   SetLength(ActorStatus,CPU_Cores + 1);
   SetLength(ActorMA_Msg,CPU_Cores + 1);
   SetLength(ActiveVSource,CPU_Cores + 1);
   SetLength(TDynamicExpClass,CPU_Cores + 1);

   setlength(FMonitorClass,CPU_Cores + 1);    // by Dahei UCF
   // Init pointer repositories for the EnergyMeter in multiple cores

   SetLength(OV_MHandle,CPU_Cores + 1);
   SetLength(VR_MHandle,CPU_Cores + 1);
   SetLength(SDI_MHandle,CPU_Cores + 1);
   SetLength(TDI_MHandle,CPU_Cores + 1);
   SetLength(SM_MHandle,CPU_Cores + 1);
   SetLength(EMT_MHandle,CPU_Cores + 1);
   SetLength(FM_MHandle,CPU_Cores + 1);
   SetLength(OV_Append,CPU_Cores + 1);
   SetLength(VR_Append,CPU_Cores + 1);
   SetLength(DI_Append,CPU_Cores + 1);
   SetLength(SDI_Append,CPU_Cores + 1);
   SetLength(TDI_Append,CPU_Cores + 1);
   SetLength(SM_Append,CPU_Cores + 1);
   SetLength(EMT_Append,CPU_Cores + 1);
   SetLength(PHV_Append,CPU_Cores + 1);
   SetLength(FM_Append,CPU_Cores + 1);
   SetLength(DIFilesAreOpen,CPU_Cores + 1);
   SetLength(DSSExecutive,CPU_Cores + 1);
   SetLength(IsourceClass,CPU_Cores + 1);
   SetLength(VSourceClass,CPU_Cores + 1);

   for ActiveActor := 1 to CPU_Cores do
   begin
    ActiveCircuit[ActiveActor]        :=  nil;
    {$IFNDEF FPC}
    {$IFNDEF CONSOLE}
    ActorProgress[ActiveActor]        :=  nil;
    {$ENDIF}
    {$ENDIF}
    ActiveDSSClass[ActiveActor]       :=  nil;
    EventStrings[ActiveActor]         := TStringList.Create;
    SavedFileList[ActiveActor]        := TStringList.Create;
    ErrorStrings[ActiveActor]         := TStringList.Create;
    ErrorStrings[ActiveActor].Clear;
    ActorHandle[ActiveActor]          :=  nil;
    Parser[ActiveActor]               :=  nil;
    ActorStatus[ActiveActor]          :=  1;

    OV_MHandle[ActiveActor]           :=  nil;
    VR_MHandle[ActiveActor]           :=  nil;
    SDI_MHandle[ActiveActor]          :=  nil;
    TDI_MHandle[ActiveActor]          :=  nil;
    SM_MHandle[ActiveActor]           :=  nil;
    EMT_MHandle[ActiveActor]          :=  nil;
    FM_MHandle[ActiveActor]           :=  nil;
    DIFilesAreOpen[ActiveActor]       :=  FALSE;

    ActiveVSource[Activeactor]        :=  nil;
    DSSObjs[ActiveActor]              :=  nil;
    DSSClassList[ActiveActor]         :=  nil;
   end;

   GISThickness           :=  '3';
   GISColor               :=  'FF0000';
   GISCoords              :=  AllocMem(Sizeof(Double) * 4);
   UseUserLinks           :=  False;
   IsProgressOn           :=  False;

   Progress_Actor         :=  nil;
   DSSClasses             :=  nil;
   ProgressCmd            :=  False;

   Allactors              :=  False;
   ActiveActor            :=  1;
   NumOfActors            :=  1;
   ActorCPU[ActiveActor]  :=  -1;
   Parser[ActiveActor]    :=  Tparser.Create;
   ProgramName            :=  'OpenDSS';
   DSSFileName            :=  GetDSSExeFile;
   DSSDirectory           :=  ExtractFilePath(DSSFileName);
   ADiakoptics            :=  False;  // Disabled by default
   ADiak_Init             :=  False;
   EventLogDefault        :=  False;  // Disabled by default

   GetDefaultPorts();                 // Gets the default ports to get connected to other add-ons
   {$IFNDEF CONSOLE}
   DSSProgressFrm         :=  GetDSSProgress(DSSFileName);
   {$ENDIF}

   SeasonalRating         :=  False;
   SeasonSignal           :=  '';

   {Various Constants and Switches}
   {$IFDEF FPC}NoFormsAllowed  := TRUE;{$ENDIF}

   CALPHA                := Cmplx(-0.5, -0.866025); // -120 degrees phase shift
   SQRT2                 := Sqrt(2.0);
   SQRT3                 := Sqrt(3.0);
   InvSQRT3              := 1.0/SQRT3;
   InvSQRT3x1000         := InvSQRT3 * 1000.0;
   CmdResult             := 0;
   //DIFilesAreOpen        := FALSE;
   ErrorNumber           := 0;
   ErrorPending          := FALSE;
   GlobalHelpString      := '';
   GlobalPropertyValue   := '';
   LastResultFile        := '';
   In_Redirect           := FALSE;
   InShowResults         := FALSE;
   IsDLL                 := FALSE;
   LastCommandWasCompile := FALSE;
   LastErrorMessage      := '';
   MaxCircuits           := 1;  //  Not required anymore. planning to remove it
   MaxAllocationIterations := 2;
   SolutionAbort         := FALSE;
   AutoShowExport        := FALSE;
   AutoDisplayShowReport        := TRUE;
   SolutionWasAttempted[ActiveActor]  := FALSE;

   DefaultBaseFreq       := 60.0;
   DaisySize             := 1.0;
   DefaultEarthModel     := DERI;
   ActiveEarthModel[ActiveActor]      := DefaultEarthModel;
   Parallel_enabled      :=  False;
   ConcatenateReports    :=  False;

//******************************************************************************
// Empty Globals for DirectDLL in case they are not used

  setlength(myStrArray, 0);
  setlength(myDBLArray,0);
  setlength(myCmplxArray,0);
  setlength(myPolarArray,0);
  setlength(myIntArray,0);

//******************************************************************************

   {Initialize filenames and directories}

   {$IFDEF FPC}
   ProgramName      := 'OpenDSSCmd';  // for now...
   {$ELSE}
   ProgramName      := 'OpenDSS';
   {$ENDIF}
   DSSFileName      := GetDSSExeFile;
   DSSDirectory     := ExtractFilePath(DSSFileName);
   // want to know if this was built for 64-bit, not whether running on 64 bits
   // (i.e. we could have a 32-bit build running on 64 bits; not interested in that
{$IFDEF CPUX64}
   VersionString    := 'Version ' + GetDSSVersion + ' (64-bit build)';
{$ELSE ! CPUX86}
   VersionString    := 'Version ' + GetDSSVersion + ' (32-bit build)';
{$ENDIF}

{$IFNDEF FPC}
   StartupDirectory := GetCurrentDir+'\';
   SetDataPath (GetDefaultDataDirectory + '\' + ProgramName + '\');
   DSS_Registry     := TIniRegSave.Create('\Software\' + ProgramName);


{$ELSE}
{$IFDEF WINDOWS} // deliberately different from MSWindows (Delphi)
        StartupDirectory := GetCurrentDir+'\';
        SetDataPath (GetDefaultDataDirectory + '\' + ProgramName + '\');
        DSS_Registry     := TIniRegSave.Create(DataDirectory[ActiveActor] + 'opendsscmd.ini');
{$ENDIF}
{$IFDEF UNIX}
        StartupDirectory := GetCurrentDir+'/';
        SetDataPath (GetDefaultDataDirectory + '/' + ProgramName + '/');
        DSS_Registry     := TIniRegSave.Create(DataDirectory[ActiveActor] + 'opendsscmd.ini');
{$ENDIF}
{$ENDIF}

   AuxParser[ActiveActor]        := TParser.Create;

   {$IFDEF Darwin}
      DefaultEditor   := 'open -t';
      DefaultFontSize := 12;
      DefaultFontName := 'Geneva';
   {$ENDIF}
   {$IFDEF Linux}
      DefaultEditor   := 'xdg-open';
      DefaultFontSize := 10;
      DefaultFontName := 'Arial';
   {$ENDIF}
   {$IF (defined(Windows) or defined(MSWindows))}
      DefaultEditor   := 'Notepad.exe';
      DefaultFontSize := 8;
      DefaultFontName := 'MS Sans Serif';
   {$ENDIF}

   {$IFNDEF FPC}NoFormsAllowed   := FALSE;{$ENDIF}

   LogQueries       := FALSE;
   QueryLogFileName := '';
   UpdateRegistry   := TRUE;
   {$IFDEF FPC}
   CPU_Freq := 1000; // until we can query it
   {$ELSE}
   QueryPerformanceFrequency(CPU_Freq);
   {$ENDIF}
//   CPU_Cores        :=  CPUCount;

   IsMultithread    :=  True;
   //WriteDLLDebugFile('DSSGlobals');

   LineTypeList := TCommandList.Create(
   ['OH', 'UG', 'UG_TS', 'UG_CN', 'SWT_LDBRK', 'SWT_FUSE', 'SWT_SECT', 'SWT_REC', 'SWT_DISC', 'SWT_BRK', 'SWT_ELBOW', 'BUSBAR']);
   LineTypeList.Abbrev := TRUE;  // Allow abbreviations for line type code

{$IFNDEF FPC}
  DSS_Viz_installed := CheckOpenDSSViewer('OpenDSS_Viewer');  // OpenDSS Viewer (flag for detected installation)
  DSS_GIS_installed := CheckOpenDSSViewer('OpenDSS_GIS');     // OpenDSS GIS (flag for detected installation)
  if Not IsDLL then
  Begin
    Check_DSS_WebVersion(True);
  end;
{$ENDIF}

  Except
    On E:Exception do DumpExceptionCallStack (E);
  end;

Finalization

  // Dosimplemsg('Enter DSSGlobals Unit Finalization.');
//  YBMatrix.Finish_Ymatrix_Critical;   // Ends the critical segment for the YMatrix class

//  ClearAllCircuits; // this is also done later, when Executive destroyed from LocalFinalization
  LocalFinalization;
  LineTypeList.Destroy;
End.



