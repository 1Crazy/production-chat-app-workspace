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

## Firebase Messaging 配置

移动端推送令牌现在统一通过 `firebase_core + firebase_messaging`
获取，并继续走现有的 `/notifications/push-registrations`
登记接口。

接入步骤：

1. 在 Firebase Console / FlutterFire CLI 中为当前 Flutter
   工程完成 iOS 与 Android 应用注册。
2. 将 Android 配置文件放到
   `mobile/android/app/google-services.json`。
3. 将 Apple 平台配置文件放到
   `mobile/ios/Runner/GoogleService-Info.plist`。
4. 在 `mobile/` 目录执行 `flutterfire configure`
   以保持 Firebase 平台配置最新。
5. 重新构建应用：

```bash
flutter pub get
flutter run --dart-define-from-file=config/env/development.json.example
```

说明：

- `google-services.json` 与 `GoogleService-Info.plist`
  都是 Firebase 官方要求的客户端配置文件，内容是项目标识，
  不是服务端密钥。
- 当前代码在启动时会尝试初始化 Firebase；如果本地尚未放置平台配置文件，
  应用主链路仍可运行，只是不会登记推送令牌。
- 如果 Firebase 初始化失败，应用内会显示一条显式配置提示横幅，
  避免出现“推送静默失效但用户无感”的情况。
- Android 13+ 与 iOS 的通知权限都由 `firebase_messaging`
  在 Dart 层统一触发申请。
- Android 前台消息会额外通过 `flutter_local_notifications`
  展示系统级本地通知，避免只有应用内提示而缺少系统通知横幅。
- Android 前台本地通知现在使用专用的 `ic_notification` 小图标，
  不再复用 launcher icon。
- 通知点击跳转当前默认解析 `data.conversationId`
  （也兼容 `conversation_id` / `chatConversationId` / `targetConversationId`）；
  同时也支持从 `data.route` 或 `data.deepLink`
  中解析 `/conversations/:id` 或 `?conversationId=...`。

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
