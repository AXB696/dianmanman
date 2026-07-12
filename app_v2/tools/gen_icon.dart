// Run this script: dart run tools/gen_icon.dart
import 'dart:io';
import 'dart:ui' as ui;

Future<void> main() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const size = 1024.0;

  final paint = ui.Paint();
  final rect = ui.Rect.fromLTWH(0, 0, size, size);
  final rrect = ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(180));

  paint.color = const ui.Color(0xFF2196F3);
  canvas.drawRRect(rrect, paint);

  paint.shader = null;
  paint.color = const ui.Color(0xFFFFFFFF);

  final cx = size / 2;
  final cy = size / 2 + 20;

  final path = ui.Path();
  path.moveTo(cx - 30, cy - 250);
  path.lineTo(cx + 70, cy - 70);
  path.lineTo(cx - 15, cy - 50);
  path.lineTo(cx + 100, cy + 220);
  path.lineTo(cx - 40, cy + 20);
  path.lineTo(cx + 30, cy + 0);
  path.close();

  canvas.drawPath(path, paint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

  File('assets/app_icon.png').writeAsBytesSync(byteData!.buffer.asUint8List());
  print('Icon saved to assets/app_icon.png');

  exit(0);
}