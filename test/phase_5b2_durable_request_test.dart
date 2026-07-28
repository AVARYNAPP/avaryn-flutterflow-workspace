import 'dart:convert';

import 'package:test/test.dart';

import '../dsl/phase_4c7_runtime_contract.dart';

void main() {
  test('fresh runtime replays the same UUID and date after midnight', () {
    const firstRequestId = 'b5240000-0000-4000-8000-000000000001';
    final firstRuntime = phase5B2ResolveDurableRequestRecord(
      null,
      () => firstRequestId,
      const {'valid_from': '2026-07-28'},
    );
    final persisted = <String, dynamic>{
      'request_id': firstRuntime.requestId,
      'replay_values': firstRuntime.replayValues,
    };
    final freshRuntime = phase5B2ResolveDurableRequestRecord(
      persisted,
      () => 'b5240000-0000-4000-8000-000000000002',
      const {'valid_from': '2026-07-29'},
    );

    expect(firstRuntime.requestId, firstRequestId);
    expect(freshRuntime.requestId, firstRequestId);
    expect(freshRuntime.replayValues, {'valid_from': '2026-07-28'});

    Map<String, dynamic> relationshipParams(
      Phase5B2DurableRequestRecord record,
    ) => {
      'p_horse_id': '00000000-0000-4000-8000-000000000010',
      'p_stable_member_id': '00000000-0000-4000-8000-000000000020',
      'p_relationship_type': 'rider',
      'p_request_id': record.requestId,
      'p_valid_from': record.replayValues['valid_from'],
      'p_label': 'Alpha fixture',
    };

    expect(
      jsonEncode(relationshipParams(freshRuntime)),
      jsonEncode(relationshipParams(firstRuntime)),
    );
  });

  test('relationship end replays byte-equivalent params after midnight', () {
    const requestId = 'b5240000-0000-4000-8000-000000000003';
    final firstRuntime = phase5B2ResolveDurableRequestRecord(
      null,
      () => requestId,
      const {'valid_until': '2026-07-28'},
    );
    final freshRuntime = phase5B2ResolveDurableRequestRecord(
      {
        'request_id': firstRuntime.requestId,
        'replay_values': firstRuntime.replayValues,
      },
      () => 'b5240000-0000-4000-8000-000000000004',
      const {'valid_until': '2026-07-29'},
    );

    Map<String, dynamic> relationshipParams(
      Phase5B2DurableRequestRecord record,
    ) => {
      'p_relationship_id': '00000000-0000-4000-8000-000000000030',
      'p_expected_row_version': 7,
      'p_request_id': record.requestId,
      'p_valid_until': record.replayValues['valid_until'],
    };

    expect(
      jsonEncode(relationshipParams(freshRuntime)),
      jsonEncode(relationshipParams(firstRuntime)),
    );
  });

  test('only null secure storage means no durable record exists', () {
    expect(phase5B2DurableStorageIsAbsent(null), isTrue);
    expect(phase5B2DurableStorageIsAbsent(''), isFalse);
    expect(phase5B2DurableStorageIsAbsent('not-json'), isFalse);
  });

  test('invalid persisted data cannot become an RPC request ID', () {
    expect(
      () => phase5B2ResolveDurableRequestRecord(
        const {'request_id': 'not-a-uuid', 'replay_values': <String, String>{}},
        () => 'also-invalid',
        const {},
      ),
      throwsStateError,
    );
    expect(
      () => phase5B2ResolveDurableRequestRecord(
        const {
          'request_id': 'b5240000-0000-4000-8000-000000000005',
          'replay_values': <String, String>{},
        },
        () => 'b5240000-0000-4000-8000-000000000006',
        const {'valid_until': '2026-07-29'},
      ),
      throwsStateError,
    );
  });
}
