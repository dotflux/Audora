import 'package:flutter/services.dart';
import 'utils/log.dart';

typedef NotificationActionCallback =
    Future<void> Function(String action, {Map<String, dynamic>? extras});

class AudoraNotification {
  static const MethodChannel _channel = MethodChannel('audora/notification');

  static NotificationActionCallback? onAction;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationAction') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final action = args?['action'] as String?;
        final extras = args?['extras'] as Map<String, dynamic>?;
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
    });
    log.d("Notif showed. + bestpart is $hasBestPart");
  }

  static Future<void> hide() async {
    await _channel.invokeMethod('hide');
  }
}
