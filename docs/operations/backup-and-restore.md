# 数据库备份与恢复演练预案

更新时间：2026-04-24

## 目标

- 确保 PostgreSQL 核心数据可按计划备份。
- 确保团队能在独立环境完成恢复演练，而不是只会执行备份命令。
- 确保恢复后能验证登录、会话、消息主链路确实可用。

## 备份范围

- 用户、验证码、设备会话
- 会话、成员、消息、已读游标
- 举报、后台审计日志
- 推送登记与附件元数据

说明：附件二进制对象由对象存储单独治理，本预案覆盖的是数据库与关键元数据恢复。

## 建议频率

- 每日 1 次全量备份
- 每次生产发布前额外做一次发布前备份
- 预发环境每周至少做一次恢复演练

## 备份命令

在具备 `pg_dump` 的环境中执行：

```bash
export DATABASE_URL='postgres://...'
mkdir -p artifacts/backups
pg_dump "$DATABASE_URL" \
  --format=custom \
  --no-owner \
  --file "artifacts/backups/chat-$(date +%Y%m%d-%H%M%S).dump"
shasum -a 256 "artifacts/backups/chat-$(date +%Y%m%d-%H%M%S).dump"
```

执行要求：

- 备份文件必须写入受控存储，而不是只留在临时目录。
- 备份完成后记录文件名、时间、操作者、校验和。
- 发布前备份要和发布版本号一一对应。

## 恢复演练步骤

1. 准备独立恢复库，例如 `chat_restore_YYYYMMDD`。
2. 执行恢复：

```bash
export RESTORE_DATABASE_URL='postgres://...'
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  --dbname "$RESTORE_DATABASE_URL" \
  artifacts/backups/<backup-file>.dump
```

3. 对恢复库执行迁移对齐：

```bash
pnpm --dir server prisma:migrate:deploy
```

4. 使用恢复库启动服务后做最小验收：
   - `POST /auth/request-code`
   - `POST /auth/login` 或 `POST /auth/register`
   - `GET /auth/sessions`
   - `GET /ops/health`
   - 抽查一条会话历史消息

## 恢复演练记录模板

| 日期 | 备份文件 | 恢复目标库 | 演练人 | 结果 | 备注 |
| --- | --- | --- | --- | --- | --- |
| 待填写 |  |  |  |  |  |

## 失败处理

- `pg_restore` 失败：立即保留原日志，禁止直接覆盖同一恢复库反复尝试。
- 恢复成功但主链路异常：先跑 `prisma:migrate:deploy`，再核对环境变量和对象存储元数据配置。
- 若发布后需要回滚，不要跳过“恢复后验收”这一步，至少验证登录、单聊、消息历史三条核心路径。
