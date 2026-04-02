---
description: "Use when modifying MQTT topics, telemetry parsing, command publishing, real-time communication, MqttClientService, or adding new real-time data sources to the Wangnong app."
---
# MQTT 协议指令

## 主题结构

```
/wangnong_2026/device/+/telemetry   ← App 订阅 (QoS 1)
/wangnong_2026/device/+/alert       ← App 订阅 (QoS 1)
/wangnong_2026/node/{nodeId}/command → App 发布 (QoS 1)
```

**核心规则**：App 端只订阅以上两个主题。如需订阅新主题，应由后端桥接转发到现有主题，而非修改 App 端订阅列表。

## Payload 结构

### 遥测 (Telemetry)
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
    "mode": true
  }
}
```

### 告警 (Alert)
```json
{
  "msg_type": "alert",
  "node_id": "A03_Node_01",
  "timestamp": 1711900000,
  "data": {
    "alert_id": "uuid",
    "type": "temp_high",
    "type_name": "高温预警",
    "level": "critical",
    "message": "温室温度 38.2°C 超出安全阈值",
    "source": "A03_Node_01"
  }
}
```

### 控制命令 (Command) — App 发布
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

## 监听器模式

MqttClientService 使用回调数组实现观察者模式：

```typescript
// 添加遥测监听
const listener = (nodeId: string, data: TelemetryData) => { /* ... */ };
MqttClientService.getInstance().addTelemetryListener(listener);

// 移除（必须在 aboutToDisappear 中调用）
MqttClientService.getInstance().removeTelemetryListener(listener);
```

同样适用于 `addAlertListener` / `removeAlertListener`。

## 趋势缓存

`getCachedTrend(nodeId, metricKey)` 返回最近 60 个数据点，用于 SensorDetailPage 实时图表。

## 发布控制命令

```typescript
MqttClientService.getInstance().publishCommand(
  nodeId,        // 节点 ID
  'water_pump',  // 目标设备
  'turn_on',     // 命令
  {}             // 参数
);
```

## 修改须知

- 修改主题结构或消息格式后，**必须同步更新** `docs/asyncapi/asyncapi.yaml`。
- 新增 `msg_type` 需在 MqttClientService 的 `onMessage` 中添加解析分支。
- 告警类消息变更需同步更新 `AlertSyncService` 的处理逻辑。
