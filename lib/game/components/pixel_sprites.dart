import 'dart:ui';
import 'package:flame/components.dart';

/// Original code-drawn pixel art. Integer cells and no texture filtering.
abstract final class PixelSprites {
  static const ship = <String>[
    '.......aa.......',
    '.......aa.......',
    '......abba......',
    '......abba......',
    '.....abccba.....',
    '.....abccba.....',
    '....aabccbaa....',
    '..aaabbbbbbaaa..',
    '.abbbbbbbbbbbba.',
    '.abbbddddddbbba.',
    '.abbaddddddaabba.',
    '.aaa.aaaaaa.aaa.',
    '.....ee..ee.....',
    '.....ef..fe.....',
    '......f..f......',
    '................',
  ];
  static const rock = <String>[
    '.....aaaaa......',
    '...aabbbbbaa....',
    '..abccbbbbbbba..',
    '.abcccbbbbbbba..',
    '.abccbbbddbbbba.',
    'abbbbbbdddbbbba.',
    'abbbbbbdddbbbba.',
    'abddbbbbbbbbbba.',
    'abdddbbbbccbbba.',
    'abddbbbbcccbbba.',
    '.abbbbbbbccbbba.',
    '.abbbbddbbbbba..',
    '..abbbddbbbba...',
    '...abbbbbbba....',
    '....aaaaaaa.....',
    '................',
  ];
  static Future<Sprite> create({required bool player}) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final palette = player
        ? <String, Color>{
            'a': const Color(0xff168f9c),
            'b': const Color(0xff70fff1),
            'c': const Color(0xffefffff),
            'd': const Color(0xff102a53),
            'e': const Color(0xffffbd72),
            'f': const Color(0xffff685f),
          }
        : <String, Color>{
            'a': const Color(0xff863747),
            'b': const Color(0xffff8578),
            'c': const Color(0xffffc0a1),
            'd': const Color(0xffbf5361),
          };
    final rows = player ? ship : rock;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < 16 && x < rows[y].length; x++) {
        final color = palette[rows[y][x]];
        if (color != null) {
          canvas.drawRect(
            Rect.fromLTWH(x * 2, y * 2, 2, 2),
            Paint()..color = color,
          );
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    picture.dispose();
    return Sprite(image);
  }
}
