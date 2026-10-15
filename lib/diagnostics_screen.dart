import 'dart:convert';

import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/file_export.dart';
import 'package:anywherelan/json_widget/json_widget.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiagnosticsScreen extends ConsumerWidget {
  static String routeName = "/diagnostics";

  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      selected: AppSection.diagnostics,
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Debug info'),
            subtitle: const Text('Runtime state snapshot: p2p info, DHT, connections'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(DebugScreen.routeName),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Server logs'),
            subtitle: const Text('Backend stdout and stderr'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(LogsScreen.routeName),
          ),
        ],
      ),
    );
  }
}

/// Asks before a diagnostics file leaves the app, and says what is in it:
/// nothing in these files is anonymised. Titled and confirmed with [action],
/// the name of the button that opened it.
Future<bool> showExportDiagnosticsDialog(BuildContext context, String action, String contents) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(action),
      content: Text(contents),
      // Nothing is destroyed, so neither button takes the error colour.
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The app bar button both diagnostics screens export through. [onPressed] is
/// null while there is nothing to export yet.
class _ExportButton extends StatelessWidget {
  final String action;
  final VoidCallback? onPressed;

  const _ExportButton({required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(exportIsDownload ? Icons.download : Icons.share),
      tooltip: action,
      onPressed: onPressed,
    );
  }
}

/// "Share logs" on a phone, "Download logs" in a browser.
String _exportAction(String what) => '${exportIsDownload ? 'Download' : 'Share'} $what';

/// Confirms, then hands [text] to [exporter] under a name built from [kind],
/// reporting a refusal instead of leaving the button looking dead.
Future<void> _export(
  BuildContext context,
  WidgetRef ref, {
  required String action,
  required String contents,
  required String kind,
  required String text,
  required ExportFormat format,
  required TextFileExporter exporter,
  required DateTime? now,
}) async {
  final confirmed = await showExportDiagnosticsDialog(context, action, contents);
  if (!confirmed) return;

  final name = diagnosticsFileName(
    kind,
    version: ref.read(myPeerInfoProvider).valueOrNull?.serverVersion,
    now: now ?? DateTime.now(),
  );
  try {
    await exporter(name, text, format);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text('Could not export the file: $e'),
      ),
    );
  }
}

/// What a diagnostics screen shows in place of its content when loading it
/// failed.
class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class DebugScreen extends ConsumerStatefulWidget {
  static String routeName = "/diagnostics/debug";

  /// Replaced in tests: the real one ends in a platform channel.
  final TextFileExporter exporter;

  /// The moment the exported file is named after. Injected by tests.
  final DateTime? now;

  const DebugScreen({super.key, this.exporter = exportTextFile, this.now});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  Map<String, dynamic>? _debugInfo;
  String? _loadError;

  void _refreshDebugInfo() async {
    Map<String, dynamic>? debugInfo;
    String? error;
    try {
      debugInfo = await ref.read(apiProvider).fetchDebugInfo();
    } catch (e) {
      error = 'Failed to load debug info: $e';
    }
    if (!mounted) {
      return;
    }
    setState(() {
      // A failed refresh keeps what was loaded: it can still be exported,
      // and is back on screen after a retry.
      _debugInfo = debugInfo ?? _debugInfo;
      _loadError = error;
    });
  }

  @override
  void initState() {
    super.initState();

    _refreshDebugInfo();
  }

  @override
  Widget build(BuildContext context) {
    final debugInfo = _debugInfo;
    final action = _exportAction('debug info');

    return AppShell(
      selected: AppSection.diagnostics,
      appBar: AppBar(
        title: const Text('Debug info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh debug info",
            onPressed: () {
              _refreshDebugInfo();
            },
          ),
          _ExportButton(
            action: action,
            onPressed: debugInfo == null
                ? null
                : () => _export(
                    context,
                    ref,
                    action: action,
                    contents:
                        'This file lists every device in your network with its name and IP addresses. Only send it to someone you trust.',
                    kind: 'debug',
                    text: const JsonEncoder.withIndent('  ').convert(debugInfo),
                    format: ExportFormat.json,
                    exporter: widget.exporter,
                    now: widget.now,
                  ),
          ),
        ],
      ),
      body: _loadError != null
          ? _LoadError(message: _loadError!, onRetry: _refreshDebugInfo)
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(child: JsonViewerWidget(debugInfo ?? const {}, openOnStart: true)),
            ),
    );
  }
}

class LogsScreen extends ConsumerStatefulWidget {
  static String routeName = "/diagnostics/logs";

  /// Replaced in tests: the real one ends in a platform channel.
  final TextFileExporter exporter;

  /// The moment the exported file is named after. Injected by tests.
  final DateTime? now;

  const LogsScreen({super.key, this.exporter = exportTextFile, this.now});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  String _logsText = "";
  String? _loadError;
  final ScrollController _scrollController = ScrollController();
  bool _needScroll = true;

  Future<void> _scrollToEnd() async {
    if (_needScroll && _logsText.isNotEmpty && _scrollController.hasClients) {
      _needScroll = false;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _refreshLogsText() async {
    String? logs;
    String? error;
    try {
      logs = await ref.read(apiProvider).fetchLogs();
    } catch (e) {
      error = 'Failed to load logs: $e';
    }
    if (!mounted) {
      return;
    }
    setState(() {
      // A failed refresh keeps what was loaded: it can still be exported,
      // and is back on screen after a retry.
      _logsText = logs ?? _logsText;
      _loadError = error;
    });
  }

  @override
  void initState() {
    super.initState();

    _refreshLogsText();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpTo(double Function(ScrollPosition) edge) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(edge(_scrollController.position));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _scrollToEnd();
    });
    final action = _exportAction('logs');

    return AppShell(
      selected: AppSection.diagnostics,
      appBar: AppBar(
        title: const Text('Server logs'),
        // Four buttons and no spacers between them: on a phone the title has
        // to fit beside them.
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: "Scroll to bottom",
            onPressed: () => _jumpTo((position) => position.maxScrollExtent),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: "Scroll to top",
            onPressed: () => _jumpTo((position) => position.minScrollExtent),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh log",
            onPressed: () {
              _refreshLogsText();
            },
          ),
          _ExportButton(
            action: action,
            onPressed: _logsText.isEmpty
                ? null
                : () => _export(
                    context,
                    ref,
                    action: action,
                    contents:
                        'The logs may show the names and IP addresses of devices in your network. Only send them to someone you trust.',
                    kind: 'logs',
                    // What is on screen, not a fresh request: the file is the
                    // log the user was looking at.
                    text: _logsText,
                    format: ExportFormat.text,
                    exporter: widget.exporter,
                    now: widget.now,
                  ),
          ),
        ],
      ),
      body: _loadError != null
          ? _LoadError(message: _loadError!, onRetry: _refreshLogsText)
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(controller: _scrollController, child: SelectableText(_logsText)),
            ),
    );
  }
}
