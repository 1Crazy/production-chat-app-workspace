# Flutter Feature 模板

新增 Flutter 功能时，优先复制下面的结构：

```text
feature_name/
├── presentation/
│   ├── pages/
│   └── widgets/
├── application/
├── domain/
│   ├── entities/
│   └── repositories/
└── data/
    ├── datasources/
    ├── dto/
    └── repositories/
```

约束：

- 页面只处理交互和展示。
- controller / use case 放在 `application/`。
- 仓储接口放在 `domain/`，实现放在 `data/`。
