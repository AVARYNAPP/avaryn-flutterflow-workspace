import 'dart:io';

import 'package:test/test.dart';

void main() {
  final contract = File('docs/phase-5-alpha-contract.md').readAsStringSync();
  final traceability =
      File('docs/phase-5-alpha-traceability.md').readAsStringSync();
  final decisions = File('docs/phase-5-decision-record.md').readAsStringSync();

  test('phase 5 contract preserves every permanent security boundary', () {
    for (final boundary in const [
      '`stable_id` blijft de tenantgrens',
      'server-side',
      'RPC-only',
      'Directe client-DML blijft geweigerd',
      'geen last-write-wins',
      'dezelfde request-ID en payload',
      'zonder domeindata',
      'Offline plaintext bestaat alleen in geheugen',
      'Horse- en Riderrechten blijven afzonderlijke domeinen',
      'uitsluitend lokaal provisionable',
      'geen externe projectreferentie',
      'geen secrets',
      'publiceren of deployen niet',
    ]) {
      expect(contract, contains(boundary), reason: 'Missing: $boundary');
    }
  });

  test('every canonical Alpha requirement has one complete matrix row', () {
    final statuses = <String>[
      'gereed en bewezen',
      'aanwezig, onvoldoende getest',
      'aanwezig, functioneel onvolledig',
      'productbeslissing',
      'buiten fase 5',
    ];
    for (var index = 1; index <= 35; index += 1) {
      final id = 'A${index.toString().padLeft(2, '0')}';
      final matches =
          RegExp(
            r'^\| ' + id + r' \|.*$',
            multiLine: true,
          ).allMatches(traceability).toList();
      expect(matches, hasLength(1), reason: '$id must have one row');
      final cells = matches.single.group(0)!.split('|');
      expect(cells, hasLength(9), reason: '$id must have seven data cells');
      expect(
        cells.skip(2).take(5).every((cell) => cell.trim().isNotEmpty),
        isTrue,
        reason: '$id must map UI, backend, proof and acceptance',
      );
      expect(
        statuses.any(cells[7].contains),
        isTrue,
        reason: '$id must use a known status',
      );
    }
  });

  test('traceability uses the complete status vocabulary', () {
    for (final status in const [
      'gereed en bewezen',
      'aanwezig, onvoldoende getest',
      'aanwezig, functioneel onvolledig',
      'productbeslissing',
      'buiten fase 5',
    ]) {
      expect(traceability, contains(status), reason: 'Missing: $status');
    }
  });

  test('personas never become authorization roles', () {
    expect(
      contract,
      contains(
        'Productpersona\'s en autorisatierollen zijn verschillende concepten',
      ),
    );
    for (final role in const ['`owner`', '`admin`', '`member`', '`viewer`']) {
      expect(contract, contains(role));
    }
    expect(
      contract,
      contains('Een persona, naam, e-mailadres, zichtbare knop of clientclaim'),
    );
    expect(contract, contains('verleent nooit\ntoegang.'));
    expect(
      contract,
      contains(
        'Een Horse-relatie is uitsluitend semantisch en verleent nul\n'
        'capabilities.',
      ),
    );
    expect(contract, isNot(contains('membership plus Horse-relatie/grant')));
  });

  test('subphases end at the external deployment gate', () {
    for (final phase in const [
      '| 5A |',
      '| 5B.1 |',
      '| 5B.2 |',
      '| 5B.3 |',
      '| 5B.4 |',
      '| 5B.5 |',
      '| 5B.6 |',
      '| 5B.7 |',
      '| 5B.8 |',
      '| 5C |',
      '| 5D |',
      '| 5E |',
    ]) {
      expect(contract, contains(phase), reason: 'Missing: $phase');
    }
    expect(
      contract,
      contains(
        'Zonder expliciete toestemming worden geen stagingprojecten, '
        'publicaties',
      ),
    );
  });

  test('web offline conflict remains explicit and fail closed', () {
    expect(contract, contains('browser bewust uit'));
    expect(
      contract,
      contains('Browseroffline wordt niet stilzwijgend toegevoegd'),
    );
    expect(traceability, contains('| A20 | browseroffline |'));
    expect(
      traceability,
      contains('beveiligde webopslag vereist nieuw contract'),
    );
    expect(decisions, contains('## Open productbesluit: browseroffline'));
    expect(
      decisions,
      contains('browseroffline niet gebouwd en kan de\noffline-eis'),
    );
  });

  test('decision record makes source priority reproducible', () {
    expect(decisions, contains('AVARYN-P5-2026-07-27'));
    expect(decisions, contains('3fca50764dde5575ed8be8097ba090159b8d4ba4'));
    expect(decisions, contains('0FZW5Yak1yDvRiVOdoui'));
    expect(contract, contains('besluitrecord `AVARYN-P5-2026-07-27`'));
    expect(
      decisions,
      contains(
        'Horse-relaties zijn uitsluitend semantisch en verlenen nul '
        'capabilities.',
      ),
    );
  });
}
