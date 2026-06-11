; Inno Setup script for Clipwell Windows.
; Build locally:  iscc installer\clipwell.iss
; CI passes /DPublishDir and /DAppVersion; defaults below suit a local build.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\src\Clipwell.Win\bin\Release\net8.0-windows10.0.19041.0\win-x64\publish"
#endif

[Setup]
AppId={{8B7A2E64-3F4D-4C8A-9E11-C11BCE110001}
AppName=Clipwell
AppVersion={#AppVersion}
AppPublisher=Mio Miao Labs LLC
AppPublisherURL=https://clipwell.app
DefaultDirName={autopf}\Clipwell
DefaultGroupName=Clipwell
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=Clipwell-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "launchatlogin"; Description: "Start Clipwell when Windows starts"; GroupDescription: "Startup:"

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Clipwell"; Filename: "{app}\Clipwell.exe"
Name: "{autodesktop}\Clipwell"; Filename: "{app}\Clipwell.exe"; Tasks: launchatlogin

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; \
    ValueName: "Clipwell"; ValueData: """{app}\Clipwell.exe"""; Flags: uninsdeletevalue; Tasks: launchatlogin

[Run]
Filename: "{app}\Clipwell.exe"; Description: "Launch Clipwell"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill"; Parameters: "/im Clipwell.exe /f"; Flags: runhidden skipifdoesntexist; RunOnceId: "KillClipwell"
