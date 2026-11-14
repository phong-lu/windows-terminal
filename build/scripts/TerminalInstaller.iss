; Build with ISCC /DAppVersion=... /DAppArch=... /DSourceDir=... /DOutputDir=...
#if AppArch == "arm64"
  #define AllowedArchitecture "arm64"
#else
  #if AppArch != "x64"
    #error Unsupported installer architecture
  #endif
  #define AllowedArchitecture "x64compatible"
#endif

[Setup]
AppId=WindowsTerminal-{#AppArch}
AppName=Windows Terminal ({#AppArch})
AppVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\Windows Terminal
PrivilegesRequired=lowest
ArchitecturesAllowed={#AllowedArchitecture}
ArchitecturesInstallIn64BitMode={#AllowedArchitecture}
MinVersion=10.0.19041
OutputDir={#OutputDir}
OutputBaseFilename=WindowsTerminal_{#AppVersion}_{#AppArch}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=no
UninstallDisplayIcon={app}\WindowsTerminal.exe
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Messages]
WelcomeLabel1=Welcome to Windows Terminal
WelcomeLabel2=Windows Terminal brings PowerShell, Command Prompt, and WSL together in one app, with tabs, panes, and customizable profiles.%n%nThis setup will install Windows Terminal {#AppVersion} ({#AppArch}) for your user account. You can also choose to create desktop shortcuts for Windows Terminal and its Quake drop-down window.%n%nClick Next to continue.

[Tasks]
Name: "desktopicons"; Description: "Create Desktop icons"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: ".portable,settings\*"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\Windows Terminal ({#AppArch})"; Filename: "{app}\WindowsTerminal.exe"
Name: "{userprograms}\Windows Terminal Quake ({#AppArch})"; Filename: "{app}\WindowsTerminal.exe"; Parameters: "-w _quake"
Name: "{userdesktop}\Windows Terminal ({#AppArch})"; Filename: "{app}\WindowsTerminal.exe"; Tasks: desktopicons
Name: "{userdesktop}\Windows Terminal Quake ({#AppArch})"; Filename: "{app}\WindowsTerminal.exe"; Parameters: "-w _quake"; Tasks: desktopicons

[Run]
Filename: "{app}\WindowsTerminal.exe"; Description: "Launch Windows Terminal"; Flags: nowait postinstall skipifsilent
