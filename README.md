# calendar

Windows / macOS 데스크탑 캘린더 & 스케줄러 앱 (Flutter).
시스템 트레이 상주, 부팅 시 자동 시작, 일정 알림, Google 캘린더 양방향 연동을 지원합니다.

소개 사이트: [`calendarWEB_front`](../calendarWEB_front) · [`calendarWEB_back`](../calendarWEB_back)

## 실행

```bash
flutter pub get
flutter run -d windows
flutter test
```

## 배포

```bash
flutter build windows --release   # build/windows/x64/runner/Release/calendar.exe
```

`installer.iss` (Inno Setup) 로 `installers/CalendarSetup.exe` 를 만듭니다. 자세한 내용은 [docs/RELEASE_AND_PACKAGING.md](docs/RELEASE_AND_PACKAGING.md).

## 문서

[docs/README.md](docs/README.md) — 프로젝트 개요, 기능 명세, Google 캘린더 연동 매뉴얼, 배포 가이드

## 참고: 이름 변경

프로젝트 이름을 `untitled` → `calendar` 로 바꿨습니다. 기존 사용자의 저장 데이터 위치가 바뀌지 않도록
Windows `ProductName`(`windows/runner/Runner.rc`)과 macOS 번들 ID(`com.example.untitled`)는 그대로 두었습니다.
