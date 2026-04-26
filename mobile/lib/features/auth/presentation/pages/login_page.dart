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
  bool _identifierTouched = false;
  bool _nicknameTouched = false;
  bool _passwordTouched = false;
  bool _codeTouched = false;
  bool _attemptedCodeRequest = false;
  bool _attemptedSubmit = false;

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
                  errorText: _identifierErrorText(),
                  onChanged: (_) {
                    setState(() {
                      _identifierTouched = true;
                    });
                  },
                ),
                if (_showsNickname) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    controller: _nicknameController,
                    label: '昵称',
                    hintText: '请输入昵称',
                    errorText: _nicknameErrorText(),
                    onChanged: (_) {
                      setState(() {
                        _nicknameTouched = true;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 14),
                _AuthField(
                  controller: _passwordController,
                  label: _pageMode == _AuthPageMode.resetPassword
                      ? '新密码'
                      : '密码',
                  hintText: '请输入至少 8 位且包含字母和数字的密码',
                  errorText: _passwordErrorText(),
                  onChanged: (_) {
                    setState(() {
                      _passwordTouched = true;
                    });
                  },
                  obscureText: true,
                ),
                if (_requiresCode) ...[
                  const SizedBox(height: 14),
                  _CodeField(
                    controller: _codeController,
                    errorText: _codeErrorText(),
                    onChanged: (_) {
                      setState(() {
                        _codeTouched = true;
                      });
                    },
                    onRequestCode: authController.isBusy ? null : _requestCode,
                  ),
                ],
                if (_showsDeviceName) ...[
                  const SizedBox(height: 14),
                  _AuthField(
                    controller: _deviceNameController,
                    label: '设备备注（选填）',
                    hintText: '例如 我的 iPhone',
                    onChanged: (_) {
                      setState(() {});
                    },
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
      _identifierTouched = false;
      _nicknameTouched = false;
      _passwordTouched = false;
      _codeTouched = false;
      _attemptedCodeRequest = false;
      _attemptedSubmit = false;
    });
  }

  Future<void> _requestCode() async {
    final validationMessage = _codeRequestValidationMessage();

    setState(() {
      _attemptedCodeRequest = true;
      _identifierTouched = true;
      _passwordTouched = true;

      if (_showsNickname) {
        _nicknameTouched = true;
      }
    });

    if (validationMessage != null) {
      return;
    }

    final authController = AuthScope.of(context);

    await authController.requestCode(
      identifier: _identifierController.text.trim(),
      purpose: _requestPurposeForMode(),
    );
    final receipt = authController.latestCodeReceipt;

    if (!mounted || receipt == null) {
      return;
    }

    final debugCode = receipt.debugCode;

    if (debugCode != null && debugCode.isNotEmpty) {
      setState(() {
        _codeController.text = debugCode;
        _codeTouched = true;
      });
    }

    showAppStatusSnackBar(
      context,
      message: debugCode == null || debugCode.isEmpty
          ? '${receipt.purpose.label}验证码已发送'
          : '测试${receipt.purpose.label}验证码：$debugCode',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _attemptedSubmit = true;
      _identifierTouched = true;
      _passwordTouched = true;
      _codeTouched = _requiresCode;

      if (_showsNickname) {
        _nicknameTouched = true;
      }
    });

    if (_submitValidationMessage() != null) {
      return;
    }

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

  String? _codeRequestValidationMessage() {
    if (!_requiresCode) {
      return null;
    }

    final identifierValidationMessage = _validateIdentifier();

    if (identifierValidationMessage != null) {
      return identifierValidationMessage;
    }

    final nicknameValidationMessage = _validateNickname();

    if (nicknameValidationMessage != null) {
      return nicknameValidationMessage;
    }

    return _validatePassword(forCodeRequest: true);
  }

  String? _submitValidationMessage() {
    final identifierValidationMessage = _validateIdentifier();

    if (identifierValidationMessage != null) {
      return identifierValidationMessage;
    }

    final passwordValidationMessage = _validatePassword(forCodeRequest: false);

    if (passwordValidationMessage != null) {
      return passwordValidationMessage;
    }

    final nicknameValidationMessage = _validateNickname();

    if (nicknameValidationMessage != null) {
      return nicknameValidationMessage;
    }

    return _validateCode();
  }

  String? _identifierErrorText() {
    if (!_identifierTouched && !_attemptedCodeRequest && !_attemptedSubmit) {
      return null;
    }

    return _validateIdentifier();
  }

  String? _nicknameErrorText() {
    if (!_showsNickname) {
      return null;
    }

    if (!_nicknameTouched && !_attemptedCodeRequest && !_attemptedSubmit) {
      return null;
    }

    return _validateNickname();
  }

  String? _passwordErrorText() {
    if (!_passwordTouched && !_attemptedCodeRequest && !_attemptedSubmit) {
      return null;
    }

    return _validatePassword(
      forCodeRequest:
          _requiresCode && (_attemptedCodeRequest || !_attemptedSubmit),
    );
  }

  String? _codeErrorText() {
    if (!_requiresCode) {
      return null;
    }

    if (!_codeTouched && !_attemptedSubmit) {
      return null;
    }

    return _validateCode();
  }

  String? _validateIdentifier() {
    if (_identifierController.text.trim().isEmpty) {
      return '请先输入账号或邮箱';
    }

    return null;
  }

  String? _validateNickname() {
    if (_showsNickname && _nicknameController.text.trim().isEmpty) {
      return '请先输入昵称';
    }

    return null;
  }

  String? _validatePassword({required bool forCodeRequest}) {
    final password = _passwordController.text;

    if (password.isEmpty) {
      return forCodeRequest ? '请先输入密码，再获取验证码' : '请输入密码';
    }

    if (password.length < 8) {
      return forCodeRequest ? '请先输入至少 8 位的密码，再获取验证码' : '密码至少需要 8 位';
    }

    if (password.length > 72) {
      return forCodeRequest ? '请先把密码控制在 72 位以内，再获取验证码' : '密码最多支持 72 位';
    }

    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return forCodeRequest ? '请先输入同时包含字母和数字的密码，再获取验证码' : '密码必须同时包含字母和数字';
    }

    return null;
  }

  String? _validateCode() {
    if (!_requiresCode) {
      return null;
    }

    final code = _codeController.text.trim();

    if (code.isEmpty) {
      return '请输入验证码';
    }

    if (code.length < 4) {
      return '验证码至少需要 4 位';
    }

    if (code.length > 8) {
      return '验证码最多支持 8 位';
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
    this.errorText,
    this.onChanged,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.onRequestCode,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final Future<void> Function()? onRequestCode;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: '验证码',
        hintText: '请输入验证码',
        errorText: errorText,
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
