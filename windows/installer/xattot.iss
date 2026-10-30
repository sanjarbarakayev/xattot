; Installer for the Özbekça (Xattot) input method and the Özbekça Tugmali (Xattot) layout.
; windows\build.bat compiles it with Inno Setup 6 after building the DLLs; build_windows.py writes
; the version it includes.

#include "..\..\dist\windows\gen\version.iss"
#define Dist "..\..\dist\windows"
#define LayoutName "Özbekça Tugmali (Xattot)"
#define InputMethodName "Özbekça (Xattot)"

[Setup]
AppId={{E07342C7-7AA5-4D40-8506-28D42FF97026}
AppName=Xattot
AppVersion={#Version}
AppVerName=Xattot {#Version}
AppPublisher=Sanjar Barakayev
AppPublisherURL=https://github.com/sanjarbarakayev/xattot
AppSupportURL=https://github.com/sanjarbarakayev/xattot/issues
DefaultDirName={autopf}\Xattot
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableWelcomePage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; Windows loads the layout DLL itself, not an app that Restart Manager could close.
CloseApplications=no
WizardStyle=modern
ShowLanguageDialog=no
UninstallDisplayName=Xattot
OutputDir=..\..\dist
OutputBaseFilename=Xattot-Setup
Compression=lzma2
SolidCompression=yes
VersionInfoVersion={#Version}
VersionInfoProductName=Xattot
VersionInfoDescription=Xattot Setup

[Languages]
Name: "uz"; MessagesFile: "compiler:Default.isl"

[Messages]
SetupAppTitle=Örnatiş
SetupWindowTitle=%1 örnatiş
UninstallAppTitle=Öçiriş
UninstallAppFullTitle=%1 öçiriş
ExitSetupTitle=Örnatişdan çiqiş
ExitSetupMessage=Örnatiş tugamadi. Hozir çiqsangiz, klaviaturalar örnatilmaydi.%n%nÖrnatişni keyinroq qayta işga tuşiriş mumkin.%n%nÇiqasizmi?
ButtonBack=< &Orqaga
ButtonNext=&Keyingi >
ButtonInstall=&Örnatiş
ButtonCancel=Bekor qiliş
ButtonYes=&Ha
ButtonNo=&Yöq
ButtonFinish=&Tayyor
WizardReady=Örnatişga tayyor
ReadyLabel1={#InputMethodName} va {#LayoutName} klaviaturalari örnatiladi va Özbekça tiliga qöşiladi.%n%n{#InputMethodName} odatdagi klaviaturada sh, ch, o', g' ni ş, ç, ö, ğ ga aylantiradi. Buning uçun u faqat yozilayotgan söznigina öqiydi: tarmoqqa ulanmaydi va hech narsani hech qayerga yubormaydi.
ReadyLabel2a=Davom etiş uçun "Örnatiş" ni bosing.
ReadyLabel2b=Davom etiş uçun "Örnatiş" ni bosing.
WizardPreparing=Örnatişga tayyorlanmoqda
PreparingDesc=[name] örnatişga tayyorlanmoqda.
WizardInstalling=Örnatilmoqda
InstallingLabel=[name] örnatilmoqda, kuting.
FinishedHeadingLabel=[name] örnatildi
FinishedLabelNoIcons={#InputMethodName} yoki {#LayoutName} ni Win+Space bilan tanlang. Röyxatda körinmasa, bir marta Sign out qilib qayta kiring.%n%nBatafsil: github.com/sanjarbarakayev/xattot
FinishedLabel={#InputMethodName} yoki {#LayoutName} ni Win+Space bilan tanlang.
ClickFinish=Çiqiş uçun "Tayyor" ni bosing.
FinishedRestartLabel=Örnatişni tugatiş uçun kompyuterni qayta yuklaş kerak. Hozir qayta yuklansinmi?
FinishedRestartMessage=Örnatişni tugatiş uçun kompyuterni qayta yuklaş kerak.%n%nHozir qayta yuklansinmi?
StatusClosingApplications=Ilovalar yopilmoqda...
StatusCreateDirs=Papkalar yaratilmoqda...
StatusExtractFiles=Fayllar köçirilmoqda...
StatusCreateRegistryEntries=Registry yozilmoqda...
StatusSavingUninstall=Öçiriş ma'lumoti saqlanmoqda...
StatusRunProgram=Örnatiş tugatilmoqda...
StatusRollback=Özgarişlar bekor qilinmoqda...
ConfirmUninstall=%1, {#InputMethodName} va {#LayoutName} klaviaturalari butunlay öçirilsinmi?
WizardUninstalling=Öçiriş
StatusUninstalling=%1 öçirilmoqda...
UninstallStatusLabel=%1 öçirilmoqda, kuting.
UninstalledAll=%1 öçirildi.
UninstalledMost=%1 öçirildi.%n%nBa'zi qismlarni öçirib bölmadi, ularni qölda öçiriş mumkin.
UninstalledAndNeedsRestart=%1 ni öçirişni tugatiş uçun kompyuterni qayta yuklaş kerak.%n%nHozir qayta yuklansinmi?

[Files]
Source: "{#Dist}\x64\kbduzxt.dll"; DestDir: "{sys}"; Check: IsX64OS; Flags: ignoreversion
Source: "{#Dist}\arm64\kbduzxt.dll"; DestDir: "{sys}"; Check: IsArm64; Flags: ignoreversion
Source: "{#Dist}\wow64\kbduzxt.dll"; DestDir: "{syswow64}"; Flags: ignoreversion
; The input method registers itself (regsvr32). Each process loads it, so an upgrade moves the old
; file aside (MoveAsideInputMethod) and an uninstall deletes a loaded one at the next restart.
Source: "{#Dist}\ime\x64\XattotIME.dll"; DestDir: "{app}"; Check: IsX64OS; Flags: ignoreversion regserver uninsrestartdelete
Source: "{#Dist}\ime\arm64\XattotIME.dll"; DestDir: "{app}"; Check: IsArm64; Flags: ignoreversion regserver uninsrestartdelete
Source: "{#Dist}\ime\x86\XattotIME.dll"; DestDir: "{app}\x86"; Flags: ignoreversion regserver 32bit uninsrestartdelete
Source: "..\..\inputmethod\Resources\SCOWL-COPYRIGHT.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "language.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Code]
const
  LayoutsKey = 'SYSTEM\CurrentControlSet\Control\Keyboard Layouts';
  LayoutFile = 'kbduzxt.dll';
  LanguageId = '0443';
  { Text service CLSID and profile GUID, windows\ime\tsf\Globals.h. }
  InputMethodTip = '0443:{FD47E00C-1DD3-4169-B402-BE4F14473EEE}{59E8B67C-4644-47C6-81CE-C0249DD669FA}';
  InputMethodFile = 'XattotIME.dll';

{ Lowercase hex padded to Digits; Pascal Script has no IntToHex. }
function Hex(Value, Digits: Integer): String;
begin
  Result := '';
  while Digits > 0 do
  begin
    Result := Copy('0123456789abcdef', (Value mod 16) + 1, 1) + Result;
    Value := Value div 16;
    Digits := Digits - 1;
  end;
end;

function FindKlid(): String;
var
  Names: TArrayOfString;
  Value: String;
  I: Integer;
begin
  Result := '';
  if not RegGetSubkeyNames(HKLM64, LayoutsKey, Names) then Exit;
  for I := 0 to GetArrayLength(Names) - 1 do
    if RegQueryStringValue(HKLM64, LayoutsKey + '\' + Names[I], 'Layout File', Value)
      and (CompareText(Value, LayoutFile) = 0) then
    begin
      Result := Names[I];
      Exit;
    end;
end;

{ Custom layouts take a KLID whose first digit is a-f; the low word names the language. }
function NewKlid(): String;
var
  I: Integer;
begin
  for I := 0 to $FFF do
  begin
    Result := 'a' + Hex(I, 3) + LanguageId;
    if not RegKeyExists(HKLM64, LayoutsKey + '\' + Result) then Exit;
  end;
  RaiseException('No free keyboard layout ID.');
end;

{ Windows tells custom layouts apart by Layout Id, which must be unique among all of them. }
function NewLayoutId(): String;
var
  Names: TArrayOfString;
  Value: String;
  I, Id, Highest: Integer;
begin
  Highest := $BF;
  if RegGetSubkeyNames(HKLM64, LayoutsKey, Names) then
    for I := 0 to GetArrayLength(Names) - 1 do
      if RegQueryStringValue(HKLM64, LayoutsKey + '\' + Names[I], 'Layout Id', Value) then
      begin
        Id := StrToIntDef('$' + Value, 0);
        if Id > Highest then Highest := Id;
      end;
  Result := Hex(Highest + 1, 4);
end;

function Tip(Klid: String): String;
begin
  Result := LanguageId + ':' + Uppercase(Klid);
end;

function PowerShell(): String;
begin
  Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

function LanguageScript(Arguments: String): String;
begin
  Result := '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\language.ps1') + '" ' + Arguments;
end;

{ A layout DLL Windows has loaded cannot be overwritten or deleted, but it can be renamed:
  the renamed copy is deleted at the next restart. }
procedure MoveAsideInUse(Path: String);
var
  Old: String;
begin
  if not FileExists(Path) or DeleteFile(Path) then Exit;
  Old := Path + '.' + GetDateTimeString('yyyymmddhhnnsszzz', #0, #0) + '.old';
  if RenameFile(Path, Old) then
    RestartReplace(Old, '')
  else
    Log('Could not move aside ' + Path);
end;

procedure MoveAsideLayouts();
begin
  MoveAsideInUse(ExpandConstant('{sys}\') + LayoutFile);
  MoveAsideInUse(ExpandConstant('{syswow64}\') + LayoutFile);
end;

procedure MoveAsideInputMethod();
begin
  MoveAsideInUse(ExpandConstant('{app}\') + InputMethodFile);
  MoveAsideInUse(ExpandConstant('{app}\x86\') + InputMethodFile);
end;

{ Tips is comma-separated, in order: the first becomes the default Uzbek keyboard. }
procedure AddToLanguageList(Tips: String);
var
  ResultCode: Integer;
begin
  { The language list belongs to the signed-in user, not to the elevated installer. }
  if not ExecAsOriginalUser(PowerShell(), LanguageScript('-Tips ' + Tips), '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
    or (ResultCode <> 0) then
  begin
    Log('language.ps1 -Tips ' + Tips + ' failed with code ' + IntToStr(ResultCode));
    SuppressibleMsgBox('Klaviaturalar örnatildi, lekin Özbekça tiliga qöşilmadi. Ularni Settings > Time & language > Language & region > Özbekça > Language options > Add a keyboard orqali qöşing.',
      mbInformation, MB_OK, IDOK);
  end;
end;

procedure RemoveFromLanguageList(Tips: String);
var
  ResultCode: Integer;
begin
  { The uninstaller has no original-user context; with the usual UAC prompt it runs as the same account. }
  if not Exec(PowerShell(), LanguageScript('-Remove -Tips ' + Tips), '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
    or (ResultCode <> 0) then
    Log('language.ps1 -Remove -Tips ' + Tips + ' failed with code ' + IntToStr(ResultCode));
end;

{ Returns the layout's KLID. }
function RegisterLayout(): String;
var
  Klid, Key: String;
begin
  Klid := FindKlid();
  if Klid = '' then
  begin
    Klid := NewKlid();
    { Layout File goes in first, so a rerun after any later failure finds this key again. }
    RegWriteStringValue(HKLM64, LayoutsKey + '\' + Klid, 'Layout File', LayoutFile);
    RegWriteStringValue(HKLM64, LayoutsKey + '\' + Klid, 'Layout Id', NewLayoutId());
  end;
  Key := LayoutsKey + '\' + Klid;
  RegWriteStringValue(HKLM64, Key, 'Layout File', LayoutFile);
  RegWriteStringValue(HKLM64, Key, 'Layout Text', '{#LayoutName}');
  RegWriteExpandStringValue(HKLM64, Key, 'Layout Display Name', '@%SystemRoot%\system32\' + LayoutFile + ',-1000');
  Result := Klid;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    MoveAsideLayouts();
    MoveAsideInputMethod();
  end;
  { The input method first: it is the default Uzbek keyboard, Tugmali the other one. }
  if CurStep = ssPostInstall then AddToLanguageList(InputMethodTip + ',' + Tip(RegisterLayout()));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Klid: String;
begin
  if CurUninstallStep <> usUninstall then Exit;
  Klid := FindKlid();
  if Klid = '' then
    RemoveFromLanguageList(InputMethodTip)
  else
  begin
    RemoveFromLanguageList(InputMethodTip + ',' + Tip(Klid));
    RegDeleteKeyIncludingSubkeys(HKLM64, LayoutsKey + '\' + Klid);
  end;
  MoveAsideLayouts();
end;
