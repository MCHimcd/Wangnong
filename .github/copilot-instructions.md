# Wangnong (鸿蒙慧田) — AI 编码指令

## 主动确认原则

**若需求描述不清晰、存在歧义，或无法确定实现方式，必须先向用户提出问题进行确认，再动手实现。** 不要基于猜测编写代码。

## 测试先行原则

**所有增删改操作，必须先编写 / 更新对应的测试用例，再实现业务逻辑。**

- 新增功能 → 先写失败测试 → 实现功能 → 测试通过
- 修改功能 → 先更新/新增测试以覆盖变更 → 修改代码 → 确认测试通过
- 删除功能 → 确认测试中无残留引用 → 删除代码 → 删除对应测试

详细测试规范参见 `.github/instructions/testing.instructions.md`。

## README 同步规则

- **修改代码前**：先阅读 `README.md` 了解项目架构、约定和现有模块清单。
- **修改代码后**：如果变更涉及以下内容，**必须同步更新 README.md 对应章节**：
  - 新增 / 删除 / 重命名页面 → 更新「页面清单」
  - 新增 / 删除 / 重命名视图 → 更新「视图清单」
  - 新增 / 删除 / 修改服务 → 更新「服务清单」
  - 新增 / 删除 / 修改模型 → 更新「数据模型清单」
  - 新增 / 修改 HTTP API 端点 → 更新「HTTP API」章节
  - 新增 / 修改 MQTT 主题或消息格式 → 更新「MQTT 协议」章节
  - 修改导航结构 → 更新「导航结构」
  - 修改 AppStorage 全局键 → 更新「状态管理」
  - 修改设计规范常量 → 更新「设计系统」
  - 修改构建配置或命令 → 更新「构建与运行」
  - 新增 / 修改测试模块 → 更新「测试」章节

## ArkTS 编码约束

1. **禁止无类型对象字面量** — ArkTS 强制 `arkts-no-untyped-obj-literals`：
   ```typescript
   // ❌ 编译错误
   let obj = { name: 'test', value: 123 };
   
   // ✅ 正确方式：定义 class 并实例化
   class MyData { name: string = ''; value: number = 0; }
   let obj = new MyData();
   obj.name = 'test';
   obj.value = 123;
   ```
2. **@Observed 深度更新** — Record<string, T> 类型需通过 `revision++` 触发 UI 刷新：
   ```typescript
   @Observed class SensorData {
     private data: Record<string, number> = {};
     revision: number = 0;
     setValue(key: string, val: number) { this.data[key] = val; this.revision++; }
   }
   ```
3. **生命周期清理** — 必须在 `aboutToDisappear()` 中清除 timer (`clearInterval`/`clearTimeout`)、取消 MQTT 监听 (`removeXxxListener`)、释放资源。
4. **API 兼容性** — 当前使用 API 22 测试，最终需兼容 API 11。避免使用仅 API 12+ 可用的新接口；若必须使用请注释标注 `// TODO: API 11 兼容`。

## 项目架构约定

- **服务层 Singleton** — 所有 Service 使用 `static getInstance()` 模式，外部通过 `XxxService.getInstance()` 获取。
- **HTTP 统一入口** — 所有网络请求通过 `HttpService`，不直接调用 `@ohos.net.http` 模块。
- **MQTT 统一入口** — 所有实时通信通过 `MqttClientService`，不直接创建 MQTT 客户端实例。
- **设计规范** — 颜色、字号、间距、圆角使用 `DesignToken.ets` (`AppColors`/`AppFontSize`/`AppSpacing`/`AppRadius`) 中的常量，**禁止硬编码**。
- **响应式布局** — 使用 `@StorageLink('currentBreakpoint')` 读取断点 (sm/md/lg)，通过条件渲染适配不同屏幕。
- **页面导航** — 使用 `router.pushUrl({ url: 'pages/XxxPage', params: {...} })`，目标页通过 `router.getParams()` 接收参数。

## MQTT 协议约定

- App 端**仅订阅**两个主题：`/wangnong_2026/device/+/telemetry` 和 `/wangnong_2026/device/+/alert`。
- App 端发布控制命令到 `/wangnong_2026/node/{nodeId}/command`。
- **新增数据源**：如需订阅新主题，应由后端桥接转发到现有主题，而非修改 App 端订阅列表，以维护协议稳定性。
- 消息格式变更需同步更新 `docs/asyncapi/asyncapi.yaml`。

## 测试后端

- `test_backend/` 为开发测试用 Flask 后端，现有独立后端可用时不再使用。
- 保留代码不删除，但不要为生产功能修改此目录。
- 修改 API 契约后应考虑同步更新 `test_backend/server.py` 以保持测试能力。

## 最终验证（必须全部通过）

**每次修改完成后，必须依次通过以下两项验证，缺一不可：**

### 1. 编译验证

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```
- 成功标志：`BUILD SUCCESSFUL`
- 失败：搜索 `ERROR:` 定位问题；`WARN` 通常可忽略（如 deprecated API 警告）

### 2. 测试验证

**本地单元测试 (CLI，无需设备)**：
```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p module=entry@default -p product=default test --no-daemon
```
- 成功标志：`BUILD SUCCESSFUL` 且 `Tests run: N, Failure: 0, Error: 0, Pass: N, Ignore: 0`
- 测试结果：`entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- `exit code 1` 由 WARN 导致，只要 `BUILD SUCCESSFUL` 且 `Failure: 0, Error: 0` 即视为通过

**OHOS 仪器测试（如有设备/模拟器）**：通过 DevEco Studio Test Runner 运行 `entry/src/ohosTest/`

### 验证流程

```
修改代码 → 编译通过 (BUILD SUCCESSFUL) → 测试全部通过 → 完成
         ↘ 编译失败 → 修复 ERROR → 重新编译
                    ↘ 测试失败 → 修复用例或代码 → 重新测试
```

**只有编译和测试都通过，才视为修改完成。**
