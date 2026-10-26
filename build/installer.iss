; Inno Setup script for Prayer Reminder.
; Build with: build\build.ps1  (or: iscc build\installer.iss)

#define AppName "Prayer Reminder"
; build.ps1 passes /DAppVersion=x.y.z; a bare #define here would override it.
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppPublisher "YRamzy993"
#define AppURL "https://github.com/YRamzy993/prayer-reminder"
#define AppExe "PrayerReminder.exe"

[Setup]
AppId={{8F3A6C21-5B7E-4D2A-9E14-7C0B5A9D3F41}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}/issues
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
; Per-user install so no admin prompt is needed.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=PrayerReminder-Setup-{#AppVersion}
SetupIconFile=..\src\app.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "startup"; Description: "Start {#AppName} automatically when I sign in"; GroupDescription: "Options:"
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Options:"; Flags: unchecked

[Files]
Source: "..\dist\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\app.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\sounds\*"; DestDir: "{app}\sounds"; Flags: ignoreversion recursesubdirs
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\CREDITS.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app.ico"
Name: "{group}\{#AppName} Settings"; Filename: "{app}\{#AppExe}"; Parameters: "-Settings"; IconFilename: "{app}\app.ico"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app.ico"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExe}"; IconFilename: "{app}\app.ico"; Tasks: startup

[Run]
Filename: "{app}\{#AppExe}"; Description: "Run {#AppName} now"; Flags: nowait postinstall skipifsilent

[InstallDelete]
; A previous version may have left a startup shortcut under a different name.
Type: files; Name: "{userstartup}\Prayer Reminder.lnk"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\PrayerReminder\cache"

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    DeleteFile(ExpandConstant('{userstartup}\Prayer Reminder.lnk'));
end;
