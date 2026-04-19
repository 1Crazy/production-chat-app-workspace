# Nest Module 模板

新增 NestJS 业务模块时，优先复制下面的结构：

```text
module_name/
├── controllers/
├── services/
├── repositories/
├── dto/
├── entities/
├── events/
└── gateways/
```

约束：

- controller 只处理协议层输入输出。
- service 负责业务编排。
- repository 负责数据访问。
- gateway 负责实时事件。
- 公共基础设施不要复制到模块内，统一放到 `src/infra/`。
