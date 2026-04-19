import 'package:flutter/material.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _identifierController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _codeController;
  late final TextEditingController _deviceNameController;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(text: 'demo_user');
    _nicknameController = TextEditingController(text: 'Demo User');
    _codeController = TextEditingController();
    _deviceNameController = TextEditingController(text: 'flutter-mobile');
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _nicknameController.dispose();
    _codeController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = AuthScope.of(context);

    return AnimatedBuilder(
      animation: authController,
      builder: (context, child) {
        final latestCodeReceipt = authController.latestCodeReceipt;

        return Scaffold(
          appBar: AppBar(title: const Text('登录 / 注册')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '先请求验证码，再选择注册或登录。',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _identifierController,
                decoration: const InputDecoration(
                  labelText: '账号标识',
                  hintText: '例如 demo_user 或 demo@example.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: '昵称（注册时使用）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: '验证码'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deviceNameController,
                decoration: const InputDecoration(labelText: '设备名称'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    onPressed: authController.isBusy
                        ? null
                        : () async {
                            await authController.requestCode(
                              identifier: _identifierController.text.trim(),
                            );
                            final receipt = authController.latestCodeReceipt;

                            if (!context.mounted || receipt == null) {
                              return;
                            }

                            _codeController.text = receipt.debugCode;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('开发验证码：${receipt.debugCode}'),
                              ),
                            );
                          },
                    child: const Text('获取验证码'),
                  ),
                  FilledButton(
                    onPressed: authController.isBusy
                        ? null
                        : () async {
                            await authController.register(
                              identifier: _identifierController.text.trim(),
                              code: _codeController.text.trim(),
                              nickname: _nicknameController.text.trim(),
                              deviceName: _deviceNameController.text.trim(),
                            );
                          },
                    child: const Text('注册'),
                  ),
                  OutlinedButton(
                    onPressed: authController.isBusy
                        ? null
                        : () async {
                            await authController.login(
                              identifier: _identifierController.text.trim(),
                              code: _codeController.text.trim(),
                              deviceName: _deviceNameController.text.trim(),
                            );
                          },
                    child: const Text('登录'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (authController.isBusy) const LinearProgressIndicator(),
              if (authController.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (latestCodeReceipt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    child: ListTile(
                      title: const Text('最近一次验证码'),
                      subtitle: Text(
                        '账号：${latestCodeReceipt.identifier}\n'
                        '验证码：${latestCodeReceipt.debugCode}\n'
                        '有效期：${latestCodeReceipt.expiresInSeconds} 秒',
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
