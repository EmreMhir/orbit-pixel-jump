import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 22050;
double square(double phase) => math.sin(phase) >= 0 ? 1 : -1;
double hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

void saveWav(String name, double seconds, double Function(double) sample) {
  final count = (seconds * sampleRate).round();
  final data = ByteData(44 + count * 2);
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + count * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    final value = (sample(i / sampleRate).clamp(-1.0, 1.0) * 24000).round();
    data.setInt16(44 + i * 2, value, Endian.little);
  }
  File('assets/audio/$name.wav').writeAsBytesSync(data.buffer.asUint8List());
}

void main() {
  Directory('assets/audio').createSync(recursive: true);
  saveWav(
    'jump',
    0.16,
    (t) =>
        square(2 * math.pi * (300 * t + 2200 * t * t)) * (1 - t / 0.16) * 0.55,
  );
  saveWav(
    'button',
    0.07,
    (t) => square(2 * math.pi * 800 * t) * (1 - t / 0.07) * 0.35,
  );
  final random = math.Random(19);
  saveWav(
    'explosion',
    0.5,
    (t) =>
        ((random.nextDouble() * 2 - 1) * 0.65 +
            square(2 * math.pi * (100 * t - 70 * t * t)) * 0.25) *
        math.pow(1 - t / 0.5, 2),
  );
  saveWav('sector', 0.4, (t) {
    final note = [72, 76, 79, 84][math.min(3, (t * 10).floor())];
    return square(2 * math.pi * hz(note) * t) * 0.35 * (1 - (t % 0.1) / 0.1);
  });
  const beat = 0.25;
  const melody = [
    76,
    79,
    83,
    79,
    76,
    79,
    86,
    83,
    74,
    78,
    81,
    78,
    74,
    78,
    83,
    81,
    72,
    76,
    79,
    76,
    72,
    76,
    83,
    79,
    74,
    78,
    81,
    83,
    86,
    83,
    81,
    78,
  ];
  saveWav('bgm', 16, (t) {
    final step = (t / beat).floor();
    final fraction = (t % beat) / beat;
    final lead =
        square(2 * math.pi * hz(melody[step % melody.length]) * t) *
        math.max(0, 1 - fraction * 1.2) *
        0.19;
    final root = [40, 38, 36, 38][(step ~/ 8) % 4];
    final bass = math.sin(2 * math.pi * hz(root) * t) * 0.25;
    final kickT = t % 0.5;
    final kick =
        math.sin(2 * math.pi * (60 * kickT + 4 * (1 - math.exp(-kickT * 40)))) *
        math.exp(-kickT * 25) *
        0.2;
    final hat = (random.nextDouble() * 2 - 1) * math.exp(-fraction * 45) * 0.1;
    final edge = math.min(1.0, math.min(t * 200, (16 - t) * 200));
    return (lead + bass + kick + hat) * edge;
  });
  stdout.writeln('Generated 5 original PCM WAV assets.');
}
