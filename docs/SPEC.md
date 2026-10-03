# Zappie — 구현 명세 (Claude Code 작업용)

macOS 메뉴 막대 앱. 어댑터 입력 → 시스템 / 배터리로 흐르는 전력을 실시간으로 보여준다.
디자인 시안: claude.ai 캔버스 "Power Flow 메뉴 막대 앱" (드롭다운 3상태, 메인 창, 메뉴 막대 아이템). 아래에 필요한 수치를 모두 옮겨 두었다.

> ⚠️ 이 문서의 IOKit 키 이름·단위는 공개 오픈소스 예제를 근거로 정리한 것이며 Apple 공식 문서가 없다. **M0 단계에서 실제 기기 출력으로 반드시 검증**하고, 다르면 이 문서를 고친 뒤 진행할 것.

---

## 0. 환경

| 항목 | 값 |
|---|---|
| 언어 / UI | Swift 6, SwiftUI (+ Swift Charts) |
| 대상 | macOS 27+, **Apple Silicon 전용** (Intel은 `PowerTelemetryData` 없음) |
| 메뉴 막대 | `MenuBarExtra` + `.menuBarExtraStyle(.window)` |
| 메인 창 | `Window` scene, 드롭다운 버튼에서 `openWindow(id:)` |
| App Sandbox | **끔** (개인용). 샌드박스에서 IORegistry 읽기 가능 여부는 미확인 |
| 배포 | 개인 빌드. App Store 대상 아님 |

Deprecated 주의: `kIOMasterPortDefault`는 macOS 12부터 deprecated → `kIOMainPortDefault` 사용.

---

## 1. 데이터 소스

`IOServiceMatching("AppleSmartBattery")` → `IORegistryEntryCreateCFProperties`로 딕셔너리를 통째로 읽는다.
일부 값(온도, raw 용량)은 자식 노드 `AppleSmartBatteryPack`의 `BatteryData`에만 있으므로 그 노드도 함께 읽는다.

> M0 검증 완료 (2026-10-02, Mac17,9 M5 Pro, macOS 27, 70W USB-C 어댑터). 원본 출력은 `docs/m0/`.

| 용도 | 키 | 단위 | 비고 |
|---|---|---|---|
| 어댑터 입력 | `PowerTelemetryData.SystemPowerIn` | mW | ✅ 확인. `SystemVoltageIn`(mV) × `SystemCurrentIn`(mA)와 일치 |
| 시스템 소비 | `PowerTelemetryData.SystemLoad` | mW | ✅ 확인 |
| 배터리 전력 | `PowerTelemetryData.BatteryPower` | mW | ✅ 충전 +, 방전 −. 방전 시 −16,860 = `SystemLoad`와 같음. (`BatteryData.BatteryPower`는 −13,822로 V×I와 일치 — 셀 단자 기준) |
| 어댑터 손실 | `PowerTelemetryData.AdapterEfficiencyLoss` | mW | M0에서 새로 발견. 손실 계산에 직접 사용 가능 |
| 배터리 전압 | `Voltage` | mV | ✅ 확인 |
| 배터리 전류 | `InstantAmperage` | mA | ✅ 방전 −1,124 |
| 온도 | **Pack** `BatteryData.Temperature` | 0.01 °C | ⚠️ 최상위 `Temperature` 없음. Pack 노드에만 있음 (`VirtualTemperature`도 동일 값) |
| 사이클 | `CycleCount` | 회 | ✅ 확인 |
| 설계 용량 | `BatteryData.DesignCapacity` | mAh | ✅ 확인 |
| 최대 충전 용량 | `BatteryData.FullChargeCapacity` | mAh | ✅ 확인. `AppleRawMaxCapacity`는 최상위에 없고 Pack에만 있음 |
| 전원 연결 | `ExternalConnected` | Bool | ✅ 확인 |
| 어댑터 정보 | `AdapterDetails` (`Watts`, `AdapterVoltage`, `Current`, `Manufacturer`, `Name`, `Description`) | W / mV / mA | ✅ 70W 어댑터인데 `Watts`=68. 프로토콜은 `Description`("pd charger") |
| 배터리 % | `CurrentCapacity` | % | ✅ 확인. raw mAh는 `BatteryData.RemainingCapacity` (Pack에는 `AppleRawCurrentCapacity`) |
| 남은 시간 | `AvgTimeToFull` / `AvgTimeToEmpty` | 분 | 65535 = 계산 중/없음 처리 |
| 충전 중 여부 | `IsCharging`, `ChargerData.NotChargingReason` | Bool / 비트마스크 | 한도 유지 중 `NotChargingReason`=16777216 (0이 아님) |

**충전 이유 값** (2026-10-03): 바이패스 상태의 아래 줄에 이유를 붙인다.
- `ChargerData.NotChargingReason` = `0x1000000` → "N% 한도에서 유지 중" (80% 한도에서 확인)
- `NotChargingReason` = `0x80` → 외부 전원 없음 (배터리 사용 중 79%에서 확인, 배터리 상태라 화면 영향 없음)
- `FullyCharged` = Yes → "완충" / 그 밖의 0이 아닌 값 → "N%에서 충전 일시 중지"
- `ChargerData.SlowChargingReason` ≠ 0 → 충전 중 아래 줄에 "· 느린 충전"
- 처음 보는 값은 잔량·전력과 함께 `~/Library/Application Support/Zappie/charge-reasons.jsonl`에 값마다 한 번만 기록(재실행해도 중복 없음, 테스트 실행 중에는 기록 안 함) → 의미를 확인하면 `ChargeReason.known`에 추가.

**음수 값**: `BatteryPower`, `InstantAmperage` 등 음수는 **UInt64 비트 패턴**으로 온다(예: 18446744073709534756 = −16,860). `NSNumber.int64Value`로 재해석한다.

**갱신 주기**: IORegistry 값은 1초마다 바뀌지 않는다. `UpdateTime` 관찰 결과 유휴 시 최대 약 60초, 부하 변화 시 1~7초 간격. 전원을 분리하면 `ExternalConnected`는 즉시 바뀌지만 전력 값은 다음 갱신까지 이전 값이 남는다. → 상태 판정은 `ExternalConnected`를 우선하고, 전력 값의 신선도는 `UpdateTime`으로 판단한다.

**USB 출력 (허브 사용)** — 2026-10-03 확인, 기록은 `docs/m0/usb-out-experiment.log`
- `PowerOutDetails`: 다른 기기에 전력을 공급 중인 포트마다 항목 하나. `PortIndex`, `Watts`(**실제 단위 mW** = `AdapterVoltage`(mV) × `Current`(mA)), `ConfiguredVoltage`, `PDPowermW`(포트 한도).
- **USB 출력은 `SystemLoad`에 포함된다.** 5.3 W 기기를 뽑자 시스템 소비 평균 약 17 W → 11 W. 따라서 "Mac 본체" = `SystemLoad` − USB 출력 합.
- 기기 분리 시 2초 안에 목록에서 사라짐 (다른 전력 값보다 빠름).
- Mac17,9는 전원 포트 컨트롤러 4개(USB-C 3 + MagSafe). 어댑터가 MagSafe면 USB-C 3개 모두 출력 가능.
- 포트 매핑 (아이폰을 옮겨 꽂아 확인, `docs/m0/port-mapping.log`): `PortIndex` 1 = 왼쪽 뒤, 2 = 왼쪽 앞, 3 = 오른쪽.
  `PortIndex − 1` = `FedDetails` 칸 번호 = USB 버스(`locationID` 최상위 바이트). `PortControllerInfo` 순서는 이와 달라 쓰지 않는다.
- `FedDetails[PortIndex−1].FedStateOfCharge` = 연결 기기 배터리 % (아이폰 84%일 때 83 — 1%p 이내). `FedVendorID` 1452 = Apple. 완충된 에어팟처럼 전력을 받지 않는 기기는 `PowerOutDetails`에 없다.
- 데이터 연결되는 기기는 `IOUSBHostDevice`의 `USB Product Name`(예: "iPhone")으로 이름을 붙인다.
- 새로 꽂은 포트의 출력은 길게는 약 60초 뒤에 나타난다. `PowerOutDetails`·`FedDetails`는 배터리 드라이버 갱신(`UpdateTime`) 때만 바뀌기 때문.
  `pmset -g batt/ps/rawbatt/accps`, `system_profiler SPPowerDataType`로는 갱신을 앞당길 수 없음을 확인 (수동 새로고침 버튼 불채택).
- 즉시 인식: 데이터 연결 기기는 `IOUSBHostDevice` 연결/해제 알림으로 바로 포트에 "기기 · 전력 확인 중"을 표시하고, 75초 안에 W가 오지 않으면 "충전 안 함". 배터리 드라이버 general-interest 알림으로 새 값은 폴링을 기다리지 않고 반영.
- 충전 전용 연결은 USB 기기 목록에 잡히지 않아 기기 이름은 알 수 없음. `FedDetails`(연결 기기 배터리 잔량 등)는 일부 Apple 기기만 채움.
- 색: USB 강조 코발트 `#2563C9` (배지 글자 `#93C5FD`). 연보라와는 색각 이상에서 색조가 겹치므로 **명도 차로 구분**(CVD ΔE 11.1, 일반 16.8). 배경 대비 2.5:1이라 USB 표시는 항상 글자 라벨을 동반한다. (앰버 `#CC8026`에서 변경, 2026-10-03)

**계산값**
- 배터리 순전력(대체값) = `Voltage × InstantAmperage / 1_000_000` (W). `BatteryPower` 키가 **없을 때만** 사용. (0일 때도 대체하던 초안은 부하 급증 순간 `InstantAmperage`가 −65 mA쯤 흔들려 입력 = 시스템인데도 −0.8 W "보조 방전"으로 오표시됨. 2026-10-03)
- 기타·손실 = 입력 − 시스템 − 배터리(충전 시). 음수면 0으로 클램프, 배터리 모드에선 "—". (`AdapterEfficiencyLoss`와 비교해 어느 쪽을 쓸지 M1에서 결정)
- 정격 대비 사용률 = 입력 W / `AdapterDetails.Watts`.
- 최대 용량 % = 최대 충전 용량 / 설계 용량.

**충전 한도(80%)**: 공개 API로 macOS 충전 한도 설정값을 읽는 방법은 확인하지 못했다. v1에서는 표시하지 않거나 "—"로 둔다.

---

## 2. 상태 판정

```
연결 안 됨 (ExternalConnected == false)            → .battery
연결됨 && batteryW > +0.1                           → .charging
연결됨 && |batteryW| <= 0.1                         → .hold   (바이패스: 배터리 관여 없이 어댑터가 시스템에 직접 공급)
연결됨 && batteryW < −0.1                           → .assisted (어댑터 부족, 배터리 보조) ※시안에 없음. 배지·헤더 모두 "배터리 보조" (2026-10-03, 배지 "보조 방전"에서 변경)
```
임계값은 0.5 W로 시작했으나 0.1 W로 낮춤 (2026-10-03): 텔레메트리는 대기 시 정확히 0이고, 실제 0.3 W 보조(입력 43.8 + 배터리 0.3 = 시스템 44.1)가 "배터리 대기"로 표시됐다. 깜빡임은 2초 히스테리시스가 막는다.
- 단, `.battery`로 들어가고 나오는 전환(분리/연결)은 히스테리시스 없이 즉시 반영한다 (완료 기준 1초).
- 연결 상태가 바뀐 시각보다 `UpdateTime`이 오래된 스냅샷은 이전 전원의 값이므로 와트를 무시하고 `.hold`로 본다.

---

## 3. 아키텍처

```
PowerReader      IOKit 읽기 → PowerSnapshot (순수 값 타입, Sendable)
PowerMonitor     @Observable @MainActor. 1초 폴링 + 전원 이벤트 구독, 상태 판정, 히스토리 기록
PowerHistory     링 버퍼: 1시간=1초 해상도, 6시간=10초 평균, 24시간=60초 평균 (메모리만, v1)
Views            MenuBarLabel / DropdownView / MainWindow(Overview, History, Adapter, Battery, Settings)
```

- 전원 연결/분리 이벤트: `IOPSNotificationCreateRunLoopSource`로 즉시 갱신 (폴링과 병행).
- `PowerReader`는 딕셔너리 → 스냅샷 파싱을 별도 함수로 분리해서 **고정 딕셔너리로 단위 테스트** 가능하게.

---

## 4. 디자인 토큰

| 토큰 | 값 |
|---|---|
| 배경 | `#1E1E20` |
| 카드 | `#2A2A2D` |
| 테두리 | `#3A3A3D` |
| 본문 텍스트 | `#F5F5F7` |
| 보조 텍스트 | `#A8A8AE` |
| 어댑터/시스템 강조 (연보라) | `#967CEC` |
| 배터리 강조 (에메랄드) | `#0FAA7B` |
| 비활성 선 | `#48484A` (점선) |
| 손실 | `#8E8E93` |
| 폰트 | 시스템 폰트, 숫자는 `.monospacedDigit()` |
| 모서리 | 패널 14 / 카드 12 / 타일 8~10 |

배지: 배터리·배터리 보조 = 에메랄드 배경 16% + `#6EE7B7` 글자 / 바이패스(충전·대기 공통) = 연보라 배경 16% + `#C4B5FD` 글자.
충전 중에도 어댑터가 시스템에 직접 공급하고 남는 전력으로 배터리를 채우므로 배지는 "바이패스", 헤더로 구분: 충전 = "전원 어댑터 · 배터리 충전 중", 대기 = "전원 어댑터 · 바이패스". (2026-10-03)
(대기 상태의 배지는 "한도 유지"였으나, 한도 도달 외에도 완충·충전 일시중지 등에서 나오므로 "바이패스"로 변경. 2026-10-03)
강조 버튼 글자 `#140F2A`. 두 강조색은 어두운 카드(`#2A2A2D`) 위에서 dataviz 팔레트 검증(명도 0.48–0.67, CVD ΔE ≥ 8, 대비 ≥ 3:1)을 통과한 값이다. (2026-10-03, 파랑·주황에서 변경)
다크 모드 기준 시안. 라이트 모드는 v2.

---

## 5. 화면

### 5-1. 메뉴 막대 라벨 (설정에서 선택)
- 충전 중: ⚡(에메랄드) `+31.4W` — 배터리로 들어가는 전력
- 바이패스: 플러그(연보라) `12.3W` — 어댑터 입력
- 배터리: 배터리(에메랄드) `−11.8W` — 방전 전력
- 아이콘만 모드

### 5-2. 드롭다운 (폭 340, 높이 약 500)
1. 헤더: "전원" + 소스 문구(예: "전원 어댑터 · 충전 중") / 상태 배지 + 배터리 % (22pt)
2. 전력 흐름 카드: `[어댑터] —W→ ● —W→ [시스템]`, 분기점 아래 `↕ W` 후 `[배터리]`
   - 충전: 모든 선 실선, 세로 화살표 ↓ 에메랄드
   - 바이패스: 배터리 선 점선 회색, 라벨 "0.0 W"
   - 배터리: 어댑터 노드 투명도 0.45, 어댑터 선 점선, 분기점·시스템 선 에메랄드, 세로 화살표 ↑
3. 숫자 3칸: 입력 / 시스템 / 배터리
4. 한 줄: 남은 시간 라벨 + 값
5. 하단: "앱에서 자세히 보기"(강조색 버튼, 메인 창 열기) + 설정 아이콘 버튼(44×44)

### 5-3. 메인 창 (1200×960 기준, 리사이즈 가능)
- 사이드바 200: 개요 / 기록 / 어댑터 / 배터리 / 설정
- 개요(3열 그리드, 간격 18):
  - 전력 흐름(2열) | 입력 전력 구성(1열: 스택 막대 + 3행 W·% + 남은 시간)
  - 전력 기록(3열): Swift Charts 라인 2개(어댑터 입력 연보라, 시스템 흰회색), 1시간/6시간/24시간 세그먼트
  - 어댑터(1열): 정격 W, 프로토콜, 사용률 막대, 협상 전압×전류 | 배터리(2열): 전압·전류·온도·사이클·최대 용량·충전 한도 6타일
- 기록/어댑터/배터리/설정 탭은 v1에서 간단 버전(설정: 갱신 주기, 메뉴 막대 라벨 형식, 로그인 시 실행)

---

## 6. 작업 순서

- **M0 검증**: `ioreg -rn AppleSmartBattery` 출력 저장 → 위 표의 키·단위 확인 → 이 문서 수정
- **M1** `PowerReader` + 파싱 단위 테스트 (M0 출력으로 fixture 작성)
- **M2** `PowerMonitor` 상태 판정 + 히스테리시스 + 이벤트 구독
- **M3** 메뉴 막대 라벨 + 드롭다운
- **M4** 메인 창 개요
- **M5** 히스토리 + 차트
- **M6** 설정, 로그인 시 실행(`SMAppService.mainApp`)

## 7. 완료 기준

- 전원 분리/연결 시 1초 이내에 드롭다운 아이콘·선 방향이 바뀐다
- 충전 중일 때 입력 ≈ 시스템 + 배터리 + 손실(±1 W)  ✅ 2026-10-03 확인: 입력 17.103 W = 시스템 16.895 W + 배터리 0.208 W (mW 단위 일치)
- 앱 자체 CPU 사용률이 평상시 1% 미만 (활성 상태 보기로 확인)
- 키가 없는 기기(데스크톱 Mac 등)에서 크래시 없이 "지원하지 않는 기기" 표시
