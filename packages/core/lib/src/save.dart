/// Save encoding: canonical JSON body + FNV-1a checksum + schema version +
/// balance content hash (requirements §16.3, §17.1). Atomic file writes and
/// generation rotation live in the app layer (SaveStore) — core only
/// encodes/decodes.
///
/// The checksum covers the ENTIRE document (schema_version + balance_hash +
/// state + meta), so tampering or bit-rot in any of them is detected.
/// decodeSave normalizes every failure to [SaveCorruptException] so the app's
/// 3-generation fallback can catch a single type.
///
/// v2 (M3): the document now carries a cross-life [MetaState] alongside the
/// per-life [GameState] (魂の記憶, §8.4). Migrations operate on the WHOLE doc
/// (not just `state`) so a version bump can add top-level sections like `meta`
/// (see docs/m3-plan-audit.md, P2 Critical-1).
library;

import 'dart:convert';

import 'balance.dart';
import 'hash.dart';
import 'meta.dart';
import 'state.dart';

const int saveSchemaVersion = 2;

/// A decoded save: the in-progress life [state] plus cross-life [meta].
class SaveData {
  final GameState state;
  final MetaState meta;
  const SaveData(this.state, this.meta);
}

/// v→v+1 pure migrations on the WHOLE save document, keyed by the version being
/// migrated FROM. A migration must advance `schema_version` (checked at runtime)
/// so the chain always terminates.
const Map<int, Map<String, dynamic> Function(Map<String, dynamic>)>
    saveMigrations = {
  1: _migrateV1ToV2,
};

/// v1 (state-only) → v2: inject a default meta section. A v1 save predates the
/// 魂の記憶 tree, so the player resumes with fresh meta. (Pre-release there is
/// no real v1 save to rescue — a v1 save also trips the balance-hash gate once
/// the economy changes; this migration proves the mechanism, AC-15.)
Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> doc) => {
      ...doc,
      'schema_version': 2,
      'meta': MetaState.initial().toJson(),
    };

class SaveCorruptException implements Exception {
  final String message;
  SaveCorruptException(this.message);
  @override
  String toString() => 'SaveCorruptException: $message';
}

String encodeSave(GameState state, MetaState meta, Balance balance) {
  final doc = <String, dynamic>{
    'schema_version': saveSchemaVersion,
    'balance_hash': balance.contentHash,
    'state': state.toJson(),
    'meta': meta.toJson(),
  };
  // Checksum over the document WITHOUT the checksum field.
  doc['checksum'] = hashHex(fnv1a64(canonicalJson(doc)));
  return canonicalJson(doc);
}

SaveData decodeSave(String text, Balance balance) {
  try {
    return _decode(text, balance);
  } on SaveCorruptException {
    rethrow;
  } on FormatException catch (e) {
    throw SaveCorruptException('unparseable save: ${e.message}');
  } catch (e) {
    // TypeError (bad casts / missing fields), ArgumentError (double in
    // canonicalJson), etc. — normalize so callers catch one exception type.
    throw SaveCorruptException('malformed save: $e');
  }
}

SaveData _decode(String text, Balance balance) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic>) {
    throw SaveCorruptException('top-level value is not an object');
  }
  var doc = decoded;

  // Checksum first — over the document AS WRITTEN (before migration), so bit-rot
  // or tampering in any field (including a v1 doc's) is caught up front.
  final stored = doc['checksum'];
  if (stored is! String) {
    throw SaveCorruptException('missing or non-string checksum');
  }
  final forHash = Map<String, dynamic>.of(doc)..remove('checksum');
  final actual = hashHex(fnv1a64(canonicalJson(forHash)));
  if (stored != actual) {
    throw SaveCorruptException('checksum mismatch (corruption or tampering)');
  }

  final version = doc['schema_version'];
  if (version is! int) {
    throw SaveCorruptException('missing or non-int schema_version');
  }
  if (version > saveSchemaVersion) {
    throw SaveCorruptException(
        'save is from a newer app version (schema v$version > '
        '$saveSchemaVersion)');
  }
  if (doc['balance_hash'] != balance.contentHash) {
    throw SaveCorruptException(
        'balance hash mismatch: save=${doc['balance_hash']} '
        'current=${balance.contentHash}');
  }

  // Migration chain: apply v→v+1 transforms on the WHOLE doc until current
  // (AC-15). Each migration must advance schema_version so this terminates.
  var v = version;
  while (v < saveSchemaVersion) {
    final migrate = saveMigrations[v];
    if (migrate == null) {
      throw SaveCorruptException('no migration path from schema v$v');
    }
    doc = migrate(doc);
    final nv = doc['schema_version'];
    if (nv is! int || nv <= v) {
      throw SaveCorruptException(
          'migration from v$v did not advance schema_version');
    }
    v = nv;
  }

  final rawState = doc['state'];
  if (rawState is! Map<String, dynamic>) {
    throw SaveCorruptException('missing state object');
  }
  final rawMeta = doc['meta'];
  if (rawMeta is! Map<String, dynamic>) {
    throw SaveCorruptException('missing meta object');
  }

  return SaveData(GameState.fromJson(rawState), MetaState.fromJson(rawMeta));
}
