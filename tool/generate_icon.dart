// Builds the Slide Tutor app icon set from a single source image and writes
// every size the web app / installable app needs.
//
// Run from the ai_tutor folder:
//   dart run tool/generate_icon.dart                  (reads assets/icon/source.png)
//   dart run tool/generate_icon.dart C:\path\icon.png (reads a file anywhere)
//
// The source is center-cropped to a square. If it sits on a solid (e.g. black)
// background, that background is flood-filled from the corners with the icon's
// own blue gradient, so the result is seamless full-bleed with no dark edges.
// Development tool only; it is not bundled into the app.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int masterSize = 1024;

void main(List<String> args) {
  final srcPath = args.isNotEmpty ? args.first : 'assets/icon/source.png';
  final srcFile = File(srcPath);
  if (!srcFile.existsSync()) {
    stderr.writeln('Could not find "$srcPath". Save your icon there first, or '
        'pass its path as an argument.');
    exitCode = 1;
    return;
  }
  final decoded = img.decodeImage(srcFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not read "$srcPath" as an image (is it a real PNG?).');
    exitCode = 1;
    return;
  }

  // Center-crop to a square, then normalize to the master size.
  final s = math.min(decoded.width, decoded.height);
  final square = img.copyCrop(decoded,
      x: (decoded.width - s) ~/ 2,
      y: (decoded.height - s) ~/ 2,
      width: s,
      height: s);
  final master = img.copyResize(square,
      width: masterSize,
      height: masterSize,
      interpolation: img.Interpolation.cubic);

  // Sample the icon's own background blue at the top and bottom (along the
  // center, away from the corners) so we can refill the dark background with a
  // matching gradient instead of a flat color.
  final top = _sampleAt(master, 0.5, 0.05) ?? img.ColorRgb8(42, 155, 251);
  final bottom = _sampleAt(master, 0.5, 0.95) ?? top;
  stdout.writeln('background blue: ${_hex(top)} -> ${_hex(bottom)}');

  // Remove the solid (black) background by flood-filling it inward from the
  // four corners with that gradient. Only the connected background is touched;
  // the artwork in the middle is never reached.
  _fillBackground(master, top, bottom);

  _writePng(master, 'assets/icon/app_icon.png');
  _writePng(_resize(master, 512), 'web/icons/Icon-512.png');
  _writePng(_resize(master, 192), 'web/icons/Icon-192.png');
  _writePng(_resize(master, 64), 'web/favicon.png');

  // Maskable: the art inset on a matching gradient, so launchers that crop to a
  // circle never clip a corner element (like the PDF tag).
  final maskable = _maskable(master, top, bottom);
  _writePng(_resize(maskable, 512), 'web/icons/Icon-maskable-512.png');
  _writePng(_resize(maskable, 192), 'web/icons/Icon-maskable-192.png');

  stdout.writeln('done');
}

img.Image _resize(img.Image src, int size) => img.copyResize(src,
    width: size, height: size, interpolation: img.Interpolation.average);

// Flood-fills the connected near-black background (reached from the corners)
// with a top-to-bottom [top]->[bottom] gradient.
void _fillBackground(img.Image im, img.ColorRgb8 top, img.ColorRgb8 bottom) {
  final w = im.width;
  final h = im.height;
  final visited = List<bool>.filled(w * h, false);
  final stack = <int>[];

  void consider(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final idx = y * w + x;
    if (visited[idx]) return;
    final p = im.getPixel(x, y);
    if (math.max(p.r, math.max(p.g, p.b)) < 70) {
      visited[idx] = true;
      stack.add(idx);
    }
  }

  consider(0, 0);
  consider(w - 1, 0);
  consider(0, h - 1);
  consider(w - 1, h - 1);
  while (stack.isNotEmpty) {
    final idx = stack.removeLast();
    final x = idx % w;
    final y = idx ~/ w;
    im.setPixel(x, y, _lerp(top, bottom, h <= 1 ? 0.0 : y / (h - 1)));
    consider(x - 1, y);
    consider(x + 1, y);
    consider(x, y - 1);
    consider(x, y + 1);
  }
}

// A full square filled with the [top]->[bottom] vertical gradient.
img.Image _gradientCanvas(int size, img.ColorRgb8 top, img.ColorRgb8 bottom) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    final color = _lerp(top, bottom, size <= 1 ? 0.0 : y / (size - 1));
    img.drawLine(canvas, x1: 0, y1: y, x2: size - 1, y2: y, color: color);
  }
  return canvas;
}

img.Image _maskable(img.Image master, img.ColorRgb8 top, img.ColorRgb8 bottom) {
  final canvas = _gradientCanvas(masterSize, top, bottom);
  const frac = 0.90;
  final inner = (masterSize * frac).round();
  final scaled = img.copyResize(master,
      width: inner, height: inner, interpolation: img.Interpolation.cubic);
  final off = (masterSize - inner) ~/ 2;
  img.compositeImage(canvas, scaled, dstX: off, dstY: off);
  return canvas;
}

img.ColorRgb8 _lerp(img.ColorRgb8 a, img.ColorRgb8 b, double t) {
  int c(num x, num y) => (x + (y - x) * t).round();
  return img.ColorRgb8(c(a.r, b.r), c(a.g, b.g), c(a.b, b.b));
}

img.ColorRgb8? _sampleAt(img.Image im, double fx, double fy) {
  final x = (im.width * fx).round().clamp(0, im.width - 1);
  final y = (im.height * fy).round().clamp(0, im.height - 1);
  final p = im.getPixel(x, y);
  if (p.a.toDouble() < 200) return null;
  return img.ColorRgb8(p.r.toInt(), p.g.toInt(), p.b.toInt());
}

String _hex(img.ColorRgb8 c) {
  String h(num v) => v.toInt().toRadixString(16).padLeft(2, '0');
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

void _writePng(img.Image image, String path) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $path');
}
