import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/auth/application/auth_status.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.bootstrapping;
  AuthSession? _authSession;
  List<DeviceSession> _deviceSessions = const [];
  bool _isBusy = false;
  String? _errorMessage;
  AuthCodeReceipt? _latestCodeReceipt;

  AuthStatus get status => _status;
  AuthSession? get authSession => _authSession;
  List<DeviceSession> get deviceSessions => _deviceSessions;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  AuthCodeReceipt? get latestCodeReceipt => _latestCodeReceipt;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    final restoredSession = await _authRepository.restore();

    if (restoredSession == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _authSession = restoredSession;
    _status = AuthStatus.authenticated;
    notifyListeners();

    try {
      await refreshSession(silent: true);
    } catch (_) {
      await _clearSession('登录已过期，请重新登录');
    }
  }

  Future<void> requestCode({required String identifier}) async {
    await _runBusy(() async {
      _errorMessage = null;
      _latestCodeReceipt = await _authRepository.requestCode(
        identifier: identifier,
      );
    });
  }

  Future<void> register({
    required String identifier,
    required String code,
    required String nickname,
    required String deviceName,
  }) async {
    await _runBusy(() async {
      _errorMessage = null;
      _authSession = await _authRepository.register(
        identifier: identifier,
        code: code,
        nickname: nickname,
        deviceName: deviceName,
      );
      _status = AuthStatus.authenticated;
      await loadDeviceSessions(silent: true);
    });
  }

  Future<void> login({
    required String identifier,
    required String code,
    required String deviceName,
  }) async {
    await _runBusy(() async {
      _errorMessage = null;
      _authSession = await _authRepository.login(
        identifier: identifier,
        code: code,
        deviceName: deviceName,
      );
      _status = AuthStatus.authenticated;
      await loadDeviceSessions(silent: true);
    });
  }

  Future<void> refreshSession({bool silent = false}) async {
    final currentSession = _authSession;

    if (currentSession == null) {
      return;
    }

    if (!silent) {
      _isBusy = true;
      notifyListeners();
    }

    try {
      _authSession = await _authRepository.refresh(
        refreshToken: currentSession.refreshToken,
      );
      _status = AuthStatus.authenticated;
      await loadDeviceSessions(silent: true);
    } catch (error) {
      _errorMessage = error.toString();

      if (silent) {
        rethrow;
      }
    } finally {
      if (!silent) {
        _isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadDeviceSessions({bool silent = false}) async {
    final currentSession = _authSession;

    if (currentSession == null) {
      return;
    }

    if (!silent) {
      _isBusy = true;
      notifyListeners();
    }

    try {
      _deviceSessions = await _authRepository.listSessions(
        accessToken: currentSession.accessToken,
      );
    } catch (error) {
      if (!silent) {
        _errorMessage = error.toString();
      }
    } finally {
      if (!silent) {
        _isBusy = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> revokeSession(String sessionId) async {
    final currentSession = _authSession;

    if (currentSession == null) {
      return;
    }

    await _runBusy(() async {
      await _authRepository.revokeSession(
        accessToken: currentSession.accessToken,
        sessionId: sessionId,
      );

      if (currentSession.currentSession.id == sessionId) {
        await _clearSession('当前设备已退出登录');
        return;
      }

      _deviceSessions = _deviceSessions
          .where((session) => session.id != sessionId)
          .toList(growable: false);
    });
  }

  Future<void> logout() async {
    final currentSession = _authSession;

    await _runBusy(() async {
      if (currentSession != null) {
        try {
          await _authRepository.logout(accessToken: currentSession.accessToken);
        } catch (_) {
          // 客户端退出登录时优先清理本地会话，服务端失败不阻断用户退出。
        }
      }

      await _clearSession();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isBusy = true;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _clearSession([String? message]) async {
    await _authRepository.clear();
    _authSession = null;
    _deviceSessions = const [];
    _status = AuthStatus.unauthenticated;
    _errorMessage = message;
    notifyListeners();
  }
}
