---
description: "Use when modifying MQTT protocol definitions, HTTP API specifications, or the AsyncAPI documentation file (asyncapi.yaml). Ensures protocol documentation stays in sync with code changes."
---
# AsyncAPI 文档同步指令

## 文件位置

`docs/asyncapi/asyncapi.yaml` — AsyncAPI 2.6.0 规范，定义了所有 MQTT 主题和 HTTP API 端点。

## 何时需要更新

以下变更**必须同步更新** asyncapi.yaml：

1. **MQTT 主题变更** — 新增/修改/删除订阅或发布主题
2. **消息格式变更** — payload 字段增减、类型变化
3. **HTTP 端点变更** — 新增 API 路径或修改请求/响应结构
4. **QoS 或协议参数变更**

## 更新步骤

1. 打开 `docs/asyncapi/asyncapi.yaml`
2. 找到对应的 `channels` (MQTT 主题) 或 `components/schemas` (数据结构)
3. 修改定义，确保与代码实现一致
4. 如果新增了消息类型，在 `components/messages` 中添加定义
5. 验证 YAML 语法合法

## CI 自动部署

`.github/workflows/asyncapi-pages.yml` 在 `main` 分支 push 时：
- 验证 AsyncAPI YAML
- 生成 HTML 文档
- 部署到 GitHub Pages

确保修改后的 YAML 能通过 AsyncAPI CLI 的校验。

## 同步检查清单

- [ ] asyncapi.yaml 中的主题名与 `MqttClientService.ets` 一致
- [ ] payload schema 与实际 JSON 结构匹配
- [ ] HTTP 端点路径与 `HttpService.ets` 中的路径一致
- [ ] 新增字段有 description 说明
