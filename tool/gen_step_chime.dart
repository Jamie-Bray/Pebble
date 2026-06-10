// Generates assets/audio/step_complete.wav — the soft confirmation chime
// played (opt-in) when a routine step is checked off.
//
// Run: dart run tool/gen_step_chime.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const durationSeconds = 0.45;
  final sampleCount = (sampleRate * durationSeconds).round();
  final samples = Float64List(sampleCount);

  // Two soft sine partials a perfect fifth apart with a fast attack and
  // exponential decay — reads as a gentle marimba-style "dink".
  const f1 = 987.77; // B5
  const f2 = 1479.98; // F#6
  for (var i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    final attack = math.min(1.0, t / 0.008);
    final decay = math.exp(-t * 9.5);
    final tone =
        0.62 * math.sin(2 * math.pi * f1 * t) +
        0.38 * math.sin(2 * math.pi * f2 * t);
    samples[i] = 0.32 * attack * decay * tone;
  }

  final pcm = Int16List(sampleCount);
  for (var i = 0; i < sampleCount; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }

  final dataBytes = pcm.buffer.asUint8List();
  final header = BytesBuilder();
  void writeString(String s) => header.add(s.codeUnits);
  void writeUint32(int v) =>
      header.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void writeUint16(int v) =>
      header.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  writeString('RIFF');
  writeUint32(36 + dataBytes.length);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(sampleRate);
  writeUint32(sampleRate * 2); // byte rate
  writeUint16(2); // block align
  writeUint16(16); // bits per sample
  writeString('data');
  writeUint32(dataBytes.length);
  header.add(dataBytes);

  final out = File('assets/audio/step_complete.wav');
  out.createSync(recursive: true);
  out.writeAsBytesSync(header.toBytes());
  stdout.writeln('Wrote ${out.path} (${header.length} bytes)');
}
