import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, image, [args]) async {
    if (!RegExp(r'^043-[a-z0-9-]+$').hasMatch(name)) return false;
    final directory = Directory('../kopru/log');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(image);
    return true;
  },
);
