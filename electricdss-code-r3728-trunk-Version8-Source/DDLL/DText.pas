unit DText;

interface

function DSSPut_Command(a:PAnsiChar):PAnsiChar;cdecl;

implementation

uses DSSGlobals, Executive, {$IFNDEF FPC_DLL}Dialogs,{$ENDIF} SysUtils;

function DSSPut_Command(a:PAnsiChar):PAnsiChar;cdecl;
begin
   SolutionAbort := FALSE;  // Reset for commands entered from outside
   DSSExecutive[ActiveActor].Command := string(a);  {Convert to String}
   Result:=PAnsiChar(AnsiString(GlobalResult));
end;

end.
