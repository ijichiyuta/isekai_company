import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/entitlements.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/iap_stub.dart';
import 'package:isekai_app/game/save_store.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_core/isekai_core.dart';

import 'helpers.dart';

class _FakeIap implements IapClient {
  final bool ok;
  _FakeIap(this.ok);
  @override
  bool get available => true;
  @override
  Future<bool> purchaseFull() async => ok;
  @override
  Future<bool> restore() async => ok;
}

void main() {
  late Balance balance;
  setUpAll(() => balance = loadTestBalanceFull());

  test('canPurchase: free/auto always, full only with the purchase (§8.4)', () {
    final free = balance.unlocks.firstWhere((u) => u.tier == 'free');
    final auto = balance.unlocks.firstWhere((u) => u.tier == 'auto');
    final full = balance.unlocks.firstWhere((u) => u.tier == 'full');
    final autoOrder = balance.unlocks.firstWhere((u) => u.key == 'auto_order');

    final locked = Entitlements(isFull: false);
    expect(locked.canPurchase(free), isTrue);
    expect(locked.canPurchase(auto), isTrue);
    expect(locked.canPurchase(autoOrder), isTrue); // #16 is free — never gated
    expect(locked.canPurchase(full), isFalse);

    final unlocked = Entitlements(isFull: true);
    expect(unlocked.canPurchase(full), isTrue);
  });

  test('UnlockSummary is derived from balance, not hardcoded (AC-16)', () {
    final meta = MetaState.initial()..ensureUnlockSlots(balance.unlocks.length);
    final reader = MetaView(meta, balance.unlocks);
    final s = UnlockSummary.compute(reader);
    expect(s.total, balance.unlocks.length); // 24, from balance
    expect(s.owned, 0);
    // Only FUNCTIONAL (shipped) nodes count as buyable — feature-gated nodes
    // are excluded so the paywall doesn't overstate its value (景表法).
    final funcFull = balance.unlocks
        .where((u) => u.tier == 'full' && isUnlockFunctional(u))
        .length;
    final funcOther = balance.unlocks
        .where((u) => u.tier != 'full' && isUnlockFunctional(u))
        .length;
    expect(s.fullLocked, funcFull);
    expect(s.freeReachable, funcOther);
    expect(s.unlockedByFull, s.fullLocked);
    // Guard: the buyable-full count is the functional subset, not all full.
    expect(
      s.fullLocked,
      lessThan(balance.unlocks.where((u) => u.tier == 'full').length),
    );

    // A smaller tree yields smaller counts — proves it's not a constant.
    final tiny = Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1,
        'start_funds': 100,
        'lifespan_weeks': 10,
        'bankruptcy_grace_weeks': 4,
        'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250,
        'fame_per_sales_g': 100,
        'wage_lv1': 8,
        'hire_cost': 20,
        'artisan_output_per_week': 3,
        'base_capacity_per_week': 2,
        'base_demand_x100': 300,
        'demand_per_fame_x100': 4,
        'rank_up_fame_bonus': 50,
        'max_employees': 30,
      },
      materialsJson: {
        'schema_version': 1,
        'materials': [
          {'id': 0, 'name': 'w', 'cost': 2},
        ],
      },
      recipesJson: {
        'schema_version': 1,
        'methods': ['h'],
        'recipes': [
          {
            'id': 0,
            'name': 'b',
            'mat_a': 0,
            'mat_b': 0,
            'method': 'h',
            'base_price': 7,
            'invention': false,
            'band': 1,
          },
        ],
      },
      ranksJson: {
        'schema_version': 1,
        'ranks': [
          {
            'id': 0,
            'name': 'r',
            'min_assets': 0,
            'min_fame': 0,
            'min_recipes': 0,
            'min_employees': 0,
            'weekly_fixed_cost': 0,
            'tax_bp': 0,
            'enabled': true,
          },
        ],
      },
      unlocksJson: {
        'schema_version': 1,
        'unlocks': [
          {
            'id': 0,
            'key': 'a',
            'name': 'A',
            'desc': '',
            'cost': 100,
            'tier': 'free',
            'requires': [],
            'mod_type': 'start_funds',
            'mod_value': 1,
            'infinite': false,
          },
          {
            'id': 1,
            'key': 'b',
            'name': 'B',
            'desc': '',
            'cost': 100,
            'tier': 'full',
            'requires': [],
            'mod_type': 'start_funds',
            'mod_value': 1,
            'infinite': false,
          },
        ],
      },
    );
    final ts = UnlockSummary.compute(
      MetaView(MetaState.initial(), tiny.unlocks),
    );
    expect(ts.total, 2);
    expect(ts.fullLocked, 1);
  });

  test('purchaseUnlock gates full-tier nodes behind 完全版', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    g.meta.soulPoints = 9000;
    final full = balance.unlocks.firstWhere(
      (u) => u.tier == 'full' && u.requires.isEmpty && isUnlockFunctional(u),
    );
    final freeFn = balance.unlocks.firstWhere(
      (u) => u.tier == 'free' && isUnlockFunctional(u),
    );
    // #16 auto_order is FREE (not paywalled) but feature-gated (effect not
    // shipped) — canPurchase true, but purchaseUnlock refuses the no-op.
    final autoOrder = balance.unlocks.firstWhere((u) => u.key == 'auto_order');

    expect(g.isFull, isFalse);
    expect(g.purchaseUnlock(full.id), isFalse); // blocked by paywall
    expect(g.purchaseUnlock(freeFn.id), isTrue); // free + functional → allowed
    expect(Entitlements().canPurchase(autoOrder), isTrue); // not paywalled…
    expect(g.purchaseUnlock(autoOrder.id), isFalse); // …but feature-gated
  });

  test(
    'purchaseFull flips the entitlement; then full nodes are buyable',
    () async {
      final g = GameController(
        balance: balance,
        clock: FakeTickClock(),
        seed: 1,
        iap: _FakeIap(true),
      );
      g.meta.soulPoints = 9000;
      final full = balance.unlocks.firstWhere(
        (u) => u.tier == 'full' && u.requires.isEmpty && isUnlockFunctional(u),
      );

      expect(await g.purchaseFull(), isTrue);
      expect(g.isFull, isTrue);
      expect(g.purchaseUnlock(full.id), isTrue); // now allowed
    },
  );

  test(
    'StubIapClient: debug succeeds; release gated by kReleaseMode (ADR-0003)',
    () async {
      final stub = StubIapClient();
      // In tests kReleaseMode is false → the dev flow works.
      expect(stub.available, isTrue);
      expect(await stub.purchaseFull(), isTrue);
      expect(await stub.restore(), isFalse); // stub has nothing to restore
      // In a release AOT build every StubIapClient method folds to false; the
      // only writers of isFull are purchaseFull/restore, so a release build can
      // never grant 完全版 for free (see ADR-0003).
    },
  );

  test('a failed purchase leaves the player un-entitled', () async {
    final g = GameController(
      balance: balance,
      clock: FakeTickClock(),
      seed: 1,
      iap: _FakeIap(false),
    );
    expect(await g.purchaseFull(), isFalse);
    expect(g.isFull, isFalse);
  });

  test('restorePurchases restores a prior 完全版 (App Store 3.1.1)', () async {
    final g = GameController(
      balance: balance,
      clock: FakeTickClock(),
      seed: 1,
      iap: _FakeIap(true),
    );
    expect(await g.restorePurchases(), isTrue);
    expect(g.isFull, isTrue);
  });

  test(
    'entitlements persist in a separate file that survives a balance change',
    () async {
      final tmp = Directory.systemTemp.createTempSync('isekai_ent');
      addTearDown(() => tmp.deleteSync(recursive: true));
      // Save the purchase under the real balance.
      await SaveStore(
        balance,
        tmp,
      ).saveEntitlements(Entitlements(isFull: true));

      // A DIFFERENT balance (economy tweak → different content hash) still reads
      // the purchase — it isn't gated by balance_hash (audit High-2).
      final other = loadTestBalance(); // events-less → different hash
      expect(other.contentHash, isNot(balance.contentHash));
      final restored = await SaveStore(other, tmp).loadEntitlements();
      expect(restored.isFull, isTrue);
    },
  );
}
