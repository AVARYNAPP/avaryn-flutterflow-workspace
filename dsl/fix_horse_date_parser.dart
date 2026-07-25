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
      _fixHorseDateParser,
      projectId: projectId,
      dryRun: dryRun,
      commitMessage: commitMessage,
    );
  } catch (error) {
    stderr.writeln('Error: ${formatFlutterFlowAIError(error)}');
    exit(1);
  }
}

void _fixHorseDateParser(App app) {
  app.raw((project) {
    updateCustomFunction(
      project,
      name: 'parseHorsePrototypeDate',
      code: r'''
if (value == null || value.isEmpty) return null;
return DateTime.tryParse(value);
''',
      description: 'Parses ISO sample dates for local prototype horses.',
    );
  });
}
