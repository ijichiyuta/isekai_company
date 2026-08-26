import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:isekai_core/isekai_core.dart';

/// App-layer save persistence — the dart:io boundary (core never touches IO,
/// §2.2). Writes are ATOMIC (temp file → rename) and keep [generations] rolling
/// copies, so a crash mid-write can lose at most the newest save; [load] falls
/// back across generations on corruption (requirements §16.3 / §17.1).
///
/// The [Directory] is injected so tests can point at a temp dir without the
/// platform channel; production uses [open].
class SaveStore {
  final Balance balance;
  final Directory dir;
  SaveStore(this.balance, this.dir);

  static const int generations = 3;

  /// Opens the store under the app documents directory (production path).
  static Future<SaveStore> open(Balance balance) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/saves');
    if (!await dir.exists()) await dir.create(recursive: true);
    return SaveStore(balance, dir);
  }

  File _gen(int i) => File('${dir.path}/save.$i.json');

  // Serialize writes so generation rotation never races with itself.
  Future<void> _writeLock = Future<void>.value();

  /// Persist [state] + [meta]: rotate the generations, then atomically write
  /// the newest. Serialized against concurrent calls; a failure is isolated so
  /// it can't poison the next save.
  Future<void> save(GameState state, MetaState meta) {
    final text = encodeSave(state, meta, balance);
    final next = _writeLock.then((_) => _write(text));
    _writeLock = next.catchError((_) {});
    return next;
  }

  Future<void> _write(String text) async {
    // Rotate: drop the oldest, shift each generation down by one.
    final oldest = _gen(generations - 1);
    if (await oldest.exists()) await oldest.delete();
    for (var i = generations - 2; i >= 0; i--) {
      final f = _gen(i);
      if (await f.exists()) await f.rename(_gen(i + 1).path);
    }
    // Atomic newest write: write a temp file, then rename over save.0.
    final tmp = File('${dir.path}/save.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(_gen(0).path);
  }

  /// The newest decodable save, falling back across generations on corruption.
  /// Returns null when nothing is readable (first run).
  Future<SaveData?> load() async {
    for (var i = 0; i < generations; i++) {
      final f = _gen(i);
      if (!await f.exists()) continue;
      try {
        return decodeSave(await f.readAsString(), balance);
      } on SaveCorruptException {
        continue; // try the next-oldest generation
      }
    }
    return null;
  }
}
