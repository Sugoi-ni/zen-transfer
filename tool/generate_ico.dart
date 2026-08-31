import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final image = img.decodePng(File('assets/icons/icon_512.png').readAsBytesSync())!;
  
  // ICO format: create multiple sizes
  final sizes = [16, 32, 48, 64, 128, 256];
  final icoImages = <img.Image>[];
  
  for (final size in sizes) {
    icoImages.add(img.copyResize(image, width: size, height: size, interpolation: img.Interpolation.linear));
  }
  
  // Write ICO file
  final icoBytes = img.encodeIco(icoImages);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(icoBytes);
  print('Created: app_icon.ico');
}
