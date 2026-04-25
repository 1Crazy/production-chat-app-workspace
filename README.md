# Production Chat App

这是一个基于 Flutter + Dart + NestJS 的聊天应用仓库。

## 目录

- `mobile/`: Flutter 移动端工程，采用 feature-first 结构。
- `server/`: NestJS 模块化单体后端。
- `docs/engineering/`: 工程约束、目录规范和代码评审清单。
- `templates/`: Flutter feature 与 Nest module 的结构模板。
- `openspec/`: 需求、设计、规格和任务拆解。

## 快速开始

### 本地基础设施 Docker

本地开发建议把基础设施放进 Docker，应用本身继续在宿主机上跑：

```bash
pnpm dev:db
```

这会启动：

- PostgreSQL: `localhost:5432`
- Redis: `localhost:6379`
- MinIO API: `localhost:9000`
- MinIO Console: `localhost:9001`

如果这些端口已经被占用，可以在命令前覆写：

```bash
POSTGRES_PORT=55432 REDIS_PORT=56379 MINIO_PORT=59000 MINIO_CONSOLE_PORT=59001 pnpm db:up
```

本地开发直接复用现有环境模板：

- `server/env/.env.development.example`
- `server/env/.env.docker-local.example`
- `mobile/README.md`

说明：

- Redis 不是可选增强，而是服务端必需基础设施。
- 服务端启动时会主动校验 `REDIS_URL` 并执行 Redis 连通性探测。
- 如果 Redis 不可用，NestJS 服务会直接启动失败，不提供“无 Redis 降级模式”。

停止基础设施：

```bash
pnpm db:down
```

如果你已经起过一次本地 PostgreSQL，又想重新执行初始化脚本创建 `chat_dev` / `chat_test` 数据库，可以清掉卷后重建：

```bash
docker compose -f docker/compose.infra.yml down -v
pnpm db:up
```

### 推荐开发顺序

```bash
pnpm dev:prepare
pnpm dev:server
pnpm dev:web
```

说明：

- `pnpm dev:prepare`：启动本地 PostgreSQL / Redis / MinIO，并执行后端开发环境迁移
- `pnpm dev:server`：启动 NestJS 开发服务
- `pnpm dev:web`：启动 Flutter Web（Chrome）

### Flutter / Web

```bash
pnpm dev:web
```

其他环境：

```bash
pnpm dev:web:test
pnpm dev:web:staging
pnpm dev:web:prod
```

### Firebase 接线状态

当前移动端已经接入 `firebase_core`、`firebase_messaging` 和前台本地通知，
但下面两项还没有在仓库内真正闭环，启动时会以横幅提示 + 安全降级的方式暴露：

1. `flutterfire configure` 还没真正处理完成。
   这个步骤需要在你本机已登录 Firebase 并选定目标项目的上下文里执行，
   我不能替你直接闭环；当前只做到了显式提示，而没有代你运行该命令。
2. `mobile/android/app/google-services.json` 与
   `mobile/ios/Runner/GoogleService-Info.plist` 缺失时，
   也还没真正处理完成。
   这两个真实配置文件仍然必须存在，应用才能真正拿到并登记 FCM token；
   当前只做到了从“静默失败”升级成“显式提示 + 文档说明 + 安全降级”。

### NestJS

```bash
pnpm server:generate
pnpm server:migrate:dev
pnpm server:dev
```

启动前请确认 PostgreSQL 和 Redis 都已可用；当前服务端把会话实时广播、在线态、输入中 TTL、消息幂等键以及多实例 Socket.IO 协调都建立在 Redis 上。

如果你本地基础设施走 Docker，且 PostgreSQL 映射在 `55432`，直接用这组命令：

```bash
pnpm server:migrate:docker-local
pnpm server:docker-local
```

### 全容器化后端栈

如果你要在本地模拟“部署态”，可以直接起整套后端镜像：

```bash
cp docker/.env.stack.example docker/.env.stack
pnpm stack:up
```

这套栈会启动：

- `api` 容器
- `postgres` 容器
- `redis` 容器
- `minio` 容器
- `migrate` 一次性迁移容器

说明：

- Flutter 移动端不适合走 Docker 部署，开发和发布仍然是原生 `flutter run` / `flutter build`。
- 后端镜像定义在 `server/Dockerfile`。
- 本地开发的基础设施编排在 `docker/compose.infra.yml`。
- 全栈容器编排在 `docker/compose.stack.yml`。

## 工程约束

- 新增功能必须落入既定的 feature 或 module 目录，而不是平铺在根目录。
- 页面、controller、service 超过可读阈值时必须拆分，禁止出现万能文件。
- 配置、环境、审计和可观测性约束从骨架阶段就保留入口。
