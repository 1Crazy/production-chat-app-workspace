# Production Chat App Mobile

Flutter 客户端采用 feature-first 结构：

```text
lib/
├── app/
├── features/
│   ├── auth/
│   ├── conversation/
│   ├── chat/
│   ├── media/
│   └── profile/
└── shared/
```

## 运行

```bash
flutter run --dart-define-from-file=config/env/development.json.example
```

## 约束

- 页面只负责展示和交互。
- 用例编排放 `application/`。
- 实体和仓储接口放 `domain/`。
- 数据实现放 `data/`。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
