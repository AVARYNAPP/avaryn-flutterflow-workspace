import 'package:test/test.dart';

import '../dsl/phase_4c7_runtime_contract.dart';

void main() {
  test('restart restores pending markers and never queues an item twice', () {
    final queued = [
      {'schedule_item_id': 'item-a', 'request_id': 'request-original'},
    ];
    final deduplicated = phase4C7QueueOnce(queued, {
      'schedule_item_id': 'item-a',
      'request_id': 'request-retry',
    });
    final marked = phase4C7MarkPendingItems([
      {'schedule_item_id': 'item-a', 'state': 'planned'},
      {'schedule_item_id': 'item-b', 'state': 'planned'},
    ], deduplicated);

    expect(deduplicated, hasLength(1));
    expect(deduplicated.single['request_id'], 'request-original');
    expect(marked.first['state'], 'pending_sync');
    expect(marked.last['state'], 'planned');
  });

  test('partial flush removes only the confirmed request', () {
    final queued = [
      {'schedule_item_id': 'item-a', 'request_id': 'request-a'},
      {'schedule_item_id': 'item-b', 'request_id': 'request-b'},
      {'schedule_item_id': 'item-c', 'request_id': 'request-c'},
    ];

    final remaining = phase4C7RemoveProcessedMutation(queued, queued[1]);

    expect(remaining.map((item) => item['request_id']), [
      'request-a',
      'request-c',
    ]);
  });

  test('secure purge keys are isolated by immutable auth UUID', () {
    final keys = phase4C7SecureKeysForAccount(const [
      'avaryn.4c7.user-a.stable-a.dayset',
      'avaryn.4c7.user-a.stable-b.private_key',
      'avaryn.4c7.user-b.stable-a.dayset',
      'unrelated.secure.key',
    ], 'user-a');

    expect(keys, {
      'avaryn.4c7.user-a.stable-a.dayset',
      'avaryn.4c7.user-a.stable-b.private_key',
    });
  });

  test('dayset accepts only matching authenticated inner metadata', () {
    final now = DateTime.utc(2026, 7, 27, 10);
    final expiry = now.add(const Duration(hours: 2));
    final envelope = {
      'authority_version': 7,
      'local_date': '2026-07-27',
      'expires_at': expiry.toIso8601String(),
    };
    final plaintext = {
      'stable_id': 'stable-a',
      'timezone': 'Europe/Amsterdam',
      'local_date': '2026-07-27',
      'authority_version': 7,
      'expires_at': expiry.toIso8601String(),
    };

    expect(
      phase4C7DaysetMetadataMatches(
        envelope: envelope,
        plaintext: plaintext,
        stableId: 'stable-a',
        timezone: 'Europe/Amsterdam',
        localDate: '2026-07-27',
        authorityVersion: 7,
        nowUtc: now,
      ),
      isTrue,
    );
    expect(
      phase4C7DaysetMetadataMatches(
        envelope: {...envelope, 'authority_version': 8},
        plaintext: {...plaintext, 'authority_version': 8},
        stableId: 'stable-a',
        timezone: 'Europe/Amsterdam',
        localDate: '2026-07-27',
        authorityVersion: 7,
        nowUtc: now,
      ),
      isFalse,
    );
    expect(
      phase4C7DaysetMetadataMatches(
        envelope: {...envelope, 'authority_version': 8},
        plaintext: plaintext,
        stableId: 'stable-a',
        timezone: 'Europe/Amsterdam',
        localDate: '2026-07-27',
        authorityVersion: 7,
        nowUtc: now,
      ),
      isFalse,
    );
    expect(
      phase4C7DaysetMetadataMatches(
        envelope: envelope,
        plaintext: {
          ...plaintext,
          'expires_at':
              expiry.add(const Duration(minutes: 1)).toIso8601String(),
        },
        stableId: 'stable-a',
        timezone: 'Europe/Amsterdam',
        localDate: '2026-07-27',
        authorityVersion: 7,
        nowUtc: now,
      ),
      isFalse,
    );
    expect(
      phase4C7DaysetMetadataMatches(
        envelope: envelope,
        plaintext: plaintext,
        stableId: 'stable-a',
        timezone: 'Europe/Amsterdam',
        localDate: '2026-07-28',
        authorityVersion: 7,
        nowUtc: now,
      ),
      isFalse,
    );
    expect(
      phase4C7DaysetMetadataMatches(
        envelope: {...envelope, 'local_date': '2026-07-28'},
        plaintext: plaintext,
        stableId: 'stable-a',
        timezone: 'Europe/Amsterdam',
        localDate: '2026-07-27',
        authorityVersion: 7,
        nowUtc: now,
      ),
      isFalse,
    );
  });

  test(
    'ambiguous retry reuses exact request payload until definitive result',
    () {
      final ledger = Phase4C7RequestLedger();
      ledger.bindScope('user-a', 'stable-a');
      var generated = 0;
      Map<String, dynamic> create() => {
        'p_request_id': 'request-${++generated}',
        'p_title': 'Hooi klaarzetten',
        'p_recorded_at': '2026-07-27T10:00:00Z',
      };

      final first = ledger.acquire(
        'create_schedule_item',
        'horse-a:task',
        create,
      );
      final retry = ledger.acquire(
        'create_schedule_item',
        'horse-a:task',
        create,
      );

      expect(identical(first, retry), isTrue);
      expect(retry['p_request_id'], 'request-1');
      expect(generated, 1);

      ledger.complete('create_schedule_item', 'horse-a:task');
      final next = ledger.acquire(
        'create_schedule_item',
        'horse-a:task',
        create,
      );
      expect(next['p_request_id'], 'request-2');

      ledger.bindScope('user-a', 'stable-b');
      final otherStable = ledger.acquire(
        'create_schedule_item',
        'horse-a:task',
        create,
      );
      expect(otherStable['p_request_id'], 'request-3');
      expect(ledger.length, 1);

      ledger.bindScope('user-b', 'stable-b');
      final otherAccount = ledger.acquire(
        'create_schedule_item',
        'horse-a:task',
        create,
      );
      expect(otherAccount['p_request_id'], 'request-4');
      expect(ledger.length, 1);
    },
  );
}
