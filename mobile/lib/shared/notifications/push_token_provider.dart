import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:production_chat_app/shared/notifications/device_push_token.dart';

abstract class PushTokenProvider {
  Future<DevicePushToken?> fetchDevicePushToken();

  Stream<DevicePushToken> get tokenRefreshStream;
}

class FirebaseMessagingPushTokenProvider implements PushTokenProvider {
  FirebaseMessagingPushTokenProvider({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Future<DevicePushToken?> fetchDevicePushToken() async {
    if (!_supportsFirebaseMessagingPlatform) {
      return null;
    }

    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        provisional: Platform.isIOS,
        sound: true,
      );

      if (_isAuthorizationRejected(settings.authorizationStatus)) {
        return null;
      }

      if (Platform.isIOS) {
        final apnsToken = await _waitForApnsToken();

        if (apnsToken == null) {
          return null;
        }
      }

      final token = await _messaging.getToken();
      return _toDevicePushToken(token);
    } on FirebaseException {
      return null;
    }
  }

  @override
  Stream<DevicePushToken> get tokenRefreshStream {
    if (!_supportsFirebaseMessagingPlatform || Firebase.apps.isEmpty) {
      return const Stream<DevicePushToken>.empty();
    }

    return _messaging.onTokenRefresh
        .asyncMap((token) async {
          if (Platform.isIOS) {
            final apnsToken = await _waitForApnsToken();

            if (apnsToken == null) {
              return null;
            }
          }

          return _toDevicePushToken(token);
        })
        .where((token) {
          return token != null;
        })
        .map((token) {
          return token!;
        });
  }

  bool get _supportsFirebaseMessagingPlatform {
    return !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  }

  bool _isAuthorizationRejected(AuthorizationStatus status) {
    return status == AuthorizationStatus.denied ||
        status == AuthorizationStatus.notDetermined;
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final apnsToken = await _messaging.getAPNSToken();

      if (apnsToken != null && apnsToken.isNotEmpty) {
        return apnsToken;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    return null;
  }

  DevicePushToken? _toDevicePushToken(String? token) {
    final normalizedToken = token?.trim();

    if (normalizedToken == null || normalizedToken.isEmpty) {
      return null;
    }

    return DevicePushToken(
      provider: 'fcm',
      token: normalizedToken,
      pushEnvironment: kDebugMode ? 'sandbox' : 'production',
    );
  }
}
