# 可观测性与告警规则

更新时间：2026-04-24

## 已落地能力

服务端现已提供以下基础能力：

- 结构化日志：统一通过 `AppLoggerService` 输出 JSON 日志。
- 请求追踪：HTTP 请求会生成并返回 `x-request-id`、`x-trace-id`。
- 接口指标：记录请求总量、错误量、耗时摘要。
- 实时指标：记录 Socket 连接总量、断开总量、当前活跃连接数。
- 业务指标：记录消息发送结果、推送发送结果、通知同步次数、关键后台动作计数。

## 观测入口

- 健康检查：`GET /ops/health`
- Prometheus 文本指标：`GET /ops/metrics`
- 指标快照（JSON）：`GET /ops/metrics/summary`

## 关键日志字段

- `timestamp`：日志时间
- `level`：日志级别
- `app` / `env`：应用名与环境
- `context`：模块上下文
- `message`：事件名
- `traceId` / `requestId`：排障主键
- `metadata`：事件附加上下文

排查链路时优先按 `traceId` 或 `requestId` 聚合，而不是只按用户 ID 全文搜索。

## 关键指标

- `http_server_requests_total`
- `http_server_errors_total`
- `http_server_request_duration_ms_count|sum|max`
- `chat_realtime_connections_total`
- `chat_realtime_disconnects_total`
- `chat_realtime_active_connections`
- `chat_message_delivery_total`
- `chat_push_delivery_total`
- `chat_notification_sync_total`
- `chat_admin_actions_total`

## 告警规则建议

### P1

- 消息发送失败率在 5 分钟窗口内超过 2%
  - 计算：`chat_message_delivery_total{result="failed"} / chat_message_delivery_total`
- `chat_realtime_active_connections` 在生产环境连续 5 分钟为 0
- `/ops/health` 失败或超时连续 3 次

### P2

- 推送发送失败率在 10 分钟窗口内超过 10%
  - 计算：`chat_push_delivery_total{result="failed"} / chat_push_delivery_total{result="sent|failed"}`
- HTTP 5xx 比例在 5 分钟窗口内超过 5%
  - 特别关注 `/auth/*`、`/messages/*`、`/notifications/sync-state`
- `http_server_request_duration_ms_max` 持续高于 1500ms

### P3

- `chat_admin_actions_total` 异常尖峰，需要复核是否存在批量封禁、批量踢下线或误操作
- `chat_push_delivery_total{result="skipped_session_invalid"}` 持续升高，说明会话回收可能滞后

## 值班排障流程

1. 先看 `/ops/health` 和活跃连接数，区分“整体不可用”还是“局部链路异常”。
2. 再看 `chat_message_delivery_total`、`chat_push_delivery_total`、HTTP 5xx 比例，定位故障面。
3. 取失败请求的 `x-request-id` 或 `x-trace-id`，在结构化日志里串起控制器、服务和后台动作。
4. 如果涉及管理员处理、封禁或踢下线，再用 `chat_admin_actions_total` 和审计日志交叉核对。
