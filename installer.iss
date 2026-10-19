; Inno Setup Script for Calendar App
#define MyAppName "Calendar"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Calendar App"
#define MyAppExeName "Calendar.exe"

[Setup]
AppId={{D8C61E5B-072B-4A1C-9E4B-83A422D305F8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
; 언어 선택 다이얼로그 표시 (첫 번째 언어인 일본어가 기본 선택됨)
ShowLanguageDialog=yes
; 설치 파일이 저장될 폴더 및 파일명 (CalendarSetup.exe)
OutputDir=installers
OutputBaseFilename=CalendarSetup
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
; 첫 번째 언어가 기본 선택값(Default)으로 지정됩니다
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Release 폴더의 부속 파일들을 패키징합니다 (exe 파일 제외)
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.exe"
; 실행 파일을 Calendar.exe 이름으로 설치합니다
Source: "build\windows\x64\runner\Release\calendar.exe"; DestDir: "{app}"; DestName: "{#MyAppExeName}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Filename: "{app}\{#MyAppExeName}"; Flags: nowait postinstall skipifsilent
