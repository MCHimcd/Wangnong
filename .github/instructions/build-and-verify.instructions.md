---
description: "Use when building, compiling, running tests, or verifying changes in the Wangnong project. Single source of truth for all hvigorw commands, output interpretation, and verification workflow."
---
# 构建与验证指令

## 验证流程

```
编写/更新测试 → 实现/修改代码 → 编译通过 → 测试全部通过 → 完成
             ↘ 编译失败 → 修复 ERROR → 重新编译
                        ↘ 测试失败 → 修复用例或代码 → 重新测试
```

**每次修改完成后，必须依次通过编译验证和测试验证，缺一不可。**

## 环境变量

```powershell
$env:DEVECO_SDK_HOME = "D:\software\Huawei\DevEco Studio\sdk"
```

所有 hvigorw 命令执行前必须设置此变量。

## 编译验证

```powershell
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default assembleHap --no-daemon
```

## 本地单元测试

无需设备，通过 hvigorw `test` 任务运行 `entry/src/test/` 下的测试：

```powershell
& "D:\software\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" `
  --mode module -p module=entry@default -p product=default test --no-daemon
```

- 测试结果：`entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- 覆盖率报告：`entry/.test/default/outputs/test/reports/index.html`

## OHOS 仪器测试

需要真机/模拟器，运行 `entry/src/ohosTest/` 下的测试。

**方式一** — DevEco Studio：右键 `entry/src/ohosTest/` → Run Tests

**方式二** — CLI：

```powershell
$hdc = "D:\software\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"

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

- 包名：`ww.wangwang.wangnong`（`AppScope/app.json5` → `bundleName`）
- 模块名：`entry_test`（`entry/src/ohosTest/module.json5` → `module.name`）

## 输出解读

| 关键字 | 含义 | 处理 |
|--------|------|------|
| `BUILD SUCCESSFUL` | 编译/测试成功 | 无需操作 |
| `BUILD FAILED` | 编译失败 | 搜索 `ERROR:` 定位 |
| `ERROR:` | 具体错误信息 | 必须修复 |
| `WARN:` | 警告 (deprecated API 等) | 通常可忽略 |
| `arkts-` 前缀 | ArkTS 语法约束违规 | 必须修复，参见 `arkts-patterns.instructions.md` |
| `Tests run: N, Failure: 0, Error: 0` | 单元测试全通过 | 视为成功 |
| `OHOS_REPORT_RESULT: ...Failure: 0, Error: 0` | 仪器测试全通过 | 视为成功 |

**注意**：`exit code 1` 可能由 WARN 导致，只要 `BUILD SUCCESSFUL` 且 `Failure: 0, Error: 0` 即视为通过。

## 常见构建问题

| 问题 | 排查 |
|------|------|
| 找不到模块 | 检查 `oh-package.json5` 依赖版本，运行 `ohpm install` |
| 类型不匹配 | ArkTS 比 TypeScript 更严格，不允许隐式 `any` |
| API 不存在 | 检查目标 API 版本 (API 22)，某些 API 仅高版本可用 |
| 仪器测试无设备 | `hdc list targets` 确认连接，或启动模拟器 |
| `aa test` 参数错误 | 确认包含 runner 参数 `OpenHarmonyTestRunner` |
