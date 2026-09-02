import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
/// Bridges the native Android notification listener via platform channels.
///
/// - [EventChannel] `com.zen.transfer/notification_events` streams notification
///   payloads pushed from the Kotlin side.
/// - [MethodChannel] `com.zen.transfer/mirroring` is used for one-off calls
///   (permission request, service status check).
///
/// On non-Android platforms the [events] stream is empty and methods are no-ops.
class NotificationMirrorService {
  static const _eventChannel =
      EventChannel('com.zen.transfer/notification_events');
  static const _methodChannel =
      MethodChannel('com.zen.transfer/mirroring');

  Stream<Map<String, dynamic>>? _events;

  /// Broadcast stream of notification maps (keys: title, text, package).
  Stream<Map<String, dynamic>> get events {
    if (_events != null) return _events!;

    // On non-Android the stream emits nothing — listener is harmless.
    if (defaultTargetPlatform != TargetPlatform.android) {
      _events = const Stream.empty();
      return _events!;
    }

    _events = _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _events!;
  }

  /// Ask the user for notification-listener permission (Android only).
  Future<void> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _methodChannel.invokeMethod('requestPermission');
    } on MissingPluginException catch (_) {
      debugPrint('NotificationMirrorService: mirroring channel not available');
    }
  }

  /// Returns whether the native notification-listener service is running.
  Future<bool> isServiceConnected() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isServiceConnected');
      return result ?? false;
    } on MissingPluginException catch (_) {
      debugPrint('NotificationMirrorService: mirroring channel not available');
      return false;
    }
  }
}
