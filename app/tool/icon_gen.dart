// Icon generator (L-1): draws the TongTong Royal launcher marks
// with the `image` package — geometric, token-colored, zero external
// assets (no ATTRIBUTION rows needed).
//
// Outputs (app/assets/brand/):
//  - icon_1024.png        full-bleed square icon (stores)
//  - adaptive_fg_1024.png adaptive foreground (symbol on transparent)
//
// Motif: a white ball mid-bounce with motion rings on brand orange —
// "tongtong" (bouncy) in one glance.
//
// Run: dart run tool/icon_gen.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:image/image.dart';

// Token colors (docs/07 design guide — keep in sync manually; the
// tool runs outside the Flutter app so tokens.dart can't be shared).
final Color _orange = ColorRgba8(0xFF, 0x8C, 0x42, 0xFF);
final Color _teal = ColorRgba8(0x2E, 0xC4, 0xB6, 0xFF);
final Color _white = ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF);
final Color _ink = ColorRgba8(0x1B, 0x26, 0x31, 0xFF);
final Color _shadow = ColorRgba8(0x1B, 0x26, 0x31, 60);

void main() {
  Directory('assets/brand').createSync(recursive: true);
  _write('icon_1024.png', _icon());
  _write('adaptive_fg_1024.png', _adaptiveForeground());
  print('icons written to app/assets/brand/');
}

void _write(String name, Image img) {
  File('assets/brand/$name').writeAsBytesSync(encodePng(img));
}

Image _canvas(int size, Color color) {
  final img = Image(width: size, height: size);
  fill(img, color: color);
  return img;
}

void _disc(Image img, int x, int y, int r, Color color) {
  fillCircle(img, x: x, y: y, radius: r, color: color, antialias: true);
}

void _ring(Image img, int x, int y, int r, int width, Color color) {
  // image 4.x drawCircle has no thickness param: draw concentric
  // outlines to build a ring of the wanted stroke width.
  for (var i = 0; i < width; i++) {
    drawCircle(img, x: x, y: y, radius: r - i, color: color);
  }
}

Image _symbol(int size) {
  final img = _canvas(size, ColorRgba8(0, 0, 0, 0)); // transparent
  final ball = (size * 0.30).round();
  final bx = (size * 0.50).round();
  final by = (size * 0.44).round();
  // Motion rings above the ball = bounce path.
  _ring(img, bx, (size * 0.80).round(), (size * 0.42).round(),
      (size * 0.045).round(), _teal);
  _ring(img, bx, (size * 0.80).round(), (size * 0.30).round(),
      (size * 0.045).round(), _teal);
  // Shadow.
  _disc(img, bx, (size * 0.80).round(), (size * 0.15).round(), _shadow);
  // Ball: ink outline + white fill + highlight.
  _disc(img, bx, by, ball + (size * 0.02).round(), _ink);
  _disc(img, bx, by, ball, _white);
  _disc(
    img,
    (bx - ball * 0.35).round(),
    (by - ball * 0.35).round(),
    (ball * 0.28).round(),
    ColorRgba8(255, 255, 255, 220),
  );
  return img;
}

Image _icon() {
  const size = 1024;
  final img = _canvas(size, _orange);
  compositeImage(img, _symbol(size));
  return img;
}

Image _adaptiveForeground() {
  // Adaptive foregrounds get cropped to a circle (~66% safe zone):
  // scale the symbol into the center on transparency.
  const size = 1024;
  final full = _symbol(size);
  final scaled = copyResize(
    full,
    width: (size * 0.62).round(),
    height: (size * 0.62).round(),
  );
  final img = _canvas(size, ColorRgba8(0, 0, 0, 0));
  compositeImage(
    img,
    scaled,
    dstX: (size - scaled.width) ~/ 2,
    dstY: (size - scaled.height) ~/ 2,
  );
  return img;
}
