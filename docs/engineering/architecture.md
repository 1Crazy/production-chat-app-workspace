# 工程架构约束

## 仓库分层

```text
mobile/
server/
docs/
templates/
openspec/
```

## Flutter 目录规则

```text
mobile/lib/
├── app/                 # 应用壳、主题、路由、启动流程
├── features/            # 按业务功能拆分
└── shared/              # 跨 feature 复用能力
```

每个 feature 固定为：

```text
features/<name>/
├── presentation/
├── application/
├── domain/
└── data/
```

规则：

- `presentation` 不直接发请求。
- `application` 只负责编排，不负责序列化和持久化细节。
- `domain` 只放实体和值对象以及仓储接口。
- `data` 负责具体实现。

## NestJS 目录规则

```text
server/src/
├── infra/
├── modules/
└── main.ts
```

每个业务模块固定为：

```text
modules/<name>/
├── controllers/
├── services/
├── repositories/
├── dto/
├── entities/
├── events/
└── gateways/
```

规则：

- 跨模块访问通过公开 service 或事件，不允许直接引用别的模块 repository。
- 基础设施能力统一收口到 `infra/`。
- 管理端接口与用户端接口分开建模，避免混写在同一个 controller 中。

## 文件复杂度约束

- Flutter 页面建议不超过 250 行，超过 300 行必须拆分。
- NestJS controller/service/repository/gateway 建议不超过 300 行。
- DTO、实体、事件、常量和校验器禁止塞进同一个大文件。
