import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String runtime;
  late String edit;
  late String migration;

  setUpAll(() {
    runtime = File('dsl/avaryn_operational_runtime.dart').readAsStringSync();
    edit = File('dsl/edit.dart').readAsStringSync();
    migration =
        File(
          'supabase/migrations/202607280002_phase_5b4_media_alpha.sql',
        ).readAsStringSync();
  });

  test('Phase 5B.4 uses the private Edge and Storage media lifecycle', () {
    for (final action in const ['create', 'finalize', 'download']) {
      expect(runtime, contains("'action': '$action'"));
    }
    expect(runtime, contains(".from('horse-media')"));
    expect(runtime, contains('.uploadBinaryToSignedUrl('));
    expect(runtime, contains("operation: 'archive_media_asset'"));
    expect(runtime, contains(".from('media_links')"));
    expect(runtime, contains(".from('media_assets')"));
    expect(runtime, contains("'list_schedule_executions'"));
    expect(runtime, contains('_showExecutionMedia(item)'));
  });

  test('signed material and media bytes are never durably persisted', () {
    final uploadStart = runtime.indexOf('Future<void> _uploadMediaBytes');
    final uploadEnd = runtime.indexOf(
      'Future<void> _openMediaAsset',
      uploadStart,
    );
    final upload = runtime.substring(uploadStart, uploadEnd);

    expect(upload, contains('phase5B2ResolveDurableRequestRecord('));
    expect(upload, contains("'finalize_request_id': _uuid.v4()"));
    expect(upload, contains("'request_id': record.requestId"));
    expect(upload, contains("'replay_values': record.replayValues"));
    expect(upload, contains('late FunctionResponse created;'));
    expect(upload, contains('on FunctionException catch (error)'));
    expect(upload, contains("createCode == 'MEDIA_UPLOAD_SESSION_CLOSED'"));
    expect(upload, contains('_recoverCompletedMediaUpload(record.requestId)'));
    expect(upload, contains("'MEDIA_UPLOAD_STATUS_UNCERTAIN'"));
    expect(
      upload.indexOf('on FunctionException catch (error)'),
      lessThan(
        upload.indexOf('final createData = _operationalMap(created.data)'),
      ),
    );
    expect(
      upload.indexOf('await _secureStorage.write('),
      lessThan(upload.indexOf("'action': 'create'")),
    );
    for (final forbidden in const [
      "'signed_upload_url':",
      "'signed_download_url':",
      "'upload_token':",
      "'object_path':",
      "'original':",
      "'thumbnail':",
    ]) {
      expect(upload, isNot(contains(forbidden)));
    }
    expect(
      runtime,
      isNot(
        contains("_secureStorage.write(key: storageKey, value: uploadToken)"),
      ),
    );
  });

  test('client thumbnail processing is bounded and format-specific', () {
    final thumbnailStart = runtime.indexOf('Uint8List _buildMediaThumbnail');
    final thumbnailEnd = runtime.indexOf(
      'Future<void> _pickAndUploadMedia',
      thumbnailStart,
    );
    final thumbnail = runtime.substring(thumbnailStart, thumbnailEnd);

    for (final decoder in const ['image.JpegDecoder()', 'image.PngDecoder()']) {
      expect(thumbnail, contains(decoder));
    }
    expect(thumbnail, isNot(contains('image.WebPDecoder()')));
    expect(thumbnail, isNot(contains('image.encodeWebP(')));
    expect(thumbnail, contains('info.numFrames != 1'));
    expect(thumbnail, contains('32 * 1024 * 1024'));
    expect(thumbnail, contains('maxDimension = 512'));
    expect(thumbnail, contains('encoded.length <= 1024 * 1024'));
  });

  test('media grants remain explicit and require an operational reason', () {
    expect(runtime, contains("'horse.media'"));
    expect(runtime, contains('Bekijken en uploaden'));
    expect(runtime, contains('Reden (verplicht voor media)'));
    expect(
      runtime,
      contains("category == 'horse.media' && reason.text.trim().isEmpty"),
    );
    expect(runtime, contains("'p_grant_reason': grant['reason']"));
    expect(migration, contains('private.media_actor_has_capability('));
    expect(migration, contains("'can_manage_media_access'"));
    expect(migration, contains('private.media_upload_session_result('));
    expect(migration, contains("asset.status = 'ready'"));
    expect(migration, contains("then 'ready'"));
    expect(
      migration,
      isNot(contains('insert into public.horse_access_grants')),
    );
  });

  test('Phase 5B.4 remains integrated in the active FlutterFlow edit flow', () {
    expect(edit, contains('buildAvarynPhase5B5,'));
    expect(edit, contains('void buildAvarynPhase5B4(App app)'));
    expect(edit, contains("findPubDependency(project, name: 'image')"));
    expect(edit, contains("version: '^4.8.0'"));
    expect(edit, contains("findPubDependency(project, name: 'json_path')"));
    expect(edit, contains("version: '0.7.2'"));
    expect(runtime, contains('file_picker.FilePicker.pickFiles('));
    expect(runtime, isNot(contains('FilePicker.platform.pickFiles(')));
    expect(runtime, contains('withData: false'));
    expect(runtime, contains('withReadStream: true'));
    expect(runtime, contains('builder.length + chunk.length > maxBytes'));
    expect(runtime, contains('file.size <= 0 || file.size > maxBytes'));
    expect(runtime, contains("uri.scheme != 'https'"));
    expect(
      runtime,
      contains('uri.host.toLowerCase() != _operationalMediaStorageHost'),
    );
    expect(
      runtime,
      contains("uri.path.startsWith('/storage/v1/object/sign/horse-media/')"),
    );
    expect(
      runtime,
      contains("allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf']"),
    );
    expect(edit, contains("name: 'TodayDashboardPage'"));
    expect(edit, isNot(contains("name: 'TodayPage'")));
    expect(edit, contains('_applyPhase4C7OperationalRuntimeResource(app);'));
  });

  test('lost finalize responses resume without issuing new credentials', () {
    final edge =
        File('supabase/functions/media-assets/index.ts').readAsStringSync();
    final integration =
        File(
          'supabase/tests/phase_4c5_media_integration.rb',
        ).readAsStringSync();

    expect(edge, contains("if (session.status === 'ready')"));
    expect(edge, contains('status: session.status'));
    expect(edge, contains('idempotent: true'));
    expect(edge, contains('uploads: []'));
    expect(integration, contains('lost finalize response resumes as success'));
  });
}
