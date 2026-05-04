import 'dart:convert';
import 'dart:io';

/// Simple helper to generate tiny placeholder PNGs for crops.
///
/// Usage:
///   dart run tools/generate_crop_placeholders.dart
///
/// This writes 1x1 transparent PNGs named like:
///   assets/images/crops/wheat_0.png
///   assets/images/crops/wheat_1.png
///   ...

const _base64Png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

void main() {
  final crops = ['wheat', 'rice', 'corn'];
  final outDir = Directory('assets/images/crops');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final bytes = base64Decode(_base64Png);
  for (final crop in crops) {
    for (var stage = 0; stage <= 3; stage++) {
      final file = File('${outDir.path}/\$crop_\$stage.png');
      file.writeAsBytesSync(bytes);
      print('Wrote: \\${file.path}');
    }
  }
  print('Placeholder crop images generated. Run `flutter pub get` if needed.');
}
