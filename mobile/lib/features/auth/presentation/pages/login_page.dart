import 'package:flutter/material.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

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
  bool _isRegisterMode = false;
  bool _rememberLogin = true;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _nicknameController = TextEditingController();
    _codeController = TextEditingController();
    _deviceNameController = TextEditingController();
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
          backgroundColor: const Color(0xFFF7F8FC),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              children: [
                const SizedBox(height: 8),
                Text(
                  _isRegisterMode ? '注册' : '登录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRegisterMode ? '创建一个新的账号' : '欢迎回来',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前版本使用验证码登录，不使用密码。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 24),
                _ModeSwitch(
                  isRegisterMode: _isRegisterMode,
                  onChanged: (value) {
                    setState(() {
                      _isRegisterMode = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _AuthField(
                  controller: _identifierController,
                  label: '账号',
                  hintText: '请输入账号或邮箱',
                ),
                if (_isRegisterMode) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    controller: _nicknameController,
                    label: '昵称',
                    hintText: '请输入昵称',
                  ),
                ],
                const SizedBox(height: 14),
                _CodeField(
                  controller: _codeController,
                  onRequestCode: authController.isBusy
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
                          showAppStatusSnackBar(
                            context,
                            message: '测试验证码：${receipt.debugCode}',
                            tone: AppStatusTone.success,
                          );
                        },
                ),
                const SizedBox(height: 14),
                _AuthField(
                  controller: _deviceNameController,
                  label: '设备备注（选填）',
                  hintText: '例如 我的 iPhone',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: _rememberLogin,
                        onChanged: (value) {
                          setState(() {
                            _rememberLogin = value ?? true;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          '记住登录',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('收不到验证码？')),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authController.isBusy
                        ? null
                        : () async {
                            if (_isRegisterMode) {
                              await authController.register(
                                identifier: _identifierController.text.trim(),
                                code: _codeController.text.trim(),
                                nickname: _nicknameController.text.trim(),
                                deviceName:
                                    _deviceNameController.text.trim().isEmpty
                                    ? null
                                    : _deviceNameController.text.trim(),
                              );
                              return;
                            }

                            await authController.login(
                              identifier: _identifierController.text.trim(),
                              code: _codeController.text.trim(),
                              deviceName:
                                  _deviceNameController.text.trim().isEmpty
                                  ? null
                                  : _deviceNameController.text.trim(),
                            );
                          },
                    child: Text(
                      authController.isBusy
                          ? '提交中...'
                          : (_isRegisterMode ? '注册' : '登录'),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (authController.isBusy)
                  const LinearProgressIndicator(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                if (authController.errorMessage case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppInlineNotice(
                      message: message,
                      tone: AppStatusTone.error,
                    ),
                  ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Color(0xFFE5E7EB), endIndent: 12),
                    ),
                    Text(
                      '其他方式',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF98A2B3),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Color(0xFFE5E7EB), indent: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialEntry(icon: Icons.wechat_rounded),
                    SizedBox(width: 28),
                    _SocialEntry(icon: Icons.apple_rounded),
                    SizedBox(width: 28),
                    _SocialEntry(icon: Icons.chat_bubble_rounded),
                  ],
                ),
                const SizedBox(height: 22),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                      });
                    },
                    child: Text(_isRegisterMode ? '已有账号，去登录' : '没有账号，去注册'),
                  ),
                ),
                if (latestCodeReceipt != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF0F2F7)),
                    ),
                    child: Text(
                      '最近一次验证码：${latestCodeReceipt.debugCode}，有效期 ${latestCodeReceipt.expiresInSeconds} 秒',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.isRegisterMode, required this.onChanged});

  final bool isRegisterMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: '登录',
              selected: !isRegisterMode,
              onTap: () {
                onChanged(false);
              },
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: '注册',
              selected: isRegisterMode,
              onTap: () {
                onChanged(true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3478F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hintText,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hintText),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.onRequestCode});

  final TextEditingController controller;
  final Future<void> Function()? onRequestCode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '验证码',
        hintText: '请输入验证码',
        suffixIconConstraints: const BoxConstraints(minWidth: 110),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton(
            onPressed: onRequestCode == null
                ? null
                : () async {
                    await onRequestCode!();
                  },
            child: const Text('获取验证码'),
          ),
        ),
      ),
    );
  }
}

class _SocialEntry extends StatelessWidget {
  const _SocialEntry({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Icon(icon, color: const Color(0xFF3478F6), size: 22),
    );
  }
}
