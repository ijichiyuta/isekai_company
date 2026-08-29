import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_controller.dart';
import 'chiptune.dart';

/// The real device backend. audioplayers' in-memory BytesSource is unreliable
/// on darwin, so we write each procedurally-rendered WAV to the app's temp dir
/// once and play it via DeviceFileSource (well-supported on iOS/macOS). Still
/// no bundled audio assets — the bytes are generated at runtime. Imported ONLY
/// by main() so tests never load the plugin.
class AudioPlayersBackend implements AudioBackend {
  final AudioPlayer _bgm = AudioPlayer(playerId: 'isekai_bgm');
  final Map<Uint8List, String> _sfxPaths = {}; // wav (by identity) -> file path
  String? _bgmPath;
  Directory? _dir;
  Future<void>? _ready;

  /// Push the audio session to native ONCE. audioplayers' iOS default is
  /// `.playback`, but the global context isn't applied to AVAudioSession until
  /// `setAudioContext` is called explicitly — until then `play()` returns with
  /// no error yet stays silent (the "no sound on iOS" trap). `mixWithOthers`
  /// keeps the player's own music going. Runs before the first play so ordering
  /// is guaranteed; a no-op on platforms without a session.
  Future<void> _configure() => _ready ??= AudioPlayer.global.setAudioContext(
    AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );

  Future<Directory> _tmp() async =>
      _dir ??= await getTemporaryDirectory();

  Future<String> _write(String name, Uint8List bytes) async {
    final dir = await _tmp();
    final f = File('${dir.path}/isekai_$name.wav');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  @override
  Future<void> playSfx(Uint8List wav) async {
    try {
      await _configure();
      final path = _sfxPaths[wav] ??= await _write('sfx${_sfxPaths.length}', wav);
      final p = AudioPlayer();
      p.onPlayerComplete.listen((_) => p.dispose());
      await p.play(DeviceFileSource(path));
    } catch (e, st) {
      if (kDebugMode) debugPrint('[audio] SFX failed: $e\n$st');
    }
  }

  @override
  Future<void> startBgm() async {
    try {
      await _configure();
      _bgmPath ??= await _write('bgm', renderBgm());
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.5);
      await _bgm.play(DeviceFileSource(_bgmPath!));
    } catch (e, st) {
      if (kDebugMode) debugPrint('[audio] BGM failed: $e\n$st');
    }
  }

  @override
  Future<void> stopBgm() async {
    try {
      await _bgm.stop();
    } catch (_) {}
  }
}
