unit CmdForms;

{
  ----------------------------------------------------------
  Copyright (c) 2008-2021, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

{
	08/17/2016  Created from OpenDSS
 ----------------------------------------------------------
  Copyright (c) 2016-2021 Battelle Memorial Institute
 ----------------------------------------------------------
}

interface

Uses Classes, sysutils;

VAR
   ControlPanelCreated     :Boolean;  // signify whether this is the DLL or EXE
   RebuildHelpForm:Boolean;
   PROCEDURE CreateControlPanel;
   PROCEDURE ExitControlPanel;
   PROCEDURE InitProgressForm;
   Procedure ProgressCaption(const S:String);
   Procedure ProgressFormCaption(const S:String);
   Procedure ProgressHide;
   PROCEDURE ShowControlPanel;
   PROCEDURE ShowHelpForm ;
   PROCEDURE ShowAboutBox;
   PROCEDURE ShowPropEditForm;
   PROCEDURE ShowPctProgress(Count:Integer);
   Procedure ShowMessageForm(S:TStrings);
   FUNCTION  DSSMessageDlg(const Msg:String;err:boolean):Integer;
   PROCEDURE DSSInfoMessageDlg(const Msg:String);
   FUNCTION  GetDSSExeFile: String;
   PROCEDURE CloseDownForms;
   Procedure ShowTreeView(Const Fname:String);
   FUNCTION  MakeChannelSelection(NumFieldsToSkip:Integer; const Filename:String):Boolean;

{$IFDEF FPC}
{$INCLUDE VersionString.inc}
{$ENDIF}

implementation

Uses ExecCommands, ExecOptions, ShowOptions, ExportOptions, 
  {$IFDEF WINDOWS}Windows{$ELSE}dl{$ENDIF},
  DSSGlobals, DSSClass, DSSClassDefs, ParserDel, Strutils, ArrayDef, ExceptionTrace;

const colwidth = 25; numcols = 4;  // for listing commands to the console

////////////////////////////////////////////////////////
// from https://forum.lazarus.freepascal.org/index.php?topic=46695.0
{$IFNDEF WINDOWS}
function mbGetModuleName(Address: Pointer): String;
const
  Dummy: Boolean = False;
var
  dlinfo: dl_info;
begin
  if Address = nil then Address:= @Dummy;
  FillChar({%H-}dlinfo, SizeOf(dlinfo), #0);
  if dladdr(Address, @dlinfo) = 0 then
    Result:= EmptyStr
  else begin
    Result:= UTF8Encode(dlinfo.dli_fname);
  end;
end;

function GetCurrentModuleName: String;
begin
  Result := mbGetModuleName(get_caller_addr(get_frame));
end;
{$ENDIF}
////////////////////////////////////////////////////////

Procedure InitProgressForm;
begin
End;

PROCEDURE ShowPctProgress(Count:Integer);
Begin
End;

Procedure ProgressCaption(const S:String);
Begin
	Writeln('Progress: ', S);
End;

Procedure ProgressFormCaption(const S:String);
begin
	Writeln('Progress: ', S);
End;

Procedure ProgressHide;
Begin
End;

Procedure ShowAboutBox;
begin
	writeln ('Console OpenDSS (Electric Power Distribution System Simulator)');
	writeln ('Version: ' + VersionStringFpc + ' (Free Pascal)');
	writeln ('Copyright (c) 2008-2023, Electric Power Research Institute, Inc.');
	writeln ('Copyright (c) 2016-2023, Battelle Memorial Institute');
	writeln ('All rights reserved.');
End;

Procedure ShowTreeView(Const Fname:String);
Begin
end;

FUNCTION GetDSSExeFile: String;
{$IFDEF WINDOWS}
Var
  TheFileName:Array[0..260] of char;
Begin
  FillChar(TheFileName, SizeOF(TheFileName), #0);  // Fill it with nulls
  GetModuleFileName(HInstance, TheFileName, SizeOF(TheFileName));
  Result := TheFileName;
  If IsLibrary then IsDLL := TRUE;
End;
{$ELSE}
Begin
  Result := GetCurrentModuleName; // 'todo'; // ExtractFilePath (Application.ExeName);
End;
{$ENDIF}

function DSSMessageDlg(const Msg:String;err:boolean):Integer;
Begin
	result := 0;
	if err then write ('** Error: ');
	writeln (Msg);
End;

procedure DSSInfoMessageDlg(const Msg:String);
Begin
	writeln (Msg);
End;

PROCEDURE CreateControlPanel;
Begin
End;

PROCEDURE ExitControlPanel;
Begin
End;

PROCEDURE ShowControlPanel;
Begin
End;

function CompareClassNames(Item1, Item2: Pointer): Integer;
begin
  Result := CompareText(TDSSClass(Item1).name, TDSSClass(Item2).name);
end;

procedure AddHelpForClasses(BaseClass: WORD; bProperties: boolean);
Var
  HelpList  :TList;
  pDSSClass :TDSSClass;
  i,j       :Integer;
begin
  HelpList := TList.Create();
  ActiveDSSClass[ActiveActor].First; // retval idx is not used
  pDSSClass := DSSClassList[ActiveActor].First;
  WHILE pDSSClass<>Nil DO Begin
    If (pDSSClass.DSSClassType AND BASECLASSMASK) = BaseClass Then HelpList.Add (pDSSClass);
    ActiveDSSClass[ActiveActor].Next;
    pDSSClass := DSSClassList[ActiveActor].Next;
  End;
  HelpList.Sort(@CompareClassNames);

  for i := 1 to HelpList.Count do begin
    pDSSClass := HelpList.Items[i-1];
    writeln (pDSSClass.name);
    if bProperties=true then for j := 1 to pDSSClass.NumProperties do
      writeln ('  ', pDSSClass.PropertyName^[j], ': ', pDSSClass.PropertyHelp^[j]);
  end;
  HelpList.Free;
end;

procedure ShowGeneralHelp;
begin
  writeln('This is a console-mode version of OpenDSS, available for Windows, Linux and Mac OS X');
  writeln('Enter a command at the >> prompt, followed by any required command parameters');
  writeln('Enter either a carriage return, "exit" or "q(uit)" to exit the program');
  writeln('For specific help, enter:');
  writeln('  "help command [cmd]" lists all executive commands, or');
  writeln('                       if [cmd] provided, details on that command');
  writeln('  "help option [opt]"  lists all simulator options, or');
  writeln('                       if [opt] provided, details on that option');
  writeln('  "help show [opt]"    lists the options to "show" various outputs, or');
  writeln('                       if [opt] provided, details on that output');
  writeln('  "help export [fmt]"  lists the options to "export" in various formats, or');
  writeln('                       if [fmt] provided, details on that format');
  writeln('  "help class [cls]"   lists the names of all available circuit model classes, or');
  writeln('                       if [cls] provided, details on that class');
  writeln('You may truncate any help topic name, which returns all matching entries');
  writeln('// begins a comment, which is ignored by the parser (including help)');
end;

procedure ShowAnyHelp (const num:integer; cmd:pStringArray; hlp:pStringArray; const opt:String);
VAR
  i: integer;
  lst: TStringList;
begin
  if Length(opt) < 1 then begin
    lst := TStringList.Create;
  	for i := 1 to num do
    {$IFDEF FPC}
      lst.Add(PadRight(cmd[i], colwidth));
    {$ELSE}
      lst.Add(cmd[i].PadRight(colwidth));
    {$ENDIF}
    lst.Sort;
  	for i :=  1 to num do
      if ((i mod numcols) = 0) then
        writeln (lst[i-1])
      else
        write (lst[i-1] + ' ');
    lst.Free;
  end else begin
  	for i :=  1 to num do begin
      if AnsiStartsStr (opt, LowerCase(cmd[i])) then begin
  		   writeln (UpperCase (cmd[i]));
         writeln ('======================');
         writeln (hlp[i]);
      end;
  	end;
  end;
end;

procedure ShowClassHelp (const opt:String);
var
  pDSSClass :TDSSClass;
  i :Integer;
begin
  if Length(opt) > 0 then begin
    ActiveDSSClass[ActiveActor].First; // retval idx is not used
    pDSSClass := DSSClassList[ActiveActor].First;
    while pDSSClass<>nil do begin
      if AnsiStartsStr (opt, LowerCase(pDSSClass.name)) then begin
        writeln (UpperCase (pDSSClass.name));
        writeln ('======================');
        for i := 1 to pDSSClass.NumProperties do
          writeln ('  ', pDSSClass.PropertyName^[i], ': ', pDSSClass.PropertyHelp^[i]);
      end;
      ActiveDSSClass[ActiveActor].Next;
      pDSSClass := DSSClassList[ActiveActor].Next;
    end;
  end else begin
  	writeln('== Power Delivery Elements ==');
	  AddHelpForClasses (PD_ELEMENT, false);
	  writeln('== Power Conversion Elements ==');
	  AddHelpForClasses (PC_ELEMENT, false);
	  writeln('== Control Elements ==');
	  AddHelpForClasses (CTRL_ELEMENT, false);
	  writeln('== Metering Elements ==');
	  AddHelpForClasses (METER_ELEMENT, false);
	  writeln('== Supporting Elements ==');
	  AddHelpForClasses (0, false);
	  writeln('== Other Elements ==');
	  AddHelpForClasses (NON_PCPD_ELEM, false);
  end;
end;

PROCEDURE ShowHelpForm;
VAR
  Param, OptName:String;
Begin
  Parser[ActiveActor].NextParam;
  Param := LowerCase(Parser[ActiveActor].StrValue);
  Parser[ActiveActor].NextParam;
  OptName := LowerCase(Parser[ActiveActor].StrValue);
  if ANSIStartsStr ('com', param) then
  	ShowAnyHelp (NumExecCommands, @ExecCommand, @CommandHelp, OptName)
  else if ANSIStartsStr ('op', param) then
  	ShowAnyHelp (NumExecOptions, @ExecOption, @OptionHelp, OptName)
  else if ANSIStartsStr ('sh', param) then
  	ShowAnyHelp (NumShowOptions, @ShowOption, @ShowHelp, OptName)
  else if ANSIStartsStr ('e', param) then
  	ShowAnyHelp (NumExportOptions, @ExportOption, @ExportHelp, OptName)
  else if ANSIStartsStr ('cl', param) then
  	ShowClassHelp (OptName)
  else
  	ShowGeneralHelp;
end;

Procedure ShowMessageForm(S:TStrings);
begin
  writeln(s.text);
End;

Procedure ShowPropEditForm;
Begin
End;

Procedure CloseDownForms;
Begin
End;

Function MakeChannelSelection(NumFieldsToSkip:Integer; const Filename:String):Boolean;
Begin
  Result := false;
End;

initialization

  Try
    RebuildHelpForm := True;
  Except
    On E:Exception do
      DumpExceptionCallStack (E);
  end;

finalization

end.
