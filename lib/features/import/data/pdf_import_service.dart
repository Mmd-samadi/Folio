import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class PickedPdf {
  const PickedPdf({
    required this.originalName,
    required this.localPath,
    required this.bytes,
  });

  final String originalName;
  final String localPath;
  final Uint8List bytes;
}

class PdfImportService {
  /// Opens the system picker, copies the PDF into app documents, returns paths.
  Future<PickedPdf?> pickAndStore() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (file == null) return null;

    final name = file.name.endsWith('.pdf') ? file.name : '${file.name}.pdf';
    final bytes = await file.readAsBytes();

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/pdfs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safeName =
        '${DateTime.now().millisecondsSinceEpoch}_$name'.replaceAll(' ', '_');
    final localPath = '${dir.path}/$safeName';
    await File(localPath).writeAsBytes(bytes, flush: true);

    return PickedPdf(
      originalName: name,
      localPath: localPath,
      bytes: bytes,
    );
  }
}
