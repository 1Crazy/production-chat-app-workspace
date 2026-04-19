# Production Chat App

这是一个基于 Flutter + Dart + NestJS 的聊天应用仓库。

## 目录

- `mobile/`: Flutter 移动端工程，采用 feature-first 结构。
- `server/`: NestJS 模块化单体后端。
- `docs/engineering/`: 工程约束、目录规范和代码评审清单。
- `templates/`: Flutter feature 与 Nest module 的结构模板。
- `openspec/`: 需求、设计、规格和任务拆解。

## 快速开始

### Flutter

```bash
cd mobile
flutter pub get
flutter run
```

### NestJS

```bash
cd server
pnpm install
pnpm start:dev
```

## 工程约束

- 新增功能必须落入既定的 feature 或 module 目录，而不是平铺在根目录。
- 页面、controller、service 超过可读阈值时必须拆分，禁止出现万能文件。
- 配置、环境、审计和可观测性约束从骨架阶段就保留入口。
