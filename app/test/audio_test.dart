import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/audio/audio_controller.dart';
import 'package:isekai_app/game/audio/chiptune.dart';

String _tag(Uint8List b, int off) => String.fromCharCodes(b.sublist(off, off + 4));

class _FakeBackend implements AudioBackend {
  final List<Uint8List> sfx = [];
  int bgmStarts = 0;
  int bgmStops = 0;
  @override
  Future<void> playSfx(Uint8List wav) async => sfx.add(wav);
  @override
  Future<void> startBgm() async => bgmStarts++;
  @override
  Future<void> stopBgm() async => bgmStops++;
}

void main() {
  group('chiptune renderSfx', () {
    test('emits a well-formed 16-bit mono PCM WAV', () {
      final w = renderSfx(Sfx.coin);
      expect(_tag(w, 0), 'RIFF');
      expect(_tag(w, 8), 'WAVE');
      expect(_tag(w, 12), 'fmt ');
      expect(_tag(w, 36), 'data');
      final bd = ByteData.sublistView(w);
      expect(bd.getUint16(22, Endian.little), 1); // channels
      expect(bd.getUint32(24, Endian.little), 22050); // sample rate
      expect(bd.getUint16(34, Endian.little), 16); // bits/sample
      // The declared data length matches the bytes that follow the 44-byte head.
      final dataLen = bd.getUint32(40, Endian.little);
      expect(w.length, 44 + dataLen);
      expect(dataLen, greaterThan(0));
    });

    test('is deterministic and distinct per effect', () {
      expect(renderSfx(Sfx.tap), renderSfx(Sfx.tap)); // stable across calls
      expect(renderSfx(Sfx.tap), isNot(renderSfx(Sfx.coin)));
      // Every effect renders to a non-trivial buffer.
      for (final s in Sfx.values) {
        expect(renderSfx(s).length, greaterThan(44));
      }
    });
  });

  group('AudioController', () {
    test('plays through the backend only when 効果音 is on', () {
      final b = _FakeBackend();
      final c = AudioController(backend: b);
      c.play(Sfx.tap);
      expect(b.sfx, hasLength(1));
      c.setSfxEnabled(false);
      c.play(Sfx.tap);
      expect(b.sfx, hasLength(1)); // suppressed
    });

    test('caches each rendered effect', () {
      final c = AudioController();
      expect(identical(c.wav(Sfx.invent), c.wav(Sfx.invent)), isTrue);
    });

    test('BGM toggle drives the backend and notifies', () {
      final b = _FakeBackend();
      final c = AudioController(backend: b);
      var notified = 0;
      c.addListener(() => notified++);
      c.setBgmEnabled(false);
      expect(b.bgmStops, 1);
      c.setBgmEnabled(true);
      expect(b.bgmStarts, 1);
      expect(notified, 2);
      c.setBgmEnabled(true); // no-op, no extra notify
      expect(notified, 2);
    });
  });
}
