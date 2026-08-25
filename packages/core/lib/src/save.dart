/// Save encoding: canonical JSON body + FNV-1a checksum + schema version +
/// balance content hash (requirements §16.3, §17.1). Atomic file writes and
/// generation rotation live in the app layer — core only encodes/decodes.
library;

import 'dart:convert';

import 'balance.dart';
import 'hash.dart';
import 'state.dart';

const int saveSchemaVersion = 1;

class SaveCorruptException implements Exception {
  final String message;
  SaveCorruptException(this.message);
  @override
  String toString() => 'SaveCorruptException: $message';
}

String encodeSave(GameState state, Balance balance) {
  final payload = state.toJson();
  final checksum = hashHex(fnv1a64(canonicalJson(payload)));
  return canonicalJson({
    'schema_version': saveSchemaVersion,
    'balance_hash': balance.contentHash,
    'checksum': checksum,
    'state': payload,
  });
}

GameState decodeSave(String text, Balance balance) {
  final Map<String, dynamic> doc;
  try {
    doc = jsonDecode(text) as Map<String, dynamic>;
  } on FormatException catch (e) {
    throw SaveCorruptException('unparseable save: ${e.message}');
  }
  if (doc['schema_version'] != saveSchemaVersion) {
    throw SaveCorruptException(
        'unsupported schema_version ${doc['schema_version']} '
        '(migration chain not yet needed at v1)');
  }
  final payload = doc['state'] as Map<String, dynamic>;
  final expected = doc['checksum'] as String;
  final actual = hashHex(fnv1a64(canonicalJson(payload)));
  if (expected != actual) {
    throw SaveCorruptException('checksum mismatch');
  }
  if (doc['balance_hash'] != balance.contentHash) {
    throw SaveCorruptException(
        'balance hash mismatch: save=${doc['balance_hash']} '
        'current=${balance.contentHash}');
  }
  return GameState.fromJson(payload);
}
