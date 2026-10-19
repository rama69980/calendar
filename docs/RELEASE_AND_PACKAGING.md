# 📦 배포 및 설치 프로그램 생성 가이드 (Release & Packaging Guide)

본 문서는 다른 사용자가 프로그램을 손쉽게 설치하고 사용할 수 있도록 **Windows용 설치 프로그램(`.exe`)** 및 **macOS용 애플리케이션(`.zip` / `.app`)**을 빌드하고 배포하는 방법을 안내합니다.

---

## 1. 🪟 Windows용 설치 프로그램 (`CalendarSetup.exe`)

Windows 사용자에게는 더블 클릭 한 번으로 설치되는 **Inno Setup 기반 설치 마법사(`CalendarSetup.exe`)**를 제공합니다.

### 📍 생성된 설치 파일 위치
* **경로**: [`installers/CalendarSetup.exe`](file:///c:/Users/3031232/project/calendarProject/calendar/installers/CalendarSetup.exe)
* **특징**:
  * 일본어/영어 다국어 설치 마법사 지원 (일본어 기본값)
  * 바탕화면 바로가기 아이콘 자동 생성 옵션
  * 설치 완료 시 자동 실행 지원
  * 프로그램 추가/제거(제어판)에서 깔끔한 삭제(Uninstall) 지원

### 🛠️ Windows 설치 파일 직접 다시 빌드하는 방법
1. **Flutter Windows 릴리즈 바이너리 빌드**:
   ```powershell
   flutter build windows --release
   ```
2. **Inno Setup 컴파일러 실행**:
   ```powershell
   & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
   ```
3. `installers/CalendarSetup.exe` 파일이 새로 생성됩니다. 이 파일만 다른 사람에게 전달하시면 됩니다.

---

## 2. 🍎 macOS용 배포 파일 (`Calendar-MacOS.zip`)

macOS 앱은 Apple 보안 정책(Xcode 빌드 도구 및 macOS 전용 SDK)으로 인해 **macOS 환경에서 빌드**해야 합니다.

본 프로젝트에는 **GitHub Actions 자동 빌드 시스템**이 구축되어 있어 Mac 컴퓨터가 없어도 GitHub에서 무료로 자동 빌드할 수 있습니다.

### 방법 A: GitHub Actions를 통한 자동 빌드 (추천 ⭐️)
1. 프로젝트를 GitHub 저장소에 Push합니다.
2. GitHub 저장소 상단의 **[Actions]** 탭으로 이동합니다.
3. 좌측 워크플로우 목록에서 **[Build macOS App]**을 클릭하고 **[Run workflow]** 버튼을 누릅니다.
4. 빌드가 완료되면 요약 페이지 하단의 **Artifacts**에서 **`Calendar-MacOS-App`** (`Calendar-MacOS.zip`)을 다운로드할 수 있습니다.

### 방법 B: Mac 컴퓨터에서 직접 빌드하는 경우
Mac 환경에서 아래 명령어를 실행합니다:
```bash
# 1. 의존성 설치
flutter pub get

# 2. macOS 릴리즈 빌드
flutter build macos --release

# 3. 배포용 zip 파일 압축
ditto -c -k --sequesterRsrc --keepParent build/macos/Build/Products/Release/*.app Calendar-MacOS.zip
```

---

## 3. 사용자 전달 및 설치 방법 가이드

### 🪟 Windows 사용자 전달 시:
* `installers/CalendarSetup.exe` 파일 1개만 전달합니다.
* 사용자가 더블 클릭하여 설치하면 바탕화면과 시작 메뉴에 등록되어 즉시 사용할 수 있습니다.

### 🍎 Mac 사용자 전달 시:
* `Calendar-MacOS.zip` 압축 파일을 전달합니다.
* 사용자가 압축을 풀고 `Calendar.app`을 **[응용 프로그램(Applications)]** 폴더로 드래그하여 사용합니다.
