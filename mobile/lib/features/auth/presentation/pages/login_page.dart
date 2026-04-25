import 'package:flutter/material.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

enum _AuthPageMode { login, register, resetPassword }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _identifierController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _codeController;
  late final TextEditingController _deviceNameController;

  _AuthPageMode _pageMode = _AuthPageMode.login;
  bool _rememberLogin = true;

  bool get _requiresCode => _pageMode != _AuthPageMode.login;
  bool get _showsNickname => _pageMode == _AuthPageMode.register;
  bool get _showsDeviceName => _pageMode != _AuthPageMode.resetPassword;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _nicknameController = TextEditingController();
    _passwordController = TextEditingController();
    _codeController = TextEditingController();
    _deviceNameController = TextEditingController();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
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
        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FC),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              children: [
                const SizedBox(height: 8),
                Text(
                  _titleForMode(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitleForMode(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hintForMode(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 24),
                _ModeSwitch(currentMode: _pageMode, onChanged: _setPageMode),
                const SizedBox(height: 20),
                _AuthField(
                  controller: _identifierController,
                  label: '账号',
                  hintText: '请输入账号或邮箱',
                ),
                if (_showsNickname) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    controller: _nicknameController,
                    label: '昵称',
                    hintText: '请输入昵称',
                  ),
                ],
                const SizedBox(height: 14),
                _AuthField(
                  controller: _passwordController,
                  label: _pageMode == _AuthPageMode.resetPassword
                      ? '新密码'
                      : '密码',
                  hintText: '请输入至少 8 位且包含字母和数字的密码',
                  obscureText: true,
                ),
                if (_requiresCode) ...[
                  const SizedBox(height: 14),
                  _CodeField(
                    controller: _codeController,
                    onRequestCode: authController.isBusy
                        ? null
                        : () async {
                            final passwordValidationMessage =
                                _validatePasswordForCodeRequest();

                            if (passwordValidationMessage != null) {
                              showAppStatusSnackBar(
                                context,
                                message: passwordValidationMessage,
                                tone: AppStatusTone.error,
                              );
                              return;
                            }

                            await authController.requestCode(
                              identifier: _identifierController.text.trim(),
                              purpose: _requestPurposeForMode(),
                            );
                            final receipt = authController.latestCodeReceipt;

                            if (!context.mounted || receipt == null) {
                              return;
                            }

                            final debugCode = receipt.debugCode;

                            if (debugCode != null && debugCode.isNotEmpty) {
                              _codeController.text = debugCode;
                            }

                            showAppStatusSnackBar(
                              context,
                              message: debugCode == null || debugCode.isEmpty
                                  ? '${receipt.purpose.label}验证码已发送'
                                  : '测试${receipt.purpose.label}验证码：$debugCode',
                              tone: AppStatusTone.success,
                            );
                          },
                  ),
                ],
                if (_showsDeviceName) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    controller: _deviceNameController,
                    label: '设备备注（选填）',
                    hintText: '例如 我的 iPhone',
                  ),
                ],
                const SizedBox(height: 12),
                if (_pageMode != _AuthPageMode.resetPassword)
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
                      TextButton(
                        onPressed: authController.isBusy
                            ? null
                            : () {
                                _setPageMode(_AuthPageMode.resetPassword);
                              },
                        child: const Text('忘记密码？'),
                      ),
                    ],
                  ),
                if (_pageMode == _AuthPageMode.resetPassword)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: authController.isBusy
                          ? null
                          : () {
                              _setPageMode(_AuthPageMode.login);
                            },
                      child: const Text('返回密码登录'),
                    ),
                  ),
                Text(
                  '密码要求：8 到 72 位，且必须同时包含字母和数字。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF98A2B3),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authController.isBusy ? null : _submit,
                    child: Text(
                      authController.isBusy ? '提交中...' : _primaryButtonLabel(),
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
                if (_pageMode != _AuthPageMode.resetPassword) ...[
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
                ] else
                  const SizedBox(height: 22),
                Center(
                  child: TextButton(
                    onPressed: authController.isBusy ? null : _toggleFooterMode,
                    child: Text(_footerButtonLabel()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setPageMode(_AuthPageMode mode) {
    setState(() {
      _pageMode = mode;
      _identifierController.clear();
      _nicknameController.clear();
      _passwordController.clear();
      _codeController.clear();
      _deviceNameController.clear();
    });
  }

  Future<void> _submit() async {
    final authController = AuthScope.of(context);
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    final code = _codeController.text.trim();
    final deviceName = _deviceNameController.text.trim().isEmpty
        ? null
        : _deviceNameController.text.trim();

    switch (_pageMode) {
      case _AuthPageMode.login:
        await authController.login(
          identifier: identifier,
          password: password,
          deviceName: deviceName,
        );
        return;
      case _AuthPageMode.register:
        await authController.register(
          identifier: identifier,
          code: code,
          password: password,
          nickname: _nicknameController.text.trim(),
          deviceName: deviceName,
        );
        return;
      case _AuthPageMode.resetPassword:
        await authController.resetPassword(
          identifier: identifier,
          code: code,
          password: password,
        );
        if (!mounted || authController.errorMessage != null) {
          return;
        }
        showAppStatusSnackBar(
          context,
          message: '密码已重置，请使用新密码登录',
          tone: AppStatusTone.success,
        );
        _setPageMode(_AuthPageMode.login);
        return;
    }
  }

  AuthCodePurpose _requestPurposeForMode() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        return AuthCodePurpose.register;
      case _AuthPageMode.register:
        return AuthCodePurpose.register;
      case _AuthPageMode.resetPassword:
        return AuthCodePurpose.resetPassword;
    }
  }

  String? _validatePasswordForCodeRequest() {
    if (!_requiresCode) {
      return null;
    }

    final password = _passwordController.text;

    if (password.length < 8) {
      return '请先输入至少 8 位的密码，再获取验证码';
    }

    if (password.length > 72) {
      return '请先把密码控制在 72 位以内，再获取验证码';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return '请先输入同时包含字母和数字的密码，再获取验证码';
    }

    return null;
  }

  String _titleForMode() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        return '登录';
      case _AuthPageMode.register:
        return '注册';
      case _AuthPageMode.resetPassword:
        return '重置密码';
    }
  }

  String _subtitleForMode() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        return '欢迎回来';
      case _AuthPageMode.register:
        return '创建一个新的账号';
      case _AuthPageMode.resetPassword:
        return '通过验证码验证身份后设置新密码';
    }
  }

  String _hintForMode() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        return '当前版本默认使用账号和密码登录。';
      case _AuthPageMode.register:
        return '注册时需要验证码校验，并为账号设置初始密码。';
      case _AuthPageMode.resetPassword:
        return '如果旧账号还没设置密码，也请走这个入口补密码。';
    }
  }

  String _primaryButtonLabel() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        return '登录';
      case _AuthPageMode.register:
        return '注册';
      case _AuthPageMode.resetPassword:
        return '确认重置密码';
    }
  }

  String _footerButtonLabel() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        return '没有账号，去注册';
      case _AuthPageMode.register:
        return '已有账号，去登录';
      case _AuthPageMode.resetPassword:
        return '没有账号，去注册';
    }
  }

  void _toggleFooterMode() {
    switch (_pageMode) {
      case _AuthPageMode.login:
        _setPageMode(_AuthPageMode.register);
        return;
      case _AuthPageMode.register:
        _setPageMode(_AuthPageMode.login);
        return;
      case _AuthPageMode.resetPassword:
        _setPageMode(_AuthPageMode.register);
        return;
    }
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.currentMode, required this.onChanged});

  final _AuthPageMode currentMode;
  final ValueChanged<_AuthPageMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final loginSelected = currentMode != _AuthPageMode.register;
    final registerSelected = currentMode == _AuthPageMode.register;

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
              label: currentMode == _AuthPageMode.resetPassword ? '重置密码' : '登录',
              selected: loginSelected,
              onTap: () {
                onChanged(_AuthPageMode.login);
              },
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: '注册',
              selected: registerSelected,
              onTap: () {
                onChanged(_AuthPageMode.register);
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
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
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
