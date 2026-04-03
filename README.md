# 鸿蒙慧田 (Wangnong)

OpenHarmony 智能温室管理系统 —— 通过手机/平板实时监控温室环境、远程控制设备、接收告警推送，并集成农业知识问答 AI。

| 属性 | 值 |
|------|-----|
| Bundle | `ww.wangwang.wangnong` |
| 版本 | 1.0.0 |
| 目标设备 | Phone, Tablet |
| 目标 SDK | API 22 (6.0.2)；最终需兼容 API 11 |
| 运行时 | OpenHarmony (Stage 模型) |

---

## 技术栈

| 层 | 技术 |
|----|------|
| 前端框架 | OpenHarmony ArkUI (ArkTS) |
| 实时通信 | `@ohos/mqtt` ^2.0.25 |
| 图表 | `@ohos/mpchart` ^3.0.26 |
| 测试 | `@ohos/hypium` 1.0.25 / `@ohos/hamock` 1.0.0 |
| 测试后端 | Python Flask (test_backend/server.py，仅测试用，生产环境使用独立后端) |
| API 文档 | AsyncAPI 2.6.0 → GitHub Pages 自动部署 |

---

## 目录结构

```
Wangnong/
├── AppScope/                        # 应用级配置 (app.json5)
├── entry/                           # 主模块
│   └── src/
│       ├── main/ets/
│       │   ├── entryability/        # 应用入口 (EntryAbility)
│       │   ├── pages/               # 14 个页面
│       │   ├── views/               # 6 个可复用视图 (Tab 级)
│       │   ├── services/            # 5 个单例服务
│       │   ├── models/              # 8 个数据模型
│       │   └── common/              # 公用配置与工具
│       │       ├── AppConfig.ets
│       │       ├── DesignToken.ets
│       │       └── BreakpointSystem.ets
│       ├── test/                    # 本地单元测试
│       │   ├── List.test.ets        # 测试入口
│       │   ├── testutils/           # 测试工厂 & 辅助
│       │   ├── models/              # 模型层测试 (4)
│       │   ├── services/            # 服务层测试 (4)
│       │   └── common/              # 公用工具测试 (3)
│       ├── ohosTest/                # OHOS 仪器测试 (设备/模拟器)
│       │   └── ets/test/
│       │       ├── pages/           # 页面冒烟测试
│       │       └── views/           # 视图冒烟测试
│       └── mock/                    # Hamock 配置
├── test_backend/                    # Flask 测试后端 (保留但不再用于生产)
│   └── server.py
├── docs/asyncapi/
│   └── asyncapi.yaml                # HTTP + MQTT 协议规范
└── .github/
    ├── copilot-instructions.md      # AI 编码指令
    ├── instructions/                # 按需 AI 指令 (含测试/调试指南)
    └── workflows/asyncapi-pages.yml # CI: 文档自动部署
```

---

## 架构概览

### 导航结构

```
LoginPage
  ↓ (登录成功)
Index (底部 Tab 容器)
  ├─ Tab 0: HomeView (首页)
  │   ├─ 侧边栏
  │   │   ├─ 综合监控 → MonitorView
  │   │   ├─ 农业知识问答 → AgriQAView
  │   │   ├─ 定时任务 → ScheduledTaskView
  │   │   └─ 切换节点
  │   └─ 内容区域（根据侧边栏选择切换视图）
  ├─ Tab 1: AlertView (告警列表)
  │   └─ → AlertDetailPage
  └─ Tab 2: ProfileView (个人中心)
      ├─ → SettingsPage → EditProfilePage / ChangePasswordPage / AgreementPage
      └─ → AdminPage (管理员可见)

独立页面:
  - SensorDetailPage    (传感器趋势图)
  - DeviceDetailPage    (设备历史统计)
  - VideoDetailPage     (直播 / 回放 / 关键帧)
  - ScheduledTaskPage   (定时任务 CRUD)
  - TraceabilityScanPage(溯源扫码)
```

### 页面清单 (14)

| 页面 | 文件 | 说明 |
|------|------|------|
| 登录 | `LoginPage.ets` | 手机号 + 验证码/密码登录，支持注册与找回 |
| 主页 | `Index.ets` | Tab 容器，加载节点列表、连接 MQTT、初始化告警同步 |
| 设备详情 | `DeviceDetailPage.ets` | 设备运行统计与控制 |
| 传感器详情 | `SensorDetailPage.ets` | 实时 + 历史趋势图 (MPChart)，支持阈值编辑 |
| 告警详情 | `AlertDetailPage.ets` | 告警详情查看与处理 |
| 视频监控 | `VideoDetailPage.ets` | 直播、回放、关键帧三个 Tab |
| 定时任务 | `ScheduledTaskPage.ets` | 定时任务创建/编辑/删除 |
| 管理后台 | `AdminPage.ets` | 节点管理、用户管理、操作日志、节点访问控制 |
| 设置 | `SettingsPage.ets` | 设置菜单入口 |
| 协议 | `AgreementPage.ets` | 用户协议 / 隐私政策 (参数化) |
| 溯源扫码 | `TraceabilityScanPage.ets` | 二维码扫描查询产品溯源 |
| 修改密码 | `ChangePasswordPage.ets` | 旧密码 → 新密码 |
| 编辑资料 | `EditProfilePage.ets` | 用户名、性别、生日 |
| 测试页 | `TestTabs.ets` | UI 原型测试 |

### 视图清单 (6)

| 视图 | 说明 |
|------|------|
| `HomeView.ets` | 侧边栏 + 内容路由 (MonitorView / AgriQAView / ScheduledTaskView) |
| `MonitorView.ets` | 传感器卡片网格 + 设备控制 + 视频入口 |
| `AlertView.ets` | 告警列表，按时间/类型排序，标记已处理 |
| `AgriQAView.ets` | 农业知识问答聊天界面 (文本 + 图片输入) |
| `ScheduledTaskView.ets` | 定时任务列表与 CRUD |
| `ProfileView.ets` | 个人中心卡片 (头像、角色、登出) |

### 服务清单 (5 × Singleton)

| 服务 | 说明 |
|------|------|
| `HttpService.ets` | HTTP REST 客户端 (40+ 方法)，统一 Bearer Token 鉴权 |
| `ServerAvailabilityService.ets` | 服务器可用性探测：启动前检查、登录后会话探活、连续失败阈值判定 |
| `MqttClientService.ets` | MQTT 实时通信：订阅遥测/告警，发布控制命令，维护 60 点趋势缓存 |
| `AlertSyncService.ets` | 告警状态聚合：启动时 HTTP 拉取 + 运行时 MQTT 推送，全局弹窗通知 |
| `VideoMonitorService.ets` | 视频流封装：直播、回放、关键帧 |

### 数据模型清单 (8)

| 模型 | 关键类型 | 响应式 |
|------|---------|--------|
| `UserData.ets` | `LoginResponse`, `UserProfile`, `BaseResponse<T>` | — |
| `SensorData.ets` | 动态 KV 存储 (Record<string, number>) | @Observed |
| `SensorMeta.ets` | `SensorMetaItem {key, name, unit, icon, warningMin?, warningMax?}` | — |
| `EquipmentMeta.ets` | `EquipmentMetaItem {key, name, icon, controllable}` | — |
| `AlertData.ets` | `alert_id, type, level, timestamp, message, is_handled` | — |
| `Node.ets` | `id, name, sensorData, nodeState, sensorMeta[], equipmentMeta[]` | @Observed |
| `NodeState.ets` | `smartMode, equipmentStates: Record<string, boolean>` | @Observed |
| `VideoMonitorData.ets` | `LiveStreamInfo`, `PlaybackItem`, `KeyframeImageItem` | — |

---

## MQTT 协议

**Broker**: `tcp://47.109.27.231:1883` (测试环境；生产应替换为自托管 Broker)

### 主题设计

| 方向 | 主题模式 | QoS |
|------|---------|-----|
| App 订阅 | `/wangnong_2026/device/+/telemetry` | 1 |
| App 订阅 | `/wangnong_2026/device/+/alert` | 1 |
| App 发布 | `/wangnong_2026/node/{nodeId}/command` | 1 |

### 消息格式

**遥测 (Telemetry)**
```json
{
  "msg_type": "telemetry",
  "node_id": "A03_Node_01",
  "timestamp": 1711900000,
  "data": {
    "environment": { "temperature": 25.3, "humidity": 68, "light": 12000, "co2": 420, "soil_temperature": 22.1, "soil_humidity": 55, "ph": 6.8 },
    "equipment": { "water_pump": true, "led_light": false, "fan": true, "camera": true },
    "mode": true
  }
}
```

**告警 (Alert)**
```json
{
  "msg_type": "alert",
  "node_id": "A03_Node_01",
  "timestamp": 1711900000,
  "data": { "alert_id": "...", "type": "temp_high", "level": "critical", "message": "..." }
}
```

**控制命令 (Command)** — App 发布
```json
{
  "cmd_id": "uuid",
  "timestamp": 1711900000,
  "msg_type": "control",
  "action": { "target_device": "water_pump", "command": "turn_on", "parameters": {} }
}
```

> 完整协议定义见 `docs/asyncapi/asyncapi.yaml`。

---

## HTTP API

后端基地址由 `AppConfig.BASE_URL` 配置 (当前 `http://192.168.1.100:8080`)。

### 端点分类

| 分类 | 前缀 | 主要端点 |
|------|------|---------|
| 基础设施 | `/api/v1/` | health |
| 认证 | `/api/v1/auth/` | login, register, forgot-password, send-verification-code, password (PUT), profile, logout, avatar/use-fixed |
| 节点 | `/api/v1/devices/` | 列表, 详情, sensor-meta, equipment-meta |
| 传感器 | `/api/v1/sensors/` | `{device_id}/history` (24h/7d/30d) |
| 设备 | `/api/v1/equipment/` | stats |
| 告警 | `/api/v1/alerts/` | list (POST 分页), handle |
| 视频 | `/api/v1/cameras/` | `{device_id}/live`, playback, keyframes |
| 农业问答 | `/api/v1/agri-qa/` | chat (支持图片, 60s 超时) |
| 溯源 | `/api/v1/traceability/` | scan |
| 定时任务 | `/api/v1/scheduled-tasks/` | CRUD |
| 管理 | `/api/v1/admin/` | nodes CRUD, users 列表/角色, node-access |
| 操作日志 | `/api/v1/operation-logs/` | 查询 |
| 阈值 | `/api/v1/thresholds/` | 更新 |

所有请求通过 `HttpService` 统一发出，Header 携带 `Authorization: Bearer <token>`。  
响应格式统一为 `BaseResponse<T> { code, message, data }`。

---

## 状态管理

| 装饰器 | 作用域 | 典型用法 |
|--------|--------|---------|
| `@State` | 组件内部 | 局部可变状态 |
| `@Prop` | 父 → 子 (只读) | 传递简单值 |
| `@ObjectLink` | 父 → 子 (@Observed 对象) | 双向引用响应式对象 |
| `@StorageLink` | 全局 AppStorage | 断点 (`currentBreakpoint`)、Tab 索引、用户角色 |
| `AppStorage` | 全局显式存储 | `setOrCreate()` / `set()` / `get()` |
| `Preferences` | 设备持久化 | 自动登录凭证保存 |

**全局 AppStorage 键**:
- `currentBreakpoint` — `'sm'` / `'md'` / `'lg'` (BreakpointSystem 写入)
- `currentTabIndex` — 底部 Tab 选中索引
- `userRole` — `'user'` / `'admin'` / `'manager'`
- `profileUserName`, `profileAvatarSrc` — 用户资料

---

## 设计系统

所有 UI 必须引用 `DesignToken.ets` 中的常量，**禁止硬编码色值/字号/间距**。

| 类 | 用途 | 示例 |
|----|------|------|
| `AppColors` | 主题色、告警色、设备状态色、图表色 | `AppColors.Primary` (#2E7D32) |
| `AppFontSize` | Hero(32) / H1(24) / H2(20) / H3(16) / Body(14) / Caption(12) / Mini(10) | `AppFontSize.Body` |
| `AppSpacing` | XS(4) / SM(8) / MD(12) / LG(16) / XL(20) / XXL(28) / PagePadding(16) | `AppSpacing.LG` |
| `AppRadius` | SM(8) / MD(12) / LG(16) / XL(20) / Full(999) | `AppRadius.MD` |
| `AppShadow` | 卡片阴影、悬浮阴影 | `AppShadow.CardRadius` |

**响应式断点** (BreakpointSystem):
- `sm`: < 600vp (手机竖屏)
- `md`: 600–840vp (手机横屏 / 小平板)
- `lg`: ≥ 840vp (平板横屏)

---

## 测试

### 测试先行原则

**所有增删改操作，必须先编写 / 更新对应的测试用例，再实现业务逻辑。**

### 测试分类

| 类型 | 目录 | 框架 | 运行环境 |
|------|------|------|----------|
| 本地单元测试 | `entry/src/test/` | `@ohos/hypium` | JVM (无设备) |
| OHOS 仪器测试 | `entry/src/ohosTest/` | `@ohos/hypium` | 设备/模拟器 |

### 覆盖范围

**本地单元测试 (12 个测试套件)**:

| 层 | 测试套件 | 测试点 |
|----|---------|--------|
| 模型 | SensorData, NodeState, AlertData, Node | 默认值、存取、revision 触发、实例独立性 |
| 服务 | HttpService, ServerAvailabilityService, MqttClientService, AlertSyncService, VideoMonitorService | Singleton、数据类默认值、监听器注册/注销、缓存查询、可用性状态机 |
| 公用 | BreakpointSystem, AppConfig, DesignToken | columnsForBreakpoint 映射、URL 格式、色值/字号/间距有效性 |

**OHOS 仪器测试 (5 个冒烟测试)**:
- Ability.test (基础测试能力校验)
- LoginPage, Index (页面可渲染)
- AlertView, MonitorView (视图可渲染)

### 测试辅助

- `entry/src/test/testutils/TestHelpers.ets` — 数据工厂方法，避免 ArkTS 无类型对象字面量约束

### 运行测试

**本地单元测试 (CLI，无需设备)**：

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default test --no-daemon
```

- 成功标志：`BUILD SUCCESSFUL` 且 `Tests run: N, Failure: 0, Error: 0, Pass: N, Ignore: 0`
- 测试结果：`entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- 覆盖率报告：`entry/.test/default/outputs/test/reports/index.html`
- `exit code 1` 由 WARN 导致，只要 `BUILD SUCCESSFUL` 且 `Failure: 0, Error: 0` 即视为通过

**OHOS 仪器测试 (需设备/模拟器)**：

方式一（DevEco Studio）：通过 Test Runner 运行 `entry/src/ohosTest/`。

方式二（CLI，适合自动化与排查）：

```powershell
$hdc = "D:\software\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"

# 1) 设备连通性
& $hdc list targets

# 2) 构建 ohosTest 测试包
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon

# 3) 安装测试包
& $hdc install -r "entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap"

# 4) 运行仪器测试
& $hdc shell aa test -b ww.wangwang.wangnong -m entry_test -s unittest OpenHarmonyTestRunner
```

- 包名：`ww.wangwang.wangnong`（来自 `AppScope/app.json5` 的 `bundleName`）
- 模块名：`entry_test`（来自 `entry/src/ohosTest/module.json5` 的 `module.name`）
- 成功标志：`OHOS_REPORT_RESULT: stream=Tests run: N, Failure: 0, Error: 0, Pass: N, Ignore: 0` 且 `TestFinished-ResultCode: 0`

---

## 构建与运行

### 前端编译 (PowerShell)

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
cd D:\DevEcoStudioProjects\Wangnong
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

- 成功: 输出 `BUILD SUCCESSFUL`
- 失败: 搜索 `ERROR:` 查看具体错误；`WARN` 通常可忽略

### 测试后端 (仅开发调试，生产不使用)

```bash
cd test_backend
pip install flask flask-cors paho-mqtt
python server.py
# 监听 http://localhost:8080
```

> `test_backend/` 为测试后端模块，现有独立后端已可用时不再使用，但代码保留不删除。

---

## 代码约定

1. **ArkTS 严格模式** — 不允许无类型对象字面量 `{ key: value }`，必须定义 class 并实例化
2. **服务层 Singleton** — 所有服务使用 `static getInstance()` 模式
3. **HTTP 统一入口** — 所有网络请求通过 `HttpService`，不直接调用 `@ohos.net.http`
4. **MQTT 统一入口** — 所有实时通信通过 `MqttClientService`，不直接创建 MQTT 客户端
5. **设计规范** — 颜色/字号/间距/圆角使用 `DesignToken.ets` 常量，禁止硬编码
6. **响应式布局** — 利用 `@StorageLink('currentBreakpoint')` 适配 sm/md/lg
7. **生命周期清理** — `aboutToDisappear()` 中清除 timer、取消 MQTT 监听、释放资源
8. **@Observed 深度更新** — 对 Record 类型使用 `revision++` 触发 UI 刷新
9. **导航** — 页面跳转使用 `router.pushUrl({ url, params })`
10. **API 兼容** — 当前使用 API 22 测试，最终需兼容 API 11，避免使用仅 API 12+ 的新接口
11. **测试先行** — 所有增删改操作必须先编写/更新测试用例，再实现业务逻辑
12. **禁止使用 HarmonyOS 特有功能** — 项目以 OpenHarmony 为目标平台，禁止使用仅在 HarmonyOS 平台可用的专有 API、模块或运行时特性，确保代码在 OpenHarmony 平台可编译运行。