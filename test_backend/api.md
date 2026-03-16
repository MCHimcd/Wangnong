# 鸿蒙慧田 API 规范与架构设计

## 1. 架构概述

本系统采用 **HTTP + MQTT** 混合通信架构，结合 **端侧本地计算**，以满足低延迟控制、实时数据可视化和弱网环境下的高可用性。

- **HTTP**: 用于基础业务数据访问（如用户管理、设备静态信息、文章知识库、图表历史数据）。
- **MQTT**: 专用于双向实时通信（传感器数据秒级上报、控制指令下发与实时确认、突发告警推送）。
- **端侧计算 (App/Edge)**: 承担本地规则防抖限制、图表数据按需抽稀以及本地心跳超时的断连判断，以此降低服务器压力并提升 App 用户体验。

---

## 2. HTTP 业务 API 规范

说明：所有接口均采用标准 RESTful JSON 格式返回，包含 `code`, `data`, `message`。本规范的 JSON 键名已严格对照 App 端的 ArkTS/TS Data Model 进行命名。

- 标记说明：**已实现** = 当前 `server.py` 路由已存在且前端已接入；**规划** = 文档保留但当前代码未落地。

### 2.1 用户模块 (User)

**1. 账号密码登录**

- **Method & Path**: `POST /api/v1/auth/login`
- **Request**: `{ "username": "...", "password": "..." }`
- **Response**:

  ```json
  {
    "code": 200,
    "message": "success",
    "data": {
      "token": "eyJhbGciOiJIUzI1NiIs...",
      "expires_in": 3600
    }
  }
  ```

**2. 注册账号**

- **Method & Path**: `POST /api/v1/auth/register`
- **Request**:

  ```json
  {
    "phone": "13800000000",
    "verificationCode": "123456",
    "password": "abc123456"
  }
  ```

- **Response**: `{ "code": 200, "message": "success", "data": null }`

**3. 找回密码**

- **Method & Path**: `POST /api/v1/auth/forgot-password`
- **Request**:

  ```json
  {
    "phone": "13800000000",
    "verificationCode": "123456",
    "newPassword": "new_abc123456"
  }
  ```

- **Response**: `{ "code": 200, "message": "success", "data": null }`

**4. 获取当前用户信息 (包含个人详细资料)**

- **Method & Path**: `GET /api/v1/auth/profile`
- **Header**: `Authorization: Bearer <token>`
- **Response**:

  ```json
  {
    "code": 200,
    "message": "success",
    "data": {
      "userId": "WangNong_001",
      "userName": "农场主",
      "gender": "男",
      "birthDate": "1990-01-01",
      "avatarSrc": "https://example.com/avatar.jpg"
    }
  }
  ```

**5. 修改用户资料 (姓名/性别/生日)**

- **Method & Path**: `PUT /api/v1/auth/profile`
- **Header**: `Authorization: Bearer <token>`
- **Request**:

  ```json
  {
    "userName": "某某农户",
    "gender": "女",
    "birthDate": "1992-05-10",
    "avatarSrc": "https://example.com/avatar_new.jpg"
  }
  ```

- **Response**: `{ "code": 200, "message": "success", "data": null }`

**6. 修改密码（已实现）**

- **Method & Path**: `PUT /api/v1/auth/password`
- **Header**: `Authorization: Bearer <token>`
- **Request**: `{ "oldPassword": "...", "newPassword": "..." }`
- **Response**: `{ "code": 200, "message": "success", "data": null }`

**7. 退出登录（已实现）**

- **Method & Path**: `POST /api/v1/auth/logout`
- **Header**: `Authorization: Bearer <token>`
- **Response**: `{ "code": 200, "message": "success", "data": null }`

**8. 使用临时固定头像（已实现，临时方案）**

- **Method & Path**: `POST /api/v1/auth/avatar/use-fixed`
- **Header**: `Authorization: Bearer <token>`
- **Request**: 无（前端不需要提供文件名字）
- **Response**:

  ```json
  {
    "code": 200,
    "message": "success",
    "data": {
      "userId": "WangNong_001",
      "userName": "农场主",
      "gender": "男",
      "birthDate": "1990-01-01",
      "avatarSrc": "http://<host>:8080/avatar_fixed.svg"
    }
  }
  ```

- **说明**: `avatar_fixed.svg` 当前暂存于后端 `server.py` 同目录并通过 `GET /avatar_fixed.svg` 暴露；后续可能替换为其他头像存储/分发方式。

---

### 2.2 设备与控制模块 (Device)

**1. 获取设备列表（已实现）**

- **Method & Path**: `GET /api/v1/devices`
- **Response**:

  ```json
  {
    "code": 200,
    "data": [
      {
        "id": "A03_Node_01",
        "name": "温室节点 1",
        "status": "online"
      }
    ]
  }
  ```

**2. 获取设备详细状态（已实现，含首次进入控制页主动状态拉取）**

- **Method & Path**: `GET /api/v1/devices/{id}`
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "id": "A03_Node_01",
      "name": "温室节点 1",
      "status": "online",
      "sensorData": {
        "temperature": 25.4,
        "humidity": 60.1,
        "light": 15000,
        "co2": 450,
        "soilTemp": 22.0,
        "soilHumidity": 45.2,
        "soilPh": 6.5
      },
      "deviceState": {
        "waterValveOn": false,
        "waterPumpOn": true,
        "ledOn": false,
        "fanOn": false,
        "extensionOn": false,
        "smartMode": true
      }
    }
  }
  ```

**3. 设备绑定/解绑（规划）**

- **Method & Path**: `POST /api/v1/devices/bind`
- **Request**: `{ "device_sn": "SNxxxx", "name": "温室1号主控" }`
- **Response**: `{ "code": 200, "data": { "id": "A03_Node_03", "status": "bound" } }`

**4. 获取设备控制历史/日志（规划）**

- **Method & Path**: `GET /api/v1/devices/{id}/control-logs?page=1&size=20`
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "total": 50,
      "items": [
        {
          "log_id": "L001",
          "action": "turn_on",
          "target": "waterPump",
          "trigger_mode": "manual",
          "operator": "user_123",
          "timestamp": 1679000000000,
          "result": "success"
        }
      ]
    }
  }
  ```

**5. 获取设备能力统计（已实现）**

- **Method & Path**: `POST /api/v1/equipment/stats`
- **Request**:

  ```json
  {
    "app_id": "WN_APP_001",
    "device_id": "A03_Node_01",
    "timestamp": 1710000000000,
    "query": {
      "device_type": "water_pump",
      "time_range": "7d"
    }
  }
  ```

- **Response**:

  ```json
  {
    "code": 200,
    "message": "success",
    "data": {
      "summary": {
        "total_value": 92,
        "unit": "灌溉量(升)"
      },
      "points": [
        { "timeLabel": "03-10", "value": 14 },
        { "timeLabel": "03-11", "value": 11 }
      ]
    }
  }
  ```

---

### 2.3 环境传感器大屏历史数据 (Sensor)

**1. 获取传感器历史趋势 (按时间范围查询曲线数据)**

- **Method & Path**: `GET /api/v1/sensors/{device_id}/history?range=24h&metric=temperature`
- **说明**: range 支持 `24h`, `7d`, `30d`；metric 支持 `temperature`, `humidity`, `light` 等。
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "metric": "temperature",
      "summary": { "max": 35.1, "min": 18.2, "avg": 26.5 },
      "points": [
        { "timeLabel": "00:00", "value": 22.1 },
        { "timeLabel": "01:00", "value": 21.8 }
      ]
    }
  }
  ```

---

### 2.4 告警监控模块 (Alert)

**1. 获取各类告警分页记录**

- **Method & Path**: `POST /api/v1/alerts/list`
- **说明**:
  - 常规场景按 `page/size/sort/filter` 分页返回。
  - 启动场景可传 `query.scene = "startup"`，返回 **全部未处理告警 + 最近10条已处理告警**。
- **Request**:

  ```json
  {
    "app_id": "WN_APP_001",
    "device_id": "A03_Node_01",
    "timestamp": 1710000000000,
    "query": {
      "scene": "startup",
      "page": 1,
      "size": 20,
      "sort_by": "timestamp",
      "order": "desc",
      "filter_type": "",
      "filter_status": ""
    }
  }
  ```

- **Response**:

  ```json
  {
    "code": 200,
    "message": "success",
    "data": {
      "total": 13,
      "unhandled_count": 3,
      "handled_recent_count": 10,
      "items": [
        {
          "alert_id": "A10992",
          "type": "high_temp",
          "type_name": "高温告警",
          "level": "critical",
          "message": "当前温度38°C，超出安全阈值",
          "timestamp": 1679000100000,
          "source": "environment",
          "source_name": "环境监测",
          "is_handled": false,
          "handle_time": null
        }
      ]
    }
  }
  ```

**2. 标记告警为已处理**

- **Method & Path**: `POST /api/v1/alerts/handle`
- **Request**:

  ```json
  {
    "app_id": "WN_APP_001",
    "device_id": "A03_Node_01",
    "timestamp": 1710000000000,
    "data": {
      "alert_id": "AL_001",
      "action": "handle",
      "notes": "已处理"
    }
  }
  ```

- **Response**:

  ```json
  {
    "code": 200,
    "message": "success",
    "data": {
      "alert_id": "AL_001",
      "is_handled": true,
      "handle_time": 1710000000000
    }
  }
  ```

---

### 2.5 科普知识库模块 (Knowledge)

**1. 获取农业知识文章列表**

- **Method & Path**: `GET /api/v1/articles?page=1&size=10`
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "total": 4,
      "items": [
        {
          "id": "1",
          "title": "云端种梦智能温室系统介绍",
          "date": "2024-04-10 15:48:31",
          "thumbnail": "https://example.com/thumbnails/1.jpg"
        }
      ]
    }
  }
  ```

**2. 获取单篇文章详情 (包含正文)**

- **Method & Path**: `GET /api/v1/articles/{id}`
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "id": "1",
      "title": "云端种梦智能温室系统介绍",
      "date": "2024-04-10 15:48:31",
      "thumbnail": "https://example.com/thumbnails/1.jpg",
      "content": "云端种梦智能温室系统是一款融合了物联网、人工智能和大数据技术的现代农业解决方案。...",
      "images": [
        "https://example.com/images/1_a.jpg",
        "https://example.com/images/1_b.jpg"
      ]
    }
  }
  ```

---

### 2.6 视频流与关键抓拍模块 (Video)

**1. 获取直播流信息**

- **Method & Path**: `GET /api/v1/cameras/{device_id}/live`
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "cameraId": "cam_01",
      "cameraName": "一号大棚全景",
      "status": "online",
      "streamTag": "MAIN_STREAM",
      "resolution": "1080P",
      "lastHeartbeat": "2026-03-16 10:20:00",
      "streamUrl": "https://media.w3.org/2010/05/sintel/trailer.mp4"
    }
  }
  ```

**2. 获取某日回放录像片段列表**

- **Method & Path**: `GET /api/v1/cameras/{device_id}/playback?date=2026-03-16`
- **Response**:

  ```json
  {
    "code": 200,
    "data": [
      {
        "id": "PB_123",
        "date": "2026-03-16 08:00:00",
        "duration": "01:00:00",
        "quality": "HD",
        "available": true,
        "abnormalCount": 2
      }
    ]
  }
  ```

**3. 获取监控异常抓拍/关键帧**

- **Method & Path**: `GET /api/v1/cameras/{device_id}/keyframes?date=2026-03-16`
- **Response**:

  ```json
  {
    "code": 200,
    "data": [
      {
        "id": "KF_001",
        "captureTime": "2026-03-16 08:15:30",
        "label": "入侵检测",
        "confidence": 0.92,
        "thumbnailHint": "https://example.com/kf_001.jpg",
        "isAbnormal": true,
        "abnormalType": "intrusion",
        "severity": "critical"
      }
    ]
  }
  ```

---

### 2.7 AI 病虫害诊断模块 (Pest)

**1. 图片上传并进行AI诊断**

- **Method & Path**: `POST /api/v1/pest-detection/analyze`
- **当前实现 Request(JSON)**:

  ```json
  {
    "app_id": "WN_APP_001",
    "device_id": "A03_Node_01",
    "timestamp": 1710000000000,
    "data": {
      "notes": "image_uri: file://local/path/to/image.jpg"
    }
  }
  ```

- **规划 Request(FormData)**: `file` -> Blob (手机拍照/相册图片)
- **Response**:

  ```json
  {
    "code": 200,
    "data": {
      "pestName": "番茄早疫病",
      "confidence": "94.2%",
      "severity": "High",
      "color": "#FF7043",
      "suggestion": "建议喷洒百菌清或代森锰锌类杀菌剂..."
    }
  }
  ```

---

### 2.8 溯源码模块 (Traceability)

**1. 扫码结果上传并获取作物信息（已实现，测试阶段固定文本）**

- **Method & Path**: `POST /api/v1/traceability/scan`
- **Header**: `Authorization: Bearer <token>`
- **Request**:

  ```json
  {
    "code": "TRACE_1710000000000"
  }
  ```

- **Response(Content-Type: text/plain)**:

  ```text
  溯源码识别结果（测试固定文本）：作物番茄，地块A03，当前状态正常。
  ```

- **说明**: 当前测试阶段后端不区分二维码内容，任意 `code` 都返回同一段固定纯文本。

---

## 3. MQTT 实时协议规范 (控制与流数据)

### 3.1 设备传感器流实时上报 (Device -> Cloud/App)

- **Topic**: `/wangnong_2026/device/{device_id}/telemetry`
- **Frequency**: 通常每 3-5 秒一次。
- **Payload**:

  ```json
  {
    "msg_type": "telemetry",
    "device_id": "A03_Node_01",
    "timestamp": 1679000100000,
    "data": {
      "environment": {
        "temperature": 25.4,
        "humidity": 60.1,
        "soilTemp": 22.0,
        "soilHumidity": 45.2,
        "light": 15000,
        "co2": 450
      },
      "equipment": {
        "water_pump": false,
        "led_light": true,
        "fan": false,
        "camera": true
      },
      "mode": "smart"
    }
  }
  ```

### 3.2 强控制指令下发 (App -> Cloud -> Device)

- **Topic**: `/wangnong_2026/device/{device_id}/command`
- **说明**:
  - 设备开关控制：`target_device` 取值如 `water_pump` / `led_light` / `fan`，`command` 取值 `turn_on` / `turn_off`。
  - 模式切换控制（已实现）：`target_device = "mode"`，`command` 取值 `smart` / `manual`。
- **Payload**:

  ```json
  {
    "cmd_id": "CMD_9901",
    "timestamp": 1679000100000,
    "msg_type": "control",
    "action": {
      "target_device": "water_pump",
      "command": "turn_on",
      "parameters": {
        "duration_seconds": 15
      }
    }
  }
  ```

### 3.3 实时突发告警推送 (Cloud/Edge -> App)

- **Topic**: `/wangnong_2026/device/{device_id}/alert`
- **Payload**:

  ```json
  {
    "msg_type": "alert",
    "device_id": "A03_Node_01",
    "timestamp": 1679000150000,
    "data": {
      "alert_id": "A10992",
      "type": "high_temp",
      "type_name": "高温告警",
      "level": "critical",
      "timestamp": 1679000150000,
      "message": "当前温度38°C，超出安全阈值",
      "source": "environment",
      "source_name": "环境监测",
      "is_handled": false,
      "handle_time": null
    }
  }
  ```

---

## 4. App 端侧本地计算与防抖策略 (Edge Logic)

1. **设备心跳断线判定 (Offline Detection)**
   - App 本地监听 MQTT。如果超过 10 秒未收到 telemetry，端侧 UI 自动渲染为离线。

2. **控制 UI 指令按键锁定 (Debounce & Flow Control)**

- 点击控制按钮后进入 `isWorking = true` 过渡态，当前实现锁定约 1 秒（防误触与防抖），后续可按需求调整为更长窗口。

1. **告警同步策略**
   - 启动时通过 `POST /api/v1/alerts/list`（`query.scene = "startup"`）拉历史；运行中通过 MQTT 实时接收新增告警。

2. **实时图表抽稀**
   - 高频上报数据进入内存队列，图表按定点或移动平均抽稀后绘制，确保 UI 流畅。

---

## 5. API 与代码对齐检查（2026-03-16）

### 5.1 已实现并已接入前端的接口

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/forgot-password`
- `PUT /api/v1/auth/password`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/avatar/use-fixed`
- `GET /api/v1/auth/profile`
- `PUT /api/v1/auth/profile`
- `GET /api/v1/devices`
- `GET /api/v1/devices/{id}`
- `GET /api/v1/sensors/{device_id}/history`
- `POST /api/v1/equipment/stats`
- `POST /api/v1/alerts/list`
- `POST /api/v1/alerts/handle`
- `GET /api/v1/articles`
- `GET /api/v1/articles/{id}`
- `GET /api/v1/cameras/{device_id}/live`
- `GET /api/v1/cameras/{device_id}/playback`
- `GET /api/v1/cameras/{device_id}/keyframes`
- `POST /api/v1/pest-detection/analyze`
- `POST /api/v1/traceability/scan`

### 5.2 文档存在但当前代码未落地的接口

- `POST /api/v1/devices/bind`
- `GET /api/v1/devices/{id}/control-logs`

### 5.3 关键字段对齐更新

- `GET /api/v1/devices/{id}` 的 `deviceState` 已补充 `smartMode` 字段，用于控制页首次进入主动状态拉取。
- MQTT telemetry 的 `data` 已补充 `mode` 字段（`smart` / `manual`），用于前端实时同步智能模式开关。
- 头像临时方案：`POST /api/v1/auth/avatar/use-fixed` 由后端返回固定头像地址，前端不传文件名；当前固定资源地址为 `GET /avatar_fixed.svg`（与 `server.py` 同目录文件）。
