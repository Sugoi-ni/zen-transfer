import 'dart:async';

import 'package:flutter/services.dart';

/// Polls the system clipboard on a 1-second interval.
/// When the text content changes (and is non-empty), invokes the [onText] callback.
/// Designed for phone→PC clipboard sync: the provider feeds the changed text
/// into the transfer pipeline so it can be sent to paired devices.
class ClipboardSyncService {
  Timer? _timer;
  String? _lastText;

  /// Start polling the clipboard every second.
  /// [onText] is called (on the event loop) each time new non-empty clipboard
  /// text is detected that differs from the previously observed value.
  Future<void> start({
    required Future<void> Function(String text) onText,
  }) async {
    if (_timer != null) return; // already running

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final data = await Clipboard.getData('text/plain');
        final text = data?.text;

        if (text == null || text.isEmpty) {
          return;
        }

        // Deduplicate: only fire when content actually changes
        if (text == _lastText) return;
        _lastText = text;

        await onText(text);
      } catch (e) {
        // Clipboard reads can throw on some platforms — silently ignore
      }
    });
  }

  /// Stop polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastText = null;
  }
}
