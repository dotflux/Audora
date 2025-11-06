import 'package:flutter/services.dart';
import 'utils/log.dart';

typedef NotificationActionCallback =
    Future<void> Function(String action, {Map<String, dynamic>? extras});

class AudoraNotification {
  static const MethodChannel _channel = MethodChannel('audora/notification');

  static NotificationActionCallback? onAction;
  static bool _supportsUpdatePlayback = true;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      log.d(
        '🔔 MethodChannel received call: ${call.method} with args: ${call.arguments}',
      );
      if (call.method == 'onNotificationAction') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final action = args?['action'] as String?;
        final rawExtras = args?['extras'];
        Map<String, dynamic>? extras;
        if (rawExtras is Map) {
          try {
            extras = Map<String, dynamic>.from(rawExtras);
          } catch (_) {
            extras = rawExtras.map((k, v) => MapEntry(k.toString(), v));
          }
        }
        if (action != null) {
          log.d('Native action received: $action');
          if (onAction != null) await onAction!(action, extras: extras);
        }
      }
      return;
    });
  }

  static Future<void> show({
    required String title,
    required String artist,
    String? artworkUrl,
    required bool isPlaying,
    int? positionMs,
    int? durationMs,
    bool hasBestPart = false,
    String? mediaId,
  }) async {
    log.d("Show notif entered");
    await _channel.invokeMethod('show', {
      'title': title,
      'artist': artist,
      'artworkUrl': artworkUrl,
      'isPlaying': isPlaying,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'hasBestPart': hasBestPart,
      'mediaId': mediaId,
    });
    log.d("Notif showed. + bestpart is $hasBestPart");
  }

  static Future<void> hide() async {
    await _channel.invokeMethod('hide');
  }

  static Future<void> updatePlaybackState({
    required bool isPlaying,
    int? positionMs,
    int? durationMs,
  }) async {
    if (!_supportsUpdatePlayback) return;
    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'durationMs': durationMs,
      });
    } on MissingPluginException {
      _supportsUpdatePlayback = false;
    }
  }

  static Future<void> testChannel() async {
    log.d('🔔 Testing method channel...');
    try {
      await _channel.invokeMethod('test');
      log.d('🔔 Test method invoked successfully');
    } catch (e) {
      log.d('🔔 Test method failed: $e');
    }
  }
}
