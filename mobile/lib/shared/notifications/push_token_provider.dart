import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:production_chat_app/shared/notifications/device_push_token.dart';

abstract class PushTokenProvider {
  Future<DevicePushToken?> fetchDevicePushToken();

  Stream<DevicePushToken> get tokenRefreshStream;
}

class NoopPushTokenProvider implements PushTokenProvider {
  const NoopPushTokenProvider();

  @override
  Future<DevicePushToken?> fetchDevicePushToken() async {
    return null;
  }

  @override
  Stream<DevicePushToken> get tokenRefreshStream {
    return const Stream<DevicePushToken>.empty();
  }
}

class FirebaseMessagingPushTokenProvider implements PushTokenProvider {
  FirebaseMessagingPushTokenProvider({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  static const MethodChannel _iosApnsTokenChannel = MethodChannel(
    'production_chat_app/apns_token',
  );

  final FirebaseMessaging _messaging;

  @override
  Future<DevicePushToken?> fetchDevicePushToken() async {
    if (!_supportsPushPlatform) {
      return null;
    }

    if (Platform.isIOS) {
      return _fetchIosDevicePushToken();
    }

    try {
      if (Firebase.apps.isEmpty) {
        return null;
      }

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (_isAuthorizationRejected(settings.authorizationStatus)) {
        return null;
      }

      final token = await _messaging.getToken();
      return _toFcmDevicePushToken(token);
    } on FirebaseException {
      return null;
    }
  }

  @override
  Stream<DevicePushToken> get tokenRefreshStream {
    if (!_supportsPushPlatform) {
      return const Stream<DevicePushToken>.empty();
    }

    if (Platform.isIOS) {
      return const Stream<DevicePushToken>.empty();
    }

    if (Firebase.apps.isEmpty) {
      return const Stream<DevicePushToken>.empty();
    }

    return _messaging.onTokenRefresh
        .map((token) => _toFcmDevicePushToken(token))
        .where((token) => token != null)
        .map((token) => token!);
  }

  bool get _supportsPushPlatform {
    return !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  }

  bool _isAuthorizationRejected(AuthorizationStatus status) {
    return status == AuthorizationStatus.denied ||
        status == AuthorizationStatus.notDetermined;
  }

  Future<DevicePushToken?> _fetchIosDevicePushToken() async {
    try {
      final json = await _iosApnsTokenChannel
          .invokeMapMethod<Object?, Object?>('requestDevicePushToken');

      if (json == null) {
        return null;
      }

      return DevicePushToken.fromJson(json);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  DevicePushToken? _toFcmDevicePushToken(String? token) {
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
