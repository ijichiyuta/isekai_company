import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'audio_controller.dart';
import 'chiptune.dart';

/// The real device backend: plays the procedurally-rendered WAV bytes via
/// audioplayers (no asset files needed — BytesSource). Imported ONLY by main()
/// so `flutter test` never instantiates the plugin (tests use SilentBackend).
class AudioPlayersBackend implements AudioBackend {
  final AudioPlayer _bgm = AudioPlayer(playerId: 'isekai_bgm');
  Uint8List? _bgmWav;

  @override
  Future<void> playSfx(Uint8List wav) async {
    // A fresh player per shot so rapid taps can overlap; freed on completion.
    final p = AudioPlayer();
    p.onPlayerComplete.listen((_) => p.dispose());
    try {
      await p.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      p.dispose();
    }
  }

  @override
  Future<void> startBgm() async {
    _bgmWav ??= renderBgm();
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.5);
      await _bgm.play(BytesSource(_bgmWav!, mimeType: 'audio/wav'));
    } catch (_) {}
  }

  @override
  Future<void> stopBgm() async {
    try {
      await _bgm.stop();
    } catch (_) {}
  }
}
