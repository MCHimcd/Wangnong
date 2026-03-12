# SunAgent 智慧农业系统 - 鸿蒙 ArkUI 前端对接指南 (V2.0 极速同步版)

本文档专为接手 `agri_system` 极速调试版的**鸿蒙 ArkTS / ArkUI** 前端开发团队编写。

后端架构已经经历过极简瘦身重构，现在的通信模式高度内聚、前后端完全解耦。前端 App **不需要**维护复杂的长连接（WebSocket/MQTT），直接通过极速的 HTTP Timer 轮询即可画出科技感爆棚的“大屏监控台”。

---

## 1. 核心架构认知与通信策略

### 1.1 极速轮询代替长连接
为了快速展示 Agent 的挂起和思考状态，建议 ArkUI 端的主入口页面开启一个 `setInterval` 或使用 `Timer` 模块，以 **2 秒** 为周期循环拉取接口。

### 1.2 只读与单点注入
- **数据面**：前端是一个纯粹的“只读监控大屏”，所有遥测数据、病害告警、以及 Agent 正在生成什么样的策略，全都通过 `GET` 拉取。
- **干预面**：前端唯一一个具有破坏性（写入）功能的地方，就是当系统挂起时弹出的**干预输入框**。通过发送一个带字符串的 `POST` 请求，瞬间扭转核心。

---

## 2. ArkUI 推荐页面路由结构

建议在 `entry/src/main/ets/pages` 下构建如下的结构：

| 页面/组件 | 功能描述 | 绑定的核心 API |
| :--- | :--- | :--- |
| `Dashboard.ets` | 核心大盘，展示 Agent 状态、温湿度数字 | `/api/latest-decision`, `/api/latest-telemetry` |
| `ChartArea.ets` (组件) | 当前环境历史折线图 | `/api/historical-telemetry` |
| `InterventionDialog.ets` (弹窗) | 当 Agent 状态为 `waiting_for_human_input` 时弹出的毛玻璃输入框 | `/api/submit-intervention` |
| `VisualAlarm.ets` (卡片) | 病害图像与 AI 视觉确诊结果显示 | `/api/latest-visual` |
| `HistoryList.ets` | 滑动列表，回顾被强干预过的历史决策 | `/api/historical-decisions` |

---

## 3. ArkTS 网络请求封装 (Axios / http模块)

### 3.1 核心数据接口调用模型
在 ArkTS 中，你需要定义与 `api_debug.md` 严格对齐的 `interface` 或 `class`，例如用于解析最新决策的心智模型：

```typescript
// 定义 Agent 思考模型
export interface AgentDecision {
  id: number;
  status: 'pending' | 'waiting_for_human_input' | 'human_feedback_received' | 'strategy_regenerated' | 'completed' | 'error';
  triggered_at: string;
  anomalies_detected: string[];
  strategy: string;
  action_items: string[];
  human_feedback: string;
  mqtt_commands: any[];
}
```

### 3.2 轮询数据池 (ViewModel 示例)
```typescript
import http from '@ohos.net.http';

@Entry
@Component
struct Dashboard {
  @State decisionInfo: AgentDecision | null = null;
  @State isWaitingIntervention: boolean = false;
  private timerId: number = -1;

  aboutToAppear() {
    // 开启 2 秒极速轮询
    this.timerId = setInterval(() => {
      this.fetchLatestDecision();
    }, 2000);
  }

  aboutToDisappear() {
    clearInterval(this.timerId); // 离开页面一定要销毁
  }

  async fetchLatestDecision() {
    let httpRequest = http.createHttp();
    let res = await httpRequest.request("http://<后端IP>:5000/api/latest-decision");
    if (res.responseCode === 200) {
      this.decisionInfo = JSON.parse(res.result as string);
      
      // 核心业务监控点：如果检测到后端卡主等待，立刻拉起输入框弹窗
      if (this.decisionInfo.status === 'waiting_for_human_input') {
        this.isWaitingIntervention = true;
      } else {
        this.isWaitingIntervention = false;
      }
    }
  }
  // ... build() 渲染逻辑
}
```

---

## 4. 重点业务流：人机协同弹窗的交互

当你在大屏页面侦测到 `isWaitingIntervention === true` 时，必须渲染出一个炫酷的干预框。

**在你的 `.ets` 视图中：**
```typescript
if (this.isWaitingIntervention) {
  Column() {
    Text('⏳ 系统挂起：等待人工校验')
      .fontColor(Color.Orange)
      .fontSize(20)
    
    // 显示 AI 当前打算干什么
    Text(this.decisionInfo?.strategy).fontColor(Color.White)
    
    // 人为强行干预输入框
    TextInput({ placeholder: '输入指令强制接管...' })
      .onChange((value: string) => { this.feedbackText = value })
      
    Button('发送指令至核心')
      .onClick(() => {
        this.submitIntervention(this.decisionInfo.id, this.feedbackText);
      })
  }
  .backgroundColor('rgba(0,0,0,0.8)') // 毛玻璃遮罩
  .backdropBlur(10)
}
```

**提交干预的 API 实现：**
向后端发送 POST 请求后，系统后端会在半秒内苏醒，开始重组。
```typescript
async submitIntervention(id: number, text: string) {
  let httpRequest = http.createHttp();
  await httpRequest.request("http://<后端IP>:5000/api/submit-intervention", {
    method: http.RequestMethod.POST,
    header: { 'Content-Type': 'application/json' },
    extraData: JSON.stringify({ decision_id: id, feedback: text })
  });
  // 提交后立刻收起弹窗，等待下一次 2s 轮询带来的 'strategy_regenerated' 更新
  this.isWaitingIntervention = false;
}
```

---

## 5. UI/UX 动效建议 (加分项)

由于这是个汇报和演示级别的 App：
1. **状态角标动效**：对于 `waiting_for_human_input` 状态，请在 ArkUI 中加一个持续缩放的动画 (`animation({ duration: 1000, iterations: -1 })`)，营造紧张的“倒计时感”。
2. **列表平滑刷新**：在获取 `/api/historical-decisions` 列表时，由于是倒序，每次新增的 `id` 在第一位。使用鸿蒙的 `List` 组件配合 `ForEach` 绑定唯一 ID 键值对，保证只有新增的数据会被插入，而不是整张列表闪烁。
3. **图表选用**：历史折线图数据（`/api/historical-telemetry`）建议使用鸿蒙生态内的 `McCharts` 或 `ECharts-HarmonyOS`，画 3 条折线（温、湿、土壤湿度），关闭动画减少 2 秒轮询时的频繁闪屏重绘。
