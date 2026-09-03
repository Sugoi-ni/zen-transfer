import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

// ignore_for_file: avoid_print

void main() {
  final image =
      img.decodePng(File('assets/icons/icon_512.png').readAsBytesSync())!;

  // ICO with multiple sizes embedded as PNG frames (Vista+ format)
  final sizes = [16, 32, 48, 64, 128, 256];
  final frames = <Uint8List>[];
  for (final size in sizes) {
    final resized = img.copyResize(image,
        width: size, height: size, interpolation: img.Interpolation.linear);
    frames.add(img.encodePng(resized));
  }

  // Write ICO file — also save as tray icon for release builds
  final icoBytes = _buildIco(frames, sizes);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(icoBytes);
  File('assets/icons/icon_48.ico').writeAsBytesSync(icoBytes);
  print('Created: app_icon.ico (${icoBytes.length} bytes, ${sizes.length} frames)');
  print('Created: icon_48.ico (${icoBytes.length} bytes, multi-size)');
}

/// Minimal ICO container: 6-byte header + 16-byte directory entries + PNG data.
Uint8List _buildIco(List<Uint8List> pngs, List<int> sizes) {
  final count = pngs.length;
  final out = BytesBuilder();

  // ICONDIR: reserved=0, type=1 (icon), count
  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, count, Endian.little);
  out.add(header.buffer.asUint8List());

  // ICONDIR + all ICONDIRENTRYs end here — PNG frames start after.
  final iconDirEndOffset = 6 + 16 * count;
  for (var i = 0; i < count; i++) {
    final s = sizes[i];
    // ICONDIRENTRY: 256 is encoded as 0
    final entry = ByteData(16)
      ..setUint8(0, s >= 256 ? 0 : s)
      ..setUint8(1, s >= 256 ? 0 : s)
      ..setUint8(2, 0) // colors in palette
      ..setUint8(3, 0) // reserved
      ..setUint16(4, 1, Endian.little) // color planes
      ..setUint16(6, 32, Endian.little) // bits per pixel
      ..setUint32(8, pngs[i].length, Endian.little)
      ..setUint32(12, iconDirEndOffset +
          (i > 0 ? pngs.sublist(0, i).fold(0, (a, b) => a + b.length)
                  : 0),
          Endian.little);
    out.add(entry.buffer.asUint8List());
  }

  for (final png in pngs) {
    out.add(png);
  }
  return out.toBytes();
}
