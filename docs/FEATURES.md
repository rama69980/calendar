# 📋 기능 상세 명세서 (Feature Specification)

현재 프로젝트에 구현되어 있는 모든 핵심 기능과 상세 동작 방식을 정의합니다.

---

## 1. 캘린더 및 일정 시각화 (Calendar & Schedule View)

### 1.1 캘린더 위젯 ([table_calendar](file:///c:/Users/3031232/project/calendarProject/calendar/lib/screens/calendar_screen.dart))
* **포맷 전환**: Month(월간), 2 Weeks(2주간), Week(주간) 뷰 지원.
* **날짜 선택 및 이동**:
  * 특정 날짜 클릭 시 해당 날짜의 일정 목록 즉시 필터링.
  * 상단 헤더의 "今日(오늘)" 버튼 클릭 시 현재 날짜로 즉시 포커스 이동.
  * 월 변경 시 포커스 동기화.
* **일정 표시 마커 (Event Markers)**:
  * 일정이 등록된 날짜 하단에 해당 일정들의 고유 색상 점(Dot Indicator) 표시.
  * 최대 4개까지 개별 색상 칩 표시, 초과 시 `+N` 배지로 직관적 표현.

### 1.2 일정 통계 배지 & Google 연동 상태 뱃지
* 선택된 날짜에 대해 **전체 일정 수, 진행 중 일정 수, 완료된 일정 수**를 상단 칩 배지로 실시간 요약 제공.
* 상단 AppBar에 **`Google 연동 중`** 상태 뱃지 및 **`동기화(Sync)`** 버튼 제공 (동기화 진행 중 스피너 애니메이션).

---

## 2. Google 캘린더 실시간 양방향 연동 (Google Calendar Two-Way Sync)

### 2.1 PC ➡️ 스마트폰 실시간 푸시 (Push)
* **일정 생성**: PC 앱에서 일정 등록 시 Google Calendar API(`events.insert`)를 통해 클라우드(`primary` 캘린더)에 즉시 업로드 ➡️ **스마트폰 구글 캘린더 앱에 실시간 생성**.
* **일정 수정**: PC 앱에서 제목, 시간, 메모, 색상, 알림 변경 시 즉시 구글 캘린더에 업데이트(`events.update`).
* **일정 삭제**: PC 앱에서 일정 삭제 시 구글 캘린더에서 즉시 삭제(`events.delete`).
* **완료 토글**: 완료 상태를 Extended Properties에 기록하여 동기화 유지.

### 2.2 스마트폰 ➡️ PC 일정 가져오기 (Pull)
* 스마트폰이나 웹에서 추가/수정/삭제된 일정을 PC 앱 실행 시 또는 상단 [동기화] 버튼 클릭 시 로컬 캘린더로 자동 반영.

### 2.3 스마트폰 푸시 알림 & 색상 매핑
* **스마트폰 푸시 알림 연동**: PC 앱에서 설정한 사전 알림(0분, 10분, 30분, 1시간, 1일 전)이 Google Calendar Reminders로 등록되어 **스마트폰에서도 동일하게 구글 캘린더 푸시 알림 수신**.
* **색상 팔레트 매핑**: 앱의 ARGB 색상이 Google Calendar의 1~11번 색상 팔레트(Blueberry, Tomato, Basil, Tangerine 등)와 상호 자동 변환.

### 2.4 오프라인 대응 및 툼스톤(Tombstone) 관리
* 오프라인 상태에서 일정을 삭제해도 `isDeletedLocally = true`로 보관했다가, 인터넷 재연결 및 동기화 실행 시 구글 서버에 삭제 요청을 보낸 후 로컬 DB에서 완전 제거.

---

## 3. 일정 관리 (CRUD & Attributes)

### 3.1 일정 속성 명세 ([schedule_event.dart](file:///c:/Users/3031232/project/calendarProject/calendar/lib/models/schedule_event.dart))

| 속성명 | 타입 | 설명 |
| :--- | :---: | :--- |
| `id` | `String` (UUID v4) | 일정 로컬 고유 식별자 |
| `title` | `String` | 일정 제목 (필수값, 폼 검증 지원) |
| `description` | `String` | 일정 상세 메모 및 설명 (선택값) |
| `date` | `DateTime` | 일정 기준 날짜 (YYYY-MM-DD) |
| `hasTime` | `bool` | 시간 지정 여부 스위치 (미지정 시 종일 일정) |
| `hour` / `minute` | `int` / `int` | 시작 시간 (24시간제 및 TimePicker UI 제공) |
| `colorValue` | `int` (ARGB) | 일정 테마 색상 (프리셋 8종 + 커스텀 컬러 피커 지원) |
| `isCompleted` | `bool` | 일정 완료 여부 (체크박스 토글) |
| `enableNotification` | `bool` | 알림 발송 여부 스위치 |
| `notificationOffsetMinutes`| `int` | 사전 알림 시점 (0분, 10분, 30분, 1시간, 1일 전) |
| `isNotified` | `bool` | 로컬 알림 발송 완료 플래그 |
| `googleEventId` | `String?` | Google Calendar 고유 이벤트 ID (연동 시 발급) |
| `etag` | `String?` | Google Calendar 충돌 감지용 ETag |
| `syncStatus` | `String` | 동기화 상태 (`synced`, `pendingUpload`, `pendingUpdate`, `pendingDelete`, `localOnly`) |
| `isDeletedLocally` | `bool` | 오프라인 삭제 툼스톤 플래그 |
| `createdAt` / `updatedAt` | `DateTime` | 생성 일시 및 최종 수정 일시 |

### 3.2 일정 리스트 및 인터랙션 ([event_list_item.dart](file:///c:/Users/3031232/project/calendarProject/calendar/lib/widgets/event_list_item.dart))
* **완료 토글**: 원클릭으로 완료 상태 전환 (완료 시 취소선 및 투명도 반영).
* **Google 뱃지**: 구글 캘린더에 연동된 일정에 파란색 `Google` 태그 표시.
* **수정 및 삭제**: 일정 카드 우측 액션 버튼을 통해 수정 다이얼로그 호출 또는 삭제 확인 팝업 후 제거.

---

## 4. 검색 및 스마트 필터링 (Search & Filtering)

* **상태별 필터**: `전체`, `진행 중`, `완료됨` 필터 칩.
* **실시간 검색**: 제목(`title`) 및 본문(`description`) 키워드 검색.
* **스마트 정렬**: 시간 지정 일정(오름차순) ➡️ 종일 일정 ➡️ 생성 순서 정렬.

---

## 5. 데스크톱 특화 시스템 기능 (Desktop Native Integration)

### 5.1 중복 실행 방지 (Single Instance Socket Guard) ([main.dart](file:///c:/Users/3031232/project/calendarProject/calendar/lib/main.dart))
* 로컬 루프백 소켓 포트(`49281`)를 선점하여 단일 인스턴스 보장.
* 중복 실행 시 기존 실행 프로세스에 `'show'` 신호를 전달하고 기존 창을 즉시 최상위로 복원.

### 5.2 시스템 트레이 상주 및 메뉴 ([tray_and_window_service.dart](file:///c:/Users/3031232/project/calendarProject/calendar/lib/services/tray_and_window_service.dart))
* **트레이 아이콘**: 좌클릭 시 창 복원/포커스, 우클릭 시 컨텍스트 메뉴 표시.
* **트레이 메뉴**: 캘린더 열기, 새 일정 추가, 알림 테스트, 자동 시작 토글, 앱 종료.

### 5.3 윈도우 창 닫기 제어 (Prevent Close to Tray)
* 윈도우 `X` 버튼 클릭 시 종료 대신 트레이로 최소화(Hide to Tray)하여 상시 알림 대기.

### 5.4 부팅 시 자동 시작 (Launch at Startup)
* Windows 시작프로그램 자동 등록 지원 (`--autostart` 인자로 백그라운드 트레이 상주).

---

## 6. 백그라운드 알림 엔진 (Notification Engine)

* **스케줄러 주기**: 30초 간격으로 로컬 저장소의 일정을 스캔.
* **네이티브 토스트 알림 ([local_notifier](file:///c:/Users/3031232/project/calendarProject/calendar/lib/services/notification_service.dart))**:
  * Windows Action Center 토스트 알림 생성 (제목, 시간, 메모, 사전 알림 기준).
  * **토스트 알림 클릭 시**: 트레이에 숨겨진 캘린더 창이 자동으로 열리며 포커스 이동.

---

## 7. 환경설정 다이얼로그 ([settings_dialog.dart](file:///c:/Users/3031232/project/calendarProject/calendar/lib/widgets/settings_dialog.dart))

1. **Google 캘린더 실시간 연동 섹션**:
   * 연동 상태 및 구글 계정 이메일 표시.
   * `[Google 계정으로 연동하기]` / `[연동 해제]` 버튼.
   * `[지금 동기화]` 수동 동기화 버튼 (스피너 로딩 지원).
   * `[자동 동기화]` 스위치.
2. **PC 시작 시 자동 실행 활성화/비활성화 스위치**
3. **창 닫기 시 트레이로 최소화 스위치**
4. **다크 모드 / 라이트 모드 전환 스위치**
5. **Windows 토스트 알림 테스트 버튼**
