import 'package:flutter/services.dart';

class ClipboardService {
  static const _channel = MethodChannel('com.zen.transfer/clipboard');

  /// Copy text to clipboard
  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Paste text from clipboard
  Future<String?> pasteText() async {
    final data = await Clipboard.getData('text/plain');
    return data?.text;
  }

  /// Get image data from clipboard (platform-specific)
  Future<Uint8List?> getImageData() async {
    try {
      final result = await _channel.invokeMethod('getClipboardImage');
      if (result != null) {
        return Uint8List.fromList(result);
      }
    } on MissingPluginException {
      // Platform channel not available (e.g. during testing)
    } catch (e) {
      // Clipboard image not supported on this platform
    }
    return null;
  }

  /// Check if clipboard has content (text or image)
  Future<ClipboardContentType> hasContent() async {
    // Check for image first (higher priority)
    final imageData = await getImageData();
    if (imageData != null) return ClipboardContentType.image;

    // Check for text
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      return ClipboardContentType.text;
    }

    return ClipboardContentType.empty;
  }

  /// Get clipboard content preview (truncated)
  Future<String> getPreview({int maxLength = 100}) async {
    final text = await pasteText();
    if (text == null) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

enum ClipboardContentType { empty, text, image }
