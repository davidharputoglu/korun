#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{C6E087E1-11D9-4D8B-A4C5-3A83A4F2D118}
AppName=Körün
AppVersion={#MyAppVersion}
AppPublisher=Körün
DefaultDirName={autopf}\Korun
DefaultGroupName=Körün
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
OutputDir=..\..\
OutputBaseFilename=korun-windows-x64-setup
SetupIconFile=..\..\assets\icon.ico
UninstallDisplayIcon={app}\korun.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Körün"; Filename: "{app}\korun.exe"
Name: "{autodesktop}\Körün"; Filename: "{app}\korun.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\korun.exe"; Description: "Launch Körün"; Flags: postinstall nowait skipifsilent
