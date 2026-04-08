---
description: "Use when writing or editing ArkTS (.ets) UI components, pages, views, or builders in the Wangnong app. Covers decorator usage, @Builder patterns, ForEach, lifecycle hooks, and common ArkTS compilation errors."
applyTo: "entry/src/main/ets/**/*.ets"
---
# ArkTS 编码模式

## 装饰器速查

| 装饰器 | 作用 | 示例 |
|--------|------|------|
| `@Entry @Component` | 页面根组件 | `@Entry @Component struct LoginPage { ... }` |
| `@Component export` | 可复用视图 | `@Component export struct MonitorView { ... }` |
| `@State` | 组件内可变状态 | `@State username: string = ''` |
| `@Prop` | 父 → 子只读 | `@Prop nodesList: string[]` |
| `@ObjectLink` | 父 → 子 @Observed 对象 | `@ObjectLink node: Node` |
| `@StorageLink` | 全局 AppStorage 双向绑定 | `@StorageLink('currentBreakpoint') bp: string = 'sm'` |
| `@Observed` | 使类实例可被 UI 追踪 | `@Observed class Node { ... }` |
| `@Builder` | 可复用 UI 构建函数 | `@Builder MenuRow(icon: string, label: string) { ... }` |

## @Builder 模式

```typescript
// ✅ 组件内 Builder：使用 this.BuilderName() 调用
@Builder MenuRow(icon: string, label: string) {
  Row() {
    Text(icon).fontSize(AppFontSize.H3)
    Text(label).fontSize(AppFontSize.Body).layoutWeight(1)
  }
  .padding(AppSpacing.MD)
}

// 调用
this.MenuRow('🔔', '告警')
```

## ForEach 必须提供 Key

```typescript
// ✅ 正确：第三个参数为 key 生成函数
ForEach(this.sensorMeta, (item: SensorMetaItem) => {
  SensorCard({ meta: item })
}, (item: SensorMetaItem) => item.key)

// ❌ 缺少 key 函数，列表更新时可能 UI 异常
ForEach(this.sensorMeta, (item: SensorMetaItem) => {
  SensorCard({ meta: item })
})
```

## 生命周期

```typescript
@Entry @Component struct MyPage {
  private timerId: number = -1;

  async aboutToAppear(): Promise<void> {
    // 初始化：加载数据、订阅 MQTT、设置定时器
    this.timerId = setInterval(() => { /* ... */ }, 1000);
  }

  aboutToDisappear(): void {
    // 清理：清除定时器、移除 MQTT 监听
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
    MqttClientService.getInstance().removeTelemetryListener(this.onTelemetry);
  }
}
```

## 设计规范引用

始终使用 `DesignToken.ets` 中的常量，不要硬编码数值：

```typescript
// ✅
.fontSize(AppFontSize.Body)
.fontColor(AppColors.TextPrimary)
.padding(AppSpacing.LG)
.borderRadius(AppRadius.MD)

// ❌
.fontSize(14)
.fontColor('#1B2631')
.padding(16)
.borderRadius(12)
```

## 响应式布局

```typescript
@StorageLink('currentBreakpoint') bp: string = 'sm';

build() {
  if (this.bp === 'lg') {
    Row() { Sidebar(); Content(); }   // 平板横屏：侧边栏 + 内容
  } else {
    Column() { Content(); }            // 手机：纯内容
  }
}
```

---

## 编译错误修正 (arkts-* 规则)

> 此节是所有 ArkTS 编译期约束违规的**唯一参考**。运行时调试参见 `debugging.instructions.md`。

### arkts-no-untyped-obj-literals

ArkTS 不允许无类型对象字面量 `{ key: value }`。

```typescript
// ❌ 编译错误
let data = { name: 'test', value: 123 };

// ✅ 定义 class 并实例化
class MyData { name: string = ''; value: number = 0; }
let data = new MyData();
data.name = 'test';
data.value = 123;

// ✅ 使用 Record 类型 (适合动态 KV 场景)
let map: Record<string, number> = {};
map['temperature'] = 25.3;
```

### arkts-no-intersection-types

ArkTS 不支持交叉类型 `A & B`，常见于测试中"临时扩展类型"写法。

```typescript
// ❌ 编译错误
let svc = HttpService.getInstance() as HttpService & Record<string, Object>;

// ✅ 使用已声明类型，或定义显式继承类/接口
let svc = HttpService.getInstance();
```

### arkts-no-props-by-index

ArkTS 不支持通过索引访问类成员 `obj['field']`。

```typescript
// ❌ 编译错误
let ok = typeof svc['checkServerHealth'] === 'function';

// ✅ 使用点语法
let ok = svc.checkServerHealth !== undefined;
```

### @Observed + Record 深度响应

修改 Record 内部值不会自动触发 UI 刷新，需通过 `revision` 计数器驱动：

```typescript
@Observed class NodeState {
  private equipmentStates: Record<string, boolean> = {};
  revision: number = 0;

  setState(key: string, on: boolean): void {
    this.equipmentStates[key] = on;
    this.revision++;  // 触发 UI 更新
  }
}
```

### ForEach 不更新

列表数据变化后 `ForEach` 不重新渲染 — 确保提供唯一 key 生成函数（见上方 ForEach 节）。

### 循环导入

**症状**：运行时 `undefined` 错误，类型在运行时为 `undefined`。

**修复**：使用 `import type` 或重构文件依赖链，消除循环。
