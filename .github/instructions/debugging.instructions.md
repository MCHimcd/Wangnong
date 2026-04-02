---
description: >
  Use when debugging compilation errors, runtime failures, MQTT/HTTP connection issues, or test failures
  in the Wangnong HarmonyOS project. Covers common ArkTS errors, hvigorw build diagnostics, hilog usage,
  and systematic troubleshooting approaches.
applyTo: "entry/src/**/*.ets"
---

# 调试指南 (Debugging Instructions)

## 常见编译错误

### 1. `arkts-no-untyped-obj-literals`

**症状**：`Object literal must correspond to some explicitly declared class or interface (arkts-no-untyped-obj-literals)`

**原因**：ArkTS 不允许 `{ key: value }` 无类型对象字面量。

**修复**：
```typescript
// ❌
let data = { name: 'test', value: 123 };

// ✅ 定义 class 并实例化
class MyData { name: string = ''; value: number = 0; }
let data = new MyData();
data.name = 'test';
data.value = 123;

// ✅ 使用 Record 类型
let map: Record<string, number> = {};
map['temperature'] = 25.3;
```

### 2. `@Observed` 对象不触发 UI 更新

**症状**：修改 `Record` 类型属性后 UI 不刷新。

**原因**：`@Observed` 不深度监听 `Record<K,V>` 的内部变化。

**修复**：使用 `revision++` 模式：
```typescript
@Observed class SensorData {
  values: Record<string, number> = {};
  revision: number = 0;
  setValue(key: string, val: number) {
    this.values[key] = val;
    this.revision++; // 触发 UI 刷新
  }
}
```

### 3. `ForEach` 不更新

**症状**：列表数据变化后 `ForEach` 不重新渲染。

**修复**：确保提供唯一 key 生成函数：
```typescript
ForEach(this.items, (item: MyItem) => { ... }, (item: MyItem) => item.id)
```

### 4. 循环导入

**症状**：运行时 `undefined` 错误，或类型在运行时为 `undefined`。

**修复**：使用 `import type` 或重构文件依赖链。

## 构建失败排查

### hvigorw 编译命令

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

### 输出解读

| 关键字 | 含义 | 处理 |
|--------|------|------|
| `BUILD SUCCESSFUL` | 编译成功 | 无需操作 |
| `BUILD FAILED` | 编译失败 | 搜索 `ERROR:` 定位 |
| `ERROR:` | 具体错误信息 | 必须修复 |
| `WARN:` | 警告 | 通常可忽略 (deprecated API 等) |
| `arkts-` 前缀 | ArkTS 语法约束违规 | 必须修复 |

### 常见构建问题

1. **找不到模块**：检查 `oh-package.json5` 依赖版本、运行 `ohpm install`
2. **类型不匹配**：ArkTS 类型比 TypeScript 更严格，不允许隐式 `any`
3. **API 不存在**：检查目标 API 版本 (API 22)，某些 API 仅在高版本可用

## HTTP 请求调试

### 排查清单

1. **检查 `AppConfig.BASE_URL`** — 是否指向正确的后端地址
2. **检查 Token** — `HttpService.setToken()` 是否已调用
3. **查看 hilog 输出** — 搜索 `[HttpService]` 标签
4. **检查网络权限** — `module.json5` 中需要 `ohos.permission.INTERNET`
5. **超时配置** — 默认 2s，AI QA 接口 60s

### hilog 关键标签

```
[HttpService] POST /api/v1/auth/login     → 请求发出
[HttpService] Request to /xxx failed.      → 请求失败 (含原因)
```

## MQTT 连接调试

### 排查清单

1. **Broker 地址** — `AppConfig.MQTT_BROKER_URL` 是否正确 (`tcp://host:port`)
2. **Client ID 唯一性** — 使用 `_` + 时间戳确保唯一
3. **查看 hilog 输出** — 搜索 `[MQTT]` 标签
4. **网络连通性** — 确认设备可访问 Broker 端口
5. **QoS 配置** — 订阅和发布均使用 QoS 1

### hilog 关键标签

```
[MQTT] Connecting to tcp://...             → 开始连接
[MQTT] Connected to tcp://...              → 连接成功
[MQTT] Failed to connect: ...              → 连接失败
[MQTT] Subscribed telemetry topic          → 订阅成功
[MQTT] Parse error                         → 消息解析失败
[MQTT] Device heartbeat timeout (10s)!     → 离线检测触发
[MQTT] Cannot publish to ..., not connected → 未连接时尝试发布
```

## 测试失败排查

### 本地单元测试 (`entry/src/test/`)

1. **导入路径** — 使用相对路径 `../../main/ets/models/xxx`
2. **List.test.ets 注册** — 新测试必须在 `List.test.ets` 中导入并调用
3. **Singleton 状态污染** — 测试间共享 Singleton 实例，用 `beforeEach` 重置
4. **异步测试** — `it()` 回调需声明 `async` 并 `await` 异步操作
5. **ArkTS 约束** — 测试代码同样受 `arkts-no-untyped-obj-literals` 限制

### OHOS 仪器测试 (`entry/src/ohosTest/`)

1. **设备连接** — 确认设备已通过 USB 连接且 HDC 可用
2. **签名配置** — 测试 HAP 需要有效签名
3. **权限** — 测试涉及的系统 API 需在 `module.json5` 中声明权限
4. **List.test.ets 注册** — 同本地测试

## hilog 使用建议

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';

// 分级使用:
hilog.debug(0x0000, 'MyTag', 'Debug: %{public}s', detail);  // 开发调试
hilog.info(0x0000, 'MyTag', 'Info: %{public}s', info);      // 关键流程
hilog.warn(0x0000, 'MyTag', 'Warn: %{public}s', warning);   // 潜在问题
hilog.error(0x0000, 'MyTag', 'Error: %{public}s', error);   // 错误
```

**注意**：`%{public}s` 使日志在非调试模式下也可见；`%{private}s` 仅调试可见。
