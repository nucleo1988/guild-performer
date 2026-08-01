; Inno Setup script — build after PyInstaller produces dist\GuildPerformerSync.exe
#define MyAppName "Guild Performer Sync"
#define MyAppVersion "1.1.1"
#define MyAppPublisher "nucleo1988"
#define MyAppURL "https://github.com/nucleo1988/guild-performer"
#define MyAppExeName "GuildPerformerSync.exe"

[Setup]
AppId={{A7C3E91B-4D2F-4B8A-9E11-71C0GP110001}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\GuildPerformerSync
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist-installer
OutputBaseFilename=GuildPerformerSync-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=
UninstallDisplayIcon={app}\{#MyAppExeName}
InfoBeforeFile=INFO.txt

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Crea icona sul Desktop"; GroupDescription: "Icone:"; Flags: unchecked
Name: "autostart"; Description: "Avvia con Windows"; GroupDescription: "Opzioni:"

[Files]
Source: "..\app\dist\GuildPerformerSync.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "GuildPerformerSync"; ValueData: """{app}\{#MyAppExeName}"" --autostart"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Apri Guild Performer Sync"; Flags: nowait postinstall skipifsilent
