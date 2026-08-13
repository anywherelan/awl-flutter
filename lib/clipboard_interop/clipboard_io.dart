import 'package:flutter/services.dart';

/// The default branch, and a real implementation rather than a stub: this is a
/// framework call with no `dart:io` in it, so it serves Android, iOS and
/// desktop alike.
Future<void> copyTextImpl(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
