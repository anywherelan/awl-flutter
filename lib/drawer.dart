import 'dart:async';

import 'package:anywherelan/blocked_peers_screen.dart';
import 'package:anywherelan/json_widget/json_widget.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:anywherelan/settings_screen.dart' show AppSettingsScreen;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MyDrawer extends ConsumerStatefulWidget {
  final bool isRetractable;

  const MyDrawer({super.key, this.isRetractable = true});

  @override
  ConsumerState<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends ConsumerState<MyDrawer> {
  @override
  Widget build(BuildContext context) {
    var listView = Column(
      children: [
        if (widget.isRetractable) const SizedBox(height: 16),
        if (!kIsWeb)
          ListTile(
            title: Text(isServerRunning() ? "Stop" : "Start"),
            enabled: true,
            leading: Icon(isServerRunning() ? Icons.stop : Icons.play_arrow),
            onTap: () async {
              final container = ProviderScope.containerOf(context);
              var message = "";
              var isError = false;
              if (isServerRunning()) {
                await stopServer();
                message = "Server stopped";
                unawaited(refreshProviders(container).catchError((_) {}));
              } else {
                var startResponse = await initServer();
                if (startResponse == "") {
                  message = "Server started";
                  unawaited(refreshProvidersRepeated(container));
                } else {
                  message = "Failed to start server: $startResponse";
                  isError = true;
                }
              }
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: isError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  content: Text(message),
                ),
              );
            },
          ),
        if (!kIsWeb && isServerRunning())
          ListTile(
            title: Text("Restart"),
            enabled: true,
            leading: const Icon(Icons.refresh),
            onTap: () async {
              final container = ProviderScope.containerOf(context);
              if (isServerRunning()) {
                await stopServer();
              }
              var startResponse = await initServer();
              if (!context.mounted) return;
              Navigator.of(context).pop();
              if (startResponse == "") {
                unawaited(refreshProvidersRepeated(container));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    content: Text("Server restarted"),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    content: Text("Failed to start server: $startResponse"),
                  ),
                );
              }
            },
          ),
        ListTile(
          title: Text("Blocked peers"),
          enabled: kIsWeb || isServerRunning(),
          leading: const Icon(Icons.app_blocking),
          onTap: () {
            Navigator.of(context).pushNamed(BlockedPeersScreen.routeName);
          },
        ),
        ListTile(
          title: Text("Settings"),
          enabled: true,
          leading: const Icon(Icons.settings),
          onTap: () {
            Navigator.of(context).pushNamed(AppSettingsScreen.routeName);
          },
        ),
        ListTile(
          title: Text("Debug info"),
          enabled: kIsWeb || isServerRunning(),
          leading: const Icon(Icons.developer_mode),
          onTap: () {
            Navigator.of(context).pushNamed(DebugScreen.routeName);
          },
        ),
        ListTile(
          title: Text("Server logs"),
          enabled: kIsWeb || isServerRunning(),
          selected: false,
          leading: const Icon(Icons.insert_drive_file),
          onTap: () {
            Navigator.of(context).pushNamed(LogsScreen.routeName);
          },
        ),
        AboutListTile(
          icon: Icon(Icons.info),
          applicationIcon: Image.asset(
            'assets/icons/awl.png',
            width: 48,
            height: 48,
            filterQuality: FilterQuality.high,
          ),
          applicationName: 'Anywherelan',
          applicationVersion: 'April 2026',
          applicationLegalese: '© 2026 The Anywherelan Authors',
          aboutBoxChildren: _buildAboutBox(),
        ),
      ],
    );

    if (widget.isRetractable) {
      return Drawer(child: SafeArea(child: listView));
    } else {
      return ConstrainedBox(
        constraints: const BoxConstraints.expand(width: 250),
        child: Drawer(child: listView),
      );
    }
  }

  List<Widget> _buildAboutBox() {
    final TextStyle textStyle = Theme.of(context).textTheme.bodyLarge!;
    const url = "https://anywherelan.com";
    return <Widget>[
      SizedBox(height: 24),
      RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              style: textStyle.copyWith(color: Theme.of(context).colorScheme.primary),
              text: url,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  if (await canLaunchUrlString(url)) await launchUrlString(url);
                },
            ),
          ],
        ),
      ),
    ];
  }
}

class DebugScreen extends ConsumerStatefulWidget {
  static String routeName = "/debug";

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
    return Scaffold(
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(child: JsonViewerWidget(_debugInfo, openOnStart: true)),
        ),
      ),
    );
  }
}

class LogsScreen extends ConsumerStatefulWidget {
  static String routeName = "/logs";

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

    return Scaffold(
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
      body: SafeArea(
        bottom: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(controller: _scrollController, child: SelectableText(_logsText)),
        ),
      ),
    );
  }
}
