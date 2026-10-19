# calendar

Windows / macOS 데스크탑 캘린더 & 스케줄러 앱 (Flutter).
시스템 트레이 상주, 부팅 시 자동 시작, 일정 알림, Google 캘린더 양방향 연동을 지원합니다.

소개 사이트: [`calendarWEB_front`](../calendarWEB_front) · [`calendarWEB_back`](../calendarWEB_back)

## 실행

Google 캘린더 연동에 쓰는 OAuth Client ID / Secret 은 코드에 없고 빌드할 때 주입합니다.
`google_oauth.example.json` 을 `google_oauth.json` 으로 복사해 값을 채우세요 (git 에 올리지 않음).
자세한 내용은 [docs/GOOGLE_CALENDAR_MANUAL.md](docs/GOOGLE_CALENDAR_MANUAL.md).

```bash
flutter pub get
flutter run -d windows --dart-define-from-file=google_oauth.json
flutter test
```

## calendarWEB 계정 로그인

환경설정 > 「calendarWEB アカウント」에서 브라우저로 calendarWEB 에 로그인하면 앱에서도 같은 계정을 씁니다.
(웹에 이미 로그인돼 있으면 「許可してログイン」만 누르면 됨. 구조는 `lib/services/web_account_service.dart` 주석 참고)

접속 주소 기본값은 로컬 개발용(`http://localhost:5173`, `http://localhost:8080`)이라 배포판은 빌드할 때 바꿔야 합니다.

| dart-define | 설명 | 기본값 |
|---|---|---|
| `CALENDARWEB_URL` | calendarWEB 프론트 주소 | `http://localhost:5173` |
| `CALENDARWEB_API_URL` | calendarWEB 백엔드 주소 | `http://localhost:8080` |

## 배포

```bash
flutter build windows --release --dart-define-from-file=google_oauth.json   # build/windows/x64/runner/Release/calendar.exe
```

calendarWEB 운영 주소를 쓰려면 `--dart-define=CALENDARWEB_URL=... --dart-define=CALENDARWEB_API_URL=...` 를 추가하세요.

`installer.iss` (Inno Setup) 로 `installers/CalendarSetup.exe` 를 만듭니다. 자세한 내용은 [docs/RELEASE_AND_PACKAGING.md](docs/RELEASE_AND_PACKAGING.md).

## 문서

[docs/README.md](docs/README.md) — 프로젝트 개요, 기능 명세, Google 캘린더 연동 매뉴얼, 배포 가이드

## 참고: 이름 변경

프로젝트 이름을 `untitled` → `calendar` 로 바꿨습니다. 기존 사용자의 저장 데이터 위치가 바뀌지 않도록
Windows `ProductName`(`windows/runner/Runner.rc`)과 macOS 번들 ID(`com.example.untitled`)는 그대로 두었습니다.
