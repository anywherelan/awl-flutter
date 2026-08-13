import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// `navigator.clipboard` is absent outside a secure context, but package:web
/// types it non-nullable because the IDL says it is always there. Reading it
/// through a nullable view is what lets the two cases be told apart.
extension on web.Navigator {
  @JS('clipboard')
  external web.Clipboard? get clipboardOrNull;
}

Future<void> copyTextImpl(String text) async {
  // First, because it is the one that works in a secure context (localhost in
  // development, any HTTPS deployment) and execCommand is deprecated.
  final clipboard = web.window.navigator.clipboardOrNull;
  if (clipboard != null) {
    await clipboard.writeText(text).toDart;
    return;
  }

  // Ported from the Flutter engine's own ExecCommandCopyStrategy (BSD-3),
  // which served this case from 2020 until https://github.com/flutter/flutter/pull/171427 removed it
  // as redundant with the Clipboard API, counting browser versions and not
  // insecure contexts. execCommand needs a user gesture, which a button is.
  final textArea = web.HTMLTextAreaElement();
  // Off-screen and transparent rather than hidden: `display: none` cannot be
  // selected, and selection is what execCommand copies.
  textArea.style
    ..position = 'absolute'
    ..top = '-99999px'
    ..left = '-99999px'
    ..opacity = '0'
    ..color = 'transparent'
    ..backgroundColor = 'transparent'
    ..background = 'transparent';
  web.document.body!.appendChild(textArea);
  textArea.value = text;
  // Without preventScroll the page jumps to the invisible textarea.
  textArea.focus(web.FocusOptions(preventScroll: true));
  textArea.select();
  try {
    if (!web.document.execCommand('copy')) {
      throw StateError('Clipboard copy was refused by the browser');
    }
  } finally {
    textArea.remove();
  }
}
