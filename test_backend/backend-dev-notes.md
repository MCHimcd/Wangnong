# 后端开发联调说明

## 1. 统一响应格式

请保持所有 HTTP 接口返回统一结构：

```json
{
  "code": 200,
  "message": "success",
  "data": {}
}
```

说明：
- code: 业务状态码，成功为 200。
- message: 简短状态文本，建议 success 或错误原因。
- data: 业务数据，空结果使用 null。

当前已知例外（测试阶段，前后端已按此联调）：
- GET /avatar_fixed.svg：返回图片文件（`image/svg+xml`），非 JSON。
- POST /api/v1/traceability/scan：返回 `text/plain` 纯文本，非 JSON。

## 2. 鉴权与 Token

前端通过 Authorization 头传递 Bearer Token：
- Authorization: Bearer <token>

当前前端会在登录成功后保存 token，并用于后续请求。
涉及鉴权的接口：
- GET /api/v1/auth/profile
- PUT /api/v1/auth/profile
- POST /api/v1/auth/avatar/use-fixed
- PUT /api/v1/auth/password
- POST /api/v1/auth/logout

建议：
- 当 token 无效时返回 401。
- logout 接口在 token 缺失时也可幂等返回成功，便于客户端兜底退出。

## 3. 关键接口对齐（已接入前端）

用户相关：
- POST /api/v1/auth/login
- POST /api/v1/auth/register
- POST /api/v1/auth/forgot-password
- POST /api/v1/auth/avatar/use-fixed
- PUT /api/v1/auth/password
- POST /api/v1/auth/logout
- GET /api/v1/auth/profile
- PUT /api/v1/auth/profile

溯源码相关：
- POST /api/v1/traceability/scan

设备相关：
- GET /api/v1/devices
- GET /api/v1/devices/{id}
- POST /api/v1/equipment/stats

传感器相关：
- GET /api/v1/sensors/{device_id}/history?range=24h&metric=temperature

告警相关：
- POST /api/v1/alerts/list
- POST /api/v1/alerts/handle

知识库相关：
- GET /api/v1/articles
- GET /api/v1/articles/{id}

视频相关：
- GET /api/v1/cameras/{device_id}/live
- GET /api/v1/cameras/{device_id}/playback
- GET /api/v1/cameras/{device_id}/keyframes

静态资源相关：
- GET /avatar_fixed.svg

病虫害识别：
- POST /api/v1/pest-detection/analyze

## 4. 特殊字段约定（请勿变更）

1) 设备详情接口 GET /api/v1/devices/{id}
- data.deviceState.smartMode: boolean
- 前端控制页首次进入依赖该字段回填智能模式。

2) MQTT telemetry
- topic: /wangnong_2026/device/{device_id}/telemetry
- data.mode: smart 或 manual
- 前端通过该字段实时同步智能模式状态。

3) 告警启动场景
- POST /api/v1/alerts/list 当 query.scene = startup 时：
  - 返回全部未处理告警
  - 加最近 10 条已处理告警

4) 头像临时方案
- 前端调用 POST /api/v1/auth/avatar/use-fixed 时不传文件名。
- 后端固定头像文件名为 avatar_fixed.svg，且文件与 server.py 同目录。
- 后端通过 GET /avatar_fixed.svg 暴露该文件；POST 接口返回可直接访问的 avatarSrc。

5) 溯源码测试方案
- POST /api/v1/traceability/scan 当前仅用于联调测试。
- 请求体中的 code 字段不参与业务判定，后端对任意值返回固定纯文本。

## 5. 已废弃接口

以下接口已从前端代码移除，请不要继续依赖：
- POST /api/v1/settings/save

## 6. 本地运行建议

当前 Python 后端依赖：
- flask
- flask-cors
- paho-mqtt

建议安装命令：

```bash
pip install flask flask-cors paho-mqtt
```

启动命令：

```bash
python server.py
```

默认监听：
- HTTP: 0.0.0.0:8080

## 7. 联调检查清单

- 登录成功后返回 token，后续鉴权接口可正常访问。
- 修改密码：oldPassword 错误时返回失败，正确时返回成功。
- 退出登录：前端可收到成功响应并清理本地登录态。
- 使用固定头像：POST /api/v1/auth/avatar/use-fixed 返回 avatarSrc 且可通过 GET /avatar_fixed.svg 打开图片。
- 溯源码测试：POST /api/v1/traceability/scan 任意 code 均返回固定纯文本。
- 设备列表：GET /api/v1/devices 返回非空数组，至少包含 id/name/status。
- 设备详情：返回 smartMode，且与 MQTT mode 字段语义一致。
- 告警处理：标记后 is_handled 和 handle_time 变化可见。
