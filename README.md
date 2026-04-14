# Wangnong Frontend

OpenHarmony smart greenhouse client for real-time monitoring, device control, alert handling, and agriculture AI assistance. The app targets phones and tablets and integrates with the HMHT backend through HTTP and MQTT.

**Contents**: [Overview](#overview) · [Changelog](#changelog) · [Tech Stack](#tech-stack) · [Project Structure](#project-structure) · [Architecture](#architecture) · [MQTT Protocol](#mqtt-protocol) · [HTTP API](#http-api) · [State Management](#state-management) · [Design System](#design-system) · [Testing](#testing) · [Build Run Verification](#build-run-verification) · [Code Constraints](#code-constraints) · [Documentation](#documentation)

## Overview

Wangnong is the frontend application of the smart agriculture system. It provides:

- real-time greenhouse telemetry monitoring
- remote equipment control
- alert synchronization and handling
- scheduled task management
- traceability scan and detail flows
- profile and administration workflows
- agriculture knowledge Q&A with Markdown rendering

The client is built with ArkTS and OpenHarmony UI patterns, while preserving a stable integration surface with the HMHT backend and the documented MQTT contract.

## Changelog

Project history from this task onward is tracked in [CHANGELOG.md](./CHANGELOG.md).

## Tech Stack

| Area | Technology |
|------|------------|
| UI framework | OpenHarmony ArkUI (ArkTS) |
| Runtime model | OpenHarmony Stage model |
| MQTT | `@ohos/mqtt` `^2.0.25` |
| Charts | `@ohos/mpchart` `^3.0.26` |
| Unit testing | `@ohos/hypium` `1.0.25` |
| Mocking | `@ohos/hamock` `1.0.0` |
| API documentation | AsyncAPI 2.6.0 with GitHub Pages deployment |
| Test backend | Python Flask in `test_backend/server.py` for development only |

### Runtime Targets

| Item | Value |
|------|-------|
| Bundle | `ww.wangwang.wangnong` |
| Version | `1.0.0` |
| Device types | Phone, Tablet |
| Target SDK | API 22 (`6.0.2`) |
| Compatibility requirement | final delivery must remain compatible with API 11 |
| Runtime | OpenHarmony Stage model |

## Project Structure

```text
Wangnong/
├── AppScope/                         # app-level configuration
├── entry/
│   └── src/
│       ├── main/ets/
│       │   ├── entryability/         # app entry
│       │   ├── pages/                # pages
│       │   ├── views/                # reusable tab-level views
│       │   ├── services/             # singleton service layer
│       │   ├── models/               # data models
│       │   └── common/               # shared config and utilities
│       ├── test/                     # local unit tests
│       ├── ohosTest/                 # device/emulator tests
│       └── mock/                     # Hamock configuration
├── test_backend/                     # development-only Flask backend
├── docs/asyncapi/                    # HTTP and MQTT contract source
└── .github/                          # project-specific coding instructions
```

## Architecture

### Navigation Model

```text
LoginPage
  -> Index
     -> Tab 0: HomeView
        -> MonitorView
        -> AgriQAView
        -> ScheduledTaskView
     -> Tab 1: AlertView
        -> AlertDetailPage
     -> Tab 2: ProfileView
        -> AvatarCropPage
        -> SettingsPage
        -> EditProfilePage
        -> ChangePasswordPage
        -> AgreementPage
        -> AdminPage

Standalone pages:
- SensorDetailPage
- DeviceDetailPage
- VideoDetailPage
- ScheduledTaskPage
- TraceabilityScanPage
- TraceabilityDetailPage
- TestTabs
```

### Pages

| Page | File | Purpose |
|------|------|---------|
| Login | `LoginPage.ets` | phone login, registration, verification, and password recovery |
| Home shell | `Index.ets` | tab container, node loading, MQTT connection, alert sync bootstrap |
| Device detail | `DeviceDetailPage.ets` | equipment switch history timeline |
| Sensor detail | `SensorDetailPage.ets` | real-time and historical charts with threshold editing |
| Alert detail | `AlertDetailPage.ets` | alert detail and handling |
| Video | `VideoDetailPage.ets` | legacy placeholder, functionality moved into `MonitorView` |
| Scheduled task | `ScheduledTaskPage.ets` | scheduled task create, edit, and delete |
| Admin | `AdminPage.ets` | node, user, access control, and operation log management |
| Settings | `SettingsPage.ets` | settings entry page |
| Agreement | `AgreementPage.ets` | agreement and privacy content |
| Traceability scan | `TraceabilityScanPage.ets` | QR-code scan flow |
| Traceability detail | `TraceabilityDetailPage.ets` | origin, quality, and timeline details |
| Avatar crop | `AvatarCropPage.ets` | photo and album avatar crop workflow |
| Change password | `ChangePasswordPage.ets` | password update |
| Edit profile | `EditProfilePage.ets` | profile editing |
| Test page | `TestTabs.ets` | UI prototype or test page |

### Views

| View | Purpose |
|------|---------|
| `HomeView.ets` | sidebar and content routing |
| `MonitorView.ets` | responsive monitoring dashboard with telemetry, device control, media, and SIM fallback |
| `AlertView.ets` | alert list and processing entry |
| `AgriQAView.ets` | agriculture Q&A chat with text, image input, and Markdown rendering |
| `ScheduledTaskView.ets` | scheduled task list and CRUD |
| `ProfileView.ets` | profile card, avatar flow, role display, and logout |

### Services

All services follow the `static getInstance()` singleton pattern.

| Service | Purpose |
|---------|---------|
| `HttpService.ets` | centralized HTTP client with bearer-token handling |
| `ServerAvailabilityService.ets` | startup and session health probing |
| `MqttClientService.ets` | MQTT subscriptions, command publishing, trend cache, and SIM telemetry injection |
| `AlertSyncService.ets` | alert aggregation from HTTP, MQTT, and local SIM sources |
| `VideoMonitorService.ets` | live stream, playback, and keyframe abstraction |
| `SmartControlService.ets` | `SIM_Node_01` smart-mode control rules |
| `ThresholdSyncService.ets` | threshold update propagation inside the frontend |
| `FrontendSimNodeService.ets` | frontend-side simulation for `SIM_Node_01` telemetry, alerts, and media fallback |

### Models

| Model | Key Types or Purpose | Reactive |
|------|-----------------------|----------|
| `UserData.ets` | login response, profile, base response | — |
| `SensorData.ets` | telemetry key-value data and image payload | `@Observed` |
| `SensorMeta.ets` | sensor definitions and thresholds | — |
| `EquipmentMeta.ets` | equipment definitions | — |
| `AlertData.ets` | alert structure | — |
| `Node.ets` | node aggregate model | `@Observed` |
| `NodeState.ets` | smart mode and equipment state map | `@Observed` |
| `TraceabilityInfo.ets` | traceability payloads and navigation params | — |
| `VideoMonitorData.ets` | live stream, playback, and keyframe items | — |

## MQTT Protocol

Documented test broker: `tcp://broker.emqx.io:1883`

### Topics

| Direction | Topic Pattern | QoS |
|-----------|---------------|-----|
| App subscribe | `/wangnong_2026/device/+/telemetry` | 1 |
| App subscribe | `/wangnong_2026/device/+/alert` | 1 |
| App publish | `/wangnong_2026/node/{nodeId}/command` | 1 |

### Message Shapes

Telemetry:

```json
{
  "msg_type": "telemetry",
  "node_id": "A03_Node_01",
  "timestamp": 1711900000,
  "data": {
    "environment": {
      "temperature": 25.3,
      "humidity": 68,
      "light": 12000,
      "co2": 420,
      "soil_temperature": 22.1,
      "soil_humidity": 55,
      "ph": 6.8
    },
    "equipment": {
      "water_pump": true,
      "led_light": false,
      "fan": true,
      "camera": true
    },
    "mode": true,
    "image_base64": "optional JPEG Base64 frame"
  }
}
```

Alert:

```json
{
  "msg_type": "alert",
  "node_id": "A03_Node_01",
  "timestamp": 1711900000,
  "data": {
    "alert_id": "...",
    "type": "temp_high",
    "level": "critical",
    "message": "..."
  }
}
```

Command:

```json
{
  "cmd_id": "uuid",
  "timestamp": 1711900000,
  "msg_type": "control",
  "action": {
    "target_device": "water_pump",
    "command": "turn_on",
    "parameters": {}
  }
}
```

Complete protocol definition: [docs/asyncapi/asyncapi.yaml](docs/asyncapi/asyncapi.yaml)

## HTTP API

Backend base URL is configured through `AppConfig.BASE_URL`.

| Category | Prefix | Representative Endpoints |
|----------|--------|--------------------------|
| Infrastructure | `/api/v1/` | health |
| Authentication | `/api/v1/auth/` | login, register, forgot-password, send-verification-code, password, profile, logout, avatar |
| Nodes | `/api/v1/nodes/` | list, detail, sensor metadata, equipment metadata, thresholds |
| Sensors | `/api/v1/sensors/` | `{device_id}/history` |
| Equipment | `/api/v1/equipment/` | statistics |
| Alerts | `/api/v1/alerts/` | list and handle |
| Cameras | `/api/v1/cameras/` | live, playback, keyframes |
| Agri QA | `/api/v1/agri-qa/` | chat |
| Traceability | `/api/v1/traceability/` | scan |
| Scheduled tasks | `/api/v1/scheduled-tasks/` | CRUD |
| Administration | `/api/v1/admin/` | nodes, users, roles, node access |
| Operation logs | `/api/v1/operation-logs/` | query |
| Thresholds | `/api/v1/nodes/` | `{nodeId}/sensor-thresholds` |

All network requests go through `HttpService`, and the response contract is `BaseResponse<T> { code, message, data }`.

## State Management

| Mechanism | Scope | Typical Use |
|-----------|-------|-------------|
| `@State` | local component state | mutable local UI state |
| `@Prop` | parent to child | simple readonly value passing |
| `@ObjectLink` | parent to child observed object | reactive shared object reference |
| `@StorageLink` | AppStorage-backed shared state | breakpoint, tab selection, role |
| `AppStorage` | explicit global state | shared app-level values |
| `Preferences` | persistent device state | saved login credentials |

Current documented AppStorage keys:

- `currentBreakpoint`
- `currentTabIndex`
- `userRole`
- `profileUserName`
- `profileAvatarSrc`

## Design System

All UI styling must use constants from `DesignToken.ets`. Hardcoded colors, font sizes, spacing, and radii are not allowed.

| Token Group | Purpose |
|-------------|---------|
| `AppColors` | theme, alert, status, and chart colors |
| `AppFontSize` | typography scale |
| `AppSpacing` | spacing scale |
| `AppRadius` | radius scale |
| `AppShadow` | card and overlay shadows |

Responsive breakpoints:

- `sm`: under `600vp`
- `md`: `600vp` to `840vp`
- `lg`: `840vp` and above

## Testing

### Test Principle

The project requires tests to be updated before or together with implementation changes.

### Test Types

| Test Type | Location | Framework | Environment |
|-----------|----------|-----------|-------------|
| Local unit tests | `entry/src/test/` | `@ohos/hypium` | CLI without device dependency |
| OHOS instrumentation tests | `entry/src/ohosTest/` | `@ohos/hypium` | device or emulator |

### Current Coverage

Local unit tests currently cover:

- models: `SensorData`, `NodeState`, `AlertData`, `Node`
- services: `HttpService`, `ServerAvailabilityService`, `MqttClientService`, `AlertSyncService`, `VideoMonitorService`, `SmartControlService`, `ThresholdSyncService`, `FrontendSimNodeService`
- shared utilities: `BreakpointSystem`, `AppConfig`, `DesignToken`, `TraceabilityFlowHelper`, `AvatarCropMath`, `AvatarCaptureHelper`, `MarkdownParser`

OHOS smoke tests currently cover:

- `Ability.test`
- `LoginPage`
- `Index`
- `TraceabilityScanPage`
- `AvatarCropPage`
- `AlertView`
- `MonitorView`
- `ProfileView`

Test helper:

- `entry/src/test/testutils/TestHelpers.ets` for typed data factories

## Build Run Verification

### Build

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

Expected success marker: `BUILD SUCCESSFUL`

### Local Unit Tests

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default test --no-daemon
```

Success criteria:

- `BUILD SUCCESSFUL`
- `Tests run: N, Failure: 0, Error: 0`

Per current project guidance, an `exit code 1` caused only by warnings can still be treated as valid if the success markers above are present.

### Device-Side Tests

Run `entry/src/ohosTest/` through DevEco Studio Test Runner or the CLI flow documented in the build-and-verify instructions.

### Development Test Backend

```bash
cd test_backend && pip install flask flask-cors paho-mqtt && python server.py
```

`test_backend/` is retained for development and testing only. Production runtime uses the external backend stack.

## Code Constraints

Current project rules require:

- service-layer singleton access through `static getInstance()`
- all HTTP access through `HttpService`
- all MQTT access through `MqttClientService`
- design-token usage instead of hardcoded style values
- no untyped object literals, intersection types, or index-based property access in ArkTS
- resource cleanup in `aboutToDisappear()`
- OpenHarmony compatibility, with higher-API usage explicitly marked for API 11 review

## Documentation

| Document | Purpose |
|----------|---------|
| [CHANGELOG.md](./CHANGELOG.md) | ongoing project history |
| [docs/asyncapi/asyncapi.yaml](docs/asyncapi/asyncapi.yaml) | HTTP and MQTT contract source |
| `.github/instructions/arkts-patterns.instructions.md` | ArkTS coding patterns |
| `.github/instructions/testing.instructions.md` | test conventions |
| `.github/instructions/build-and-verify.instructions.md` | build and verification workflow |
