import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

/// What a text file handed to [exportTextFile] is: its extension and the two
/// spellings of its type the platforms ask for.
enum ExportFormat {
  text('txt', 'text/plain', MimeType.text),
  json('json', 'application/json', MimeType.json);

  final String extension;
  final String mimeType;
  final MimeType saverType;

  const ExportFormat(this.extension, this.mimeType, this.saverType);
}

/// Gets [text] out of the app as a file called `<name>.<extension>`.
typedef TextFileExporter = Future<void> Function(String name, String text, ExportFormat format);

/// A browser downloads the file; anywhere else it goes to the system share
/// sheet, which on a phone is the short way to wherever it is being sent.
const bool exportIsDownload = kIsWeb;

/// The default [TextFileExporter]. Throws when the platform refuses.
Future<void> exportTextFile(String name, String text, ExportFormat format) async {
  final bytes = utf8.encode(text);
  if (exportIsDownload) {
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: format.extension,
      mimeType: format.saverType,
    );
    return;
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: format.mimeType)],
      // A file made from bytes has no name of its own.
      fileNameOverrides: ['$name.${format.extension}'],
    ),
  );
}

/// `awl-logs-v0.18.0-20261013-0927`: what it is, which version wrote it, and
/// when it was taken, in local time. The version is in the name because the
/// log itself has usually lost it: the buffer is a ring, and the startup lines
/// are the first to go.
String diagnosticsFileName(String kind, {String? version, required DateTime now}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final at = now.toLocal();
  final stamp = '${at.year}${two(at.month)}${two(at.day)}-${two(at.hour)}${two(at.minute)}';
  final safeVersion = (version ?? '').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
  return ['awl', kind, if (safeVersion.isNotEmpty) safeVersion, stamp].join('-');
}
