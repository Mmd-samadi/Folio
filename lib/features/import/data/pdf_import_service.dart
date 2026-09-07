import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:nexus_chat/features/books/domain/book.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class PickedPdf {
  const PickedPdf({
    required this.bookId,
    required this.originalName,
    required this.localPath,
    required this.bytes,
    this.coverPath,
  });

  final String bookId;
  final String originalName;
  final String localPath;
  final Uint8List bytes;
  final String? coverPath;

  String get title => Book.titleFromPdfName(originalName);
}

class PdfImportService {
  /// Opens the system picker, stores PDF under `books/{bookId}/`, renders cover.
  Future<PickedPdf?> pickAndStore() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (file == null) return null;

    final name = file.name.endsWith('.pdf') ? file.name : '${file.name}.pdf';
    final bytes = await file.readAsBytes();

    final bookId = DateTime.now().microsecondsSinceEpoch.toString();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/books/$bookId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final localPath = '${dir.path}/original.pdf';
    await File(localPath).writeAsBytes(bytes, flush: true);

    final coverPath = await renderCoverPng(
      localPath,
      coverPathForPdf(localPath),
    );

    return PickedPdf(
      bookId: bookId,
      originalName: name,
      localPath: localPath,
      bytes: bytes,
      coverPath: coverPath,
    );
  }

  /// Preferred cover path next to [sourcePdfPath] (same folder as `cover.png`).
  static String coverPathForPdf(String sourcePdfPath) {
    final dir = File(sourcePdfPath).parent.path;
    return '$dir/cover.png';
  }

  /// Deletes `app_docs/books/{bookId}/` if present.
  static Future<void> deleteBookFolder(String bookId) async {
    if (bookId.isEmpty) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/books/$bookId');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; metadata is already removed.
    }
  }

  /// Renders page 1 of [pdfPath] to [outPath]. Returns path on success, else null.
  static Future<String?> renderCoverPng(String pdfPath, String outPath) async {
    PdfDocument? doc;
    PdfImage? rendered;
    ui.Image? uiImage;
    try {
      doc = await PdfDocument.openFile(pdfPath);
      if (doc.pages.isEmpty) return null;
      final page = doc.pages.first;
      const fullWidth = 480.0;
      final fullHeight =
          page.height <= 0 ? fullWidth * 1.4 : fullWidth * (page.height / page.width);
      rendered = await page.render(
        fullWidth: fullWidth,
        fullHeight: fullHeight,
      );
      if (rendered == null) return null;

      final pixels = Uint8List.fromList(rendered.pixels);
      final width = rendered.width;
      final height = rendered.height;
      rendered.dispose();
      rendered = null;

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        pixels,
        width,
        height,
        ui.PixelFormat.bgra8888,
        completer.complete,
      );
      uiImage = await completer.future;
      final byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      await File(outPath).writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        flush: true,
      );
      return outPath;
    } catch (_) {
      return null;
    } finally {
      rendered?.dispose();
      uiImage?.dispose();
      await doc?.dispose();
    }
  }
}
