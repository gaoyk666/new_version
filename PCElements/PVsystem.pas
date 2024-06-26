unit PVSystem;
{
  ----------------------------------------------------------
  Copyright (c) 2011-2022, Electric Power Research Institute, Inc.
  All rights reserved.
  ----------------------------------------------------------
}
{$HINTS OFF}
{   Change Log
    1/28/2011 Created from Storage Model

  To Do:
    Make connection to User model
    Yprim for various modes
    Define state vars and dynamics mode behavior
    Complete Harmonics mode algorithm (generator mode is implemented)
}
{
  The PVsystem element is essentially a generator that consists of a PV panel and an inverter.
  The PVsystem element can also produce or absorb vars within the kVA rating of the inverter.
  // WGS: Updated 9/24/2015 to allow for simultaneous modes and additional functionality in the InvControl.

  09/11/2022 Compatibility with dynamics simulation added
  10/28/2022 Grid forming inverter capabilities added
}
//  The PVSystem element is assumed balanced over the no. of phases defined

interface
uses  PVsystemUserModel, DSSClass,  PCClass, PCElement, ucmatrix, ucomplex,
      LoadShape, TempShape, XYCurve, Spectrum, ArrayDef, Dynamics, MathUtil, InvDynamics;

const  NumPVSystemRegisters = 6;    // Number of energy meter registers
       NumPVSystemVariables = 22;   // Includes dynamics state variables - added on 09/15/2022.
       VARMODEPF   = 0;
       VARMODEKVAR = 1;
type
  {Struct to pass basic data to user-written DLLs}
  TPVSystemVars = Packed Record
    FkVArating            : Double;
    kVPVSystemBase        : Double;
    RThev                 : Double;
    XThev                 : Double;
    Vthevharm             : Double;  {Thevinen equivalent voltage mag  for Harmonic model}
    VthevmagDyn           : Double;  {Thevinen equivalent voltage mag  reference for Dynamics model}
    Thetaharm             : Double;  {Thevinen equivalent  angle reference for Harmonic model}
    ThetaDyn              : Double;  {Thevinen equivalent  angle reference for Dynamics model}
    InitialVAngle         : Double;  {initial terminal voltage angle when entering dynamics mode}
    EffFactor             : Double;
    TempFactor            : Double;
    PanelkW               : Double; //computed
    FTemperature          : Double;
    FPmpp                 : Double;
    FpuPmpp               : Double;
    FIrradiance           : Double;
    MaxDynPhaseCurrent    : Double;
    Fkvarlimit            : Double; //maximum kvar output of the PVSystem (unsigned)
    Fkvarlimitneg         : Double;
    // Variables set from InvControl. They are results of monitor in mode 3
    Vreg                  : Double; // will be set from InvControl or ExpControl
    Vavg                  : Double;
    VVOperation           : Double;
    VWOperation           : Double;
    DRCOperation          : Double;
    VVDRCOperation        : Double;
    WPOperation           : Double;
    WVOperation           : Double;
    //        kW_out_desired   :Double;
    {32-bit integers}
    NumPhases             : Integer;   {Number of phases}
    NumConductors         : Integer; {Total Number of conductors (wye-connected will have 4)}
    Conn                  : Integer;   // 0 = wye; 1 = Delta
    P_Priority            : Boolean;  // default False // added 10/30/2018
    PF_Priority           : Boolean;  // default False // added 1/29/2019
    // Dynamic variables - introduced on 09/15/2022



   End;
  TPVSystem = CLASS(TPCClass)
    private
      PROCEDURE InterpretConnection(const S:String);
      PROCEDURE SetNcondsForConnection;
    Protected
      PROCEDURE DefineProperties;
      FUNCTION MakeLike(Const OtherPVsystemObjName:STring):Integer;Override;
    public
      RegisterNames:Array[1..NumPVSystemRegisters] of String;
      constructor Create;
      destructor Destroy; override;
      FUNCTION Edit(ActorID : Integer):Integer; override;
      FUNCTION Init(Handle:Integer; ActorID : Integer):Integer; override;
      FUNCTION NewObject(const ObjName:String):Integer; override;
      PROCEDURE ResetRegistersAll;
      PROCEDURE SampleAll(ActorID: Integer);
      PROCEDURE UpdateAll;
   End;
  TPVsystemObj = class(TPCElement)
    private
      YEQ                     : Complex;   // at nominal
      YEQ_Min                 : Complex;   // at Vmin
      YEQ_Max                 : Complex;   // at VMax
      PhaseCurrentLimit       : Complex;
      Zthev                   : Complex;
      LastThevAngle           : Double;
      DebugTrace              : Boolean;
      PVSystemSolutionCount   : Integer;
      PVSystemFundamental     : Double;  {Thevinen equivalent voltage mag and angle reference for Harmonic model}
      PVSystemObjSwitchOpen   : Boolean;
      FirstSampleAfterReset   : Boolean;
      //PFSpecified             :Boolean;
      //kvarSpecified           :Boolean;
      ForceBalanced           : Boolean;
      CurrentLimited          : Boolean;
      kvar_out                : Double;
      kW_out                  : Double;
      kvarRequested           : Double;
      Fpf_wp_nominal          : Double;
      kWRequested             : Double;
      FvarMode                : Integer;
      FpctCutIn               : Double;
      FpctCutOut              : Double;
      FVarFollowInverter      : Boolean;
      CutInkW                 : Double;
      CutOutkW                : Double;
      FInverterON             : Boolean;
      FpctPminNoVars          : Double;
      FpctPminkvarLimit       : Double;
      PminNoVars              : Double;
      PminkvarLimit           : Double;
      pctR                    : Double;
      pctX                    : Double;
      OpenPVSystemSolutionCount :Integer;
      Pnominalperphase        : Double;
      Qnominalperphase        : Double;
      RandomMult              : Double;
      Reg_Hours               : Integer;
      Reg_kvarh               : Integer;
      Reg_kWh                 : Integer;
      Reg_MaxkVA              : Integer;
      Reg_MaxkW               : Integer;
      Reg_Price               : Integer;
      ShapeFactor             : Complex;
      TShapeValue             : Double;
      Tracefile               : TextFile;
      UserModel               : TPVsystemUserModel;   {User-Written Models}
      varBase                 : Double; // Base vars per phase
      VBaseMax                : Double;
      VBaseMin                : Double;
      Vmaxpu                  : Double;
      Vminpu                  : Double;
      YPrimOpenCond           : TCmatrix;
      FVWMode                 : Boolean; //boolean indicating if under volt-watt control mode from InvControl (not ExpControl)
      FVVMode                 : Boolean; //boolean indicating if under volt-var mode from InvControl
      FWVMode                 : Boolean; //boolean indicating if under watt-var mode from InvControl
      FWPMode                 : Boolean; //boolean indicating if under watt-pf mode from InvControl
      FDRCMode                : Boolean; //boolean indicating if under DRC mode from InvControl
      FAVRMode                : Boolean; //boolean indicating whether under AVR mode from ExpControl (or InvControl, but that does not seem to be implemented yet)
      PROCEDURE CalcDailyMult(Hr:double);  // now incorporates DutyStart offset
      PROCEDURE CalcDutyMult(Hr:double);
      PROCEDURE CalcYearlyMult(Hr:double);  // now incorporates DutyStart offset
      PROCEDURE CalcDailyTemperature(Hr:double);
      PROCEDURE CalcDutyTemperature(Hr:double);
      PROCEDURE CalcYearlyTemperature(Hr:double);
      PROCEDURE ComputePanelPower;
      PROCEDURE ComputeInverterPower;
      PROCEDURE ComputekWkvar;
      PROCEDURE CalcPVSystemModelContribution(ActorID : Integer);   // This is where the power gets computed
      PROCEDURE CalcInjCurrentArray(ActorID : Integer);
      (*PROCEDURE CalcVterminal;*)
      PROCEDURE CalcVTerminalPhase(ActorID : Integer);
      PROCEDURE CalcYPrimMatrix(Ymatrix:TcMatrix; ActorID : integer);
      PROCEDURE DoConstantPQPVSystemObj(ActorID : Integer);
      PROCEDURE DoConstantZPVSystemObj(ActorID : Integer);
      PROCEDURE DoDynamicMode(ActorID : Integer);
      PROCEDURE DoHarmonicMode(ActorID : Integer);
      PROCEDURE DoUserModel(ActorID : Integer);
      PROCEDURE Integrate(Reg:Integer; const Deriv:Double; Const Interval:Double);
      PROCEDURE SetDragHandRegister(Reg:Integer; const Value:Double);
      PROCEDURE StickCurrInTerminalArray(TermArray:pComplexArray; Const Curr:Complex; i:Integer);
      PROCEDURE WriteTraceRecord(const s:string);
      // PROCEDURE SetKWandKvarOut;
      PROCEDURE UpdatePVSystem;    // Update PVSystem elements based on present kW and IntervalHrs variable
      FUNCTION  Get_PresentkW:Double;
      FUNCTION  Get_Presentkvar:Double;
      FUNCTION  Get_PresentkV: Double;
      FUNCTION  Get_PresentIrradiance: Double;
      PROCEDURE Set_PresentkV(const Value: Double);
      PROCEDURE Set_Presentkvar(const Value: Double);
      PROCEDURE Set_PresentkW(const Value: Double);
      PROCEDURE Set_PowerFactor(const Value: Double);
      PROCEDURE Set_PresentIrradiance(const Value: Double);
      PROCEDURE Set_pf_wp_nominal(const Value: Double);
      procedure Set_kVARating(const Value: Double);
      procedure Set_Pmpp(const Value: Double);
      procedure Set_puPmpp(const Value: Double);
      function  Get_Varmode: Integer; Override;
      procedure Set_Varmode(const Value: Integer); Override;
      function  Get_VWmode: Boolean; Override;
      procedure Set_VWmode(const Value: Boolean); Override;
      function  Get_VVmode: Boolean; Override;
      procedure Set_VVmode(const Value: Boolean); Override;
      function  Get_WPmode: Boolean; Override;
      procedure Set_WPmode(const Value: Boolean); Override;
      function  Get_WVmode: Boolean; Override;
      procedure Set_WVmode(const Value: Boolean); Override;
      function  Get_DRCmode: Boolean; Override;
      procedure Set_DRCmode(const Value: Boolean); Override;
      function  Get_AVRmode: Boolean; Override;
      procedure Set_AVRmode(const Value: Boolean); Override;
      procedure kWOut_Calc;
      // CIM support
      function Get_Pmin:double;
      function Get_Pmax:double;
      function Get_QMaxInj:double;
      function Get_QMaxAbs:double;
      function Get_pMaxUnderPF:double;
      function Get_pMaxOverPF:double;
      function Get_acVnom:double;
      function Get_acVmin:double;
      function Get_acVmax:double;
      function Get_Zero:double;
      function Get_CIMDynamicMode:boolean;
    Protected
      PROCEDURE Set_ConductorClosed(Index:Integer; ActorID:integer; Value:Boolean); Override;
      PROCEDURE GetTerminalCurrents(Curr:pComplexArray; ActorID : Integer); Override ;
    public
      PVSystemVars            : TPVSystemVars;
      myDynVars               : TInvDynamicVars;    // Link to the dybamci variables record
      VBase                   : Double;  // Base volts suitable for computing currents
      CurrentkvarLimit        : Double;
      CurrentkvarLimitNeg     : Double;
      Connection              : Integer;  {0 = line-neutral; 1=Delta}
      DailyShape              : String;  // Daily (24 HR) PVSystem element irradiance shape
      DailyShapeObj           : TLoadShapeObj;  // Daily PVSystem element irradianceShape for this load
      DutyShape               : String;  // Duty cycle irradiance shape for changes typically less than one hour
      DutyShapeObj            : TLoadShapeObj;  // irradiance Shape for this PVSystem element
      DutyStart               : Double; // starting time offset into the DutyShape [hrs] for this PVsystem
      YearlyShape             : String;  //
      YearlyShapeObj          : TLoadShapeObj;  // Yearly irradiance Shape for this PVSystem element
      DailyTShape             : String;
      DailyTShapeObj          : TTShapeObj;
      DutyTShape              : String;
      DutyTShapeObj           : TTShapeObj;
      YearlyTShape            : String;
      YearlyTShapeObj         : TTShapeObj;
      InverterCurve           : String;
      InverterCurveObj        : TXYCurveObj;
      Power_TempCurve         : String;
      Power_TempCurveObj      : TXYCurveObj;
      kvarLimitSet            : Boolean;
      kvarLimitNegSet         : Boolean;
      FClass                  : Integer;
      VoltageModel            : Integer;   // Variation with voltage
      PFnominal               : Double;
      Registers               : Array[1..NumPVSystemRegisters] of Double;
      Derivatives             : Array[1..NumPVSystemRegisters] of Double;
      PICtrl                  : Array of TPICtrl;
      constructor Create(ParClass :TDSSClass; const SourceName :String);
      destructor  Destroy; override;
      PROCEDURE RecalcElementData(ActorID : Integer); Override;
      PROCEDURE CalcYPrim(ActorID : Integer); Override;
      FUNCTION  InjCurrents(ActorID : Integer):Integer; Override;
      PROCEDURE GetInjCurrents(Curr:pComplexArray; ActorID : Integer); Override;
      FUNCTION  NumVariables:Integer;Override;
      PROCEDURE GetAllVariables(States:pDoubleArray);Override;
      FUNCTION  Get_Variable(i: Integer): Double; Override;
      PROCEDURE Set_Variable(i: Integer; Value: Double);  Override;
      FUNCTION  VariableName(i:Integer):String ;Override;
      FUNCTION  Get_InverterON:Boolean; Override;
      PROCEDURE Set_InverterON(const Value: Boolean); Override;
      FUNCTION  Get_VarFollowInverter:Boolean;
      PROCEDURE Set_VarFollowInverter(const Value: Boolean);
      PROCEDURE Set_Maxkvar(const Value: Double);
      PROCEDURE Set_Maxkvarneg(const Value: Double);
      PROCEDURE SetNominalPVSystemOuput(ActorID : Integer);
      PROCEDURE Randomize(Opt:Integer);   // 0 = reset to 1.0; 1 = Gaussian around mean and std Dev  ;  // 2 = uniform

      PROCEDURE ResetRegisters;
      PROCEDURE TakeSample(ActorID: Integer);
      // Support for Dynamics Mode
      PROCEDURE InitStateVars(ActorID : Integer); Override;
      PROCEDURE IntegrateStates(ActorID : Integer);Override;
      // Support for Harmonics Mode
      PROCEDURE InitHarmonics(ActorID : Integer); Override;
      PROCEDURE MakePosSequence(ActorID : Integer);Override;  // Make a positive Sequence Model
      PROCEDURE InitPropertyValues(ArrayOffset:Integer);Override;
      PROCEDURE DumpProperties(VAR F:TextFile; Complete:Boolean);Override;
      FUNCTION  GetPropertyValue(Index:Integer):String;Override;
      Procedure GetCurrents(Curr: pComplexArray; ActorID : Integer);Override;
      Function CheckOLInverter(ActorID : Integer): Boolean;
      Function CheckAmpsLimit(ActorID : Integer): Boolean;
      procedure DoGFM_Mode(ActorID : Integer);

      {Porperties}
      Property PresentIrradiance    : Double   Read Get_PresentIrradiance       Write Set_PresentIrradiance  ;
      Property PresentkW    : Double           Read Get_PresentkW               Write Set_PresentkW;
      Property Presentkvar  : Double           Read Get_Presentkvar             Write Set_Presentkvar;
      Property PresentkV    : Double           Read Get_PresentkV               Write Set_PresentkV;
      Property PowerFactor  : Double           Read PFnominal                   Write Set_PowerFactor;
      Property kVARating    : Double           Read PVSystemVars.FkVARating     Write Set_kVARating;
      Property Pmpp         : Double           read PVSystemVars.FPmpp          write Set_pmpp;
      Property puPmpp       : Double           read PVSystemVars.FpuPmpp        Write Set_puPmpp;
      Property Varmode      : Integer          read Get_Varmode                 Write Set_Varmode;  // 0=constant PF; 1=kvar specified
      Property VWmode       : Boolean          read Get_VWmode                  Write Set_VWmode;
      Property VVmode       : Boolean          read Get_VVmode                  Write Set_VVmode;
      Property WPmode       : Boolean          read Get_WPmode                  Write Set_WPmode;
      Property WVmode       : Boolean          read Get_WVmode                  Write Set_WVmode;
      Property AVRmode      : Boolean          read Get_AVRmode                 Write Set_AVRmode;
      Property DRCmode      : Boolean          read Get_DRCmode                 Write Set_DRCmode;
      Property InverterON   : Boolean          read Get_InverterON              Write Set_InverterON;
      Property VarFollowInverter : Boolean     read Get_VarFollowInverter       Write Set_VarFollowInverter;
      Property kvarLimit      : Double         read PVSystemVars.Fkvarlimit     Write Set_Maxkvar;
      Property kvarLimitneg   : Double         Read PVSystemVars.Fkvarlimitneg  Write Set_Maxkvarneg;
      Property MinModelVoltagePU : Double      Read VminPu;
      Property pf_wp_nominal : Double                                            Write Set_pf_wp_nominal;
      Property IrradianceNow :Double           Read ShapeFactor.re;
      // for CIM network export, using the k prefix
      Property Pmin:Double     Read Get_Pmin;
      Property Pmax:Double     Read Get_Pmax;
      // for CIM dynamics and IEEE 1547 export, using the k prefix
      Property qMaxInj:Double  Read Get_qMaxInj;
      Property qMaxAbs:Double  Read Get_qMaxAbs;
      Property acVmin:Double   Read Get_acVmin;
      Property acVmax:Double   Read Get_acVmax;
      Property acVnom:Double   Read Get_acVnom;
      Property pMaxUnderPF:Double  Read Get_pMaxUnderPF;
      Property pMaxOverPF:Double   Read Get_pMaxOverPF;
      Property pMaxCharge:Double   Read Get_Zero;
      Property apparentPowerChargeMax:Double Read Get_Zero;
      Property UsingCIMDynamics:Boolean Read Get_CIMDynamicMode;
   End;
var
  ActivePVSystemObj   : TPVsystemObj;
implementation
uses  ParserDel, Circuit,  Sysutils, Command, Math, DSSClassDefs, DSSGlobals, Utilities, Classes;
const
// ===========================================================================================
{
   To add a property,
    1) add a property constant to this list
    2) add a handler to the CASE statement in the Edit FUNCTION
    3) add a statement(s) to InitPropertyValues FUNCTION to initialize the string value
    4) add any special handlers to DumpProperties and GetPropertyValue, If needed
}
// ===========================================================================================
  propKV                      =  3;
  propIrradiance              =  4;
  propPF                      =  5;
  propMODEL                   =  6;
  propYEARLY                  =  7;
  propDAILY                   =  8;
  propDUTY                    =  9;
  propTYEARLY                 = 10;
  propTDAILY                  = 11;
  propTDUTY                   = 12;
  propCONNECTION              = 13;
  propKVAR                    = 14;
  propPCTR                    = 15;
  propPCTX                    = 16;
  propCLASS                   = 17;
  propInvEffCurve             = 18;
  propTemp                    = 19;
  propPmpp                    = 20;
  propP_T_Curve               = 21;
  propCutin                   = 22;
  propCutout                  = 23;
  propVMINPU                  = 24;
  propVMAXPU                  = 25;
  propKVA                     = 26;
  propUSERMODEL               = 27;
  propUSERDATA                = 28;
  propDEBUGTRACE              = 29;
  proppctPmpp                 = 30;
  propBalanced                = 31;
  propLimited                 = 32;
  propVarFollowInverter       = 33;
  propkvarLimit               = 34;
  propDutyStart               = 35;
  propPpriority               = 36;
  propPFpriority              = 37;
  propPminNoVars              = 38;
  propPminkvarLimit           = 39;
  propkvarLimitneg            = 40;
  propkVDC                    = 41;
  propkp                      = 42;
  propCtrlTol                 = 43;
  propSMT                     = 44;
  propSM                      = 45;
  propDynEq                   = 46;
  propDynOut                  = 47;
  propGFM                     = 48;
  propAmpsLimit               = 49;
  propAmpsError               = 50;
  NumPropsThisClass           = 50; // Make this agree with the last property constant
var
  cBuffer             : Array[1..24] of Complex;  // Temp buffer for calcs  24-phase PVSystem element?
constructor TPVsystem.Create;  // Creates superstructure for all PVSystem elements
  begin
    Inherited Create;
    Class_Name := 'PVSystem';
    DSSClassType := DSSClassType + PVSystem_ELEMENT;  // In both PCelement and PVSystem element list
    ActiveElement := 0;
    // Set Register names
    RegisterNames[1]  := 'kWh';
    RegisterNames[2]  := 'kvarh';
    RegisterNames[3]  := 'Max kW';
    RegisterNames[4]  := 'Max kVA';
    RegisterNames[5]  := 'Hours';
    RegisterNames[6]  := 'Price($)';
    DefineProperties;
    CommandList := TCommandList.Create(PropertyName, NumProperties);
    CommandList.Abbrev := TRUE;
  end;
destructor TPVsystem.Destroy;
  begin
    // ElementList and  CommandList freed in inherited destroy
    Inherited Destroy;
  end;
PROCEDURE TPVsystem.DefineProperties;
  Begin
    Numproperties := NumPropsThisClass;
    CountProperties;   // Get inherited property count
    AllocatePropertyArrays;   {see DSSClass}
    // Define Property names
    {
    Using the AddProperty FUNCTION, you can list the properties here in the order you want
    them to appear when properties are accessed sequentially without tags.   Syntax:
    AddProperty( <name of property>, <index in the EDIT Case statement>, <help text>);
    }
    AddProperty('phases',    1,
                            'Number of Phases, this PVSystem element.  Power is evenly divided among phases.');
    AddProperty('bus1',      2,
                            'Bus to which the PVSystem element is connected.  May include specific node specification.');
    AddProperty('kv',        propKV,
                            'Nominal rated (1.0 per unit) voltage, kV, for PVSystem element. For 2- and 3-phase PVSystem elements, specify phase-phase kV. '+
                            'Otherwise, specify actual kV across each branch of the PVSystem element. '+
                            'If 1-phase wye (star or LN), specify phase-neutral kV. '+
                            'If 1-phase delta or phase-phase connected, specify phase-phase kV.');  // line-neutral voltage//  base voltage
    AddProperty('irradiance', propIrradiance,
                            'Get/set the present irradiance value in kW/sq-m. Used as base value for shape multipliers. '+
                            'Generally entered as peak value for the time period of interest and the yearly, daily, and duty load shape ' +
                            'objects are defined as per unit multipliers (just like Loads/Generators).' );
    AddProperty('Pmpp',      propPmpp,
                            'Get/set the rated max power of the PV array for 1.0 kW/sq-m irradiance and a user-selected array temperature. ' +
                            'The P-TCurve should be defined relative to the selected array temperature.' );
    AddProperty('%Pmpp',     proppctPmpp,
                            'Upper limit on active power as a percentage of Pmpp.');
    AddProperty('Temperature', propTemp,
                            'Get/set the present Temperature. Used as fixed value corresponding to PTCurve property. '+
                            'A multiplier is obtained from the Pmpp-Temp curve and applied to the nominal Pmpp from the irradiance ' +
                            'to determine the net array output.' );
    AddProperty('pf',        propPF,
                            'Nominally, the power factor for the output power. Default is 1.0. ' +
                            'Setting this property will cause the inverter to operate in constant power factor mode.' +
                            'Enter negative when kW and kvar have opposite signs.'+CRLF+
                            'A positive power factor signifies that the PVSystem element produces vars ' + CRLF +
                            'as is typical for a generator.  ');
    AddProperty('conn',      propCONNECTION,
                            '={wye|LN|delta|LL}.  Default is wye.');
    AddProperty('kvar',      propKVAR,
                            'Get/set the present kvar value.  Setting this property forces the inverter to operate in constant kvar mode.');
    AddProperty('kVA',       propKVA,
                            'kVA rating of inverter. Used as the base for Dynamics mode and Harmonics mode values.');
    AddProperty('%Cutin',     propCutin,
                            '% cut-in power -- % of kVA rating of inverter. ' +
                            'When the inverter is OFF, the power from the array must be greater than this for the inverter to turn on.');
    AddProperty('%Cutout',    propCutout,
                            '% cut-out power -- % of kVA rating of inverter. '+
                            'When the inverter is ON, the inverter turns OFF when the power from the array drops below this value.');
    AddProperty('EffCurve',  propInvEffCurve,
                            'An XYCurve object, previously defined, that describes the PER UNIT efficiency vs PER UNIT of rated kVA for the inverter. ' +
                            'Inverter output power is discounted by the multiplier obtained from this curve.');
    AddProperty('P-TCurve',   propP_T_Curve,
                            'An XYCurve object, previously defined, that describes the PV array PER UNIT Pmpp vs Temperature curve. ' +
                            'Temperature units must agree with the Temperature property and the Temperature shapes used for simulations. ' +
                            'The Pmpp values are specified in per unit of the Pmpp value for 1 kW/sq-m irradiance. ' +
                            'The value for the temperature at which Pmpp is defined should be 1.0. ' +
                            'The net array power is determined by the irradiance * Pmpp * f(Temperature)');
    AddProperty('%R',        propPCTR,
                            'Equivalent percent internal resistance, ohms. Default is 50%. Placed in series with internal voltage source' +
                            ' for harmonics and dynamics modes. (Limits fault current to about 2 pu if not current limited -- see LimitCurrent) ');
    AddProperty('%X',        propPCTX,
                            'Equivalent percent internal reactance, ohms. Default is 0%. Placed in series with internal voltage source' +
                            ' for harmonics and dynamics modes. ' );
    AddProperty('model',     propMODEL,
                            'Integer code (default=1) for the model to use for power output variation with voltage. '+
                            'Valid values are:' +CRLF+CRLF+
                            '1:PVSystem element injects a CONSTANT kW at specified power factor.'+CRLF+
                            '2:PVSystem element is modeled as a CONSTANT ADMITTANCE.'  +CRLF+
                            '3:Compute load injection from User-written Model.');
    AddProperty('Vminpu',       propVMINPU,
                               'Default = 0.90.  Minimum per unit voltage for which the Model is assumed to apply. ' +
                               'Below this value, the load model reverts to a constant impedance model except for Dynamics model. ' +
                               'In Dynamics mode, the current magnitude is limited to the value the power flow would compute for this voltage.');
    AddProperty('Vmaxpu',       propVMAXPU,
                               'Default = 1.10.  Maximum per unit voltage for which the Model is assumed to apply. ' +
                               'Above this value, the load model reverts to a constant impedance model.');
    AddProperty('Balanced',     propBalanced,
                               '{Yes | No*} Default is No.  Force balanced current only for 3-phase PVSystems. Forces zero- and negative-sequence to zero. ');
    AddProperty('LimitCurrent', propLimited,
                               'Limits current magnitude to Vminpu value for both 1-phase and 3-phase PVSystems similar to Generator Model 7. For 3-phase, ' +
                               'limits the positive-sequence current but not the negative-sequence.');
    AddProperty('yearly',       propYEARLY,
                               'Dispatch shape to use for yearly simulations.  Must be previously defined '+
                               'as a Loadshape object. If this is not specified, the Daily dispatch shape, if any, is repeated '+
                               'during Yearly solution modes. In the default dispatch mode, ' +
                               'the PVSystem element uses this loadshape to trigger State changes.');
    AddProperty('daily',        propDAILY,
                               'Dispatch shape to use for daily simulations.  Must be previously defined '+
                               'as a Loadshape object of 24 hrs, typically.  In the default dispatch mode, '+
                               'the PVSystem element uses this loadshape to trigger State changes.'); // daily dispatch (hourly)
    AddProperty('duty',          propDUTY,
                               'Load shape to use for duty cycle dispatch simulations such as for solar ramp rate studies. ' +
                               'Must be previously defined as a Loadshape object. '+
                               'Typically would have time intervals of 1-5 seconds. '+
                               'Designate the number of points to solve using the Set Number=xxxx command. '+
                               'If there are fewer points in the actual shape, the shape is assumed to repeat.');  // as for wind generation
    AddProperty('Tyearly',       propTYEARLY,
                               'Temperature shape to use for yearly simulations.  Must be previously defined '+
                               'as a TShape object. If this is not specified, the Daily dispatch shape, if any, is repeated '+
                               'during Yearly solution modes. ' +
                               'The PVSystem element uses this TShape to determine the Pmpp from the Pmpp vs T curve. ' +
                               'Units must agree with the Pmpp vs T curve.');
    AddProperty('Tdaily',        propTDAILY,
                               'Temperature shape to use for daily simulations.  Must be previously defined '+
                               'as a TShape object of 24 hrs, typically.  '+
                               'The PVSystem element uses this TShape to determine the Pmpp from the Pmpp vs T curve. ' +
                               'Units must agree with the Pmpp vs T curve.'); // daily dispatch (hourly)
    AddProperty('Tduty',          propTDUTY,
                               'Temperature shape to use for duty cycle dispatch simulations such as for solar ramp rate studies. ' +
                               'Must be previously defined as a TShape object. '+
                               'Typically would have time intervals of 1-5 seconds. '+
                               'Designate the number of points to solve using the Set Number=xxxx command. '+
                               'If there are fewer points in the actual shape, the shape is assumed to repeat. ' +
                               'The PVSystem model uses this TShape to determine the Pmpp from the Pmpp vs T curve. ' +
                               'Units must agree with the Pmpp vs T curve.');  // Cloud transient simulation
    AddProperty('class',       propCLASS,
                              'An arbitrary integer number representing the class of PVSystem element so that PVSystem values may '+
                              'be segregated by class.'); // integer
    AddProperty('UserModel',   propUSERMODEL,
                              'Name of DLL containing user-written model, which computes the terminal currents for Dynamics studies, ' +
                              'overriding the default model.  Set to "none" to negate previous setting.');
    AddProperty('UserData',    propUSERDATA,
                              'String (in quotes or parentheses) that gets passed to user-written model for defining the data required for that model.');
    AddProperty('debugtrace',  propDEBUGTRACE,
                              '{Yes | No }  Default is no.  Turn this on to capture the progress of the PVSystem model ' +
                              'for each iteration.  Creates a separate file for each PVSystem element named "PVSystem_name.CSV".' );
    AddProperty('VarFollowInverter',     propVarFollowInverter,
                            'Boolean variable (Yes|No) or (True|False). Defaults to False which indicates that the reactive power generation/absorption does not respect the inverter status.' +
                            'When set to True, the PVSystem reactive power generation/absorption will cease when the inverter status is off, due to panel kW dropping below %Cutout.  The reactive power '+
                            'generation/absorption will begin again when the panel kW is above %Cutin.  When set to False, the PVSystem will generate/absorb reactive power regardless of the status of the inverter.');

    AddProperty('DutyStart', propDutyStart,
                            'Starting time offset [hours] into the duty cycle shape for this PVSystem, defaults to 0');
    AddProperty('WattPriority', propPPriority,
                            '{Yes/No*/True/False} Set inverter to watt priority instead of the default var priority');
    AddProperty('PFPriority', propPFPriority,
                            '{Yes/No*/True/False} Set inverter to operate with PF priority when in constant PF mode. If "Yes", value assigned to "WattPriority"' +
                             ' is neglected. If controlled by an InvControl with either Volt-Var or DRC or both functions activated, PF priority is neglected and "WattPriority" is considered. Default = No.');
    AddProperty('%PminNoVars', propPminNoVars,
                           'Minimum active power as percentage of Pmpp under which there is no vars production/absorption.');

    AddProperty('%PminkvarMax', propPminkvarLimit,
                           'Minimum active power as percentage of Pmpp that allows the inverter to produce/absorb reactive power up to its kvarMax or kvarMaxAbs.');


    AddProperty('kvarMax',     propkvarLimit,
                            'Indicates the maximum reactive power GENERATION (un-signed numerical variable in kvar) for the inverter (as an un-signed value). Defaults to kVA rating of the inverter.');

    AddProperty('kvarMaxAbs', propkvarLimitneg,
                           'Indicates the maximum reactive power ABSORPTION (un-signed numerical variable in kvar) for the inverter (as an un-signed value). Defaults to kVA rating of the inverter.');

    AddProperty('kVDC', propkVDC,
                           'Indicates the rated voltage (kV) at the input of the inverter at the peak of PV energy production. The value is normally greater or equal to the kV base of the PV system. It is used for dynamics simulation ONLY.');

    AddProperty('Kp', propkp,
                           'It is the proportional gain for the PI controller within the inverter. Use it to modify the controller response in dynamics simulation mode.');

    AddProperty('PITol', propCtrlTol,
                           'It is the tolerance (%) for the closed loop controller of the inverter. For dynamics simulation mode.');

    AddProperty('SafeVoltage', propSMT,
                           'Indicates the voltage level (%) respect to the base voltage level for which the Inverter will operate. If this threshold is violated, the Inverter will enter safe mode (OFF). For dynamic simulation. By default is 80%');

    AddProperty('SafeMode', propSM,
                           '(Read only) Indicates whether the inverter entered (Yes) or not (No) into Safe Mode.');
    AddProperty('DynamicEq', propDynEq,
                           'The name of the dynamic equation (DinamicExp) that will be used for defining the dynamic behavior of the generator. ' +
                                 'if not defined, the generator dynamics will follow the built-in dynamic equation.');
    AddProperty('DynOut', propDynOut,
                            'The name of the variables within the Dynamic equation that will be used to govern the PVSystem dynamics.' +
                                 'This PVsystem model requires 1 output from the dynamic equation: ' + CRLF + CRLF +
                                 '1. Current.' + CRLF +
                                 'The output variables need to be defined in the same order.');
    AddProperty('ControlMode', propGFM,
                            'Defines the control mode for the inverter. It can be one of {GFM | GFL*}. By default it is GFL (Grid Following Inverter).' +
                                 ' Use GFM (Grid Forming Inverter) for energizing islanded microgrids, but, if the device is conencted to the grid, it is highly recommended to use GFL.' + CRLF + CRLF +
                                 'GFM control mode disables any control action set by the InvControl device.');
     AddProperty('AmpLimit', propAmpsLimit,
                            'Is the current limiter per phase for the IBR when operating in GFM mode. This limit is imposed to prevent the IBR to enter into Safe Mode when reaching the IBR power ratings.' + CRLF +
                            'Once the IBR reaches this value, it remains there without moving into Safe Mode. This value needs to be set lower than the IBR Amps rating.');
    AddProperty('AmpLimitGain', propAmpsError,
                            'Use it for fine tunning the current limiter when active, by default is 0.8, it has to be a value between 0.1 and 1. This value allows users to fine tune the IBRs current limiter to match with the user requirements.');

    ActiveProperty := NumPropsThisClass;
    inherited DefineProperties;  // Add defs of inherited properties to bottom of list
    // Override default help string
    PropertyHelp^[NumPropsThisClass +1] := 'Name of harmonic voltage or current spectrum for this PVSystem element. ' +
                       'A harmonic voltage source is assumed for the inverter. ' +
                       'Default value is "default", which is defined when the DSS starts.';
  end;
function TPVsystem.NewObject(const ObjName:String):Integer;
  Begin
    // Make a new PVSystem element and add it to PVSystem class list
    With ActiveCircuit[ActiveActor] Do
      Begin
        ActiveCktElement := TPVsystemObj.Create(Self, ObjName);
        Result := AddObjectToList(ActiveDSSObject[ActiveActor]);
      End;
  End;
PROCEDURE TPVsystem.SetNcondsForConnection;
  Begin
    With ActivePVSystemObj Do
      Begin
        CASE Connection OF
          0: NConds := Fnphases +1;
          1: CASE Fnphases OF
              1,2: NConds := Fnphases +1; // L-L and Open-delta
             ELSE
                    NConds := Fnphases;
             END;
        END;
      End;
End;
PROCEDURE TPVsystem.UpdateAll;
  VAR
    i : Integer;
  Begin
    For i := 1 to ElementList.ListSize  Do
      With TPVsystemObj(ElementList.Get(i)) Do
        If Enabled Then UpdatePVSystem;
  End;
PROCEDURE TPVsystem.InterpretConnection(const S:String);
  // Accepts
  //    delta or LL           (Case insensitive)
  //    Y, wye, or LN
  VAR
    TestS     : String;
  Begin
    With ActivePVSystemObj Do Begin
      TestS := lowercase(S);
      CASE TestS[1] OF
        'y','w': Connection := 0;  {Wye}
        'd': Connection := 1;  {Delta or line-Line}
        'l': CASE Tests[2] OF
               'n': Connection := 0;
               'l': Connection := 1;
             END;
      END;
      SetNCondsForConnection;
      {VBase is always L-N voltage unless 1-phase device or more than 3 phases}
      With PVSystemVars Do
        CASE Fnphases Of
          2,3: VBase := kVPVSystemBase * InvSQRT3x1000;    // L-N Volts
          ELSE
            VBase := kVPVSystemBase * 1000.0 ;   // Just use what is supplied
        END;
      VBaseMin  := Vminpu * VBase;
      VBaseMax  := Vmaxpu * VBase;
      Yorder := Fnconds * Fnterms;
      YprimInvalid[ActiveActor] := True;
    End;
  End;

//- - - - - - - - - - - - - - -MAIN EDIT FUNCTION - - - - - - - - - - - - - - -
FUNCTION TPVsystem.Edit(ActorID : Integer):Integer;
  VAR
    VarIdx,
    i, iCase, ParamPointer    : Integer;
    TmpStr,
    ParamName,
    Param                     : String;
  Begin
  // continue parsing with contents of Parser
  ActivePVSystemObj := ElementList.Active;
  ActiveCircuit[ActorID].ActiveCktElement := ActivePVSystemObj;
  Result := 0;
  With ActivePVSystemObj Do
    Begin
       ParamPointer := 0;
       ParamName    := Parser[ActorID].NextParam;  // Parse next property off the command line
       Param        := Parser[ActorID].StrValue;   // Put the string value of the property value in local memory for faster access
       While Length(Param)>0 Do
        Begin
          If  (Length(ParamName) = 0) Then Inc(ParamPointer)       // If it is not a named property, assume the next property
          ELSE ParamPointer := CommandList.GetCommand(ParamName);  // Look up the name in the list for this class
          If  (ParamPointer>0) and (ParamPointer<=NumProperties)
          Then PropertyValue[PropertyIdxMap^[ParamPointer]] := Param   // Update the string value of the property
          ELSE
          Begin
            // first, checks if there is a dynamic eq assigned, then
            // checks if the new property edit the state variables within
            VarIdx   :=  CheckIfDynVar(ParamName, ActorID);
            if VarIdx < 0 then
              DoSimpleMsg('Unknown parameter "'+ParamName+'" for PVSystem "'+Name+'"', 560);
          End;
          If (ParamPointer > 0) then
            Begin
              iCase := PropertyIdxMap^[ParamPointer];
              CASE iCASE OF
                0                 : DoSimpleMsg('Unknown parameter "' + ParamName + '" for Object "' + Class_Name +'.'+ Name + '"', 561);
                1                 : Begin
                                      NPhases    := Parser[ActorID].Intvalue; // num phases
                                      Set_PresentkV(PVSystemVars.kVPVSystemBase);          // In case phases have been defined after
                                    End;
                2                 : SetBus(1, param);
                propKV            : PresentkV     := Parser[ActorID].DblValue;
                propIrradiance    : PVSystemVars.FIrradiance   := Parser[ActorID].DblValue;
                propPF            : Begin
                                      varMode := VARMODEPF;
                                      PFnominal     := Parser[ActorID].DblValue;
                                    end;
                propMODEL         : VoltageModel := Parser[ActorID].IntValue;
                propYEARLY        : YearlyShape  := Param;
                propDAILY         : DailyShape   := Param;
                propDUTY          : DutyShape    := Param;
                propTYEARLY       : YearlyTShape := Param;
                propTDAILY        : DailyTShape  := Param;
                propTDUTY         : DutyTShape   := Param;
                propCONNECTION    : InterpretConnection(Param);
                propKVAR          : Begin
                                      varMode       := VARMODEKVAR;
                                      Presentkvar   := Parser[ActorID].DblValue;
                                    End;
                propPCTR          : pctR         := Parser[ActorID].DblValue;
                propPCTX          : pctX         := Parser[ActorID].DblValue;
                propCLASS         : FClass       := Parser[ActorID].IntValue;
                propInvEffCurve   : InverterCurve:= Param;
                propTemp          : PVSystemVars.FTemperature := Parser[ActorID].DblValue ;
                propPmpp          : PVSystemVars.FPmpp        := Parser[ActorID].DblValue ;
                propP_T_Curve     : Power_TempCurve := Param;
                propCutin         : FpctCutIn    := Parser[ActorID].DblValue;
                propCutout        : FpctCutOut   := Parser[ActorID].DblValue;
                propVMINPU        : VMinPu       := Parser[ActorID].DblValue;
                propVMAXPU        : VMaxPu       := Parser[ActorID].DblValue;
                propKVA           : With PVSystemVars Do
                                      Begin
                                        FkVArating    := Parser[ActorID].DblValue;
                                        if not kvarLimitSet                       then PVSystemVars.Fkvarlimit    := FkVArating;
                                        if not kvarLimitSet and not kvarLimitNegSet then PVSystemVars.Fkvarlimitneg := FkVArating;
                                      End;
                propUSERMODEL     : UserModel.Name := Parser[ActorID].StrValue;  // Connect to user written models
                propUSERDATA      : UserModel.Edit := Parser[ActorID].StrValue;  // Send edit string to user model
                propDEBUGTRACE    : DebugTrace   := InterpretYesNo(Param);
                proppctPmpp       : PVSystemVars.FpuPmpp  := Parser[ActorID].DblValue / 100.0;  // convert to pu
                propBalanced      : ForceBalanced  := InterpretYesNo(Param);
                propLimited       : CurrentLimited := InterpretYesNo(Param);
                propVarFollowInverter
                                  : FVarFollowInverter := InterpretYesNo(Param);
                propkvarLimit     : Begin
                                      PVSystemVars.Fkvarlimit     := Abs(Parser[ActorID].DblValue);
                                      kvarLimitSet := True;
                                      if not kvarLimitNegSet then PVSystemVars.Fkvarlimitneg := Abs(PVSystemVars.Fkvarlimit);
                                    End;
                propDutyStart     : DutyStart := Parser[ActorID].DblValue;
                propPPriority     : PVSystemVars.P_priority := InterpretYesNo(Param);  // set watt priority flag
                propPFPriority    : PVSystemVars.PF_priority := InterpretYesNo(Param);
                propPminNoVars    : FpctPminNoVars      := abs(Parser[ActorID].DblValue);
                propPminkvarLimit : FpctPminkvarLimit   := abs(Parser[ActorID].DblValue);
                propkvarLimitneg  : Begin
                                      PVSystemVars.Fkvarlimitneg := Abs(Parser[ActorID].DblValue);
                                      kvarLimitNegSet           := True;
                                    End;
                propkVDC          : myDynVars.RatedVDC          := Parser[ActorID].DblValue * 1000;
                propkp            : myDynVars.kP                := Parser[ActorID].DblValue / 1000;
                propCtrlTol       : myDynVars.CtrlTol           := Parser[ActorID].DblValue / 100.0;
                propSMT           : myDynVars.SMThreshold       := Parser[ActorID].DblValue;
                propDynEq         : DynamicEq                   := Param;
                propDynOut        : SetDynOutput(Param);
                propGFM           : Begin
                                      if lowercase(Parser[ActorID].StrValue) = 'gfm' then
                                      Begin
                                        GFM_mode            :=  True;               // Enables GFM mode for this IBR
                                        myDynVars.ResetIBR  :=  False;
                                        if length( myDynVars.Vgrid ) < NPhases then
                                          setlength( myDynVars.Vgrid, NPhases );  // Used to store the voltage per phase
                                      End
                                      else
                                        GFM_mode  :=  False;
                                      YprimInvalid[ActorID] :=  True;
                                    End

                ELSE
                  // Inherited parameters
                  ClassEdit(ActivePVSystemObj, ParamPointer - NumPropsThisClass)
              END;
              CASE iCase OF
                1                 : SetNcondsForConnection;  // Force Reallocation of terminal info
                {Set loadshape objects;  returns nil If not valid}
                propYEARLY        : YearlyShapeObj      := LoadShapeClass[ActorID].Find(YearlyShape);
                propDAILY         : DailyShapeObj       := LoadShapeClass[ActorID].Find(DailyShape);
                propDUTY          : DutyShapeObj        := LoadShapeClass[ActorID].Find(DutyShape);
                propTYEARLY       : YearlyTShapeObj     := TShapeClass[ActorID].Find(YearlyTShape);
                propTDAILY        : DailyTShapeObj      := TShapeClass[ActorID].Find(DailyTShape);
                propTDUTY         : DutyTShapeObj       := TShapeClass[ActorID].Find(DutyTShape);
                propInvEffCurve   : InverterCurveObj    := XYCurveClass[ActorID].Find(InverterCurve);
                propP_T_Curve     : Power_TempCurveObj  := XYCurveClass[ActorID].Find(Power_TempCurve);
                propDEBUGTRACE    : IF DebugTrace THEN
                                      Begin   // Init trace file
                                        AssignFile(TraceFile, GetOutputDirectory + 'STOR_'+Name+'.CSV');
                                        ReWrite(TraceFile);
                                        Write(TraceFile, 't, Iteration, LoadMultiplier, Mode, LoadModel, PVSystemModel,  Qnominalperphase, Pnominalperphase, CurrentType');
                                        For i := 1 to nphases Do Write(Tracefile,  ', |Iinj'+IntToStr(i)+'|');
                                        For i := 1 to nphases Do Write(Tracefile,  ', |Iterm'+IntToStr(i)+'|');
                                        For i := 1 to nphases Do Write(Tracefile,  ', |Vterm'+IntToStr(i)+'|');
                                        Write(TraceFile, ',Vthev, Theta');
                                        Writeln(TraceFile);
                                        CloseFile(Tracefile);
                                      End;
                propDynEq         : Begin
                                      DynamicEqObj :=  TDynamicExpClass[ActorID].Find(DynamicEq);
                                      If Assigned(DynamicEqObj) then With DynamicEqObj Do
                                        setlength(DynamicEqVals, NumVars);
                                    End;
              END;
            End;
          ParamName := Parser[ActorID].NextParam;
          Param     := Parser[ActorID].StrValue;
        End;
      RecalcElementData(ActorID);
      YprimInvalid[ActorID] := True;
    End;
End;
FUNCTION TPVsystem.MakeLike(Const OtherPVSystemObjName:String):Integer;
// Copy over essential properties from other object
  VAR
    OtherPVSystemObj      : TPVsystemObj;
    i                     : Integer;
  Begin
    Result := 0;
    {See If we can find this line name in the present collection}
    OtherPVSystemObj := Find(OtherPVsystemObjName);
    If   (OtherPVSystemObj <> Nil) Then
      begin
        With ActivePVSystemObj Do
          Begin
            If (Fnphases <> OtherPVSystemObj.Fnphases) Then
              Begin
                Nphases := OtherPVSystemObj.Fnphases;
                NConds := Fnphases;  // Forces reallocation of terminal stuff
                Yorder := Fnconds*Fnterms;
                YprimInvalid[ActiveActor] := True;
              End;
            PVSystemVars.kVPVSystemBase   := OtherPVSystemObj.PVSystemVars.kVPVSystemBase;
            Vbase                           := OtherPVSystemObj.Vbase;
            Vminpu                          := OtherPVSystemObj.Vminpu;
            Vmaxpu                          := OtherPVSystemObj.Vmaxpu;
            VBaseMin                        := OtherPVSystemObj.VBaseMin;
            VBaseMax                        := OtherPVSystemObj.VBaseMax;
            kW_out                          := OtherPVSystemObj.kW_out;
            kvar_out                        := OtherPVSystemObj.kvar_out;
            Pnominalperphase                := OtherPVSystemObj.Pnominalperphase;
            PFnominal                       := OtherPVSystemObj.PFnominal;
            Qnominalperphase                := OtherPVSystemObj.Qnominalperphase;
            Connection                      := OtherPVSystemObj.Connection;
            YearlyShape                     := OtherPVSystemObj.YearlyShape;
            YearlyShapeObj                  := OtherPVSystemObj.YearlyShapeObj;
            DailyShape                      := OtherPVSystemObj.DailyShape;
            DailyShapeObj                   := OtherPVSystemObj.DailyShapeObj;
            DutyShape                       := OtherPVSystemObj.DutyShape;
            DutyShapeObj                    := OtherPVSystemObj.DutyShapeObj;
            DutyStart                       := OtherPVSystemObj.DutyStart;
            YearlyTShape                    := OtherPVSystemObj.YearlyTShape;
            YearlyTShapeObj                 := OtherPVSystemObj.YearlyTShapeObj;
            DailyTShape                     := OtherPVSystemObj.DailyTShape;
            DailyTShapeObj                  := OtherPVSystemObj.DailyTShapeObj;
            DutyTShape                      := OtherPVSystemObj.DutyTShape;
            DutyTShapeObj                   := OtherPVSystemObj.DutyTShapeObj;
            InverterCurve                   := OtherPVSystemObj.InverterCurve;
            InverterCurveObj                := OtherPVSystemObj.InverterCurveObj;
            Power_TempCurve                 := OtherPVSystemObj.Power_TempCurve;
            Power_TempCurveObj              := OtherPVSystemObj.Power_TempCurveObj;
            FClass                          := OtherPVSystemObj.FClass;
            VoltageModel                    := OtherPVSystemObj.VoltageModel;
            PVSystemVars.FTemperature      := OtherPVSystemObj.PVSystemVars.FTemperature;
            PVSystemVars.FPmpp             := OtherPVSystemObj.PVSystemVars.FPmpp;
            FpctCutin                       := OtherPVSystemObj.FpctCutin;
            FpctCutout                      := OtherPVSystemObj.FpctCutout;
            FVarFollowInverter              := OtherPVSystemObj.FVarFollowInverter;
            PVSystemVars.Fkvarlimit        := OtherPVSystemObj.PVSystemVars.Fkvarlimit;
            PVSystemVars.Fkvarlimitneg     := OtherPVSystemObj.PVSystemVars.Fkvarlimitneg;
            FpctPminNoVars                  := OtherPVSystemObj.FpctPminNoVars;
            FpctPminkvarLimit               := OtherPVSystemObj.FpctPminkvarLimit;
            kvarLimitSet                    := OtherPVSystemObj.kvarLimitSet;
            kvarLimitNegSet                 := OtherPVSystemObj.kvarLimitNegSet;

            PVSystemVars.FIrradiance       := OtherPVSystemObj.PVSystemVars.FIrradiance;
            PVSystemVars.FkVArating        := OtherPVSystemObj.PVSystemVars.FkVArating;
            pctR                            := OtherPVSystemObj.pctR;
            pctX                            := OtherPVSystemObj.pctX;
            RandomMult                      := OtherPVSystemObj.RandomMult;
            FVWMode                         := OtherPVSystemObj.FVWMode;
            FVVMode                         := OtherPVSystemObj.FVVMode;
            FWPMode                         := OtherPVSystemObj.FWPMode;
            FWVMode                         := OtherPVSystemObj.FWPMode;
            FDRCMode                        := OtherPVSystemObj.FDRCMode;
            FAVRMode                        := OtherPVSystemObj.FAVRMode;
            UserModel.Name                  := OtherPVSystemObj.UserModel.Name;  // Connect to user written models
            ForceBalanced                   := OtherPVSystemObj.ForceBalanced;
            CurrentLimited                  := OtherPVSystemObj.CurrentLimited;
            ClassMakeLike(OtherPVSystemObj);
            For i := 1 to ParentClass.NumProperties Do
              FPropertyValue[i] := OtherPVSystemObj.FPropertyValue[i];
            Result := 1;
          End;
      end
    ELSE  DoSimpleMsg('Error in PVSystem MakeLike: "' + OtherPVsystemObjName + '" Not Found.', 562);
  End;
FUNCTION TPVsystem.Init(Handle:Integer; ActorID : Integer):Integer;
  VAR
    p       : TPVsystemObj;
  Begin
    If (Handle = 0) THEN
      Begin  // init all
        p := elementList.First;
        WHILE (p <> nil) Do
          Begin
            p.Randomize(0);
            p := elementlist.Next;
          End;
      End
    ELSE
      Begin
        Active := Handle;
        p := GetActiveObj;
        p.Randomize(0);
      End;
    DoSimpleMsg('Need to implement TPVSystem.Init', -1);
    Result := 0;
  End;
PROCEDURE TPVsystem.ResetRegistersAll;  // Force all EnergyMeters in the circuit to reset
  VAR
    idx   : Integer;
  Begin
    idx := First;
    WHILE (idx > 0) Do
      Begin
        TPVsystemObj(GetActiveObj).ResetRegisters;
        idx := Next;
      End;
  End;
PROCEDURE TPVsystem.SampleAll(ActorID: Integer);  // Force all active PV System energy meters  to take a sample
  VAR
    i     : Integer;
  Begin
    For i := 1 to ElementList.ListSize  Do
      With TPVsystemObj(ElementList.Get(i)) Do
        If Enabled Then TakeSample(ActorID);
  End;
Constructor TPVsystemObj.Create(ParClass:TDSSClass; const SourceName:String);
  Begin
    Inherited create(ParClass);
    Name := LowerCase(SourceName);
    DSSObjType := ParClass.DSSClassType ; // + PVSystem_ELEMENT;  // In both PCelement and PVSystemelement list
    Nphases                       := 3;
    Fnconds                       := 4;  // defaults to wye
    Yorder                        := 0;  // To trigger an initial allocation
    Nterms                        := 1;  // forces allocations
    YearlyShape                   := '';
    YearlyShapeObj                := nil;  // If YearlyShapeobj = nil Then the Irradiance alway stays nominal
    DailyShape                    := '';
    DailyShapeObj                 := nil;  // If DaillyShapeobj = nil Then the Irradiance alway stays nominal
    DutyShape                     := '';
    DutyShapeObj                  := nil;  // If DutyShapeobj = nil Then the Irradiance alway stays nominal
    DutyStart                     := 0.0;
    YearlyTShape                  := '';
    YearlyTShapeObj               := nil;  // If YearlyShapeobj = nil Then the Temperature always stays nominal
    DailyTShape                   := '';
    DailyTShapeObj                := nil;  // If DaillyShapeobj = nil Then the Temperature always stays nominal
    DutyTShape                    := '';
    DutyTShapeObj                 := nil;  // If DutyShapeobj = nil Then the Temperature always stays nominal
    InverterCurveObj              := Nil;
    Power_TempCurveObj            := Nil;
    InverterCurve                 := '';
    Power_TempCurve               := '';
    Connection                    := 0;    // Wye (star, L-N)
    VoltageModel                  := 1;  {Typical fixed kW negative load}
    FClass                        := 1;
    PVSystemSolutionCount         := -1;  // For keep track of the present solution in Injcurrent calcs
    OpenPVSystemSolutionCount     := -1;
    YPrimOpenCond                 := nil;
    PVSystemVars.kVPVSystemBase   := 12.47;
    VBase                         := 7200.0;
    Vminpu                        := 0.90;
    Vmaxpu                        := 1.10;
    VBaseMin                      := Vminpu  * Vbase;
    VBaseMax                      := Vmaxpu  * Vbase;
    Yorder                        := Fnterms * Fnconds;
    RandomMult                    := 1.0 ;
    varMode                       := VARMODEPF;
    FInverterON                   := TRUE; // start with inverterON
    FVarFollowInverter            := FALSE;
    ForceBalanced                 := FALSE;
    CurrentLimited                := FALSE;
    NumStateVars                  := NumPVSystemVariables;
    With PVSystemVars, myDynVars Do
    Begin
      FTemperature              :=  25.0;
      FIrradiance               :=  1.0;  // kW/sq-m
      FkVArating                :=  500.0;
      FPmpp                     :=  500.0;
      FpuPmpp                   :=  1.0;    // full on
      Vreg                      :=  9999;
      Vavg                      :=  9999;
      VVOperation               :=  9999;
      VWOperation               :=  9999;
      DRCOperation              :=  9999;
      VVDRCOperation            :=  9999;
      WPOperation               :=  9999;
      WVOperation               :=  9999;
      //         kW_out_desired  :=9999;
      Fkvarlimit                :=  FkVArating;
      Fkvarlimitneg             :=  FkVArating;
      P_Priority                :=  FALSE;    // This is a change from older versions
      PF_Priority               :=  FALSE;
      RatedVDC                  :=  8000;
      SMThreshold               :=  80;
      SafeMode                  :=  False;
      kP                        :=  0.00001;
      ILimit                    :=  -1;         // No Amps limit
      IComp                     :=  0;
      VError                    :=  0.8;
    End;
    FpctCutIn                     := 20.0;
    FpctCutOut                    := 20.0;
    FpctPminNoVars                := -1.0;
    FpctPminkvarLimit             := -1.0;
    Fpf_wp_nominal                := 1.0;
    {Output rating stuff}
    kW_out                        := 500.0;
    kvar_out                      := 0.0;
    PFnominal                     := 1.0;
    pctR                          := 50.0;
    pctX                          := 0.0;
    PublicDataStruct              := @PVSystemVars;
    PublicDataSize                := SizeOf(TPVSystemVars);
    kvarLimitSet                  := False;
    kvarLimitNegSet               := False;

    UserModel                     := TPVsystemUserModel.Create;
    Reg_kWh                       := 1;
    Reg_kvarh                     := 2;
    Reg_MaxkW                     := 3;
    Reg_MaxkVA                    := 4;
    Reg_Hours                     := 5;
    Reg_Price                     := 6;
    DebugTrace                    := FALSE;
    PVSystemObjSwitchOpen         := FALSE;
    Spectrum                      := '';  // override base class
    SpectrumObj                   := nil;
    FVWMode                       := FALSE;
    FVVMode                       := FALSE;
    FWVMode                       := FALSE;
    FWPMode                       := FALSE;
    FDRCMode                      := FALSE;
    FAVRMode                      := FALSE;

    setlength(PICtrl,0);

    InitPropertyValues(0);
    RecalcElementData(ActiveActor);
  End;
PROCEDURE TPVsystemObj.InitPropertyValues(ArrayOffset: Integer);
// Define default values for the properties
  Begin
    With PVSystemVars Do
      Begin
        PropertyValue[1]                        := '3';         //'phases';
        PropertyValue[2]                        := Getbus(1);   //'bus1';
        PropertyValue[propKV]                   := Format('%-g', [kVPVSystemBase]);
        PropertyValue[propIrradiance]           := Format('%-g', [FIrradiance]);
        PropertyValue[propPF]                   := Format('%-g', [PFnominal]);
        PropertyValue[propMODEL]                := '1';
        PropertyValue[propYEARLY]               := '';
        PropertyValue[propDAILY]                := '';
        PropertyValue[propDUTY]                 := '';
        PropertyValue[propTYEARLY]              := '';
        PropertyValue[propTDAILY]               := '';
        PropertyValue[propTDUTY]                := '';
        PropertyValue[propCONNECTION]           := 'wye';
        PropertyValue[propKVAR]                 := Format('%-g', [Presentkvar]);
        PropertyValue[propPCTR]                 := Format('%-g', [pctR]);
        PropertyValue[propPCTX]                 := Format('%-g', [pctX]);
        PropertyValue[propCLASS]                := '1'; //'class'
        PropertyValue[propInvEffCurve]          := '';
        PropertyValue[propTemp]                 := Format('%-g', [FTemperature]);
        PropertyValue[propPmpp]                 := Format('%-g', [FPmpp]);
        PropertyValue[propP_T_Curve]            := '';
        PropertyValue[propCutin]                := '20';
        PropertyValue[propCutout]               := '20';
        PropertyValue[propVarFollowInverter]    := 'NO';
        PropertyValue[propVMINPU]               := '0.90';
        PropertyValue[propVMAXPU]               := '1.10';
        PropertyValue[propKVA]                  := Format('%-g', [FkVArating]);
        PropertyValue[propUSERMODEL]            := '';  // Usermodel
        PropertyValue[propUSERDATA]             := '';  // Userdata
        PropertyValue[propDEBUGTRACE]           := 'NO';
        PropertyValue[proppctPmpp]              := '100';
        PropertyValue[propBalanced]             := 'NO';
        PropertyValue[propLimited]              := 'NO';
        PropertyValue[propkvarLimit]            := Format('%-g', [Fkvarlimit]);
        PropertyValue[propkvarLimitneg]         := Format('%-g', [Fkvarlimitneg]);
        PropertyValue[propPpriority]            := 'NO';
        PropertyValue[propPFpriority]           := 'NO';
        PropertyValue[propKVDC]                 := '8000';
        PropertyValue[propkp]                   := '0.00001';
        PropertyValue[propCtrlTol]              := '5';
        PropertyValue[propSMT]                  := '80';
        PropertyValue[propSM]                   := 'NO';
        PropertyValue[propGFM]                  := 'GFL';
      End;
    inherited  InitPropertyValues(NumPropsThisClass);
  End;
FUNCTION TPVsystemObj.GetPropertyValue(Index: Integer): String;
  Begin
    Result := '';
    With PVSystemVars, myDynVars Do
      CASE Index of
        propKV            : Result := Format('%.6g', [kVPVSystemBase]);
        propIrradiance    : Result := Format('%.6g', [FIrradiance]);
        propPF            : Result := Format('%.6g', [PFnominal]);
        propMODEL         : Result := Format('%d',   [VoltageModel]);
        propYEARLY        : Result := YearlyShape;
        propDAILY         : Result := DailyShape;
        propDUTY          : Result := DutyShape;
        propTYEARLY       : Result := YearlyTShape;
        propTDAILY        : Result := DailyTShape;
        propTDUTY         : Result := DutyTShape;
        propCONNECTION    : If Connection = 0 Then Result := 'wye' else Result :=  'delta';
        propKVAR          : Result := Format('%.6g', [kvar_out]);
        propPCTR          : Result := Format('%.6g', [pctR]);
        propPCTX          : Result := Format('%.6g', [pctX]);
        {propCLASS      = 17;}
        propInvEffCurve   : Result := InverterCurve;
        propTemp          : Result := Format('%.6g', [FTemperature]);
        propPmpp          : Result := Format('%.6g', [FPmpp]);
        propP_T_Curve     : Result := Power_TempCurve;
        propCutin         : Result := Format('%.6g', [FpctCutin]);
        propCutOut        : Result := Format('%.6g', [FpctCutOut]);
        propVarFollowInverter : If FVarFollowInverter Then Result:='Yes' Else Result := 'No';
        propPminNoVars    : Result := Format('%.6g', [FpctPminNoVars]);
        propPminkvarLimit : Result := Format('%.6g', [FpctPminkvarLimit]);
        propVMINPU        : Result := Format('%.6g', [VMinPu]);
        propVMAXPU        : Result := Format('%.6g', [VMaxPu]);
        propKVA           : Result := Format('%.6g', [FkVArating]);
        propUSERMODEL     : Result := UserModel.Name;
        propUSERDATA      : Result := '(' + inherited GetPropertyValue(index) + ')';
        proppctPmpp       : Result := Format('%.6g', [FpuPmpp * 100.0]);
        propBalanced      : If ForceBalanced  Then Result:='Yes' Else Result := 'No';
        propLimited       : If CurrentLimited Then Result:='Yes' Else Result := 'No';
        propkvarLimit     : Result := Format('%.6g', [Fkvarlimit]);
        propkvarLimitneg  : Result := Format('%.6g', [Fkvarlimitneg]);
        propDutyStart     : Result := Format('%.6g', [DutyStart]);
        propkVDC          : Result := Format('%.6g', [RatedVDC / 1000]);
        propkp            : Result := Format('%.10g',[kP * 1000]);
        propCtrlTol       : Result := Format('%.6g', [CtrlTol * 100]);
        propSMT           : Result := Format('%.6g', [SMThreshold]);
        propSM            : if SafeMode then Result :=  'Yes' else Result := 'No';
        propDynEq         : Result := DynamicEq;
        propDynOut        : GetDynOutputStr();
        propGFM           : if GFM_Mode then Result :=  'GFM' else Result :=  'GFL';
        {propDEBUGTRACE = 33;}
        ELSE  // take the generic handler
          Result := Inherited GetPropertyValue(index);
      END;
  End;
Destructor TPVsystemObj.Destroy;
  Begin
    YPrimOpenCond.Free;
    UserModel.Free;
    Inherited Destroy;
  End;
PROCEDURE TPVsystemObj.Randomize(Opt:Integer);
  Begin
    CASE Opt OF
      0             :  RandomMult := 1.0;
      GAUSSIAN      :  RandomMult := Gauss(YearlyShapeObj.Mean, YearlyShapeObj.StdDev);
      UNIfORM       :  RandomMult := Random;  // number between 0 and 1.0
      LOGNORMAL     :  RandomMult := QuasiLognormal(YearlyShapeObj.Mean);
    END;
  End;
PROCEDURE TPVsystemObj.CalcDailyMult(Hr:Double);
  Begin
    If (DailyShapeObj <> Nil) Then
      Begin
        ShapeFactor := DailyShapeObj.GetMult(Hr);
      End
    ELSE ShapeFactor := CDOUBLEONE;  // Default to no  variation
  End;
PROCEDURE TPVsystemObj.CalcDailyTemperature(Hr: double);
  Begin
    If (DailyTShapeObj <> Nil) Then
      Begin
        TShapeValue := DailyTShapeObj.GetTemperature(Hr);
      End
    ELSE TShapeValue := PVSystemVars.FTemperature;  // Default to no  variation
  end;
PROCEDURE TPVsystemObj.CalcDutyMult(Hr:Double);
  Begin
    If DutyShapeObj <> Nil Then
      Begin
        ShapeFactor := DutyShapeObj.GetMult(Hr + DutyStart);
      End
    ELSE CalcDailyMult(Hr);  // Default to Daily Mult If no duty curve specified
  End;
PROCEDURE TPVsystemObj.CalcDutyTemperature(Hr: double);
  Begin
    If DutyTShapeObj <> Nil Then
      Begin
        TShapeValue := DutyTShapeObj.GetTemperature(Hr);
      End
    ELSE CalcDailyTemperature(Hr);  // Default to Daily Mult If no duty curve specified
  end;
PROCEDURE TPVsystemObj.CalcYearlyMult(Hr:Double);
  Begin
    If YearlyShapeObj<>Nil Then
      Begin
        ShapeFactor := YearlyShapeObj.GetMult(Hr + DutyStart) ;
      End
    ELSE CalcDailyMult(Hr);  // Defaults to Daily curve
  End;


PROCEDURE TPVsystemObj.CalcYearlyTemperature(Hr: double);
  Begin
    If YearlyTShapeObj<>Nil Then
      Begin
        TShapeValue := YearlyTShapeObj.GetTemperature(Hr) ;
      End
    ELSE CalcDailyTemperature(Hr);  // Defaults to Daily curve
  end;


// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
// Required for operation in GFM mode
// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
Procedure TPVsystemObj.GetCurrents(Curr: pComplexArray; ActorID : Integer);
var
  i : Integer;
Begin
  WITH  ActiveCircuit[ActorID].Solution Do
  Begin
    if GFM_Mode then
    Begin
      TRY
         //FOR i := 1 TO (Nterms * NConds) DO Vtemp^[i] := V^[NodeRef^[i]];
         // This is safer    12/7/99
         FOR     i := 1 TO Yorder DO
         Begin
          if not ADiakoptics or (ActorID = 1) then
             Vterminal^[i] := NodeV^[NodeRef^[i]]
          else
             Vterminal^[i] := VoltInActor1(NodeRef^[i]);
         End;

         YPrim.MVMult(Curr, Vterminal);  // Current from Elements in System Y

        // Add Together  with yprim currents
         FOR i := 1 TO Yorder DO Curr^[i] := Csub(Curr^[i], InjCurrent^[i]);

      EXCEPT
        On E: Exception Do
          DoErrorMsg(('GetCurrents for Element: ' + Name + '.'), E.Message,
            'Inadequate storage allotted for circuit element.', 327);
      END;

    End
    else
      inherited GetCurrents(Curr, ActorID);
  End;

End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
// Returns True if any of the inverter phases is overloaded
// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
Function TPVsystemObj.CheckOLInverter(ActorID : Integer): Boolean;
var
  myCurr    : complex;
  MaxAmps,
  PhaseAmps : Double;
  i         : Integer;
Begin
  // Check if reaching saturation point in GFM
  Result  :=  False;
  if GFM_Mode then
  Begin
    ComputePanelPower();
    MaxAmps    :=  ( ( PVSystemvars.PanelkW * 1000 ) / NPhases ) / VBase;
    ComputeIterminal(ActorID);
    for i := 1 to NPhases do
    Begin
      myCurr    :=  Iterminal^[i];
      PhaseAmps :=  cabs( myCurr);
      if PhaseAmps > MaxAmps then
      Begin
        Result  :=  True;
        break;
      End;
    End;
  End;
End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
// Returns True if any of the inverter phases has reached the current limit
// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
Function TPVsystemObj.CheckAmpsLimit(ActorID : Integer): Boolean;
var
  myCurr    : complex;
  myVolts,
  NomP,
  PhaseP,
  PhaseAmps : Double;
  i         : Integer;
Begin
  // Check if reaching saturation point in GFM
  Result  :=  False;
  NomP    :=  myDynvars.ILimit * VBase;
  if GFM_Mode then
  Begin
    GetCurrents(Iterminal, ActorID);
    myDynVars.IComp         :=  0.0;
    for i := 1 to NPhases do
    Begin
      myCurr                  :=  Iterminal^[i];
      PhaseAmps               :=  cabs( myCurr);
      myVolts                 :=  ctopolar(ActiveCircuit[ActorID].Solution.NodeV[NodeRef[i]]).mag;
      PhaseP                  :=  PhaseAmps * myVolts;
      if PhaseP > NomP then
      Begin
        if PhaseP > myDynVars.IComp then
          myDynVars.IComp :=  PhaseP;
        Result  :=  True;
      End;
    End;
  End;
End;

// - - - - - - - - - - - - - - - - - - - - - - - -- - - - - - - - - - - - - - - - - -
// Implements the grid forming inverter control routine for the PVSystem device
//------------------------------------------------------------------------------------
procedure TPVsystemObj.DoGFM_Mode(ActorID : Integer);
Var
  j,
  i           : Integer;
  myW,
  ZSys        : Double;

Begin

  myDynVars.BaseV          :=  VBase;
  myDynVars.Discharging     :=  True;

  with ActiveCircuit[ActorID].Solution, myDynVars do
  Begin
    {Initial conditions just in case}
    if length( myDynVars.Vgrid ) < NPhases then setlength(myDynVars.Vgrid, NPhases);

    for i := 1 to NPhases do Vgrid[i - 1]      :=  ctopolar( NodeV^[ NodeRef^[ i ] ] );
    if IComp > 0 then
    Begin
      ZSys    :=  ( 2 * ( Vbase * ILimit ) ) - IComp;
      BaseV   :=  ( ZSys / ILimit ) * VError ;
    End;
    myDynVars.CalcGFMVoltage( ActorID, NPhases, Vterminal );
    YPrim.MVMult( InjCurrent, Vterminal );

    set_ITerminalUpdated(FALSE, ActorID);
  End;
End;

PROCEDURE TPVsystemObj.RecalcElementData(ActorID : Integer);
  Begin
    VBaseMin  := VMinPu * VBase;
    VBaseMax := VMaxPu * VBase;
    varBase := 1000.0 * kvar_out / Fnphases;
    With PVSystemVars Do
      Begin
        // values in ohms for thevenin equivalents
        RThev := pctR * 0.01 * SQR(PresentkV)/FkVArating * 1000.0;
        XThev := pctX * 0.01 * SQR(PresentkV)/FkVArating * 1000.0;
        CutInkW := FpctCutin * FkVArating / 100.0;
        CutOutkW := FpctCutOut * FkVArating / 100.0;
        if FpctPminNoVars <= 0 then PminNoVars    := -1
        else PminNoVars := FpctPminNoVars * FPmpp / 100.0;
        if FpctPminkvarLimit <= 0 then PminkvarLimit := -1
        else PminkvarLimit := FpctPminkvarLimit * FPmpp / 100.0;
      End;
    SetNominalPVSystemOuput(ActorID);
    {Now check for errors.  If any of these came out nil and the string was not nil, give warning}
    If YearlyShapeObj=Nil Then
      If Length(YearlyShape)>0 Then DoSimpleMsg('WARNING! Yearly load shape: "'+ YearlyShape +'" Not Found.', 563);
    If DailyShapeObj=Nil Then
      If Length(DailyShape)>0 Then DoSimpleMsg('WARNING! Daily load shape: "'+ DailyShape +'" Not Found.', 564);
    If DutyShapeObj=Nil Then
      If Length(DutyShape)>0 Then DoSimpleMsg('WARNING! Duty load shape: "'+ DutyShape +'" Not Found.', 565);
    If YearlyTShapeObj=Nil Then
      If Length(YearlyTShape)>0 Then DoSimpleMsg('WARNING! Yearly temperature shape: "'+ YearlyTShape +'" Not Found.', 5631);
    If DailyTShapeObj=Nil Then
      If Length(DailyTShape)>0 Then DoSimpleMsg('WARNING! Daily temperature shape: "'+ DailyTShape +'" Not Found.', 5641);
    If DutyTShapeObj=Nil Then
      If Length(DutyTShape)>0 Then DoSimpleMsg('WARNING! Duty temperature shape: "'+ DutyTShape +'" Not Found.', 5651);
    If Length(Spectrum)> 0 Then
      Begin
        SpectrumObj := SpectrumClass[ActorID].Find(Spectrum);
        If SpectrumObj=Nil Then DoSimpleMsg('ERROR! Spectrum "'+Spectrum+'" Not Found.', 566);
      End
    Else SpectrumObj := Nil;
    // Initialize to Zero - defaults to PQ PVSystem element
    // Solution object will reset after circuit modifications
    Reallocmem(InjCurrent, SizeOf(InjCurrent^[1])*Yorder);
    {Update any user-written models}
    If Usermodel.Exists  Then UserModel.FUpdateModel;
  End;
PROCEDURE TPVsystemObj.SetNominalPVSystemOuput(ActorID : Integer);
  Begin
    ShapeFactor  := CDOUBLEONE;  // init here; changed by curve routine
    TShapeValue  := PVSystemVars.FTemperature; // init here; changed by curve routine
    // Check to make sure the PVSystem element is ON
    With ActiveCircuit[ActorID], ActiveCircuit[ActorID].Solution Do
      Begin
        IF NOT (IsDynamicModel or IsHarmonicModel) then     // Leave PVSystem element in whatever state it was prior to entering Dynamic mode
        Begin
          // Check dispatch to see what state the PVSystem element should be in
          With Solution Do
            CASE Mode OF
              SNAPSHOT    : ; {Just solve for the present kW, kvar}  // Don't check for state change
              DAILYMODE   : Begin  CalcDailyMult(DynaVars.dblHour);  CalcDailyTemperature(DynaVars.dblHour); End;
              YEARLYMODE  : Begin  CalcYearlyMult(DynaVars.dblHour); CalcYearlyTemperature(DynaVars.dblHour); End;
           (*
              MONTECARLO1,
              MONTEFAULT,
              FAULTSTUDY;
              DYNAMICMODE : Begin 
                            End   ;*)

              GENERALTIME : Begin
                             // This mode allows use of one class of load shape
                              case ActiveCircuit[ActiveActor].ActiveLoadShapeClass of
                                  USEDAILY:  Begin CalcDailyMult(DynaVars.dblHour);  CalcDailyTemperature(DynaVars.dblHour);  End;
                                  USEYEARLY: Begin CalcYearlyMult(DynaVars.dblHour); CalcYearlyTemperature(DynaVars.dblHour); End;
                                  USEDUTY:   Begin CalcDutyMult(DynaVars.dblHour);   CalcDutyTemperature(DynaVars.dblHour);   End;
                              else
                                  ShapeFactor := CDOUBLEONE     // default to 1 + j1 if not known
                              end;
                            End;
              // Assume Daily curve, If any, for the following
              MONTECARLO2,
              MONTECARLO3,
              LOADDURATION1,
              LOADDURATION2 : Begin CalcDailyMult(DynaVars.dblHour); CalcDailyTemperature(DynaVars.dblHour); End;
              PEAKDAY       : Begin CalcDailyMult(DynaVars.dblHour); CalcDailyTemperature(DynaVars.dblHour); End;
              DUTYCYCLE     : Begin CalcDutyMult(DynaVars.dblHour) ; CalcDutyTemperature(DynaVars.dblHour) ;  End;
              {AUTOADDFLAG:  ; }
            END;
          ComputekWkvar();
          Pnominalperphase   := 1000.0 * kW_out    / Fnphases;
          Qnominalperphase   := 1000.0 * kvar_out  / Fnphases;
          CASE VoltageModel  of
            //****  Fix this when user model gets connected in
            3: // YEQ := Cinv(cmplx(0.0, -StoreVARs.Xd))  ;  // Gets negated in CalcYPrim
            ELSE
              YEQ  := CDivReal(Cmplx(Pnominalperphase, -Qnominalperphase), Sqr(Vbase));   // Vbase must be L-N for 3-phase
              If   (Vminpu <> 0.0) Then YEQ_Min := CDivReal(YEQ, SQR(Vminpu))  // at 95% voltage
                                   Else YEQ_Min := YEQ; // Always a constant Z model
              If   (Vmaxpu <> 0.0) Then  YEQ_Max := CDivReal(YEQ, SQR(Vmaxpu))   // at 105% voltage
                                   Else  YEQ_Max := YEQ;
          { Like Model 7 generator, max current is based on amount of current to get out requested power at min voltage
          }
              With PVSystemvars Do
                Begin
                  PhaseCurrentLimit  := Cdivreal( Cmplx(Pnominalperphase,Qnominalperphase), VBaseMin) ;
                  MaxDynPhaseCurrent := Cabs(PhaseCurrentLimit);
                End;

          END;
         { When we leave here, all the YEQ's are in L-N values}
        End;  {If  NOT (IsDynamicModel or IsHarmonicModel)}
      End;  {With ActiveCircuit[ActiveActor]}

  End;

// ===========================================================================================
PROCEDURE TPVsystemObj.CalcYPrimMatrix(Ymatrix:TcMatrix; ActorID : integer);
  VAR
    Y , Yij         : Complex;
    i, j            : Integer;
    FreqMultiplier  : Double;
Begin
  FYprimFreq := ActiveCircuit[ActiveActor].Solution.Frequency  ;
  FreqMultiplier := FYprimFreq / BaseFrequency;
  With  ActiveCircuit[ActiveActor].solution  Do
    IF IsHarmonicModel Then
    Begin
      {YEQ is computed from %R and %X -- inverse of Rthev + j Xthev}
      Y  := YEQ;   // L-N value computed in initial condition routines
      IF Connection=1 Then Y := CDivReal(Y, 3.0); // Convert to delta impedance
      Y.im := Y.im / FreqMultiplier;
      Yij := Cnegate(Y);
      FOR i := 1 to Fnphases Do
        Begin
          CASE Connection of
            0 :   Begin
                    Ymatrix.SetElement(i, i, Y);
                    Ymatrix.AddElement(Fnconds, Fnconds, Y);
                    Ymatrix.SetElemsym(i, Fnconds, Yij);
                  End;
            1 :   Begin   {Delta connection}
                    Ymatrix.SetElement(i, i, Y);
                    Ymatrix.AddElement(i, i, Y);  // put it in again
                    For j := 1 to i-1 Do Ymatrix.SetElemsym(i, j, Yij);
                  End;
           END;
        End;
    End
    ELSE
    Begin  //  Regular power flow PVSystem element model
      if not GFM_Mode then
      Begin
        {YEQ is always expected as the equivalent line-neutral admittance}
        Y := cnegate(YEQ);   // negate for generation    YEQ is L-N quantity
        // ****** Need to modify the base admittance for real harmonics calcs
        Y.im           := Y.im / FreqMultiplier;
        CASE Connection OF
          0 : With YMatrix Do
            Begin // WYE
              Yij := Cnegate(Y);
              FOR i := 1 to Fnphases Do
                Begin
                  SetElement(i, i, Y);
                  AddElement(Fnconds, Fnconds, Y);
                  SetElemsym(i, Fnconds, Yij);
                End;
            End;
         1 : With YMatrix Do
            Begin  // Delta  or L-L
              Y    := CDivReal(Y, 3.0); // Convert to delta impedance
              Yij  := Cnegate(Y);
              FOR i := 1 to Fnphases Do
                Begin
                  j := i+1;
                  If j>Fnconds Then j := 1;  // wrap around for closed connections
                  AddElement(i,i, Y);
                  AddElement(j,j, Y);
                  AddElemSym(i,j, Yij);
                End;
            End;
        END;
      End
      else
      Begin
        // Otherwise, the inverter is in GFM control modem calculation changes
        with myDynVars do
        Begin
          RatedkVLL      :=  PresentkV;
          mKVARating     :=  PVSystemVars.FkVArating;
          CalcGFMYprim(ActorID, NPhases, @YMatrix);
        End;
      End;
    End;  {ELSE IF Solution.mode}
End;
PROCEDURE TPVsystemObj.ComputeInverterPower;
  VAR
    kVA_Gen         : Double;
    Qramp_limit     : Double;
    TempPF          : Double;
    CutOutkWAC      : Double;
    CutInkWAC       : Double;
  Begin
    // Reset CurrentkvarLimit to kvarLimit
    Qramp_limit := 0.0;TempPF := 0.0;
    CurrentkvarLimit    := PVSystemVars.Fkvarlimit;
    CurrentkvarLimitNeg := PVSystemVars.Fkvarlimitneg;
    With PVSystemVars Do
      Begin
        EffFactor := 1.0;
        kW_Out := 0.0;
        If Assigned(InverterCurveObj) Then
        Begin
          CutOutkWAC := CutOutkW * InverterCurveObj.GetYValue(abs(CutOutkW)/FkVArating);
          CutInkWAC  := CutInkW  * InverterCurveObj.GetYValue(abs(CutInkW)/FkVArating);
        End
        else  // Assume Ideal Inverter
        Begin
          CutOutkWAC := CutOutkW;
          CutInkWAC  := CutInkW;
        End;

        // Determine state of the inverter
        If FInverterON Then
          Begin
            If Panelkw < CutOutkW Then
              Begin
                FInverterON := FALSE;
              End;
          End
        ELSE
          Begin
            If Panelkw >= CutInkW Then
              Begin
                FInverterON := TRUE;
              End;
          End;
        // set inverter output. Defaults to 100% of the panelkW if no efficiency curve spec'd
        If FInverterON Then
          Begin
            If Assigned(InverterCurveObj) Then EffFactor := InverterCurveObj.GetYValue(PanelkW/FkVArating);  // pu eff vs pu power
            kWOut_Calc;
          End
        ELSE
          Begin
            kW_Out := 0.0;
          End;
        if (abs(kW_Out) < PminNoVars) then
          Begin
            kvar_out := 0.0;  // Check minimum P for Q gen/absorption. if PminNoVars is disabled (-1), this will always be false
            CurrentkvarLimit:=0; CurrentkvarLimitNeg:= 0.0;  // Set current limit to be used by InvControl's Check_Qlimits procedure.
          End
        else if varMode = VARMODEPF Then
          Begin
            IF PFnominal = 1.0 Then kvar_out := 0.0
            ELSE
              Begin
                kvar_out := kW_out * sqrt(1.0/SQR(PFnominal) - 1.0) * sign(PFnominal);
                // Check limits
                if abs(kW_out) < PminkvarLimit then // straight line limit check. if PminkvarLimit is disabled (-1), this will always be false.
                  begin
                    // straight line starts at max(PminNoVars, CutOutkWAC)
                    // if CutOut differs from CutIn, take cutout since it is assumed that CutOut <= CutIn always.
                    if abs(kW_out) >= max(PminNoVars, CutOutkWAC) then
                      begin
                        if (kvar_Out > 0.0) then
                          begin
                            Qramp_limit := Fkvarlimit / PminkvarLimit * abs(kW_out);   // generation limit
                            CurrentkvarLimit    := Qramp_limit;  // For use in InvControl
                          end
                        else if (kvar_Out < 0.0) then
                          begin
                            Qramp_limit := Fkvarlimitneg / PminkvarLimit * abs(kW_out);   // absorption limit
                            CurrentkvarLimitNeg := Qramp_limit;  // For use in InvControl
                          end;
                        if abs(kvar_Out) > Qramp_limit then kvar_out := Qramp_limit * sign(kW_out) * sign(PFnominal);
                      end;
                  end
                Else if (abs(kvar_Out) > Fkvarlimit) or (abs(kvar_Out) > Fkvarlimitneg) then  // Other cases, check normal kvarLimit and kvarLimitNeg
                  begin
                    if (kvar_Out > 0.0) then kvar_out := Fkvarlimit * sign(kW_out) * sign(PFnominal)
                    else kvar_out := Fkvarlimitneg * sign(kW_out) * sign(PFnominal);
                    if PF_Priority then // Forces constant power factor when kvar limit is exceeded and PF Priority is true.
                      Begin
                        kW_out :=  kvar_out* sqrt(1.0/(1.0 - Sqr(PFnominal)) - 1.0) * sign(PFnominal);
                      End;
                  end;
              end;
          End
        ELSE     // kvar is specified
          Begin
            // Check limits
            if abs(kW_out) < PminkvarLimit then // straight line limit check. if PminkvarLimit is disabled (-1), this will always be false.
              begin
                  // straight line starts at max(PminNoVars, CutOutkWAC)
                  // if CutOut differs from CutIn, take cutout since it is assumed that CutOut <= CutIn always.
                  if abs(kW_out) >= max(PminNoVars, CutOutkWAC) then
                  begin
                    if (kvarRequested > 0.0) then
                      begin
                        Qramp_limit := Fkvarlimit / PminkvarLimit * abs(kW_out);   // generation limit
                        CurrentkvarLimit    := Qramp_limit;   // For use in InvControl
                      end
                    else if (kvarRequested < 0.0) then
                      begin
                        Qramp_limit := Fkvarlimitneg / PminkvarLimit * abs(kW_out);   // absorption limit
                        CurrentkvarLimitNeg := Qramp_limit;   // For use in InvControl
                      end;
                    if abs(kvarRequested) > Qramp_limit then kvar_out := Qramp_limit * sign(kvarRequested)
                    else kvar_out := kvarRequested;
                  end;
              end
            else if ((kvarRequested > 0.0) and (abs(kvarRequested) >= Fkvarlimit)) or ((kvarRequested < 0.0) and (abs(kvarRequested) >= Fkvarlimitneg)) then
              begin
                if (kvarRequested > 0.0) then kvar_Out := Fkvarlimit * sign(kvarRequested)
                else kvar_Out := Fkvarlimitneg * sign(kvarRequested);
                if (varMode = VARMODEKVAR) and PF_Priority and FWPMode then
                  begin
                    kW_out := abs(kvar_out) * sqrt(1.0/(1.0 - Sqr(Fpf_wp_nominal)) - 1.0) * sign(kW_out);
                  end
                // Forces constant power factor when kvar limit is exceeded and PF Priority is true. Temp PF is calculated based on kvarRequested
                else if PF_Priority and (not FVVMode or not FDRCMode or not FWVmode or not FAVRMode) then
                  Begin
                    if abs(kvarRequested) > 0.0  then
                      begin
                        TempPF := cos(arctan(abs(kvarRequested/kW_out)));
                        kW_out := abs(kvar_out) * sqrt(1.0/(1.0 - Sqr(TempPF)) - 1.0) * sign(kW_out);
                      end;
                  End;
              end
            else kvar_Out := kvarRequested;
          End;
        if (FInverterON = FALSE) and (FVarFollowInverter = TRUE) then kvar_out := 0.0;
        // Limit kvar and kW so that kVA of inverter is not exceeded
        kVA_Gen := Sqrt(Sqr(kW_out) + Sqr(kvar_out));
        If kVA_Gen > FkVArating Then
          Begin
            If (varMode = VARMODEPF) and PF_Priority then
              // Operates under constant power factor when kVA rating is exceeded. PF must be specified and PFPriority must be TRUE
              Begin
                kW_out := FkVArating * abs(PFnominal);
                kvar_out := FkVArating * sqrt(1 - Sqr(PFnominal)) * sign(PFnominal);
              End
            Else if (varMode = VARMODEKVAR) and PF_Priority and FWPMode then
              begin
                kW_out := FkVArating * abs(Fpf_wp_nominal) * sign(kW_out);
                kvar_out := FkVArating * abs(sin(ArcCos(Fpf_wp_nominal))) * sign(kvarRequested)
              end
            Else if (varMode = VARMODEKVAR) and PF_Priority and (not FVVMode or not FDRCMode or not FWVmode or not FAVRMode) then
              // Operates under constant power factor (PF implicitly calculated based on kw and kvar)
              Begin
                if abs(kvar_out) = Fkvarlimit then
                  begin   // for handling cases when kvar limit and inverter's kVA limit are exceeded
                    kW_out := FkVArating * abs(TempPF) * sign(kW_out);
                  end
                else
                  begin
                    kW_out := FkVArating * abs(cos(ArcTan(kvarRequested/kW_out))) * sign(kW_out);
                   end;
                kvar_out := FkVArating * abs(sin(ArcCos(kW_out/FkVArating))) * sign(kvarRequested);
              end
            else
              Begin
                If P_Priority Then
                  Begin  // back off the kvar
                    If kW_out > FkVArating Then
                      Begin
                        kW_out   := FkVArating;
                        kvar_out := 0.0;
                      End
                    ELSE kvar_Out :=  Sqrt(SQR(FkVArating) - SQR(kW_Out)) * sign(kvar_Out);
                  End
                Else
                  kW_Out :=  Sqrt(SQR(FkVArating) - SQR(kvar_Out)) * sign(kW_Out);
              End;
          End;
        if (FInverterON = FALSE) and (FVarFollowInverter = TRUE) then kvar_out := 0.0;
      End;  {With PVSystemVars}
  end;

PROCEDURE TPVsystemObj.ComputekWkvar;
  Begin
    ComputePanelPower;   // apply irradiance
    ComputeInverterPower; // apply inverter eff after checking for cutin/cutout
  end;
// ===========================================================================================
PROCEDURE TPVsystemObj.ComputePanelPower;
  Begin
    With PVSystemVars Do
      Begin
        TempFactor := 1.0;
        If Assigned(Power_TempCurveObj) Then
          Begin
            TempFactor := Power_TempCurveObj.GetYValue(TshapeValue);  // pu Pmpp vs T (actual)
          End;
        PanelkW := FIrradiance * ShapeFactor.re * FPmpp * TempFactor;
      End;
  end;
PROCEDURE TPVsystemObj.CalcYPrim(ActorID : Integer);
  VAR
    i     : integer;
  Begin
    // Build only shunt Yprim
    // Build a dummy Yprim Series so that CalcV Does not fail
    If YprimInvalid[ActorID] Then
      Begin
        If YPrim_Shunt<>nil Then YPrim_Shunt.Free;
        YPrim_Shunt := TcMatrix.CreateMatrix(Yorder);
        IF YPrim_Series <> nil THEN Yprim_Series.Free;
        YPrim_Series := TcMatrix.CreateMatrix(Yorder);
        If YPrim <> nil Then  YPrim.Free;
        YPrim := TcMatrix.CreateMatrix(Yorder);
      End
    ELSE
      Begin
        YPrim_Shunt.Clear;
        YPrim_Series.Clear;
        YPrim.Clear;
      End;
    SetNominalPVSystemOuput(ActorID);
    CalcYPrimMatrix(YPrim_Shunt, ActorID);
    // Set YPrim_Series based on diagonals of YPrim_shunt  so that CalcVoltages Doesn't fail
    For i := 1 to Yorder Do Yprim_Series.SetElement(i, i, CmulReal(Yprim_Shunt.Getelement(i, i), 1.0e-10));
    YPrim.CopyFrom(YPrim_Shunt);
    // Account for Open Conductors
    Inherited CalcYPrim(ActorID);
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.StickCurrInTerminalArray(TermArray:pComplexArray; Const Curr:Complex; i:Integer);
 {Add the current into the proper location according to connection}
 {Reverse of similar routine in load  (Cnegates are switched)}
  VAR
    j     : Integer;
  Begin
    CASE Connection OF
      0:  Begin  //Wye
            Caccum(TermArray^[i], Curr );
            Caccum(TermArray^[Fnconds], Cnegate(Curr) ); // Neutral
          End;
      1:  Begin //DELTA
            Caccum(TermArray^[i], Curr );
            j := i + 1;
            If j > Fnconds Then j := 1;
            Caccum(TermArray^[j], Cnegate(Curr) );
          End;
    End;
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.WriteTraceRecord(const s:string);
  VAR
    i     : Integer;
  Begin
    Try
      If (Not InshowResults) Then
        Begin
          Append(TraceFile);
          Write(TraceFile,Format('%-.g, %d, %-.g, ',
                  [ActiveCircuit[ActiveActor].Solution.DynaVARs.t,
                   ActiveCircuit[ActiveActor].Solution.Iteration,
                   ActiveCircuit[ActiveActor].LoadMultiplier]),
                   GetSolutionModeID,', ',
                   GetLoadModel,', ',
                   VoltageModel:0,', ',
                  (Qnominalperphase*3.0/1.0e6):8:2,', ',
                  (Pnominalperphase*3.0/1.0e6):8:2,', ',
                  s,', ');
          For i := 1 to nphases Do Write(TraceFile,(Cabs(InjCurrent^[i])):8:1 ,', ');
          For i := 1 to nphases Do Write(TraceFile,(Cabs(ITerminal^[i])):8:1 ,', ');
          For i := 1 to nphases Do Write(TraceFile,(Cabs(Vterminal^[i])):8:1 ,', ');
          Writeln(TRacefile);
          CloseFile(TraceFile);
        End;
    Except
      On E:Exception Do
        Begin
        End;
    End;
  End;

// ===========================================================================================
PROCEDURE TPVsystemObj.DoConstantPQPVSystemObj(ActorID : Integer);
{Compute total terminal current for Constant PQ}
  VAR
    i               : Integer;
    PhaseCurr,
    DeltaCurr,
    VLN, VLL        : Complex;
    VmagLN,
    VmagLL          : Double;
    V012            : Array[0..2] of Complex;  // Sequence voltages
  Begin
    //Treat this just like the Load model
    CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array
    ZeroITerminal;
    CalcVTerminalPhase(ActorID); // get actual voltage across each phase of the load
    If ForceBalanced and (Fnphases=3) Then
      Begin  // convert to pos-seq only
        Phase2SymComp(Vterminal, @V012);
        V012[0] := CZERO; // Force zero-sequence voltage to zero
        V012[2] := CZERO; // Force negative-sequence voltage to zero
        SymComp2Phase(Vterminal, @V012);  // Reconstitute Vterminal as balanced
      End;
    FOR i := 1 to Fnphases Do
      Begin
        CASE Connection of
          0:  Begin  {Wye}
                VLN    := Vterminal^[i];
                VMagLN := Cabs(VLN);
                If CurrentLimited Then
                  Begin
                    {Current-Limited Model}
                    PhaseCurr := Conjg(Cdiv(Cmplx(Pnominalperphase, Qnominalperphase), VLN));
                    If Cabs(PhaseCurr) >  PVSystemvars.MaxDynPhaseCurrent Then
                      PhaseCurr := Conjg( Cdiv( PhaseCurrentLimit, CDivReal(VLN, VMagLN)) );
                  End
                Else
                  Begin
                   {The usual model}
                    IF (VMagLN <= VBaseMin) THEN PhaseCurr := Cmul(YEQ_Min, VLN)  // Below Vminpu use an impedance model
                   ELSE If (VMagLN > VBaseMax) THEN PhaseCurr := Cmul(YEQ_Max, VLN)  // above Vmaxpu use an impedance model
                   ELSE PhaseCurr := Conjg(Cdiv(Cmplx(Pnominalperphase, Qnominalperphase), VLN));  // Between Vminpu and Vmaxpu, constant PQ
                  End;
                StickCurrInTerminalArray(ITerminal, Cnegate(PhaseCurr), i);  // Put into Terminal array taking into account connection
                set_ITerminalUpdated(TRUE, ActorID);
                StickCurrInTerminalArray(InjCurrent, PhaseCurr, i);  // Put into Terminal array taking into account connection
              End;
          1:  Begin  {Delta}
                VLL    := Vterminal^[i];
                VMagLL := Cabs(VLL);
                If CurrentLimited Then
                  Begin
                    {Current-Limited Model}
                    DeltaCurr := Conjg(Cdiv(Cmplx(Pnominalperphase, Qnominalperphase), VLL));
                    If Cabs(DeltaCurr)*SQRT3 >  PVSystemvars.MaxDynPhaseCurrent Then
                      DeltaCurr := Conjg( Cdiv( PhaseCurrentLimit, CDivReal(VLL, VMagLL/SQRT3)) );
                  End
                Else
                  Begin
                   {The usual model}
                    case Fnphases of
                      2,3: VMagLN := VmagLL/SQRT3;
                    else
                        VMagLN := VmagLL;
                    end;
                    IF   VMagLN <= VBaseMin THEN DeltaCurr := Cmul(CdivReal(YEQ_Min, 3.0), VLL)  // Below 95% use an impedance model
                    ELSE If VMagLN > VBaseMax THEN DeltaCurr := Cmul(CdivReal(YEQ_Max, 3.0), VLL)  // above 105% use an impedance model
                    ELSE  DeltaCurr := Conjg(Cdiv(Cmplx(Pnominalperphase, Qnominalperphase), VLL));  // Between 95% -105%, constant PQ
                  End;
                StickCurrInTerminalArray(ITerminal, Cnegate(DeltaCurr), i);  // Put into Terminal array taking into account connection
                set_ITerminalUpdated(TRUE, ActorID);
                StickCurrInTerminalArray(InjCurrent, DeltaCurr, i);  // Put into Terminal array taking into account connection
              End;
        END;
      End;
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.DoConstantZPVSystemObj;
{constant Z model}
  VAR
    i           : Integer;
    Curr,
    YEQ2        : Complex;
    V012        : Array[0..2] of Complex;  // Sequence voltages
  Begin
    // Assume YEQ is kept up to date
    CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array
    CalcVTerminalPhase(ActorID); // get actual voltage across each phase of the load
    If ForceBalanced and (Fnphases=3) Then
      Begin  // convert to pos-seq only
        Phase2SymComp(Vterminal, @V012);
        V012[0] := CZERO; // Force zero-sequence voltage to zero
        V012[2] := CZERO; // Force negative-sequence voltage to zero
        SymComp2Phase(Vterminal, @V012);  // Reconstitute Vterminal as balanced
      End;
    ZeroITerminal;
    If (Connection=0) Then YEQ2 := YEQ        // YEQ is always line to neutral
    Else YEQ2 := CdivReal(YEQ, 3.0);          // YEQ for delta connection
    FOR i := 1 to Fnphases Do
      Begin
        Curr := Cmul(YEQ2, Vterminal^[i]);
        StickCurrInTerminalArray(ITerminal, Cnegate(Curr), i);  // Put into Terminal array taking into account connection
        set_ITerminalUpdated(TRUE, ActorID);
        StickCurrInTerminalArray(InjCurrent, Curr, i);  // Put into Terminal array taking into account connection
      End;
  End;

// =================================================================DOUSERMODEL==========================
PROCEDURE TPVsystemObj.DoUserModel;
{Compute total terminal Current from User-written model}
  VAR
    i       : Integer;
  Begin
    CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array
    If UserModel.Exists then     // Check automatically selects the usermodel If true
      Begin
        UserModel.FCalc (Vterminal, Iterminal);
        set_ITerminalUpdated(TRUE, ActorID);
        With ActiveCircuit[ActorID].Solution Do
          Begin          // Negate currents from user model for power flow PVSystem element model
            FOR i := 1 to FnConds Do Caccum(InjCurrent^[i], Cnegate(Iterminal^[i]));
          End;
      End
    Else DoSimpleMsg('PVSystem.' + name + ' model designated to use user-written model, but user-written model is not defined.', 567);
  End;
// ===============================================================DoDynamicMode============================
PROCEDURE TPVsystemObj.DoDynamicMode;
{Compute Total Current and add into InjTemp}
  Var
    PolarN        : Polar;
    i             : Integer;
    V012,
    I012          : Array[0..2] of Complex;
    NeutAmps,
    Vthev         : Complex;
    iActual,                // To determine the output values for current based on the inverter features
    Theta         : Double; // phase angle of thevinen source
    {-------------- Internal Proc -----------------------}
    Procedure CalcVthev_Dyn(const V:Complex);
    {
       If the voltage magnitude drops below 15% or so, the accuracy of determining the
       phase angle gets flaky. This algorithm approximates the action of a PLL that will
       hold the last phase angle until the voltage recovers.
    }
      Begin
        {Try to keep in phase with terminal voltage}
        With PVSystemVars Do
          Begin
            If Cabs(V) > 0.20 * Vbase Then  Theta := ThetaDyn + (Cang(V) - InitialVangle)
            Else  Theta := LastThevAngle;
            Vthev := pclx(VthevMagDyn, Theta);
            LastThevAngle :=  Theta;     // remember this for angle persistence
          End;
      End;
Begin
  if not GFM_Mode then
  Begin
    CalcYPrimContribution(InjCurrent, ActorID);  // Init InjCurrent Array  and computes VTerminal
    {Inj = -Itotal (in) - Yprim*Vtemp}
    CASE VoltageModel of
      3 :       If UserModel.Exists Then       // auto selects model (User model)
                  Begin   {We have total currents in Iterminal}
                    UserModel.FCalc(Vterminal, Iterminal);  // returns terminal currents in Iterminal
                  End
                ELSE
                  Begin
                    DoSimpleMsg(Format('Dynamics model missing for PVSystem.%s ',[Name]), 5671);
                    SolutionAbort := TRUE;
                  End;
    ELSE  {All other models }
      {This model has no limitation in the nmber of phases and is ideally unbalanced (no dq-dv, but is implementable as well)}
      // First, get the phase angles for the currents
      NeutAmps    :=  cmplx( 0, 0 );
      for i := 1 to FNphases do
      Begin
        with myDynVars do
        Begin
          // determine if the PV panel is ON
          if ( it[ i - 1 ] <= iMaxPPhase ) or GFM_Mode then
            iActual       :=  it[i -1]
          else
            iActual       :=  iMaxPPhase;
          //--------------------------------------------------------
          //if iActual < MinAmps then iActual :=  0;                // To mach with the %CutOut property
          //if not GFM_Mode then
          PolarN        :=  topolar( iActual, Vgrid[i - 1].ang);     // Output Current estimated for active power
          Iterminal^[i] :=  cnegate( ptocomplex(PolarN) );
          NeutAmps      :=  csub( NeutAmps, Iterminal^[i] );
        End;
      End;
      if FnConds > FNphases then Iterminal^[FnConds] :=  NeutAmps;
    END;
    {Add it into inj current array}
    FOR i := 1 to FnConds Do Caccum(InjCurrent^[i], Cnegate(Iterminal^[i]));
    set_ITerminalUpdated(TRUE, ActorID);
  End
  Else
  Begin
    myDynVars.BaseV   :=  myDynVars.BasekV * 1000 * ( myDynVars.it[0] / myDynVars.IMaxPPhase );  // Uses dynamics model as reference
    myDynVars.CalcGFMVoltage( ActorID, NPhases, Vterminal );
    YPrim.MVMult( InjCurrent, Vterminal );
  End;

End;
// ====================================================================DoHarmonicMode=======================
PROCEDURE TPVsystemObj.DoHarmonicMode(ActorID : Integer);
{Compute Injection Current Only when in harmonics mode}
{Assumes spectrum is a voltage source behind subtransient reactance and YPrim has been built}
{Vd is the fundamental frequency voltage behind Xd" for phase 1}
  VAR
    i                   : Integer;
    E                   : Complex;
    PVSystemHarmonic    : double;
  Begin
    ComputeVterminal(ActorID);
    WITH ActiveCircuit[ActorID].Solution, PVSystemVars Do
      Begin
        PVSystemHarmonic := Frequency/PVSystemFundamental;
        If SpectrumObj <> Nil Then E := CmulReal(SpectrumObj.GetMult(PVSystemHarmonic), VThevHarm) // Get base harmonic magnitude
        Else E := CZERO;
        RotatePhasorRad(E, PVSystemHarmonic, ThetaHarm);  // Time shift by fundamental frequency phase shift
        FOR i := 1 to Fnphases DO
          Begin
            cBuffer[i] := E;
            If i < Fnphases Then RotatePhasorDeg(E, PVSystemHarmonic, -120.0);  // Assume 3-phase PVSystem element
          End;
      END;
    {Handle Wye Connection}
    IF Connection=0 THEN cbuffer[Fnconds] := Vterminal^[Fnconds];  // assume no neutral injection voltage
    {Inj currents = Yprim (E) }
    YPrim.MVMult(InjCurrent,@cBuffer);
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.CalcVTerminalPhase(ActorID : Integer);
  VAR
    i, j        : Integer;
  Begin
    { Establish phase voltages and stick in Vterminal}
    Case Connection OF
      0 :   Begin
              With ActiveCircuit[ActorID].Solution Do
                FOR i := 1 to Fnphases Do Vterminal^[i] := VDiff(NodeRef^[i], NodeRef^[Fnconds], ActorID);
            End;
     1  :   Begin
              With ActiveCircuit[ActorID].Solution Do
                FOR i := 1 to Fnphases Do
                  Begin
                    j := i + 1;
                    If j > Fnconds Then j := 1;
                    Vterminal^[i] := VDiff( NodeRef^[i] , NodeRef^[j], ActorID);
                  End;
            End;
    End;
    PVSystemSolutionCount := ActiveCircuit[ActorID].Solution.SolutionCount;
  End;
// ===========================================================================================
(*
PROCEDURE TPVsystemObj.CalcVTerminal;
{Put terminal voltages in an array}
Begin
   ComputeVTerminal;
   PVSystemSolutionCount := ActiveCircuit[ActiveActor].Solution.SolutionCount;
End;
*)

// ============================================CalcPVSystemModelContribution===============================================
PROCEDURE TPVsystemObj.CalcPVSystemModelContribution(ActorID : Integer);
// Calculates PVSystem element current and adds it properly into the injcurrent array
// routines may also compute ITerminal  (ITerminalUpdated flag)
  Begin
    set_ITerminalUpdated(FALSE, ActorID);
    WITH  ActiveCircuit[ActorID], ActiveCircuit[ActorID].Solution DO
      Begin
        IF    IsDynamicModel THEN  DoDynamicMode(ActorID)
        ELSE IF IsHarmonicModel and (Frequency <> Fundamental) THEN  DoHarmonicMode(ActorID)
        ELSE
        Begin
          //  compute currents and put into InjTemp array;
          if GFM_Mode then DoGFM_Mode(ActorID)
          else
          Begin
            CASE VoltageModel OF
              1: DoConstantPQPVSystemObj(ActorID);
              2: DoConstantZPVSystemObj(ActorID);
              3: DoUserModel(ActorID);
              ELSE
                DoConstantPQPVSystemObj(ActorID);  // for now, until we implement the other models.
            End;
          End;
        END; {ELSE}
      END; {WITH}
    {When this is Done, ITerminal is up to date}
  End;
// ==========================================CalcInjCurrentArray=================================================
PROCEDURE TPVsystemObj.CalcInjCurrentArray(ActorID : Integer);
  // Difference between currents in YPrim and total current
  Begin
    // Now Get Injection Currents
    If PVSystemObjSwitchOpen Then ZeroInjCurrent
    Else CalcPVSystemModelContribution(ActorID);
  End;
// =========================================GetTerminalCurrents==================================================
PROCEDURE TPVsystemObj.GetTerminalCurrents(Curr:pComplexArray; ActorID : Integer);
// Compute total Currents
  Begin
    WITH ActiveCircuit[ActorID].Solution  DO
      Begin
        If IterminalSolutionCount[ActorID] <> ActiveCircuit[ActorID].Solution.SolutionCount Then
          Begin     // recalc the contribution
            IF Not PVSystemObjSwitchOpen Then CalcPVSystemModelContribution(ActorID);  // Adds totals in Iterminal as a side effect
          End;
        Inherited GetTerminalCurrents(Curr,ActorID);
      End;
    If (DebugTrace) Then WriteTraceRecord('TotalCurrent');
  End;
// ===========================================INJCURRENTS================================================
FUNCTION TPVsystemObj.InjCurrents(ActorID : Integer):Integer;
  Begin
    With ActiveCircuit[ActorID].Solution Do
      Begin
        If LoadsNeedUpdating Then SetNominalPVSystemOuput(ActorID); // Set the nominal kW, etc for the type of solution being Done
        CalcInjCurrentArray(ActorID);          // Difference between currents in YPrim and total terminal current
        If (DebugTrace) Then WriteTraceRecord('Injection');
        // Add into System Injection Current Array
        Result := Inherited InjCurrents(ActorID);
      End;
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.GetInjCurrents(Curr:pComplexArray; ActorID : Integer);
// Gives the currents for the last solution performed
// Do not call SetNominal, as that may change the load values
  VAR
    i     : Integer;
  Begin
    CalcInjCurrentArray(ActorID);  // Difference between currents in YPrim and total current
    TRY
      // Copy into buffer array
      FOR i := 1 TO Yorder Do Curr^[i] := InjCurrent^[i];
      EXCEPT ON E: Exception Do
        DoErrorMsg('PVSystem Object: "' + Name + '" in GetInjCurrents FUNCTION.', E.Message, 'Current buffer not big enough.', 568);
    End;
  End;

// ===========================================================================================
PROCEDURE TPVsystemObj.ResetRegisters;
  VAR
    i       : Integer;
  Begin
    For i := 1 to NumPVSystemRegisters Do Registers[i]   := 0.0;
    For i := 1 to NumPVSystemRegisters Do Derivatives[i] := 0.0;
    FirstSampleAfterReset := True;  // initialize for trapezoidal integration
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.Integrate(Reg:Integer; const Deriv:Double; Const Interval:Double);
  Begin
    IF ActiveCircuit[ActiveActor].TrapezoidalIntegration THEN
      Begin
        {Trapezoidal Rule Integration}
        If Not FirstSampleAfterReset Then Registers[Reg] := Registers[Reg] + 0.5 * Interval * (Deriv + Derivatives[Reg]);
      End
    ELSE   {Plain Euler integration}
      Registers[Reg] := Registers[Reg] + Interval * Deriv;
      Derivatives[Reg] := Deriv;
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.TakeSample(ActorID: Integer);
// Update Energy from metered zone
  VAR
    S             : Complex;
    Smag          : double;
    HourValue     : Double;
  Begin
    // Compute energy in PVSystem element branch
    IF  Enabled THEN
      Begin
        S := cmplx(Get_PresentkW, Get_Presentkvar);
        Smag := Cabs(S);
        HourValue := 1.0;

        WITH ActiveCircuit[ActorID].Solution Do
          Begin
            IF ActiveCircuit[ActorID].PositiveSequence THEN
              Begin
                S    := CmulReal(S, 3.0);
                Smag := 3.0*Smag;
              End;
            Integrate            (Reg_kWh,   S.re, IntervalHrs);   // Accumulate the power
            Integrate            (Reg_kvarh, S.im, IntervalHrs);
            SetDragHandRegister  (Reg_MaxkW, abs(S.re));
            SetDragHandRegister  (Reg_MaxkVA, Smag);
            Integrate            (Reg_Hours, HourValue, IntervalHrs);  // Accumulate Hours in operation
            Integrate            (Reg_Price, S.re*ActiveCircuit[ActorID].PriceSignal * 0.001 , IntervalHrs);  //
            FirstSampleAfterReset := False;
          End;
      End;
  End;
PROCEDURE TPVsystemObj.UpdatePVSystem;
{Update PVSystem levels}
  Begin
    { Do Nothing}
  End;
FUNCTION TPVsystemObj.Get_PresentkW:Double;
  Begin
    Result := Pnominalperphase * 0.001 * Fnphases;
  End;
FUNCTION TPVsystemObj.Get_PresentIrradiance: Double;
  Begin
    Result := PVSystemVars.FIrradiance * ShapeFactor.re;
  End;
FUNCTION TPVsystemObj.Get_PresentkV: Double;
  Begin
    Result := PVSystemVars.kVPVSystemBase;
  End;
FUNCTION TPVsystemObj.Get_Presentkvar:Double;
  Begin
    Result := Qnominalperphase * 0.001 * Fnphases;
  End;
FUNCTION  TPVsystemObj.Get_VarFollowInverter:Boolean;
  Begin
    if FVarFollowInverter then Result := TRUE else Result := FALSE;
  End;
PROCEDURE TPVsystemObj.DumpProperties(VAR F:TextFile; Complete:Boolean);
  VAR
    i, idx      : Integer;
  Begin
    Inherited DumpProperties(F, Complete);
    With ParentClass Do
      begin                              // HERE
        For i := 1 to NumProperties Do
          Begin
            idx := PropertyIdxMap^[i] ;
            Case idx of
              propUSERDATA: Writeln(F,'~ ',PropertyName^[i],'=(',PropertyValue[idx],')')
              Else
                Writeln(F,'~ ',PropertyName^[i],'=',PropertyValue[idx]);
            End;
          End;
      end;
    Writeln(F);
  End;

// ============================================================InitHarmonics===============================
PROCEDURE TPVsystemObj.InitHarmonics(ActorID : Integer);
// This routine makes a thevenin equivalent behis the reactance spec'd in %R and %X
  VAR
    i,
    j         : Integer;
    E, Va     : complex;
  Begin
    YprimInvalid[ActorID]       := TRUE;  // Force rebuild of YPrims
    PVSystemFundamental := ActiveCircuit[ActorID].Solution.Frequency ;  // Whatever the frequency is when we enter here.
    {Compute reference Thevinen voltage from phase 1 current}
    ComputeIterminal(ActorID);  // Get present value of current
    With ActiveCircuit[ActorID].solution Do
      begin
        Case Connection of
          0:  Begin {wye - neutral is explicit}
                if not ADIakoptics or (ActorID = 1) then
                  Va  := Csub(NodeV^[NodeRef^[1]], NodeV^[NodeRef^[Fnconds]])
                else
                  Va  := Csub(VoltInActor1(NodeRef^[1]), VoltInActor1(NodeRef^[Fnconds]));
              End;
          1:  Begin  {delta -- assume neutral is at zero}
                if not ADiakoptics or (ActorID = 1) then
                  Va := NodeV^[NodeRef^[1]]
                else
                  Va := VoltInActor1(NodeRef^[1]);

              End;
        End;
      end;
    With PVSystemVars do
      Begin
        YEQ := Cinv(Cmplx(RThev, XThev));           // used for current calcs  Always L-N
        E := Csub(Va, Cmul(Iterminal^[1], cmplx(Rthev, Xthev)));
        Vthevharm := Cabs(E);   // establish base mag and angle
        ThetaHarm := Cang(E);
      End;
  End;

// ===============================================================InitStateVars============================
PROCEDURE TPVsystemObj.InitStateVars(ActorID : Integer);
// for going into dynamics mode
  VAR
    NumData,
    i,
    j             : Integer;
    BaseZt        : Double;

  Begin
    YprimInvalid[ActorID] := TRUE;  // Force rebuild of YPrims
    With PVSystemVars, myDynVars do
    Begin

      if ( Length(PICtrl) = 0 ) or ( Length(PICtrl) < Fnphases ) then
      Begin
        setlength(PICtrl, Fnphases);
        for i := 0 to ( Fnphases - 1 ) do
        Begin
          PICtrl[i]      :=  TPICtrl.Create;
          PICtrl[i].Kp   :=  myDynVars.kP;
          PICtrl[i].kNum :=  0.9502;
          PICtrl[i].kDen :=  0.04979;
        End;
      End;
      SafeMode    :=  False;
      With ActiveCircuit[ActorID].Solution Do
      Begin
        case ActiveCircuit[ActiveActor].ActiveLoadShapeClass of
            USEDAILY:  Begin CalcDailyMult(DynaVars.dblHour);  CalcDailyTemperature(DynaVars.dblHour);  End;
            USEYEARLY: Begin CalcYearlyMult(DynaVars.dblHour); CalcYearlyTemperature(DynaVars.dblHour); End;
            USEDUTY:   Begin CalcDutyMult(DynaVars.dblHour);   CalcDutyTemperature(DynaVars.dblHour);   End;
        else
            ShapeFactor := CDOUBLEONE     // default to 1 + j1 if not known
        end;
      End;

      ComputePanelPower();
      NumPhases     := Fnphases;     // set Publicdata vars
      NumConductors := Fnconds;
      Conn          := Connection;
      // Sets the length of State vars to cover the num of phases
      InitDynArrays(NumPhases);

      if NumPhases > 1 then
        BasekV  :=  PresentkV / sqrt(3)
      else
        BasekV  :=  PresentkV;

      BaseZt      :=  0.01 * ( SQR( PresentkV ) / FkVArating ) * 1000;
      MaxVS       :=  ( 2 - ( SMThreshold / 100 ) ) * BasekV * 1000;
      MinVS       :=  ( SMThreshold / 100 ) * BasekV * 1000;
      MinAmps     :=  ( FpctCutOut / 100 ) *  ( ( FkVArating / BasekV ) / NumPhases );
      ResetIBR    :=  False;
      iMaxPPhase  :=  ( FkVArating / BasekV ) / NumPhases;
      if pctX = 0 then
        pctX        :=  50;                                                             // forces the value to 50% in dynamics mode if not given

      XThev       :=  pctX * BaseZt;
      RS          :=  pctR * BaseZt;
      Zthev       :=  Cmplx(RS, XThev) ;
      YEQ         :=  Cinv(Zthev);                                                       // used for current calcs  Always L-N

      ComputeIterminal(ActorID);
      With ActiveCircuit[ActorID].Solution Do
      Begin
        LS            :=  XThev / (2 * PI * DefaultBaseFreq);

        For i := 0 to (NPhases - 1) Do
        Begin
          dit[i]    :=  0;
          Vgrid[i]:=  ctopolar( NodeV^[NodeRef^[i + 1]] );
          if GFM_Mode then it[i] :=  0
          else             it[i]   :=  ( ( PanelkW * 1000 ) / Vgrid[i].mag ) / NumPhases;
          m[i]    :=  ( ( RS * it[i] ) + Vgrid[i].mag ) / RatedVDC;                     // Duty factor in terms of actual voltage

          if m[i] > 1 then m[i] :=  1;
          ISPDelta[i] :=  0;
          AngDelta[i] :=  0;
        End;
        if DynamicEqObj <> nil then
          for i := 0 to High(DynamicEqVals) do  DynamicEqVals[i][1] :=  0.0;            // Initializes the memory values for the dynamic equation
      End;
    End;

  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.IntegrateStates(ActorID : Integer);
// dynamics mode integration routine
 VAR
    GFMUpdate : Boolean;              // To avoid updating the IBR if current limit reached
    NumData,
    k,
    j,
    i         : Integer;
    IPresent  : Double;               // present amps per phase
    myCurr    : Array of Complex;     // For storing the present currents when using current limiter
  Begin
    // Compute Derivatives and Then integrate
    ComputeIterminal(ActorID);
    If Usermodel.Exists  Then Usermodel.Integrate   // Checks for existence and Selects
    Else
    Begin

      // Compute actual power output for the PVPanel
      With ActiveCircuit[ActorID].Solution Do
      Begin
        case ActiveCircuit[ActorID].ActiveLoadShapeClass of
            USEDAILY:  Begin CalcDailyMult(DynaVars.dblHour);  CalcDailyTemperature(DynaVars.dblHour);  End;
            USEYEARLY: Begin CalcYearlyMult(DynaVars.dblHour); CalcYearlyTemperature(DynaVars.dblHour); End;
            USEDUTY:   Begin CalcDutyMult(DynaVars.dblHour);   CalcDutyTemperature(DynaVars.dblHour);   End;
        else
            ShapeFactor := CDOUBLEONE     // default to 1 + j1 if not known
        end;
      End;
      ComputePanelPower();
      With ActiveCircuit[ActorID].Solution, PVSystemVars, myDynVars Do
      Begin
        IMaxPPhase :=  ( PanelkW / BasekV ) / NumPhases;
        for i := 0 to (NumPhases - 1) do                                              // multiphase approach
        Begin
            With DynaVars Do
            If (IterationFlag = 0) Then
            Begin {First iteration of new time step}
              itHistory[i] := it[i] + 0.5*h*dit[i];
            End;
            Vgrid[i]    :=  ctopolar(NodeV^[NodeRef^[i + 1]]);                          // Voltage at the Inv terminals
            // Compute the actual target (Amps)

            if not GFM_Mode then
            Begin
              ISP   :=  ( ( PanelkW * 1000 ) / Vgrid[i].mag ) / NumPhases;
              if ISP > IMaxPPhase then  ISP :=  IMaxPPhase;
              if ( Vgrid[i].mag < MinVS ) then ISP  :=  0.01;                                 // turn off the inverter
            End
            else
            Begin
              if ResetIBR then  VDelta[i]   :=  ( 0.001 - ( Vgrid[i].mag / 1000 ) ) / BasekV
              else              VDelta[i]   :=  ( BasekV - ( Vgrid[i].mag / 1000 ) ) / BasekV;
              GFMUpdate     :=  True;
              // Checks if there is current limit set
              if ILimit > 0 then
              Begin
                setlength(myCurr, NPhases + 1);
                GetCurrents(@myCurr[0], ActorID);
                for j := 0 to ( Nphases - 1 ) do
                Begin
                  IPresent    :=  ctopolar( myCurr[j] ).mag;
                  GFMUpdate   :=  GFMUpdate and ( IPresent < ( ILimit * VError ) );
                End;
              End;
              if ( abs(VDelta[i]) > CtrlTol ) and GFMUpdate then
              BEgin
                ISPDelta[i] :=  ISPDelta[i] + ( IMaxPPhase * VDelta[i] ) * kP * 100;
                if ISPDelta[i] > IMaxPPhase then ISPDelta[i] :=  IMaxPPhase
                else  if ISPDelta[i] < 0   then ISPDelta[i] :=  0.01;
              End;
              ISP         :=  ISPDelta[i];
              FixPhaseAngle(ActorID, i);
            End;
            if DynamicEqObj <> nil then                                                 // Loads values into dynamic expression if any
            Begin
              NumData   :=  ( length(DynamicEqPair) div 2 )  - 1 ;
              DynamicEqVals[DynOut[0]][0] :=  it[i];                                    // brings back the current values/phase
              DynamicEqVals[DynOut[0]][1] :=  dit[i];

              for j := 0 to NumData do
              Begin
                if not DynamicEqObj.IsInitVal(DynamicEqPair[( j * 2 ) + 1]) then        // it's not intialization
                Begin
                  case DynamicEqPair[( j * 2 ) + 1] of
                    2:  DynamicEqVals[DynamicEqPair[ j * 2 ]][0] := Vgrid[i].mag;       // volt per phase
                    4:  ;                                                               // Nothing for this object (current)
                    10: DynamicEqVals[DynamicEqPair[ j * 2 ]][0] := RatedVDC;
                    11: Begin
                          SolveModulation( i, ActorID, @PICtrl[i] );
                          DynamicEqVals[DynamicEqPair[ j * 2 ]][0] := m[i]
                        End
                  else
                    DynamicEqVals[DynamicEqPair[ j * 2 ]][0] := PCEValue[1, DynamicEqPair[( j * 2 ) + 1], ActorID];
                  end;
                End;
              End;
              DynamicEqObj.SolveEq(DynamicEqVals);                                      // solves the differential equation using the given dynamic expression
            End
            else
              SolveDynamicStep( i, ActorID, @PICtrl[i] );                               // Solves dynamic step for inverter (no dynamic expression)

            // Trapezoidal method
            With DynaVars Do
            Begin
              if DynamicEqObj <> nil then dit[i]:=  DynamicEqVals[DynOut[0]][1];
              it[i] := itHistory[i] + 0.5*h*dit[i];
            End;

        End;
      End;
    End
  End;

// ===========================================================Get_Variable================================
FUNCTION TPVsystemObj.Get_Variable(i: Integer): Double;
{Return variables one at a time}
  VAR
    N, k      : Integer;
  Begin
    Result := -9999.99;  // error return value; no state fars
    If i < 1 Then Exit;
    // for now, report kWhstored and mode
    With PVSystemVars, myDynVars Do
      CASE i of
        1: Result := PresentIrradiance;
        2: Result := PanelkW;
        3: Result := TempFactor;
        4: Result := EffFactor;
        5: Result := Vreg;
        6: Result := Vavg;
        7: Result := VVOperation;
        8: Result := VWOperation;
        9: Result := DRCOperation;
        10:Result := VVDRCOperation;
        11:Result := WPOperation;
        12:Result := WVOperation;
        13:Result := PanelkW * EffFactor;
        ELSE
        Begin
          with myDynVars do       // Dynamic state variables read
              Result  :=  Get_InvDynValue( i - 14, NumPhases );
          If UserModel.Exists Then
          Begin
            N := UserModel.FNumVars;
            k := (i-NumPVSystemVariables);
            If k <= N Then
              Begin
                Result := UserModel.FGetVariable(k);
                Exit;
              End;
          End
        End;
      END;
  End;
function  TPVsystemObj.Get_InverterON:Boolean;
  begin
    Result := FInverterON;
  end;
// ============================================================Get_Varmode===============================
function TPVsystemObj.Get_Varmode: Integer;
  begin
    Result := FvarMode;
  end;
// ============================================================Get_VWmode===============================
function TPVsystemObj.Get_VWmode: Boolean;
  begin
    Result := FVWmode;    // TRUE if volt-watt mode                                   //  engaged from InvControl (not ExpControl)
  end;
// ============================================================Get_VVmode===============================
function TPVsystemObj.Get_VVmode: Boolean;
  begin
    Result :=FVVmode;                                                                 //  engaged from InvControl (not ExpControl)
  end;
// ============================================================Get_WPmode===============================
function TPVsystemObj.Get_WPmode: Boolean;
  begin
    Result := FWPmode;                                                                //  engaged from InvControl (not ExpControl)
  end;
// ============================================================Get_WVmode===============================
function TPVsystemObj.Get_WVmode: Boolean;
  begin
    Result := FWVmode;                                                                //  engaged from InvControl (not ExpControl)
  end;
// ============================================================Get_DRCmode===============================
function TPVsystemObj.Get_DRCmode: Boolean;
  begin
    Result := FDRCmode;                                                               //  engaged from InvControl (not ExpControl)
  end;

// ============================================================Get_AVRmode===============================
function TPVsystemObj.Get_AVRmode: Boolean;
  begin
    Result := FAVRmode;                                                               //  engaged from InvControl (not ExpControl)
  end;
// ============================================================kWOut_Calc===============================

// for CIM export
function TPVSystemObj.Get_Pmin:double;
begin
  Result :=  min (FPctCutIn, FPctCutOut) * kVARating / 100.0;
end;

function TPVSystemObj.Get_Pmax:double;
begin
  Result := Pmpp;
end;

function TPVSystemObj.Get_QMaxInj:double;
begin
  Result := PVSystemVars.Fkvarlimit;
  if not kvarlimitset then Result:=0.25 * kvarating; // unlike storage, defaults to category A
end;

function TPVSystemObj.Get_QMaxAbs:double;
begin
  Result := PVSystemVars.FkvarlimitNeg;
  if not kvarlimitnegset then Result:=0.25 * kvarating; // unlike storage, defaults to category A
end;

function TPVSystemObj.Get_pMaxUnderPF:double;
var
  q: Double;
begin
  q := Get_QMaxAbs;
  with PVSystemVars do Result := sqrt(FKvaRating*FKvaRating - q*q);
end;

function TPVSystemObj.Get_pMaxOverPF:double;
var
  q: Double;
begin
  q := Get_QMaxInj;
  with PVSystemVars do Result := sqrt(FKvaRating*FKvaRating - q*q);
end;

function TPVSystemObj.Get_acVnom:double;
begin
  Result := PresentKV;
end;

function TPVSystemObj.Get_acVmin:double;
begin
  Result := PresentKV * Vminpu;
end;

function TPVSystemObj.Get_acVmax:double;
begin
  Result := PresentKV * Vmaxpu;
end;

function TPVSystemObj.Get_Zero:double;
begin
  Result := 0.0;
end;

function TPVSystemObj.Get_CIMDynamicMode:boolean;
begin
  Result := FVWMode or FVVMode or FWVMode or FAVRMode or FDRCMode; // FWPMode not in CIM Dynamics
end;

Procedure TPVsystemObj.kWOut_Calc;
  Var
    Pac           : Double;
    PpctLimit     : Double;
  Begin
    With PVSystemVars Do
      Begin
        Pac := PanelkW * EffFactor;
        if VWmode or WVmode then
          begin
            if(Pac > kwrequested) then kW_Out := kwrequested
            else kW_Out := Pac
          end
        else
          begin
            PpctLimit := FPmpp*FpuPmpp;
            if(Pac > PpctLimit) then kW_Out := PpctLimit
            else kW_Out := Pac;
          end;
      End;
  End;
// ============================================================Set_Variable===============================
PROCEDURE TPVsystemObj.Set_Variable(i: Integer;  Value: Double);
  var
    N, k      : Integer;
  Begin
    If i<1 Then Exit;  // No variables to set
    With PVSystemVars, myDynVars Do
    CASE i of
      1: FIrradiance := Value;
      2: ; // Setting this has no effect Read only
      3: ; // Setting this has no effect Read only
      4: ; // Setting this has no effect Read only
      5: Vreg := Value; // the InvControl or ExpControl will do this
      6: Vavg := Value;
      7: VVOperation := Value;
      8: VWOperation := Value;
      9: DRCOperation := Value;
      10:VVDRCOperation := Value;
      11:WPOperation := Value;
      12:WVOperation := Value;
      13: ; //ReadOnly //kW_out_desired := Value;
      ELSE
      Begin
        with myDynVars do           // Dynamic state variables write
          Set_InvDynValue( i - 14, Value );
        If UserModel.Exists Then
        Begin
          N := UserModel.FNumVars;
          k := (i-NumPVSystemVariables) ;
          If  k<= N Then
          Begin
            UserModel.FSetVariable( k, Value );
            Exit;
          End;
        End;
      End;

    END;
  End;

procedure TPVsystemObj.Set_Varmode(const Value: Integer);
  begin
    FvarMode:= Value;
  end;
// ===========================================================================================
procedure TPVsystemObj.Set_VWmode(const Value: Boolean);
  begin
    FVWmode := Value;
  end;
// ===========================================================================================
procedure TPVsystemObj.Set_VVmode(const Value: Boolean);
  begin
    FVVmode := Value;
  end;
// ===========================================================================================
procedure TPVsystemObj.Set_WVmode(const Value: Boolean);
  begin
    FWVmode := Value;
  end;

// ===========================================================================================
procedure TPVsystemObj.Set_WPmode(const Value: Boolean);
  begin
    FWPmode := Value;
  end;
// ===========================================================================================
  procedure TPVsystemObj.Set_DRCmode(const Value: Boolean);
  begin
    FDRCmode := Value;
  end;
// ===========================================================================================
procedure TPVsystemObj.Set_AVRmode(const Value: Boolean);
  begin
    FAVRmode := Value;
  end;
// ===========================================================================================
PROCEDURE TPVsystemObj.GetAllVariables(States: pDoubleArray);
  VAR
    i,
    N      : Integer;
  Begin
    if DynamiceqObj = nil then
      For i := 1 to NumPVSystemVariables Do States^[i] := Variable[i]
    else
      For i := 1 to DynamiceqObj.NumVars * length(DynamicEqVals[0]) Do
        States^[i] := DynamiceqObj.Get_DynamicEqVal(i - 1, DynamicEqVals);

    If   UserModel.Exists Then UserModel.FGetAllVars(@States^[NumPVSystemVariables+1]);
  End;
// ===========================================================================================
FUNCTION TPVsystemObj.NumVariables: Integer;
  Begin
    Result  := NumPVSystemVariables;
    If UserModel.Exists    Then Result := Result + UserModel.FNumVars;
  End;
// ===========================================================================================
FUNCTION TPVsystemObj.VariableName(i: Integer):String;
  Const
    BuffSize = 255;
  VAR
    n,
    i2          : integer;
    Buff        : Array[0..BuffSize] of AnsiChar;
    pName       : pAnsichar;
  Begin
    If i<1 Then Exit;  // Someone goofed
    CASE i of
      1:  Result := 'Irradiance';
      2:  Result := 'PanelkW';
      3:  Result := 'P_TFactor';
      4:  Result := 'Efficiency';
      5:  Result := 'Vreg';
      6:  Result := 'Vavg (DRC)';
      7:  Result := 'volt-var';
      8:  Result := 'volt-watt';
      9:  Result := 'DRC';
      10: Result := 'VV_DRC';
      11: Result := 'watt-pf';
      12: Result := 'watt-var';
      13: Result := 'kW_out_desired'
      ELSE
      Begin
        with myDynVars do   // Adds dynamic state variables names
          Result  :=  Get_InvDynName( i - 14 );
        If UserModel.Exists Then
        Begin
          pName := @Buff;
          n := UserModel.FNumVars;
          i2 := i-NumPVSystemVariables;
          If (i2 <= n) Then
            Begin
              UserModel.FGetVarName(i2, pName, BuffSize);
              Result := String(pName);
              Exit;
            End;
        End;
      End;
    END;
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.MakePosSequence(ActorID : Integer);
  VAR
    S     : String;
    V     : Double;
  Begin
    S := 'Phases=1 conn=wye';
    With PVSystemVars Do
      Begin
        // Make sure voltage is line-neutral
        If (Fnphases>1) or (connection<>0) Then V :=  kVPVSystemBase/SQRT3
        Else V :=  kVPVSystemBase;
        S := S + Format(' kV=%-.5g',[V]);
        If (Fnphases>1) Then S := S + Format(' kva=%-.5g  PF=%-.5g',[FkVArating/Fnphases, PFnominal]);
        Parser[ActorID].CmdString := S;
        Edit(ActorID);
      End;
    inherited;   // write out other properties
  End;
// ===========================================================================================
PROCEDURE TPVsystemObj.Set_ConductorClosed(Index: Integer; ActorID: Integer; Value: Boolean);
  Begin
    inherited;
    // Just turn PVSystem element on or off;
    If Value Then PVSystemObjSwitchOpen := FALSE
    Else PVSystemObjSwitchOpen := TRUE;
  End;
procedure TPVsystemObj.Set_Maxkvar(const Value: Double);
  begin
    PVSystemVars.Fkvarlimit := Value;
    PropertyValue[propkvarLimit]       := Format('%-g', [PVSystemVars.Fkvarlimit]);
  end;
procedure TPVsystemObj.Set_Maxkvarneg(const Value: Double);
  begin
    PVSystemVars.Fkvarlimitneg := Value;
    PropertyValue[propkvarLimitneg]       := Format('%-g', [PVSystemVars.Fkvarlimitneg]);
  end;
procedure TPVsystemObj.Set_kVARating(const Value: Double);
  begin
    PVSystemVars.FkVARating := Value;
    PropertyValue[propKVA]       := Format('%-g', [PVSystemVars.FkVArating]);
  end;
// ===========================================================================================
procedure TPVsystemObj.Set_Pmpp(const Value: Double);
Begin
      PVSystemVars.FPmpp      := Value;
      PropertyValue[propPmpp] := Format('%-g', [PVSystemVars.FkVArating]);
End;
PROCEDURE TPVsystemObj.Set_PowerFactor(const Value: Double);
  Begin
    PFnominal := Value;
    varMode := VARMODEPF;
  End;
PROCEDURE TPVsystemObj.Set_PresentIrradiance(const Value: Double);
  Begin
    PVSystemVars.FIrradiance := Value;
  end;
PROCEDURE TPVsystemObj.Set_PresentkV(const Value: Double);
  Begin
    With PVSystemVars Do
      Begin
        kVPVSystemBase := Value ;
        CASE FNphases Of
          2,3: VBase := kVPVSystemBase * InvSQRT3x1000;
          ELSE
            VBase := kVPVSystemBase * 1000.0 ;
        END;
      End;
  End;
PROCEDURE TPVsystemObj.Set_VarFollowInverter(const Value: Boolean);
  Begin
    FVarFollowInverter := Value;
  End;
PROCEDURE TPVsystemObj.Set_InverterON(const Value: Boolean);
  Begin
    FInverterON := Value;
  End;
PROCEDURE TPVsystemObj.Set_PresentkW(const Value: Double);
  Begin
    kWRequested := Value;
  End;
PROCEDURE TPVsystemObj.Set_Presentkvar(const Value: Double);
  Begin
    kvarRequested := Value;
  End;
PROCEDURE TPVsystemObj.Set_pf_wp_nominal(const Value: Double);
  Begin
    Fpf_wp_nominal := Value;
  End;
procedure TPVsystemObj.Set_puPmpp(const Value: Double);
  begin
    PVSystemVars.FpuPmpp := Value;
  end;
PROCEDURE TPVsystemObj.SetDragHandRegister(Reg: Integer; const Value: Double);
  Begin
    If  (Value > Registers[reg]) Then Registers[Reg] := Value;
  End;
end.
