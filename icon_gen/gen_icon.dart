import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math' as math;

void main() {
  final size = 1024;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  final margin = 40;
  final cr = 180;
  final x0 = margin, y0 = margin, x1 = size - margin, y1 = size - margin;

  // Draw rounded rect with blue gradient
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (_inRoundRect(x, y, x0, y0, x1, y1, cr)) {
        final t = (y - y0) / (y1 - y0);
        final r = (33 + (25 - 33) * t).round().clamp(0, 255);
        final g = (150 + (118 - 150) * t).round().clamp(0, 255);
        final b = (243 + (210 - 243) * t).round().clamp(0, 255);
        image.setPixel(x, y, img.ColorUint8.rgb(r, g, b));
      }
    }
  }

  // Lightning bolt
  final cx = size ~/ 2;
  final cy = size ~/ 2 + 20;
  final points = [
    [cx - 30, cy - 250],
    [cx + 70, cy - 70],
    [cx - 15, cy - 50],
    [cx + 100, cy + 220],
    [cx - 40, cy + 20],
    [cx + 30, cy + 0],
  ];

  // Simple flood fill for lightning bolt
  final minY = points.map((p) => p[1]).reduce(math.min);
  final maxY = points.map((p) => p[1]).reduce(math.max);

  for (int y = minY; y <= maxY; y++) {
    final crossings = <int>[];
    for (int i = 0; i < points.length; i++) {
      final j = (i + 1) % points.length;
      final py1 = points[i][1], py2 = points[j][1];
      final px1 = points[i][0], px2 = points[j][0];
      if ((py1 <= y && py2 > y) || (py2 <= y && py1 > y)) {
        crossings.add((px1 + (y - py1) * (px2 - px1) / (py2 - py1)).round());
      }
    }
    crossings.sort();
    for (int k = 0; k < crossings.length - 1; k += 2) {
      for (int x = crossings[k]; x < crossings[k + 1]; x++) {
        if (x >= 0 && x < size) {
          image.setPixel(x, y, img.ColorUint8.rgb(255, 255, 255));
        }
      }
    }
  }

  final png = img.encodePng(image);
  final path = 'C:/Users/28773/Desktop/Smart Charge/app/smart_charge/assets/app_icon.png';
  File(path).writeAsBytesSync(png);
  print('Icon generated: $path');
}

bool _inRoundRect(int x, int y, int rx, int ry, int rw, int rh, int cr) {
  if (x < rx || x > rw || y < ry || y > rh) return false;
  final tl = x < rx + cr && y < ry + cr;
  final tr = x > rw - cr && y < ry + cr;
  final bl = x < rx + cr && y > rh - cr;
  final br = x > rw - cr && y > rh - cr;
  if (tl) { final dx = x - rx - cr; final dy = y - ry - cr; return dx*dx + dy*dy <= cr*cr; }
  if (tr) { final dx = x - rw + cr; final dy = y - ry - cr; return dx*dx + dy*dy <= cr*cr; }
  if (bl) { final dx = x - rx - cr; final dy = y - rh + cr; return dx*dx + dy*dy <= cr*cr; }
  if (br) { final dx = x - rw + cr; final dy = y - rh + cr; return dx*dx + dy*dy <= cr*cr; }
  return true;
}
