import 'package:flutter/foundation.dart';

import 'chiptune.dart';

/// App-global SFX hook so leaf widgets (e.g. every [PixelButton]) can click
/// without threading a provider through the tree. main() points it at the live
/// controller; it stays a no-op in tests (no audio plugin touched).
void Function(Sfx sfx) playSfxHook = (_) {};

/// Plays sound. Swappable so the app stays testable and plugin-free: the
/// default [SilentAudioBackend] is a no-op, and a real backend (audioplayers'
/// BytesSource playing [renderSfx] output, or CC0 assets) drops in on device.
abstract class AudioBackend {
  Future<void> playSfx(Uint8List wav);
  Future<void> startBgm();
  Future<void> stopBgm();
}

/// Default backend — makes no sound (build/tests need no native audio plugin).
class SilentAudioBackend implements AudioBackend {
  const SilentAudioBackend();
  @override
  Future<void> playSfx(Uint8List wav) async {}
  @override
  Future<void> startBgm() async {}
  @override
  Future<void> stopBgm() async {}
}

/// Central sound control: renders/caches the procedural SFX, gates them behind
/// the player's 効果音/音楽 toggles, and forwards to the active backend.
class AudioController extends ChangeNotifier {
  AudioController({
    AudioBackend backend = const SilentAudioBackend(),
    this.sfxEnabled = true,
    this.bgmEnabled = true,
  }) : _backend = backend;

  AudioBackend _backend;
  bool sfxEnabled;
  bool bgmEnabled;
  final Map<Sfx, Uint8List> _cache = {};

  /// Swap in the real device backend (audioplayers/etc.) at startup.
  set backend(AudioBackend b) => _backend = b;

  /// The rendered WAV for [s], cached so each effect is synthesized once.
  Uint8List wav(Sfx s) => _cache[s] ??= renderSfx(s);

  /// Play [s] if 効果音 is on.
  void play(Sfx s) {
    if (sfxEnabled) _backend.playSfx(wav(s));
  }

  /// Kick off BGM at app start if 音楽 is on (setBgmEnabled is a no-op when the
  /// value is unchanged, so startup needs its own entry point).
  void begin() {
    if (bgmEnabled) _backend.startBgm();
  }

  void setSfxEnabled(bool on) {
    if (on == sfxEnabled) return;
    sfxEnabled = on;
    notifyListeners();
  }

  void setBgmEnabled(bool on) {
    if (on == bgmEnabled) return;
    bgmEnabled = on;
    if (on) {
      _backend.startBgm();
    } else {
      _backend.stopBgm();
    }
    notifyListeners();
  }
}
