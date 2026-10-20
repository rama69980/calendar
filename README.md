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

웹 주소 기본값은 Vercel 배포판(`https://my-test-app-lyart.vercel.app`)입니다. 로그인, 관리자 페이지, 초대 QR 코드가 이 주소를 씁니다. 로컬 웹으로 개발할 때는 `--dart-define=CALENDARWEB_URL=http://localhost:5173` 을 붙이세요. 백엔드 주소는 아직 로컬(`http://localhost:8080`)이 기본값입니다.

| dart-define | 설명 | 기본값 |
|---|---|---|
| `CALENDARWEB_URL` | calendarWEB 프론트 주소 | `https://my-test-app-lyart.vercel.app` |
| `CALENDARWEB_API_URL` | calendarWEB 백엔드 주소 | `http://localhost:8080` |

## 사원 일정 공유 · 검색

- calendarWEB 계정으로 로그인해 있으면 내 일정이 자동으로 서버에 올라갑니다 (저장 후 3초 뒤, 바뀐 경우만).
- 관리자가 사원으로 승인한 사람끼리만 서로의 일정을 볼 수 있습니다. 일정 편집 화면의 「非公開にする」를 켜면 다른 사원에게는 「予定あり」와 시간만 보입니다.
- 오른쪽 위 **社員メンバー**: 내 승인 상태 / 사원 신청 / 멤버 목록 / 동료 초대용 QR 코드 (회원가입 화면이 열림)
- 오른쪽 위 **予定を検索** (또는 검색창 옆 「詳細検索」): 연/월/주/일 기간 + 나·멤버 선택 + 키워드. 위쪽에 사람별 「予定なし / N件」이 나와서 다른 사람의 일정 유무를 바로 확인할 수 있습니다.
- 오른쪽 일정 목록의 검색창은 「期間」 칩(全期間/年/月/週/日)으로 범위를 바꿀 수 있습니다. 기본은 선택한 날짜(日)만입니다.

## 자동 업데이트

Windows 앱은 시작할 때 GitHub Releases 에 새 버전이 있는지 확인하고, 있으면 「新しいバージョンがあります」 창에서 바로 내려받아 설치합니다. 새 버전을 내는 방법은 [docs/RELEASE_AND_PACKAGING.md](docs/RELEASE_AND_PACKAGING.md) 4장.

## 배포

```bash
flutter build windows --release --dart-define-from-file=google_oauth.json   # build/windows/x64/runner/Release/calendar.exe
```

백엔드를 배포하면 `--dart-define=CALENDARWEB_API_URL=...` 를 추가하세요.

`installer.iss` (Inno Setup) 로 `installers/CalendarSetup.exe` 를 만듭니다. 자세한 내용은 [docs/RELEASE_AND_PACKAGING.md](docs/RELEASE_AND_PACKAGING.md).

## 문서

[docs/README.md](docs/README.md) — 프로젝트 개요, 기능 명세, Google 캘린더 연동 매뉴얼, 배포 가이드

## 참고: 이름 변경

프로젝트 이름을 `untitled` → `calendar` 로 바꿨습니다. 기존 사용자의 저장 데이터 위치가 바뀌지 않도록
Windows `ProductName`(`windows/runner/Runner.rc`)과 macOS 번들 ID(`com.example.untitled`)는 그대로 두었습니다.
