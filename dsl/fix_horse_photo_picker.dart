library;

import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';

Future<void> main(List<String> args) async {
  String? projectId;
  String? commitMessage;
  var dryRun = false;
  for (var index = 0; index < args.length; index++) {
    switch (args[index]) {
      case '--project-id':
        projectId = args[++index];
      case '--commit-message':
        commitMessage = args[++index];
      case '--dry-run':
        dryRun = true;
    }
  }
  try {
    await flutterFlowAI(
      _fixHorsePhotoPicker,
      projectId: projectId,
      dryRun: dryRun,
      commitMessage: commitMessage,
    );
  } catch (error) {
    stderr.writeln('Error: ${formatFlutterFlowAIError(error)}');
    exit(1);
  }
}

void _fixHorsePhotoPicker(App app) {
  app.raw((project) {
    updateCustomAction(
      project,
      name: 'pickHorsePrototypePhoto',
      code: r'''
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<String> pickHorsePrototypePhoto() async {
  final result = await FilePicker.pickFiles(
    type: FileType.image,
    allowMultiple: false,
    withData: true,
  );
  if (result == null || result.files.isEmpty) {
    return '';
  }
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    return '';
  }
  final extension = (file.extension ?? '').toLowerCase();
  final mimeType = switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}
''',
      description:
          'Selects a local horse photo and returns a persistent data URL.',
    );
  });
}
