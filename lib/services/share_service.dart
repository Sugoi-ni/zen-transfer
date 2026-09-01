import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of a share: either text or a list of file descriptors.
class SharedContent {
  final String type; // 'text' | 'files' | 'none'
  final String? text;
  final List<SharedFile> files;

  const SharedContent({
    required this.type,
    this.text,
    this.files = const [],
  });

  bool get isText => type == 'text';
  bool get isFiles => type == 'files';
  bool get isEmpty => type == 'none';
}

class SharedFile {
  final String uri;
  final String name;
  final String mime;

  const SharedFile({
    required this.uri,
    required this.name,
    required this.mime,
  });
}

/// Handles content shared into the app from Android's share sheet
/// (ACTION_SEND / ACTION_SEND_MULTIPLE).
class ShareService {
  static const _channel = MethodChannel('com.zen.transfer/share');
  static const _eventChannel = EventChannel('com.zen.transfer/share_events');
  static ShareService? _instance;

  factory ShareService() => _instance ??= ShareService._();
  ShareService._() {
    _subscribeToEvents();
  }

  StreamSubscription<dynamic>? _eventSub;

  /// Keeps the event subscription alive and lets callers stop it if needed.
  void dispose() {
    _eventSub?.cancel();
    _eventSub = null;
    _onNewShare = null;
  }

  /// Listens for a Kotlin-side signal whenever a new SEND intent arrives
  /// while the app is already running (onNewIntent path).
  void _subscribeToEvents() {
    try {
      _eventSub = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          debugPrint('ShareService: got new-share event from Kotlin');
          _onNewShare?.call();
        },
        onError: (e) => debugPrint('Share event error: $e'),
      );
    } catch (e) {
      debugPrint('Share event subscribe error: $e');
    }
  }

  /// Invoked from Dart when a new share lands while the app is open.
  VoidCallback? _onNewShare;
  set onNewShare(VoidCallback? cb) => _onNewShare = cb;

  /// Get content shared into the app (clears after reading).
  Future<SharedContent> getSharedContent() async {
    try {
      final raw = await _channel.invokeMethod<String>('getSharedContent');
      if (raw == null || raw.isEmpty) {
        return const SharedContent(type: 'none');
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String? ?? 'none';

      if (type == 'text') {
        return SharedContent(type: 'text', text: json['text'] as String?);
      }

      if (type == 'files') {
        final filesJson = json['files'] as List<dynamic>? ?? [];
        final files = filesJson.map((f) {
          final map = f as Map<String, dynamic>;
          return SharedFile(
            uri: map['uri'] as String,
            name: map['name'] as String? ?? 'shared_file',
            mime: map['mime'] as String? ?? 'application/octet-stream',
          );
        }).toList();
        return SharedContent(type: 'files', files: files);
      }

      return const SharedContent(type: 'none');
    } catch (e) {
      debugPrint('Share channel error: $e');
      return const SharedContent(type: 'none');
    }
  }

  /// Read a shared file's bytes via its content:// uri.
  Future<List<int>> readSharedFile(String uri) async {
    try {
      final bytes = await _channel.invokeMethod<List<int>>(
        'readSharedFile',
        {'uri': uri},
      );
      return bytes ?? [];
    } catch (e) {
      debugPrint('Read shared file error: $e');
      return [];
    }
  }
}