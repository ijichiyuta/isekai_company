import 'dart:typed_data';

/// Retro sound effects, generated procedurally as WAV bytes — the "code-drawn"
/// counterpart to the in-code pixel art (no audio asset files). A real
/// [AudioBackend] plays these bytes; until one is wired the sound layer is
/// silent, so the app builds and tests without any native audio plugin.
enum Sfx { tap, confirm, cancel, coin, invent, rankUp, weekTick, error }

const int _sampleRate = 22050; // retro-friendly, small buffers

/// One square-wave note of a chiptune phrase.
class _Note {
  const _Note(this.freq, this.ms);
  final double freq; // Hz
  final int ms;
}

/// The little phrase each effect plays (simple, recognizable, arcade-ish).
List<_Note> _phrase(Sfx sfx) => switch (sfx) {
  Sfx.tap => const [_Note(660, 45)],
  Sfx.confirm => const [_Note(523, 55), _Note(784, 95)],
  Sfx.cancel => const [_Note(523, 55), _Note(392, 95)],
  Sfx.coin => const [_Note(988, 40), _Note(1319, 95)],
  Sfx.invent => const [
    _Note(523, 70),
    _Note(659, 70),
    _Note(784, 70),
    _Note(1046, 190),
  ],
  Sfx.rankUp => const [
    _Note(523, 70),
    _Note(659, 70),
    _Note(784, 70),
    _Note(1046, 70),
    _Note(1319, 210),
  ],
  Sfx.weekTick => const [_Note(330, 40)],
  Sfx.error => const [_Note(196, 230)],
};

/// Renders [sfx] to a 16-bit mono PCM WAV (deterministic — no RNG/wall clock).
Uint8List renderSfx(Sfx sfx) {
  final notes = _phrase(sfx);
  var total = 0;
  for (final n in notes) {
    total += _sampleRate * n.ms ~/ 1000;
  }
  final pcm = Int16List(total);
  final attack = _sampleRate * 4 ~/ 1000; // 4ms fade-in avoids clicks
  var i = 0;
  for (final n in notes) {
    final count = _sampleRate * n.ms ~/ 1000;
    final period = _sampleRate / n.freq;
    for (var s = 0; s < count; s++) {
      final square = (s % period) / period < 0.5 ? 1.0 : -1.0;
      double env;
      if (s < attack) {
        env = s / attack;
      } else {
        env = 1.0 - (s - attack) / (count - attack);
      }
      if (env < 0) env = 0;
      pcm[i++] = (square * env * 0.32 * 32767).toInt();
    }
  }
  return _wav(pcm);
}

/// A gentle, low-volume looping arpeggio for background music (placeholder —
/// swap for a CC0 track when one is sourced). Softer amplitude than the SFX so
/// it sits under them. Deterministic.
Uint8List renderBgm() {
  const loop = [
    _Note(523, 260), _Note(659, 260), _Note(784, 260), _Note(659, 260), // C E G E
    _Note(587, 260), _Note(784, 260), _Note(988, 260), _Note(784, 260), // D G B G
  ];
  var total = 0;
  for (final n in loop) {
    total += _sampleRate * n.ms ~/ 1000;
  }
  final pcm = Int16List(total);
  var i = 0;
  for (final n in loop) {
    final count = _sampleRate * n.ms ~/ 1000;
    final period = _sampleRate / n.freq;
    for (var s = 0; s < count; s++) {
      final square = (s % period) / period < 0.5 ? 1.0 : -1.0;
      // soft attack/decay so notes don't click and the loop stays mellow
      final t = s / count;
      final env = (t < 0.1 ? t / 0.1 : (1.0 - t) / 0.9).clamp(0.0, 1.0);
      pcm[i++] = (square * env * 0.14 * 32767).toInt();
    }
  }
  return _wav(pcm);
}

Uint8List _wav(Int16List pcm) {
  final dataLen = pcm.length * 2;
  final out = BytesBuilder();
  void tag(String s) => out.add(s.codeUnits);
  void u32(int v) =>
      out.add([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);
  void u16(int v) => out.add([v & 0xff, v >> 8 & 0xff]);

  tag('RIFF');
  u32(36 + dataLen);
  tag('WAVE');
  tag('fmt ');
  u32(16); // fmt chunk size
  u16(1); // PCM
  u16(1); // mono
  u32(_sampleRate);
  u32(_sampleRate * 2); // byte rate (mono, 16-bit)
  u16(2); // block align
  u16(16); // bits per sample
  tag('data');
  u32(dataLen);
  final samples = Uint8List(dataLen);
  final view = ByteData.view(samples.buffer);
  for (var k = 0; k < pcm.length; k++) {
    view.setInt16(k * 2, pcm[k], Endian.little);
  }
  out.add(samples);
  return out.toBytes();
}
