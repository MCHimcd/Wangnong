# Wangnong (鸿蒙慧田) — AI 编码指令

## 编码指令文件索引

| 文件 | 用途 | 适用范围 |
|------|------|----------|
| `instructions/arkts-patterns.instructions.md` | ArkTS UI 模式、装饰器、编译错误修正 | `entry/src/main/ets/**/*.ets` |
| `instructions/testing.instructions.md` | 测试编写规范、Hypium API、测试数据工厂 | `entry/src/test/**`, `entry/src/ohosTest/**` |
| `instructions/build-and-verify.instructions.md` | 构建命令、测试命令、输出解读、验证流程 | 全局 |
| `instructions/debugging.instructions.md` | 运行时调试：HTTP/MQTT 排查、hilog 用法 | `entry/src/**/*.ets` |
| `instructions/api-endpoints.instructions.md` | HTTP API 端点清单、HttpService 用法 | HTTP 相关变更 |
| `instructions/mqtt-protocol.instructions.md` | MQTT 主题契约、Payload 结构、监听器模式 | MQTT 相关变更 |
| `instructions/asyncapi-sync.instructions.md` | AsyncAPI 文档同步检查清单 | 协议变更 |

---

## 核心原则

### 1. 主动确认

需求不清晰、存在歧义、或无法确定实现方式时，**必须先向用户提问确认，再动手实现**。不要基于猜测编写代码。

### 2. 测试先行

所有增删改操作，**必须先编写/更新测试用例，再实现业务逻辑**。详见 `testing.instructions.md`。

### 3. README 同步

- **修改代码前**：先阅读 `README.md` 了解项目架构与模块清单
- **修改代码后**：涉及以下内容时必须同步更新 README 对应章节：
  - 页面/视图/服务/模型/通用工具 的增删重命名
  - HTTP API 端点 或 MQTT 主题/消息格式 变更
  - 导航结构、AppStorage 全局键、设计规范常量 变更
  - 构建配置、测试模块 变更

### 4. 最终验证

每次修改完成后必须通过编译验证 + 测试验证。命令与输出解读详见 `build-and-verify.instructions.md`。

---

## 项目架构约定

- **服务层 Singleton** — 所有 Service 使用 `static getInstance()` 模式
- **HTTP 统一入口** — 所有网络请求通过 `HttpService`，禁止直接调用 `@ohos.net.http`
- **MQTT 统一入口** — 所有实时通信通过 `MqttClientService`，禁止直接创建 MQTT 客户端
- **设计规范** — 颜色/字号/间距/圆角使用 `DesignToken.ets` 常量，**禁止硬编码**
- **响应式布局** — 使用 `@StorageLink('currentBreakpoint')` 读取断点 (sm/md/lg)
- **页面导航** — `router.pushUrl()` 跳转，目标页 `router.getParams()` 接收参数
- **OpenHarmony 平台** — 禁止使用 HarmonyOS 专有 API，确保 OpenHarmony 可编译运行

## ArkTS 编码约束

1. **禁止无类型对象字面量** — 必须定义 class 并实例化 (`arkts-no-untyped-obj-literals`)
2. **禁止交叉类型** — 不支持 `A & B` (`arkts-no-intersection-types`)
3. **禁止索引访问** — 不支持 `obj['field']` 读取类成员 (`arkts-no-props-by-index`)
4. **@Observed 深度更新** — Record 类型需 `revision++` 触发 UI 刷新
5. **生命周期清理** — `aboutToDisappear()` 中清除 timer、移除 MQTT 监听、释放资源
6. **API 兼容** — 当前 API 22 测试，最终需兼容 API 11；高版本 API 标注 `// TODO: API 11 兼容`

具体示例与修正方法详见 `arkts-patterns.instructions.md`。

## MQTT 协议约定

- App 端**仅订阅** `/wangnong_2026/device/+/telemetry` 和 `/wangnong_2026/device/+/alert`
- App 端发布控制命令到 `/wangnong_2026/node/{nodeId}/command`
- 新增数据源应由后端桥接转发到现有主题，不修改 App 端订阅列表
- 消息格式变更需同步更新 `docs/asyncapi/asyncapi.yaml`

详见 `mqtt-protocol.instructions.md`。

## 测试后端

`test_backend/` 为开发测试用 Flask 后端，保留代码不删除，不为生产功能修改此目录。修改 API 契约后应考虑同步更新 `test_backend/server.py`。
