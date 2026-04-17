import 'package:anywherelan/app_shell.dart';
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

class DebugScreen extends ConsumerStatefulWidget {
  static String routeName = "/diagnostics/debug";

  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  late Map<String, dynamic> _debugInfo = {};

  void _refreshDebugInfo() async {
    var debugInfo = await ref.read(apiProvider).fetchDebugInfo();
    if (!mounted) {
      return;
    }
    setState(() {
      _debugInfo = debugInfo!;
    });
  }

  @override
  void initState() {
    super.initState();

    _refreshDebugInfo();
  }

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(child: JsonViewerWidget(_debugInfo, openOnStart: true)),
      ),
    );
  }
}

class LogsScreen extends ConsumerStatefulWidget {
  static String routeName = "/diagnostics/logs";

  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  String _logsText = "";
  final ScrollController _scrollController = ScrollController();
  bool _needScroll = true;

  Future<void> _scrollToEnd() async {
    if (_needScroll && _logsText.isNotEmpty) {
      _needScroll = false;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _refreshLogsText() async {
    var logs = await ref.read(apiProvider).fetchLogs();
    if (!mounted) {
      return;
    }
    setState(() {
      _logsText = logs;
    });
  }

  @override
  void initState() {
    super.initState();

    _refreshLogsText();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _scrollToEnd();
    });

    return AppShell(
      selected: AppSection.diagnostics,
      appBar: AppBar(
        title: const Text('Server logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            tooltip: "Scroll to bottom",
            onPressed: () {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            tooltip: "Scroll to top",
            onPressed: () {
              _scrollController.jumpTo(_scrollController.position.minScrollExtent);
            },
          ),
          SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh log",
            onPressed: () {
              _refreshLogsText();
            },
          ),
          SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(controller: _scrollController, child: SelectableText(_logsText)),
      ),
    );
  }
}
