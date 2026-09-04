import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

Future<void> main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    stderr.writeln('.env file not found.');
    exit(1);
  }

  final apiKey = _readEnvValue(envFile, 'GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
    stderr.writeln('GEMINI_API_KEY is missing or invalid in .env');
    exit(1);
  }

  final model = GenerativeModel(
    model: 'gemini-3.6-flash',
    apiKey: apiKey,
  );

  try {
    final response = await model.generateContent([
      Content.text('Say hello in one word'),
    ]);
    final text = response.text?.trim();

    if (text == null || text.isEmpty) {
      stderr.writeln('Gemini returned an empty response.');
      exit(1);
    }

    stdout.writeln('Gemini API verification succeeded.');
    exit(0);
  } catch (error) {
    stderr.writeln('Gemini API verification failed: $error');
    exit(1);
  }
}

String? _readEnvValue(File file, String key) {
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('$key=')) {
      return line.substring(key.length + 1).trim();
    }
  }
  return null;
}
