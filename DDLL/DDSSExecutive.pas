unit DDSSExecutive;

interface

function DSSExecutiveI(mode:longint; arg:longint):longint;cdecl;
function DSSExecutiveS(mode:longint; arg:pAnsiChar):pAnsiChar;cdecl;

implementation

uses DSSGlobals, ExecCommands, ExecOptions, Executive, sysutils;

function DSSExecutiveI(mode:longint; arg:longint):longint;cdecl;
begin
  case mode of
  0: begin  // DSS_executive.NumCommands
     Result :=  NumExecCommands;
  end;
  1: begin  // DSS_executive.NumOptions
     Result :=  NumExecOptions;
  end
  else
      Result:=-1;
  end;
end;

//****************************String type properties******************************
function DSSExecutiveS(mode:longint; arg:pAnsiChar):pAnsiChar;cdecl;

var
    i:integer;

begin
  case mode of
  0: begin // DSS_Executive.Command
     i:=StrToInt(string(arg));
     Result := pAnsiChar(AnsiString(ExecCommand[i]));
  end;
  1: begin // DSS_Executive.Option
     i:=StrToInt(string(arg));
     Result := pAnsiChar(AnsiString(ExecOption[i]));
  end;
  2: begin // DSS_Executive.CommandHelp
     i:=StrToInt(string(arg));
     Result := pAnsiChar(AnsiString(CommandHelp[i]));
  end;
  3: begin // DSS_Executive.OptionHelp
     i:=StrToInt(string(arg));
     Result := pAnsiChar(AnsiString(OptionHelp[i]));
  end;
  4: begin // DSS_Executive.OptionValue
     i:=StrToInt(string(arg));
     DSSExecutive[ActiveActor].Command := 'get ' + ExecOption[i];
     Result := pAnsiChar(AnsiString(GlobalResult));
  end
  else
      Result:=pAnsiChar(AnsiString('Error, parameter not valid'));
  end;
end;

end.
