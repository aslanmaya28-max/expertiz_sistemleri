import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Var olan site sembolünü kodla PNG'ye işler; çizimin kaynağı SVG'dir.
void main() {
  testWidgets('YerimeBak vektör marka varlıklarını üret', (tester) async {
    const path =
        'M40,42 L521,41 Q537,42 535,61 L410,388 Q404,426 448,442 L466,442 L621,54 Q627,40 641,40 L977,41 L773,511 Q748,568 725,606 Q673,666 633,684 Q583,706 523,708 L195,708 Q103,706 71,601 L54,538 L388,536 Q438,534 452,478 L285,478 Q163,478 131,346 Z';
    await tester.runAsync(() async {
      final dir = Directory('assets/marka')..createSync(recursive: true);
      for (final background in [false, true]) {
        final transform = background
            ? 'translate(172 262) scale(.67)'
            : 'translate(227 303) scale(.56)';
        final svg =
            '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${background ? '<rect width="1024" height="1024" fill="#0B4A45"/>' : ''}<g transform="$transform"><path fill="#8FE0D3" d="$path"/></g></svg>';
        final name = background ? 'ikon' : 'sembol';
        File('${dir.path}/$name.svg').writeAsStringSync(svg);
        final picture = await vg.loadPicture(SvgStringLoader(svg), null);
        final image = await picture.picture.toImage(1024, 1024);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${dir.path}/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        if (background) {
          final recorder = ui.PictureRecorder();
          ui.Canvas(recorder)
            ..scale(.5)
            ..drawPicture(picture.picture);
          final smallPicture = recorder.endRecording();
          final small = await smallPicture.toImage(512, 512);
          final data = await small.toByteData(format: ui.ImageByteFormat.png);
          File(
            'magaza/ikon-512.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          small.dispose();
          smallPicture.dispose();
        }
        image.dispose();
        picture.picture.dispose();
      }
    });
  });
}
