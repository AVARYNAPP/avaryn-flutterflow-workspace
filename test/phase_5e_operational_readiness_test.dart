import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String protocol;
  late String operations;
  late String deployment;
  late String bugTemplate;
  late String incidentTemplate;
  late String sessionTemplate;
  late String runner;

  setUpAll(() {
    protocol = File('docs/phase-5e-alpha-test-protocol.md').readAsStringSync();
    operations = File('docs/phase-5e-operations-runbook.md').readAsStringSync();
    deployment = File('docs/phase-5e-deployment-gate.md').readAsStringSync();
    bugTemplate =
        File('docs/templates/phase-5-alpha-bug-report.md').readAsStringSync();
    incidentTemplate =
        File(
          'docs/templates/phase-5-alpha-incident-record.md',
        ).readAsStringSync();
    sessionTemplate =
        File('docs/templates/phase-5-alpha-test-session.md').readAsStringSync();
    runner = File('tool/test_phase_5e_local.sh').readAsStringSync();
  });

  test('protocol covers roles scenarios viewports and complete regression', () {
    for (final required in [
      'Persona\'s zijn alleen scenario-aanduidingen',
      'TP-01',
      'TP-15',
      '390 × 844',
      '820 × 1180',
      '1440 × 900',
      'tool/test_phase_5d3_local.sh --confirm-local-reset',
      'geen open P0, P1 of P2',
      'online-only',
    ]) {
      expect(protocol, contains(required), reason: required);
    }
  });

  test('operations are local-first and fail closed on security incidents', () {
    for (final required in [
      'ACCOUNT_DELETED',
      'ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW',
      'Auth-UUID',
      'authorityrotatie',
      'service-role',
      'Securitymigraties worden niet teruggedraaid',
      'geen echte testers uitgenodigd',
      'privacyverklaring',
      'retentiebeleid',
    ]) {
      expect(operations, contains(required), reason: required);
    }
    expect(operations, isNot(contains('service-role key:')));
  });

  test(
    'deployment gate remains non-authorizing and has rollback and costs',
    () {
      for (final required in [
        'Externe status: NIET GEAUTORISEERD',
        'één nieuw, uitsluitend staging Supabase-project',
        'flutterflow.app',
        'Supabase staging',
        'Pro vanaf \$25/maand',
        'FlutterFlow Basic staat vanaf \$39/maand',
        'FF_API_KEY',
        'Rollbackplan',
        'NO-GO',
        'Vóór echte testers',
      ]) {
        expect(deployment, contains(required), reason: required);
      }
      expect(deployment, isNot(contains('SUPABASE_SERVICE_ROLE_KEY=')));
    },
  );

  test('templates require redaction traceability and negative evidence', () {
    for (final template in [bugTemplate, incidentTemplate, sessionTemplate]) {
      expect(template, isNot(contains('example@example.com')));
      expect(template, isNot(contains('Bearer eyJ')));
    }
    expect(bugTemplate, contains('Negatieve tegenproef'));
    expect(bugTemplate, contains('Andere account-, stal- of Horse-data'));
    expect(incidentTemplate, contains('Containment'));
    expect(incidentTemplate, contains('Onafhankelijke heraudit'));
    expect(sessionTemplate, contains('TP-15'));
    expect(sessionTemplate, contains('GO / NO-GO'));
  });

  test('local gate cannot execute deployment commands', () {
    expect(runner, contains('required_documents'));
    expect(runner, contains('sh -n'));
    expect(runner, contains('flutterflow_ai.dart test'));
    expect(
      runner,
      contains('executable tooling contains an external deployment command'),
    );
    expect(runner, isNot(contains('supabase db push --linked')));
    expect(runner, isNot(contains('flutterflow deploy')));
  });
}
