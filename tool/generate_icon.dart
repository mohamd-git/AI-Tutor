// Builds the Slide Tutor app icon set from a single source image and writes
// every size the web app / installable app needs.
//
// Run from the ai_tutor folder:
//   dart run tool/generate_icon.dart                  (reads assets/icon/source.png)
//   dart run tool/generate_icon.dart C:\path\icon.png (reads a file anywhere)
//
// This is a development tool only; it is not bundled into the app. The source
// is center-cropped to a square and placed full-bleed on the icon's own blue so
// there are never transparent or black corners.
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

  // Find the icon's background blue by sampling points that sit in the open
  // blue area (top edge and sides, away from the corners).
  final blue = _sampleBrandColor(master);
  stdout.writeln('brand color: ${_hex(blue)}');

  // The source sits on a solid (often black) background. Flood-fill that
  // background inward from the four corners with the icon's own blue, so the
  // result is seamless full-bleed with no dark corners. Only the connected
  // background is touched - the artwork in the middle is left alone.
  _fillBackground(master, blue);

  // Standard icons: the (now full-bleed) art at its natural size.
  _writePng(master, 'assets/icon/app_icon.png');
  _writePng(_resize(master, 512), 'web/icons/Icon-512.png');
  _writePng(_resize(master, 192), 'web/icons/Icon-192.png');
  _writePng(_resize(master, 64), 'web/favicon.png');

  // Maskable icons: art inset on full-bleed blue, so launchers that crop to a
  // circle never clip the artwork.
  final maskable = _onBlue(master, blue, 0.90);
  _writePng(_resize(maskable, 512), 'web/icons/Icon-maskable-512.png');
  _writePng(_resize(maskable, 192), 'web/icons/Icon-maskable-192.png');

  stdout.writeln('done');
}

// Places [master] (scaled to [frac] of the canvas) centered on a solid [blue]
// square, so the result is always full-bleed with no transparent corners.
img.Image _onBlue(img.Image master, img.ColorRgb8 blue, double frac) {
  final canvas = img.Image(width: masterSize, height: masterSize, numChannels: 4);
  img.fill(canvas, color: blue);
  final inner = (masterSize * frac).round();
  final scaled = inner == masterSize
      ? master
      : img.copyResize(master,
          width: inner, height: inner, interpolation: img.Interpolation.cubic);
  final off = (masterSize - inner) ~/ 2;
  img.compositeImage(canvas, scaled, dstX: off, dstY: off);
  return canvas;
}

// Recolors the solid background - the connected run of near-black pixels that
// touches the corners - to [fill]. The artwork in the middle is not connected
// to the corners, so it is left untouched.
void _fillBackground(img.Image im, img.Color fill) {
  final w = im.width;
  final h = im.height;
  final visited = List<bool>.filled(w * h, false);
  final stack = <int>[];

  void consider(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final idx = y * w + x;
    if (visited[idx]) return;
    final p = im.getPixel(x, y);
    final maxc = math.max(p.r, math.max(p.g, p.b));
    if (maxc < 70) {
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
    im.setPixel(idx % w, idx ~/ w, fill);
    consider((idx % w) - 1, idx ~/ w);
    consider((idx % w) + 1, idx ~/ w);
    consider(idx % w, (idx ~/ w) - 1);
    consider(idx % w, (idx ~/ w) + 1);
  }
}

img.Image _resize(img.Image src, int size) => img.copyResize(src,
    width: size, height: size, interpolation: img.Interpolation.average);

img.ColorRgb8 _sampleBrandColor(img.Image im) {
  const points = <List<double>>[
    [0.5, 0.06],
    [0.5, 0.10],
    [0.08, 0.5],
    [0.92, 0.5],
    [0.5, 0.5],
  ];
  for (final p in points) {
    final x = (im.width * p[0]).round().clamp(0, im.width - 1);
    final y = (im.height * p[1]).round().clamp(0, im.height - 1);
    final px = im.getPixel(x, y);
    final a = px.a.toDouble();
    final r = px.r.toInt();
    final g = px.g.toInt();
    final b = px.b.toInt();
    // Want an opaque, clearly-blue pixel (blue dominant, not near-black/white).
    if (a > 200 && b > 90 && b > r + 20 && b > g + 10) {
      return img.ColorRgb8(r, g, b);
    }
  }
  return img.ColorRgb8(31, 99, 233); // #1F63E9 fallback
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
