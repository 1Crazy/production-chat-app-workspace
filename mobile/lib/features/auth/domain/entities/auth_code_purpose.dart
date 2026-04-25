enum AuthCodePurpose { register, resetPassword }

extension AuthCodePurposeX on AuthCodePurpose {
  String get wireValue {
    switch (this) {
      case AuthCodePurpose.register:
        return 'register';
      case AuthCodePurpose.resetPassword:
        return 'reset-password';
    }
  }

  String get label {
    switch (this) {
      case AuthCodePurpose.register:
        return '注册';
      case AuthCodePurpose.resetPassword:
        return '重置密码';
    }
  }

  static AuthCodePurpose fromWireValue(String rawValue) {
    switch (rawValue) {
      case 'reset-password':
        return AuthCodePurpose.resetPassword;
      case 'register':
      default:
        return AuthCodePurpose.register;
    }
  }
}
