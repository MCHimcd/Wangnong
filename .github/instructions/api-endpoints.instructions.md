---
description: "Use when adding, modifying, or debugging HTTP API calls, backend endpoints, HttpService methods, or REST API integration in the Wangnong app."
---
# HTTP API 端点指令

## 基本约定

- **统一入口**：所有 HTTP 请求必须通过 `HttpService.getInstance()` 发出，不直接调用 `@ohos.net.http`。
- **基地址**：`AppConfig.BASE_URL` (当前 `http://192.168.1.100:8080`)
- **鉴权**：除 auth 类接口外，所有请求 Header 携带 `Authorization: Bearer <token>`
- **响应格式**：`BaseResponse<T> { code: number, message: string, data: T }`

## HttpService 泛型请求

```typescript
private async request<T>(method: string, url: string, body?: object): Promise<BaseResponse<T>> {
  // method = 'GET' | 'POST' | 'PUT' | 'DELETE'
  // url 为相对路径，如 '/api/v1/devices'
}
```

## 端点清单

### 认证 `/api/v1/auth/`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `login` | 登录 (phone + password) → Token |
| POST | `register` | 注册 (phone + code + password) |
| POST | `forgot-password` | 找回密码 |
| POST | `send-verification-code` | 发送验证码 |
| PUT | `password` | 修改密码 |
| GET/PUT | `profile` | 获取/更新用户资料 |
| POST | `avatar/use-fixed` | 使用系统默认头像 |
| POST | `logout` | 登出 |

### 节点与传感器
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/devices` | 节点列表 |
| GET | `/api/v1/devices/{id}` | 节点详情 |
| GET | `/api/v1/devices/{id}/sensor-meta` | 传感器元数据 |
| GET | `/api/v1/devices/{id}/equipment-meta` | 设备元数据 |
| GET | `/api/v1/sensors/{id}/history?range=24h\|7d\|30d` | 传感器历史数据 |
| POST | `/api/v1/equipment/stats` | 设备运行统计 |

### 告警
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/alerts/list` | 告警列表 (分页 + 筛选) |
| POST | `/api/v1/alerts/handle` | 标记告警处理状态 |

### 视频
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/cameras/{id}/live` | 直播流地址 |
| GET | `/api/v1/cameras/{id}/playback?date=YYYY-MM-DD` | 回放片段 |
| GET | `/api/v1/cameras/{id}/keyframes?date=YYYY-MM-DD` | 关键帧 |

### 其他
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/agri-qa/chat` | 农业问答 (文本+图片, 60s 超时) |
| POST | `/api/v1/traceability/scan` | 溯源扫码 |
| CRUD | `/api/v1/scheduled-tasks/` | 定时任务 |
| CRUD | `/api/v1/admin/nodes/` | 管理员节点管理 |
| GET/PUT | `/api/v1/admin/users/` | 用户管理/角色 |
| GET | `/api/v1/operation-logs/` | 操作日志 |
| PUT | `/api/v1/thresholds/` | 阈值更新 |

## 添加新端点的步骤

1. 在 `HttpService.ets` 中添加 `public async` 方法
2. 使用 `this.request<T>(method, path, body)` 调用
3. 定义请求/响应类型（使用 class，不使用对象字面量）
4. 在页面/视图中通过 `HttpService.getInstance().newMethod()` 调用
5. 更新 `README.md` 的「HTTP API」章节
6. 如需在测试环境验证，考虑同步更新 `test_backend/server.py`

## 错误处理

```typescript
try {
  const resp = await HttpService.getInstance().getNodes();
  if (resp.code === 200) {
    // 成功
  } else {
    // 业务错误: resp.message
  }
} catch (err) {
  // 网络错误
}
```
