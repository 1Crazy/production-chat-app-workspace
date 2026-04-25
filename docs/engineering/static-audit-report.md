# 静态巡检报告

更新时间：2026-04-24

## 目标

本次巡检聚焦 OpenSpec 任务 7.4：识别“目录混乱、文件过大、职责过多”的高风险模块，并把 code review 时必须盯住的清单显式写出来。这里先做静态盘点，不在本报告里直接展开大规模重构。

## 结论摘要

- `server` 侧已有多处超过约定的 300 行阈值，最突出的是实时网关、消息服务、通知服务和数据库聚合仓储。
- `mobile` 侧超过约定的 250 行阈值更明显，聊天控制器、应用壳、聊天页和推送服务都已经进入高风险区。
- 当前目录边界总体仍然清晰，问题主要不是“文件到处乱放”，而是少数主链路文件持续吸收新职责。

## Server 高风险文件

约束：NestJS controller/service/repository/gateway 建议不超过 300 行。

| 文件 | 行数 | 风险判断 | 建议 |
| --- | ---: | --- | --- |
| `server/src/modules/realtime/gateways/chat.gateway.ts` | 446 | 过大，聚合了鉴权、入房、presence 广播、typing、断线恢复 | 优先拆分连接鉴权、presence 广播、房间同步辅助器 |
| `server/src/infra/database/repositories/prisma-chat-model.repository.ts` | 440 | 仓储职责过宽，聚合了会话/消息/已读多类读写 | 按 conversation/message/read-cursor 子仓储拆分 |
| `server/src/modules/notifications/services/notifications.service.ts` | 407 | 同时承担推送登记、离线推送、补偿同步、摘要拼装 | 将 push dispatch 与 sync-state 组装拆为独立协作者 |
| `server/src/modules/conversations/services/conversations.service.ts` | 389 | 会话创建、列表摘要、读游标、成员资料拼装混在一起 | 按创建链路、摘要查询、读状态更新拆分 |
| `server/src/modules/messages/services/messages.service.ts` | 371 | 发送、幂等、历史分页、断线补偿、附件消息归一化集中在一个 service | 先拆 send/sync/history 三段，再下沉附件组装器 |
| `server/src/modules/media/services/media.service.ts` | 336 | 上传授权、确认、访问鉴权、状态转换耦合 | 上传授权与访问鉴权可先拆成两个协作者 |
| `server/src/modules/auth/services/auth.service.ts` | 325 | 注册、登录、刷新、会话治理集中，接近失控边缘 | 保持当前边界，但后续把验证码校验与会话编排拆开 |

## Mobile 高风险文件

约束：Flutter 页面建议不超过 250 行，超过 300 行必须拆分。

| 文件 | 行数 | 风险判断 | 建议 |
| --- | ---: | --- | --- |
| `mobile/lib/features/chat/application/chat_controller.dart` | 647 | 控制器已承载消息状态机、同步、重连补偿、多类 UI 命令 | 优先拆成发送链路、同步链路、附件链路三个 coordinator |
| `mobile/lib/app/shell/app_shell.dart` | 582 | 应用壳过重，路由、导航、页面编排耦合 | 把侧栏/主面板/详情面板拆成独立组件 |
| `mobile/lib/features/chat/presentation/pages/chat_page.dart` | 469 | 页面布局、交互、状态桥接混写 | 抽消息列表区、输入区、顶部信息区 |
| `mobile/lib/shared/notifications/push_notification_service.dart` | 458 | 推送解析、权限、路由跳转、角标同步职责过多 | 解析器、权限协调器、跳转协调器拆开 |
| `mobile/lib/features/chat/presentation/widgets/chat_message_bubble.dart` | 447 | 多消息类型渲染集中在一个组件 | 拆文本、图片、语音、文件子渲染器 |
| `mobile/lib/features/profile/presentation/pages/profile_page.dart` | 349 | 资料页视图状态和行为过多 | 拆 section widget 与 action sheet 逻辑 |

## Code Review 重点清单

- 是否继续把新逻辑塞进上述大文件，而不是借机拆职责。
- 是否在 service/controller/page 中同时出现“网络调用 + 数据转换 + UI/事件编排”三类职责。
- 是否新增跨模块直接依赖 repository 的行为，尤其是 `messages` / `notifications` / `conversations` 之间。
- 是否把本应进入 `infra/observability` 或 `shared/notifications` 的通用逻辑塞进业务文件。
- 对超过阈值文件的改动，是否同步补了更细粒度测试，避免后续拆分时无保护。

## 建议的后续顺序

1. 先处理 `chat.gateway.ts`、`messages.service.ts`、`chat_controller.dart` 这三处，因为它们都位于主链路中央。
2. 再处理 `notifications.service.ts` 和 `push_notification_service.dart`，把推送与同步的责任边界清晰化。
3. 最后拆应用壳和资料页一类 UI 聚合文件，降低后续页面扩展成本。
