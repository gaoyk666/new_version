unit DCmathLib;

interface

function CmathLibF(mode:longint; arg1:double; arg2:double):double;cdecl;
procedure CmathLibV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

implementation

uses Ucomplex, variants, DSSGLobals, sysutils;

function CmathLibF(mode:longint; arg1:double; arg2:double):double;cdecl;
begin
  case mode of
  0: begin  // CmathLib.Cabs
     Result := cabs(cmplx(arg1, arg2));
  end;
  1: begin
     Result := cdang(cmplx(arg1, arg2));
  end
  else
     Result:=-1.0;
  end;
end;

//***************************Variant type properties****************************
procedure CmathLibV(mode:longint; var myPointer: Pointer; var myType, mySize: longint);cdecl;

Var
   pCmplx     : ^Complex;
   pPolar     : ^Polar;
   pDbl       : ^double;
   a,
   b          : double;

begin
  case mode of
  0: begin  // CmathLib.Cmplx
    pDbl            :=  myPointer;
    myType          :=  3;        // Complex
    setlength(myCmplxArray, 1);
    a               :=  pDbl^;
    inc(PByte(pDbl), 8);
    b               :=  pDbl^;
    myCmplxArray[0] :=  cmplx(a, b);
    myPointer       :=  @(myCmplxArray[0]);
    mySize          :=  SizeOf(myCmplxArray[0]) * Length(myCmplxArray);
  end;
  1: begin  // CmathLib.ctopolardeg
    pCmplx          :=  myPointer;
    myType          :=  3;        // Complex
    setlength(myPolarArray, 1);
    myPolarArray[0] := ctopolardeg(pCmplx^);
    myPointer       :=  @(myPolarArray[0]);
    mySize          :=  SizeOf(myPolarArray[0]) * Length(myPolarArray);
  end;
  2: begin  // CmathLib.pdegtocomplex
    pPolar          :=  myPointer;
    myType          :=  3;        // Complex
    setlength(myCmplxArray, 1);
    myCmplxArray[0] :=  pdegtocomplex(pPolar^.mag, pPolar^.ang);
    myPointer       :=  @(myCmplxArray[0]);
    mySize          :=  SizeOf(myCmplxArray[0]) * Length(myCmplxArray);
  end
  else
    myType  :=  4;        // String
    setlength(myStrArray, 0);
    WriteStr2Array('Error, parameter not recognized');
    myPointer :=  @(myStrArray[0]);
    mySize    :=  Length(myStrArray);
  end;
end;

end.
