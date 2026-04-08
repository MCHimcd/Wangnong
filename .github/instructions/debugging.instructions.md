---
description: >
  Use when debugging runtime failures, MQTT/HTTP connection issues, or test failures
  in the Wangnong HarmonyOS project. Covers hilog usage, network diagnostics, and
  systematic troubleshooting approaches.
applyTo: "entry/src/**/*.ets"
---

# 运行时调试指南

> 编译期错误 (arkts-*) 参见 `arkts-patterns.instructions.md`。
> 构建命令与输出解读参见 `build-and-verify.instructions.md`。

## HTTP 请求调试

### 排查清单

1. **检查 `AppConfig.BASE_URL`** — 是否指向正确的后端地址
2. **检查 Token** — `HttpService.setToken()` 是否已调用
3. **查看 hilog 输出** — 搜索 `[HttpService]` 标签
4. **检查网络权限** — `module.json5` 中需要 `ohos.permission.INTERNET`
5. **超时配置** — 默认 2s，AI QA 接口 60s

### hilog 关键日志

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

### hilog 关键日志

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
5. **ArkTS 约束** — 测试代码同样受 arkts-* 规则约束

### OHOS 仪器测试 (`entry/src/ohosTest/`)

1. **设备连接** — 确认设备已通过 USB 连接且 HDC 可用
2. **签名配置** — 测试 HAP 需要有效签名
3. **权限** — 测试涉及的系统 API 需在 `module.json5` 中声明权限
4. **List.test.ets 注册** — 同本地测试

## hilog 使用规范

```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';

hilog.debug(0x0000, 'MyTag', 'Debug: %{public}s', detail);  // 开发调试
hilog.info(0x0000, 'MyTag', 'Info: %{public}s', info);      // 关键流程
hilog.warn(0x0000, 'MyTag', 'Warn: %{public}s', warning);   // 潜在问题
hilog.error(0x0000, 'MyTag', 'Error: %{public}s', error);   // 错误
```

- `%{public}s` — 非调试模式下可见
- `%{private}s` — 仅调试模式可见（敏感数据使用）
