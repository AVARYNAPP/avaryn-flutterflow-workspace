List<Map<String, dynamic>> phase4C7MarkPendingItems(
  List<Map<String, dynamic>> schedule,
  List<Map<String, dynamic>> queued,
) {
  final pendingIds =
      queued
          .map((mutation) => mutation['schedule_item_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
  return schedule
      .map(
        (item) =>
            pendingIds.contains(item['schedule_item_id']?.toString() ?? '')
                ? {...item, 'state': 'pending_sync'}
                : Map<String, dynamic>.from(item),
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> phase4C7QueueOnce(
  List<Map<String, dynamic>> queued,
  Map<String, dynamic> mutation,
) {
  final itemId = mutation['schedule_item_id']?.toString() ?? '';
  if (itemId.isEmpty) {
    throw ArgumentError('schedule_item_id is required');
  }
  if (queued.any(
    (candidate) => candidate['schedule_item_id']?.toString() == itemId,
  )) {
    return List<Map<String, dynamic>>.from(queued);
  }
  return [...queued, Map<String, dynamic>.from(mutation)];
}

List<Map<String, dynamic>> phase4C7RemoveProcessedMutation(
  List<Map<String, dynamic>> queued,
  Map<String, dynamic> processed,
) {
  final requestId = processed['request_id']?.toString() ?? '';
  return queued
      .where((candidate) => candidate['request_id']?.toString() != requestId)
      .map(Map<String, dynamic>.from)
      .toList(growable: true);
}

Set<String> phase4C7SecureKeysForAccount(
  Iterable<String> keys,
  String authUserId,
) {
  final normalized = authUserId.trim();
  if (normalized.isEmpty) return const <String>{};
  final prefix = 'avaryn.4c7.$normalized.';
  return keys.where((key) => key.startsWith(prefix)).toSet();
}

bool phase4C7DaysetMetadataMatches({
  required Map<String, dynamic> envelope,
  required Map<String, dynamic> plaintext,
  required String stableId,
  required String timezone,
  required int authorityVersion,
  required DateTime nowUtc,
}) {
  DateTime? parsed(Object? value) =>
      value is DateTime
          ? value
          : value is String
          ? DateTime.tryParse(value)
          : null;

  final outerExpiry = parsed(envelope['expires_at']);
  final innerExpiry = parsed(plaintext['expires_at']);
  final outerAuthority = int.tryParse(
    envelope['authority_version']?.toString() ?? '',
  );
  final innerAuthority = int.tryParse(
    plaintext['authority_version']?.toString() ?? '',
  );
  return plaintext['stable_id']?.toString() == stableId &&
      plaintext['timezone']?.toString() == timezone &&
      innerAuthority == authorityVersion &&
      outerAuthority == authorityVersion &&
      outerAuthority == innerAuthority &&
      outerExpiry != null &&
      innerExpiry != null &&
      innerExpiry.isAfter(nowUtc) &&
      innerExpiry.toUtc() == outerExpiry.toUtc();
}

final class Phase4C7RequestLedger {
  final Map<String, Map<String, dynamic>> _pending = {};
  String _scope = '';

  void bindScope(String authUserId, String stableId) {
    final nextScope = '${authUserId.trim()}:${stableId.trim()}';
    if (authUserId.trim().isEmpty || stableId.trim().isEmpty) {
      throw ArgumentError('An auth user and stable are required');
    }
    if (_scope == nextScope) return;
    _pending.clear();
    _scope = nextScope;
  }

  Map<String, dynamic> acquire(
    String operation,
    String intentKey,
    Map<String, dynamic> Function() create,
  ) {
    if (_scope.isEmpty) {
      throw StateError('Bind the request ledger to an auth/stable scope first');
    }
    final key = '$_scope:$operation:$intentKey';
    return _pending.putIfAbsent(key, () => Map<String, dynamic>.from(create()));
  }

  void complete(String operation, String intentKey) {
    _pending.remove('$_scope:$operation:$intentKey');
  }

  void clear() => _pending.clear();

  void reset() {
    _pending.clear();
    _scope = '';
  }

  int get length => _pending.length;
}
