/// FNV-1a 64-bit hashing and canonical JSON stringification.
///
/// Used for: state hashes (replay verification), save checksums, and the
/// balance content hash (replay compatibility boundary, requirements §2.2-7).
/// Integer-only. Relies on Dart native 64-bit wrapping arithmetic (VM/AOT).
library;

const int _fnvOffset = 0xcbf29ce484222325;
const int _fnvPrime = 0x100000001b3;

int fnv1a64(String input) {
  var hash = _fnvOffset;
  for (final unit in input.codeUnits) {
    hash ^= unit & 0xFF;
    hash *= _fnvPrime;
    hash ^= unit >>> 8;
    hash *= _fnvPrime;
  }
  return hash;
}

/// Unsigned 16-hex-digit rendering of a 64-bit hash.
String hashHex(int h) =>
    ((h >>> 32) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0') +
    (h & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

/// Deterministic JSON stringification: map keys sorted, no whitespace.
/// Non-ASCII characters are emitted raw (UTF-16 code units are hashed as-is).
String canonicalJson(Object? value) {
  final sb = StringBuffer();
  _write(sb, value);
  return sb.toString();
}

void _write(StringBuffer sb, Object? v) {
  if (v == null) {
    sb.write('null');
  } else if (v is bool || v is int) {
    sb.write(v);
  } else if (v is String) {
    sb.write('"');
    for (final unit in v.codeUnits) {
      if (unit == 0x22) {
        sb.write(r'\"');
      } else if (unit == 0x5C) {
        sb.write(r'\\');
      } else if (unit < 0x20) {
        sb.write(r'\u');
        sb.write(unit.toRadixString(16).padLeft(4, '0'));
      } else {
        sb.writeCharCode(unit);
      }
    }
    sb.write('"');
  } else if (v is List) {
    sb.write('[');
    for (var i = 0; i < v.length; i++) {
      if (i > 0) sb.write(',');
      _write(sb, v[i]);
    }
    sb.write(']');
  } else if (v is Map) {
    final keys = v.keys.map((k) => k as String).toList()..sort();
    sb.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) sb.write(',');
      _write(sb, keys[i]);
      sb.write(':');
      _write(sb, v[keys[i]]);
    }
    sb.write('}');
  } else {
    throw ArgumentError('Unsupported type in canonicalJson: ${v.runtimeType}');
  }
}
