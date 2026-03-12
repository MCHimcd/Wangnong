# 全局统一定义 (通用设计)

## 统一公共参数 (上行) / 必传

不论是 HTTP 还是 MQTT，只要是 App 发出的数据，都必须带有以下 3 个公共参数：

- **`app_id`**：App的唯一标识（如："WN_APP_IOS_001"）
- **`device_id`**：网关/大棚节点的ID（如："A03_Node_01"）
- **`timestamp`**：当前13位时间戳，用于时序校验。

## 统一 HTTP 返回结构 (下行)

```json
{
  "code": 200,             // 状态码：200为成功
  "msg": "success",        // 状态描述
  "timestamp": 1710000000000, // 服务器响应时间
  "data": { ... }          // 具体业务数据层
}
```

---

# 一、 MQTT 实时通信层 (设备状态与控制)

## 1. APP -> 后端：发送设备控制指令 (对应 `ControlView.ets`)

App 向下发出的全部指令（开关、滑动调光），格式统一。

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000000000,
  "msg_type": "command",
  "payload": {
    "target_device": "water_pump", // 目标："water_pump", "led_light", "fan", "camera"
    "action": "turn_on",           // 动作："turn_on", "turn_off", "adjust"
    "params": {
      "duration_seconds": 15,      // [可选] 用于水泵的单次开启时长
      "target_volume": 5.0,        // [可选] 用于精密灌溉目标水量(升)，满足水量自动计算与控制功能
      "brightness": 80             // [可选] 用于 action 为 "adjust" 时调光
    }
  }
}
```

## 2. 后端 -> APP：主动预警与异常推送 (新增，应对阈值预警规则与推送)

后端监控环境阈值与设备状态，主动推送告警。

```json
{
  "msg_type": "alarm",
  "device_id": "A03_Node_01",
  "timestamp": 1710000002000,
  "data": {
    "level": "critical",             // 告警级别："critical", "warning", "info"
    "alarm_type": "moisture_low",    // 告警类型："temp_high", "moisture_low", "device_offline"
    "message": "土壤湿度连续低于阈值，建议立即灌溉",
    "recommend_action": "start_irrigation"
  }
}
```

## 3. 后端 -> APP：实时环境与状态推送 (对应 `DashboardView.ets` 和主页)

后端返回时剔除了冗余层级，将所有变量名统一，保证 App 侧只需要简单的模型映射。

```json
{
  "msg_type": "telemetry",
  "device_id": "A03_Node_01",
  "timestamp": 1710000005000,
  "data": {
    "environment": {
      "temperature": 28.5,   // 统一命名为 temperature (原 air_temp)
      "humidity": 55.0,      // 统一命名为 humidity
      "light": 1500,         // 统一命名为 light
      "co2": 420             // 统一命名为 co2
    },
    "equipment": {
      "water_pump": true,    // 水泵当前状态
      "led_light": false,    // LED当前状态
      "led_brightness": 80,  // LED当前亮度
      "fan": true,           // 风扇排风当前状态
      "camera": false        // 摄像头 AI 识别状态
    }
  }
}
```

---

# 二、 HTTP API 历史记录与配置层

## 1. 获取传感器历史趋势折线图 (对应 `SensorDetailPage.ets`)

用于获取：温度/湿度/光照/CO2 的历史数据（包含最高、平均、最低值）。

**请求：** `[POST /api/v1/sensor/history]`

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000000000,
  "query": {
    "sensor_type": "temperature", // "temperature", "humidity", "light", "co2"
    "time_range": "7d"            // "24h", "7d", "30d"
  }
}
```

**响应：** 参数名已与您最新的 ArkTS 模型高度对齐 (`time`, `value`, `maxVal`, `minVal`)：

```json
{
  "code": 200,
  "msg": "success",
  "timestamp": 1710000001000,
  "data": {
    "summary": {
      "avg_value": 26.5,
      "max_value": 31.0,
      "min_value": 18.5
    },
    "points": [
      {
        "time": "3-10",
        "value": 26.5,    // 平均值
        "maxVal": 31.0,   // 当日最高
        "minVal": 18.5    // 当日最低
      }
      // ... 以此类推，7天就有7条
    ]
  }
}
```

## 2. 获取设备运行统计柱状图 (对应 `DeviceDetailPage.ets`)

用于获取：水泵灌溉量、LED补光时长、AI摄像头识别次数 等日统计。

**请求：** `[POST /api/v1/equipment/stats]`
（参数结构与传感器历史查询完全一致，真正做到通用统一）

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000000000,
  "query": {
    "device_type": "water_pump", // "water_pump", "led_light", "camera"
    "time_range": "7d"           // "7d", "30d"
  }
}
```

**响应：**

```json
{
  "code": 200,
  "msg": "success",
  "timestamp": 1710000001000,
  "data": {
    "summary": {
      "total_value": 85.0,  // "近7日总量" 汇总值
      "unit": "升"           // 前端直接使用此单位 (升/H/次)
    },
    "points": [
      {
        "timeLabel": "3-08", // 横坐标
        "value": 15.0        // 当日柱状图数值
      },
      {
        "timeLabel": "3-09",
        "value": 10.0
      }
    ]
  }
}
```

## 4. 自动化限制、联动逻辑与预警阈值读取/保存 (对应 `SettingsView.ets`)

将所有的自动化选项合并为单一配置文件进行上传。支持高级联动逻辑设定。

**请求：** `[POST /api/v1/settings/save]`

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000000000,
  "data": {
    "automation": {
      "auto_irrigation": true, // 允许自动灌溉系统
      "auto_cooling": true     // 允许设备高温排风
    },
    "crop_info": {             // 新增，为智能灌溉算法提供支撑
      "crop_type": "tomato",
      "soil_type": "loam"
    },
    "thresholds": {
      "temp_high_alert": 35.0, // 温度高位告警阈值 (°C)
      "humid_low_alert": 40.0  // 土壤湿度低位灌溉阈值 (%)
    },
    "linkage_rules": [         // 新增，实现大赛要求的“联动逻辑配置”
      {
        "id": "rule_001",
        "trigger": {"sensor": "temperature", "operator": ">", "value": 35.0},
        "action": {"device": "fan", "command": "turn_on"}
      }
    ]
  }
}
```

**响应：**

```json
{
  "code": 200,
  "msg": "Config saved successfully",
  "timestamp": 1710000005000,
  "data": {}
}
```

---

# 三、 扩展设备与系统状态层 (贴合扩展与状态管理扣分点)

## 1. 扩展设备：AI 摄像头状态与识别配置 (实现任务 5 的扩展功能)

**请求：** `[POST /api/v1/equipment/camera/config]`

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000000000,
  "data": {
    "mode": "pest_detection",   // 工作模式："pest_detection" (虫害监测), "growth_monitor" (长势监控)
    "interval_minutes": 60      // 抓拍上报间隔
  }
}
```

## 2. 获取网关/子设备在线状态列表 (实现设备连接管理)

**请求：** `[GET /api/v1/device/status]`

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000000000,
  "query": {}
}
```

**响应：**

```json
{
  "code": 200,
  "timestamp": 1710000001000,
  "data": {
    "gateway_status": "online",
    "signal_strength": -65,
    "last_heartbeat": 1710000000500,
    "sub_devices": [
      {
        "device_type": "water_pump",
        "status": "online",
        "health": "good"
      },
      {
        "device_type": "camera",
        "status": "offline",
        "health": "disconnected"
      }
    ]
  }
}
```

---

# 四、 预警管理 (HTTP)

## 1. 获取预警列表

**Endpoint:** `GET /api/v1/alerts/list`
**Method:** `GET`
**Description:** 获取特定设备或网关的预警记录列表。

**请求参数 (Query string):**

- `device_id` (String): 设备ID (可选)
- `type` (String): 预警类型 (如 temp_high, pest_warning) (可选)
- `status` (String): 处理状态 (unhandled, handled) (可选)
- `page` (Number): 页码
- `size` (Number): 每页数量

**响应:**

```json
{
  "code": 200,
  "data": {
    "total": 50,
    "alerts": [
      {
        "alert_id": "A123",
        "device_id": "A03_Node_01",
        "type": "temp_high",
        "message": "大棚温度过高，超过35度",
        "timestamp": 1710000000000,
        "status": "unhandled"
      }
    ]
  }
}
```

## 2. 处理预警

**Endpoint:** `POST /api/v1/alerts/handle`
**Method:** `POST`
**Description:** 标记预警为已处理并记录处理方式（此时App向后端同步预警对应措施）。

**请求 (JSON):**

```json
{
  "app_id": "WN_APP_001",
  "device_id": "A03_Node_01",
  "timestamp": 1710000010000,
  "data": {
    "alert_id": "A123",
    "action": "open_fan",
    "remark": "已开启风扇降温"
  }
}
```

**响应:**

```json
{
  "code": 200,
  "message": "success"
}
```
