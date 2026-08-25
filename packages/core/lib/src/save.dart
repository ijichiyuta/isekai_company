/// Save encoding: canonical JSON body + FNV-1a checksum + schema version +
/// balance content hash (requirements §16.3, §17.1). Atomic file writes and
/// generation rotation live in the app layer — core only encodes/decodes.
///
/// The checksum covers the ENTIRE document (schema_version + balance_hash +
/// state), so tampering or bit-rot in any of them is detected — not just the
/// state subtree. decodeSave normalizes every failure to [SaveCorruptException]
/// so the app's 3-generation fallback can catch a single type.
library;

import 'dart:convert';

import 'balance.dart';
import 'hash.dart';
import 'state.dart';

const int saveSchemaVersion = 1;

/// v→v+1 pure migrations on the raw `state` JSON. Empty at v1: the scaffold
/// exists so AC-15 (requirements §17.1) has a home the instant the schema
/// version increments, and the migration test can assert on it from day one.
const Map<int, Map<String, dynamic> Function(Map<String, dynamic>)>
    saveMigrations = {};

class SaveCorruptException implements Exception {
  final String message;
  SaveCorruptException(this.message);
  @override
  String toString() => 'SaveCorruptException: $message';
}

String encodeSave(GameState state, Balance balance) {
  final doc = <String, dynamic>{
    'schema_version': saveSchemaVersion,
    'balance_hash': balance.contentHash,
    'state': state.toJson(),
  };
  // Checksum over the document WITHOUT the checksum field.
  doc['checksum'] = hashHex(fnv1a64(canonicalJson(doc)));
  return canonicalJson(doc);
}

GameState decodeSave(String text, Balance balance) {
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

GameState _decode(String text, Balance balance) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic>) {
    throw SaveCorruptException('top-level value is not an object');
  }
  final doc = decoded;

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

  final rawState = doc['state'];
  if (rawState is! Map<String, dynamic>) {
    throw SaveCorruptException('missing state object');
  }

  // Migration chain: apply v→v+1 transforms until current (AC-15).
  var stateJson = rawState;
  var v = version;
  while (v < saveSchemaVersion) {
    final migrate = saveMigrations[v];
    if (migrate == null) {
      throw SaveCorruptException('no migration path from schema v$v');
    }
    stateJson = migrate(stateJson);
    v++;
  }

  return GameState.fromJson(stateJson);
}
