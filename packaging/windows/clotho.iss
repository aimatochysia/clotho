; Inno Setup script for the Windows installer.
; iscc /DAppVersion=1.2.3 /DSourceDir=<Release folder> /DOutputDir=<dist> /DIconFile=<app_icon.ico> clotho.iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{7B1E4C2A-6D3F-4E8B-9A51-C10F2D3A7E64}
AppName=Clotho
AppVersion={#AppVersion}
AppPublisher=aimatochysia
AppPublisherURL=https://github.com/aimatochysia/clotho
AppSupportURL=https://github.com/aimatochysia/clotho/issues
AppUpdatesURL=https://github.com/aimatochysia/clotho/releases
DefaultDirName={autopf}\Clotho
DefaultGroupName=Clotho
DisableProgramGroupPage=yes
; Per-user install by default (no admin prompt); the person can choose
; all users instead.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=clotho-{#AppVersion}-windows-x64-setup
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\clotho.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Remove files from older versions that this one no longer ships.
Type: filesandordirs; Name: "{app}\data"

[Icons]
Name: "{autoprograms}\Clotho"; Filename: "{app}\clotho.exe"
Name: "{autodesktop}\Clotho"; Filename: "{app}\clotho.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\clotho.exe"; Description: "{cm:LaunchProgram,Clotho}"; Flags: nowait postinstall skipifsilent
