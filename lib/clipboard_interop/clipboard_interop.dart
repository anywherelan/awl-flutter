import 'clipboard_io.dart' if (dart.library.js_interop) 'clipboard_web.dart';

/// Puts [text] on the system clipboard.
///
/// Wraps `Clipboard.setData` everywhere except the web, where it throws over
/// plain HTTP: the engine's only strategy is `navigator.clipboard`, which
/// browsers expose in a secure context alone, and `http://admin.awl` is not
/// one. The web branch keeps that path and falls back to `execCommand`, which
/// carries no such requirement.
///
/// Throws if the copy did not happen, which callers must handle: a copy button
/// that reports success it didn't have sends the user off to paste an empty
/// clipboard.
Future<void> copyText(String text) async {
  return copyTextImpl(text);
}
