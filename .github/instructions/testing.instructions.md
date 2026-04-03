---
description: >
  Use when writing, editing, or reviewing test files (.test.ets) in the Wangnong project. Covers Hypium API patterns,
  ArkTS test constraints, test data factory usage, Singleton isolation, async testing, test registration, and the
  test-first development mandate.
applyTo: "entry/src/test/**/*.ets,entry/src/ohosTest/**/*.ets"
---

# 测试编写规范 (Testing Instructions)

## 核心原则：测试先行

**所有增删改操作，必须先编写 / 更新对应的测试用例，再实现业务逻辑。**

- 新增功能 → 先写失败测试 → 实现功能 → 测试通过
- 修改功能 → 先更新/新增测试以覆盖变更 → 修改代码 → 确认测试通过
- 删除功能 → 确认测试中无残留引用 → 删除代码 → 删除对应测试

## 测试分类

| 类型 | 目录 | 用途 | 运行环境 |
|------|------|------|----------|
| 本地单元测试 | `entry/src/test/` | 纯逻辑：模型、服务、工具函数 | JVM (无设备) |
| OHOS 仪器测试 | `entry/src/ohosTest/` | UI 渲染、系统 API 集成、Ability | 设备/模拟器 |

**选择标准**：如果被测代码不依赖 `@ohos.*` 系统 API 或 ArkUI 渲染，放 `entry/src/test/`；否则放 `entry/src/ohosTest/`。

## 文件命名与目录

```
entry/src/test/
├── List.test.ets            # 入口：导入并注册所有本地测试
├── LocalUnit.test.ets       # 原始示例测试
├── testutils/
│   └── TestHelpers.ets      # 工厂方法 & 断言辅助
├── models/
│   ├── SensorData.test.ets
│   ├── NodeState.test.ets
│   ├── AlertData.test.ets
│   └── Node.test.ets
├── services/
│   ├── HttpService.test.ets
│   ├── MqttClientService.test.ets
│   ├── AlertSyncService.test.ets
│   └── VideoMonitorService.test.ets
└── common/
    ├── BreakpointSystem.test.ets
    ├── AppConfig.test.ets
    └── DesignToken.test.ets
```

命名规则：`{SourceFileName}.test.ets`，与源文件同名，放在对应子目录下。

## Hypium API 速查

```typescript
import { describe, it, expect, beforeAll, beforeEach, afterEach, afterAll } from '@ohos/hypium';

export default function myTest() {
  describe('SuiteName', () => {
    beforeAll(() => { /* 套件开始前执行一次 */ });
    beforeEach(() => { /* 每个用例前执行 */ });
    afterEach(() => { /* 每个用例后执行 */ });
    afterAll(() => { /* 套件结束后执行一次 */ });

    it('test_case_name', 0, () => {
      expect(value).assertEqual(expected);
      expect(bool).assertTrue();
      expect(bool).assertFalse();
      expect(str).assertContain(substr);
      expect(val).assertNull();
      expect(val).assertUndefined();
    });

    // 异步测试
    it('async_test', 0, async () => {
      let result = await someAsyncFunction();
      expect(result).assertEqual(expected);
    });
  });
}
```

**注意**：`it()` 的第二个参数 `0` 是用例过滤标志位，默认传 `0`。

## ArkTS 测试约束

### 1. 禁止无类型对象字面量

```typescript
// ❌ 编译错误
let mockData = { temperature: 25.3, humidity: 68 };

// ✅ 使用工厂方法 (TestHelpers.ets)
import { createMockSensorData } from '../testutils/TestHelpers';
let sd = createMockSensorData();

// ✅ 或使用类实例
let sd = new SensorData();
sd.setValue('temperature', 25.3);
```

### 2. Record 类型初始化

```typescript
// ❌ 编译错误
let kvs = { temperature: 25.3 };

// ✅ 正确方式
let kvs: Record<string, number> = {};
kvs['temperature'] = 25.3;
```

### 3. JSON 字符串构造

测试 MQTT 消息解析时，使用模板字符串构造 JSON：
```typescript
import { createTelemetryJson, createAlertJson } from '../testutils/TestHelpers';
let json = createTelemetryJson('A03_Node_01', 25.3, 68);
```

## 测试数据工厂 (TestHelpers.ets)

所有测试数据通过 `entry/src/test/testutils/TestHelpers.ets` 中的工厂方法创建：

| 工厂方法 | 返回类型 | 用途 |
|---------|---------|------|
| `createMockAlert(id, level?, timestamp?)` | `AlertData` | 告警测试数据 |
| `createHandledAlert(id, timestamp?)` | `AlertData` | 已处理告警 |
| `createTelemetryJson(nodeId, temp?, humidity?)` | `string` | 遥测 JSON 字符串 |
| `createAlertJson(nodeId, alertId, level?)` | `string` | 告警 JSON 字符串 |
| `createMockSensorData()` | `SensorData` | 预填充传感器数据 |
| `createMockNodeState()` | `NodeState` | 预填充设备状态 |
| `createMockNode(id?, name?)` | `Node` | 节点实例 |
| `createMockTrendPoints(count, baseValue?)` | `CachedTrendPoint[]` | 趋势缓存点 |

## Singleton 服务测试

Singleton 实例在测试间共享，注意：
1. 测试不应依赖执行顺序
2. 在 `beforeEach` 中重置关键状态（如果服务暴露了 reset 方法）
3. 监听器必须在测试后清理，避免泄漏：
```typescript
let listener = (nodeId: string, msg: string) => {};
beforeEach(() => {
  svc.addTelemetryListener(listener);
});
afterEach(() => {
  svc.removeTelemetryListener(listener);
});
```

## 注册新测试

每个新测试文件必须在对应的 `List.test.ets` 中注册：

**本地测试** → `entry/src/test/List.test.ets`：
```typescript
import myNewTest from './path/MyNew.test';

export default function testsuite() {
  // ... existing tests ...
  myNewTest();
}
```

**OHOS 测试** → `entry/src/ohosTest/ets/test/List.test.ets`，同理。

## 测试命名约定

- 测试套件名 = 类/模块名：`describe('SensorData', ...)`
- 用例名 = `方法名_场景_预期`：`it('getValue_unknown_key_returns_zero', ...)`
- 使用下划线分隔，全小写

## 最终验证（必须全部通过）

**每次修改完成后，必须依次通过编译验证和测试验证，缺一不可。**

### 验证流程

```
编写/更新测试 → 实现/修改代码 → 编译通过 (BUILD SUCCESSFUL) → 测试全部通过 → 完成
```

### 1. 编译验证

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

- 成功标志：输出 `BUILD SUCCESSFUL`
- 失败：搜索 `ERROR:` 定位问题，`WARN` 通常可忽略

### 2. 测试验证 (CLI)

**本地单元测试** — 通过 hvigorw `test` 任务在 CLI 运行，无需设备/模拟器：

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default test --no-daemon
```

- 成功标志：`BUILD SUCCESSFUL` 且 `Tests run: N, Failure: 0, Error: 0, Pass: N, Ignore: 0`
- 测试结果文件：`entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- 覆盖率报告：`entry/.test/default/outputs/test/reports/index.html`
- `exit code 1` 由 WARN 导致，只要 `BUILD SUCCESSFUL` 且 `Failure: 0, Error: 0` 即视为通过

**OHOS 仪器测试** — 需要真机/模拟器，支持 DevEco Studio 与 CLI 两种方式：
- DevEco Studio：右键 `entry/src/ohosTest/` → Run Tests
- CLI（推荐用于可复现调试）：

```powershell
$hdc = "D:\software\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"

# 1) 确认设备连接
& $hdc list targets

# 2) 构建测试 HAP
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@ohosTest -p product=default assembleHap --no-daemon

# 3) 安装测试包
& $hdc install -r "entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap"

# 4) 执行仪器测试
& $hdc shell aa test -b ww.wangwang.wangnong -m entry_test -s unittest OpenHarmonyTestRunner
```

- 成功标志：终端输出 `OHOS_REPORT_RESULT: stream=Tests run: N, Failure: 0, Error: 0, Pass: N, Ignore: 0` 且 `TestFinished-ResultCode: 0`
- 失败排查：
1. `hdc list targets` 无设备时先连真机/启动模拟器
2. `aa test` 报 `option [-s] is incorrect` 时，检查是否遗漏 runner 参数 `OpenHarmonyTestRunner`

**所有测试用例必须全部通过 (PASS)，不允许存在 FAIL 或 ERROR 状态。**

如果测试失败：
1. 查看 `test_result.txt` 定位失败用例名
2. 检查是否是测试本身的问题（断言错误、Singleton 状态污染）
3. 检查是否是被测代码的回归 bug
4. 修复后重新运行，直到全部通过
