import 'dart:io';
import 'package:image/image.dart' as img;

// ignore_for_file: avoid_print

void main() {
  // Create logo at multiple sizes
  final sizes = {
    'icon_512.png': 512,
    'icon_192.png': 192,
    'icon_144.png': 144,
    'icon_96.png': 96,
    'icon_72.png': 72,
    'icon_48.png': 48,
  };

  for (final entry in sizes.entries) {
    final image = _createLogo(entry.value);
    final file = File('assets/icons/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(image));
    print('Created: ${entry.key} (${entry.value}x${entry.value})');
  }

  // Also create adaptive icon foreground (512x512 with padding)
  final foreground = _createAdaptiveForeground(512);
  final fgFile = File('assets/icons/ic_launcher_foreground.png');
  fgFile.writeAsBytesSync(img.encodePng(foreground));
  print('Created: ic_launcher_foreground.png');

  // Create adaptive icon background (solid purple)
  final background = _createAdaptiveBackground(512);
  final bgFile = File('assets/icons/ic_launcher_background.png');
  bgFile.writeAsBytesSync(img.encodePng(background));
  print('Created: ic_launcher_background.png');
}

img.Image _createLogo(int size) {
  final image = img.Image(width: size, height: size);

  // Fill background with dark color (#1a1028)
  img.fill(image, color: img.ColorRgb8(0x1a, 0x10, 0x28));

  // Draw rounded rectangle background with purple gradient feel
  _drawRoundedRect(image, 0, 0, size, size, size ~/ 8,
      img.ColorRgb8(0x2d, 0x1b, 0x4e));

  // Draw the transfer arrows icon
  _drawTransferArrows(image, size);

  return image;
}

img.Image _createAdaptiveForeground(int size) {
  final image = img.Image(width: size, height: size);

  // Transparent background
  // Draw the arrows centered with padding for adaptive icon safe zone
  _drawTransferArrows(image, size);

  return image;
}

img.Image _createAdaptiveBackground(int size) {
  final image = img.Image(width: size, height: size);

  // Solid dark purple background
  img.fill(image, color: img.ColorRgb8(0x2d, 0x1b, 0x4e));

  return image;
}

void _drawTransferArrows(img.Image image, int size) {
  final cx = size / 2;
  final cy = size / 2;
  final scale = size / 512.0;

  // Arrow parameters
  final arrowLength = 160 * scale;
  final arrowHeight = 28 * scale;
  final headSize = 50 * scale;
  final gap = 40 * scale;

  // Colors
  final purple = img.ColorRgb8(0x9b, 0x59, 0xb6);
  final lightPurple = img.ColorRgb8(0xbb, 0x86, 0xfc);

  // Top arrow (pointing right)
  final topY = cy - gap / 2 - arrowHeight / 2;
  // Arrow body
  _fillRect(image, (cx - arrowLength / 2).toInt(), (topY - arrowHeight / 2).toInt(),
      arrowLength.toInt(), arrowHeight.toInt(), purple);
  // Arrow head (triangle pointing right)
  _fillTriangle(
    image,
    (cx + arrowLength / 2).toInt(),
    (topY - headSize / 2).toInt(),
    (cx + arrowLength / 2 + headSize).toInt(),
    topY.toInt(),
    (cx + arrowLength / 2).toInt(),
    (topY + headSize / 2).toInt(),
    lightPurple,
  );

  // Bottom arrow (pointing left)
  final botY = cy + gap / 2 + arrowHeight / 2;
  // Arrow body
  _fillRect(image, (cx - arrowLength / 2).toInt(), (botY - arrowHeight / 2).toInt(),
      arrowLength.toInt(), arrowHeight.toInt(), purple);
  // Arrow head (triangle pointing left)
  _fillTriangle(
    image,
    (cx - arrowLength / 2).toInt(),
    (botY - headSize / 2).toInt(),
    (cx - arrowLength / 2 - headSize).toInt(),
    botY.toInt(),
    (cx - arrowLength / 2).toInt(),
    (botY + headSize / 2).toInt(),
    lightPurple,
  );

  // Circle glow behind arrows
  final circleR = 120 * scale;
  _drawCircleOutline(image, cx.toInt(), cy.toInt(), circleR.toInt(), 4.toInt(),
      img.ColorRgba8(0x9b, 0x59, 0xb6, 40));
}

void _fillRect(img.Image image, int x, int y, int w, int h, img.Color color) {
  for (var j = y; j < y + h; j++) {
    for (var i = x; i < x + w; i++) {
      if (i >= 0 && i < image.width && j >= 0 && j < image.height) {
        image.setPixel(i, j, color);
      }
    }
  }
}

void _fillTriangle(img.Image image, int x1, int y1, int x2, int y2, int x3, int y3,
    img.Color color) {
  // Bounding box
  var minX = x1 < x2 ? (x1 < x3 ? x1 : x3) : (x2 < x3 ? x2 : x3);
  var maxX = x1 > x2 ? (x1 > x3 ? x1 : x3) : (x2 > x3 ? x2 : x3);
  var minY = y1 < y2 ? (y1 < y3 ? y1 : y3) : (y2 < y3 ? y2 : y3);
  var maxY = y1 > y2 ? (y1 > y3 ? y1 : y3) : (y2 > y3 ? y2 : y3);

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      if (_pointInTriangle(x, y, x1, y1, x2, y2, x3, y3)) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

bool _pointInTriangle(int px, int py, int x1, int y1, int x2, int y2, int x3, int y3) {
  final d1 = _sign(px, py, x1, y1, x2, y2);
  final d2 = _sign(px, py, x2, y2, x3, y3);
  final d3 = _sign(px, py, x3, y3, x1, y1);
  final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
  final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
  return !(hasNeg && hasPos);
}

int _sign(int px, int py, int x1, int y1, int x2, int y2) {
  return (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
}

void _drawRoundedRect(img.Image image, int x, int y, int w, int h, int r,
    img.Color color) {
  for (var j = y; j < y + h; j++) {
    for (var i = x; i < x + w; i++) {
      // Check if point is inside rounded rect
      var inside = true;
      // Top-left corner
      if (i < x + r && j < y + r) {
        final dx = i - (x + r);
        final dy = j - (y + r);
        if (dx * dx + dy * dy > r * r) inside = false;
      }
      // Top-right corner
      if (i >= x + w - r && j < y + r) {
        final dx = i - (x + w - r - 1);
        final dy = j - (y + r);
        if (dx * dx + dy * dy > r * r) inside = false;
      }
      // Bottom-left corner
      if (i < x + r && j >= y + h - r) {
        final dx = i - (x + r);
        final dy = j - (y + h - r - 1);
        if (dx * dx + dy * dy > r * r) inside = false;
      }
      // Bottom-right corner
      if (i >= x + w - r && j >= y + h - r) {
        final dx = i - (x + w - r - 1);
        final dy = j - (y + h - r - 1);
        if (dx * dx + dy * dy > r * r) inside = false;
      }

      if (inside && i >= 0 && i < image.width && j >= 0 && j < image.height) {
        image.setPixel(i, j, color);
      }
    }
  }
}

void _drawCircleOutline(img.Image image, int cx, int cy, int r, int thickness,
    img.Color color) {
  for (var j = cy - r - thickness; j <= cy + r + thickness; j++) {
    for (var i = cx - r - thickness; i <= cx + r + thickness; i++) {
      final dx = i - cx;
      final dy = j - cy;
      final dist = dx * dx + dy * dy;
      final outerR = r + thickness;
      final innerR = r;
      if (dist <= outerR * outerR && dist >= innerR * innerR) {
        if (i >= 0 && i < image.width && j >= 0 && j < image.height) {
          image.setPixel(i, j, color);
        }
      }
    }
  }
}
