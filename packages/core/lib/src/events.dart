/// Event definitions (requirements §3.7). Loaded from events.json. Effects are
/// integer-only and applied through the engine so determinism holds (§2.2).
/// Any parse failure normalizes to [EventsException] (no raw TypeError).
library;

class EventsException implements Exception {
  final String message;
  EventsException(this.message);
  @override
  String toString() => 'EventsException: $message';
}

/// One effect of a choice. `type` selects the field; `value`/`refId` its args.
class EventEffect {
  final String type; // funds|fame|grant_recipe|material|product|royal_flag
  final int value;
  final int refId; // material/product/recipe id, else -1
  const EventEffect(this.type, this.value, this.refId);
}

class EventChoice {
  final String label;
  final List<EventEffect> effects;
  const EventChoice(this.label, this.effects);
}

class EventDef {
  final int id;
  final String kind;
  final String title;
  final String body;
  final int minLife; // fires only from this life number (周回専用 = 2)
  final int minFame;
  final int maxFame;
  final int weight;
  final bool forcedFameReached; // royal: forced-fire at fame >= forcedValue
  final int forcedValue;
  final List<EventChoice> choices;
  const EventDef({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.minLife,
    required this.minFame,
    required this.maxFame,
    required this.weight,
    required this.forcedFameReached,
    required this.forcedValue,
    required this.choices,
  });
}

const _kinds = {
  'kingdom',
  'disaster',
  'opportunity',
  'character',
  'hero',
  'reincarnator',
  'cycle',
};
const _effectTypes = {
  'funds',
  'fame',
  'grant_recipe',
  'material',
  'product',
  'royal_flag',
};

int _reqInt(Map m, String k) {
  final v = m[k];
  if (v is! int) throw EventsException('"$k" must be int, got $v');
  return v;
}

String _reqStr(Map m, String k) {
  final v = m[k];
  if (v is! String) throw EventsException('"$k" must be string, got $v');
  return v;
}

/// Parses events.json into a validated list. Empty/absent → [].
List<EventDef> parseEvents(Map<String, dynamic>? json) {
  if (json == null) return const [];
  try {
    if (json['schema_version'] != 1) {
      throw EventsException('events.json: unsupported schema_version');
    }
    final raw = json['events'];
    if (raw is! List) {
      throw EventsException('events.json: "events" must be a list');
    }
    final out = <EventDef>[];
    for (final e in raw) {
      if (e is! Map) throw EventsException('events.json: entry not an object');
      final kind = _reqStr(e, 'kind');
      if (!_kinds.contains(kind)) {
        throw EventsException('events.json: unknown kind "$kind"');
      }
      final choicesRaw = e['choices'];
      if (choicesRaw is! List || choicesRaw.isEmpty) {
        throw EventsException('events.json: choices must be a non-empty list');
      }
      final choices = <EventChoice>[];
      for (final c in choicesRaw) {
        if (c is! Map) throw EventsException('events.json: choice not object');
        final effRaw = c['effects'];
        if (effRaw is! List) {
          throw EventsException('events.json: effects must be a list');
        }
        final effects = <EventEffect>[];
        for (final ef in effRaw) {
          if (ef is! Map) throw EventsException('events.json: effect not object');
          final t = _reqStr(ef, 'type');
          if (!_effectTypes.contains(t)) {
            throw EventsException('events.json: unknown effect type "$t"');
          }
          final refId = ef.containsKey('id') ? _reqInt(ef, 'id') : -1;
          final value = ef.containsKey('value') ? _reqInt(ef, 'value') : 0;
          effects.add(EventEffect(t, value, refId));
        }
        choices.add(EventChoice(_reqStr(c, 'label'), effects));
      }
      final forced = e['forced'];
      var forcedFame = false;
      var forcedValue = 0;
      if (forced is Map) {
        if (_reqStr(forced, 'type') != 'fame_reached') {
          throw EventsException('events.json: unknown forced type');
        }
        forcedFame = true;
        forcedValue = _reqInt(forced, 'value');
      }
      final weight = e.containsKey('weight') ? _reqInt(e, 'weight') : 100;
      if (weight <= 0) throw EventsException('events.json: weight must be > 0');
      out.add(EventDef(
        id: _reqInt(e, 'id'),
        kind: kind,
        title: _reqStr(e, 'title'),
        body: _reqStr(e, 'body'),
        minLife: e.containsKey('min_life') ? _reqInt(e, 'min_life') : 1,
        minFame: e.containsKey('min_fame') ? _reqInt(e, 'min_fame') : 0,
        maxFame: e.containsKey('max_fame')
            ? _reqInt(e, 'max_fame')
            : 1000000000000000,
        weight: weight,
        forcedFameReached: forcedFame,
        forcedValue: forcedValue,
        choices: choices,
      ));
    }
    for (var i = 0; i < out.length; i++) {
      if (out[i].id != i) {
        throw EventsException('events.json: ids must be sequential');
      }
    }
    return out;
  } on EventsException {
    rethrow;
  } catch (e) {
    throw EventsException('malformed events.json: $e');
  }
}
