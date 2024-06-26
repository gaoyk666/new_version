unit ConnectOptions;
{
  ----------------------------------------------------------
  Copyright (c) 2008-2017, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}

interface

Uses Command;

CONST
        NumConnectOptions = 2;

FUNCTION DoConnectCmd:Integer;
FUNCTION DoDisConnectCmd:Integer;

Var
         ConnectOption,
         ConnectHelp :Array[1..NumConnectOptions] of String;
         ConnectCommands:TCommandList;

implementation

Uses
  {$IFNDEF Linux}
  TCP_IP,
  {$ENDIF}
  DSSGlobals, SysUtils, ParserDel, Utilities, ExceptionTrace;


PROCEDURE DefineOptions;
Begin
      ConnectOption[ 1] := 'address';
      ConnectOption[ 2] := 'port';

      ConnectHelp[ 1] := 'Address is a string containing the IP address of a particular system with which OpenDSS should form a connection';
      ConnectHelp[ 2] := 'Port is the ID of the desired server connection:'+ CRLF +
                      '47625 = OpenDSS Viewer';
End;

FUNCTION DoConnectCmd:Integer;
//Var
//   ParamName, Param:String;
//   ParamPointer, i:Integer;
Begin
  Result := 0;

//    If NoFormsAllowed Then Begin Result :=1; Exit; End;
  {$IFNDEF Linux}
  If Not Assigned(DSSConnectObj) Then DSSConnectObj := TDSSConnect.Create;
  DSSConnectObj.SetDefaults;
  With DSSConnectObj Do Begin
    Connect;
  End;
  {$ENDIF}
End;

FUNCTION DoDisConnectCmd:Integer;
//Var
//  ParamName, Param:String;
//  ParamPointer, i:Integer;
Begin
  Result := 0;

//    If NoFormsAllowed Then Begin Result :=1; Exit; End;
  {$IFNDEF Linux}
  If Assigned(DSSConnectObj) Then
  begin
    With DSSConnectObj Do Begin
      Disconnect;
    End;
  end;
  {$ENDIF}
End;


Procedure DisposeStrings;
Var i:Integer;

Begin
    For i := 1 to NumConnectOptions Do Begin
       ConnectOption[i] := '';
       ConnectHelp[i]   := '';
   End;

End;

Initialization
  {$IFDEF FPC_TRACE_INIT}writeln(format ('init %s:%s', [{$I %FILE%}, {$I %LINE%}]));{$ENDIF}
  Try
    DefineOptions;
    ConnectCommands := TCommandList.Create(ConnectOption);
    ConnectCommands.Abbrev := True;
  Except
    On E:Exception do DumpExceptionCallStack (E);
  end;

Finalization
    DoDisConnectCmd;
    DisposeStrings;
    ConnectCommands.Free;
end.
