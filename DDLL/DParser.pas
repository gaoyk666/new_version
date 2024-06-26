unit DParser;

interface

function ParserI(mode: longint; arg:longint):longint;cdecl;
function ParserF(mode: longint; arg:double):double;cdecl;
function ParserS(mode: longint; arg:pAnsiChar):pAnsiChar;cdecl;
procedure ParserV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

implementation

uses {$IFNDEF FPC_DLL}ComServ, Dialogs, {$ENDIF}ParserDel, Variants, ArrayDef, DSSGlobals, sysutils, ExceptionTrace;

Var ComParser : ParserDel.TParser;

function ParserI(mode: longint; arg:longint):longint;cdecl;
begin
  Result:=0;    // Default return value
  case mode of
  0: begin // Parser.IntValue
    Result := ComParser.IntValue ;
  end;
  1: begin // Parser.ResetDelimiters
     ComParser.ResetDelims;
  end;
  2: begin  // Parser.Autoincrement read
     if ComParser.AutoIncrement then Result := 1;
  end;
  3: begin  // Parser.Autoincrement write
     if arg=1 then
       ComParser.AutoIncrement := TRUE
     else
       ComParser.AutoIncrement := FALSE;
  end
  else
      Result:=-1;
  end;
end;

//***************************Floating point type properties*********************
function ParserF(mode: longint; arg:double):double;cdecl;
begin
  case mode of
  0: begin  // Parser.DblValue
      Result := ComParser.DblValue ;
  end
  else
      Result:=-1.0;
  end;
end;

//***************************String type properties*****************************
function ParserS(mode: longint; arg:pAnsiChar):pAnsiChar;cdecl;
begin
  Result := pAnsiChar(AnsiString('0')); // Default return value
  case mode of
  0: begin  // Parser.CmdString read
     Result := pAnsiChar(AnsiString(ComParser.CmdString));
  end;
  1: begin  // Parser.CmdString write
     ComParser.CmdString  :=  string(arg);
  end;
  2: begin  // Parser.NextParam
     Result := pAnsiChar(AnsiString(ComParser.NextParam));
  end;
  3: begin  // Parser.StrValue
     Result := pAnsiChar(AnsiString(ComParser.StrValue));
  end;
  4: begin  // Parser.WhiteSpace read
     Result := pAnsiChar(AnsiString(Comparser.Whitespace));
  end;
  5: begin  // Parser.WhiteSpace write
     ComParser.Whitespace := string(arg);
  end;
  6: begin  // Parser.BeginQuote read
      Result := pAnsiChar(AnsiString(ComParser.BeginQuoteChars));
  end;
  7: begin  // Parser.BeginQuote write
      ComParser.BeginQuoteChars := string(arg);
  end;
  8: begin  // Parser.EndQuote read
      Result := pAnsiChar(AnsiString(ComParser.EndQuoteChars));
  end;
  9: begin  // Parser.EndQuote write
      ComParser.EndQuoteChars := string(arg);
  end;
  10: begin  // Parser.Delimiters read
      Result := pAnsiChar(AnsiString(ComParser.Delimiters));
  end;
  11: begin  // Parser.Delimiters write
      ComParser.Delimiters := string(arg);
  end
  else
      Result:= pAnsiChar(AnsiString('Error, parameter not valid'));
  end;
end;

//***************************Variant type properties****************************
procedure ParserV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

Var   i,
      ActualSize,
      ExpectedSize,
      ExpectedOrder,
      MatrixSize      : Integer;
      VectorBuffer    : pDoubleArray;
      MatrixBuffer    : pDoubleArray;

begin
  {$IFDEF FPC_DLL}initialize(VectorBuffer);initialize(MatrixBuffer);{$ENDIF}
  case mode of
  0:begin  // Parser.Vector
      myType        :=  2;        // Double
      setlength(myDBLArray, 1);
      myDBLArray[0] := 0;
      ExpectedSize  := integer(mySize);
      VectorBuffer  := Allocmem(SizeOf(VectorBuffer^[1]) * ExpectedSize);
      ActualSize    := ComParser.ParseAsVector(ExpectedSize, VectorBuffer);
      setlength(myDBLArray, ActualSize);
      For i := 0 to (ActualSize-1) Do
        myDBLArray[i] := VectorBuffer^[i+1];
      Reallocmem(VectorBuffer, 0);
      myPointer     :=  @(myDBLArray[0]);
      mySize        :=  SizeOf(myDBLArray[0]) * Length(myDBLArray);
    end;
  1:begin  // Parser.Matrix
      myType        :=  2;        // Double
      setlength(myDBLArray, 1);
      ExpectedOrder := integer(mySize);
      MatrixSize    := ExpectedOrder * ExpectedOrder;
      MatrixBuffer  := Allocmem(SizeOf(MatrixBuffer^[1]) * MatrixSize);
      ComParser.ParseAsMatrix(ExpectedOrder, MatrixBuffer);

      setlength(myDBLArray,MatrixSize);
      For i := 0 to (MatrixSize-1) Do
        myDBLArray[i] := MatrixBuffer^[i+1];

      Reallocmem(MatrixBuffer, 0);
      myPointer     :=  @(myDBLArray[0]);
      mySize        :=  SizeOf(myDBLArray[0]) * Length(myDBLArray);
    end;
  2:begin  // Parser.SymMatrix
      myType        :=  2;        // Double
      setlength(myDBLArray, 1);
      ExpectedOrder := integer(mySize);
      MatrixSize    := ExpectedOrder*ExpectedOrder;
      MatrixBuffer  := Allocmem(SizeOf(MatrixBuffer^[1])*MatrixSize);
      ComParser.ParseAsSymMatrix(ExpectedOrder, MatrixBuffer);

      setlength(myDBLArray, MatrixSize);
      For i := 0 to (MatrixSize-1) Do
        myDBLArray[i] := MatrixBuffer^[i+1];

      Reallocmem(MatrixBuffer, 0);
      myPointer     :=  @(myDBLArray[0]);
      mySize        :=  SizeOf(myDBLArray[0]) * Length(myDBLArray);
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

initialization
  {$IFDEF FPC_TRACE_INIT}writeln(format ('init %s:%s', [{$I %FILE%}, {$I %LINE%}]));{$ENDIF}
  Try
    ComParser := ParserDel.TParser.Create;  // create COM Parser object
  Except
    On E:Exception do DumpExceptionCallStack (E);
  end;
end.
