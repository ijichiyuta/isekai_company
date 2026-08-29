import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/audio/audio_controller.dart';
import 'game/audio/audioplayers_backend.dart';
import 'game/providers.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Install the real (device) audio backend and route the global SFX hook to
  // it. Tests never run this file, so they keep the SilentAudioBackend.
  final audio = AudioController(backend: AudioPlayersBackend());
  playSfxHook = audio.play;
  audio.begin(); // start BGM if 音楽 is on
  runApp(
    ProviderScope(
      overrides: [audioControllerProvider.overrideWith((ref) => audio)],
      child: const IsekaiApp(),
    ),
  );
}
