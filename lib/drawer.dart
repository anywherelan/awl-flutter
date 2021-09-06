import 'package:anywherelan/api.dart';
import 'package:anywherelan/json_widget/json_widget.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MyDrawer extends StatefulWidget {
  final bool isRetractable;

  MyDrawer({Key? key, this.isRetractable = true}) : super(key: key);

  @override
  _MyDrawerState createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    var listView = ListView(
      children: [
        if (widget.isRetractable) ...[
          ListTile(
            title: Text(
              "Anywherelan",
              style: textTheme.headline5,
            ),
          ),
          const Divider(),
        ],
        if (!kIsWeb)
          ListTile(
            title: Text(
              isServerRunning() ? "Stop server" : "Start server",
            ),
            enabled: true,
            selected: false,
            leading: Icon(isServerRunning() ? Icons.stop : Icons.play_arrow),
            onTap: () async {
              var message = "";
              if (isServerRunning()) {
                await stopServer();
                message = "Server stopped";
              } else {
                await initServer();
                message = "Server started";
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: Colors.green,
                content: Text(message),
              ));
            },
          ),
        if (!kIsWeb && isServerRunning())
          ListTile(
            title: Text(
              "Restart server",
            ),
            enabled: true,
            selected: false,
            leading: const Icon(Icons.refresh),
            onTap: () async {
              if (isServerRunning()) {
                await stopServer();
              }
              await initServer();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: Colors.green,
                content: Text("Server restarted"),
              ));
            },
          ),
        ListTile(
          title: Text(
            "Settings",
          ),
          enabled: true,
          selected: false,
          leading: const Icon(Icons.settings),
          onTap: () {
            Navigator.of(context).pushNamed('/settings');
          },
        ),
        ListTile(
          title: Text(
            "Debug info",
          ),
          enabled: true,
          selected: false,
          leading: const Icon(Icons.developer_mode),
          onTap: () {
            Navigator.of(context).pushNamed('/debug');
          },
        ),
        ListTile(
          title: Text(
            "Server logs",
          ),
          enabled: true,
          selected: false,
          leading: const Icon(Icons.insert_drive_file),
          onTap: () {
            Navigator.of(context).pushNamed('/logs');
          },
        ),
        // TODO update text
        AboutListTile(
          icon: Icon(Icons.info),
          applicationIcon: FlutterLogo(),
          applicationName: 'Anywherelan',
          applicationVersion: 'April 2021',
          applicationLegalese: '© 2021 The Anywherelan Authors',
          aboutBoxChildren: _buildAboutBox(),
        ),
      ],
    );

    if (widget.isRetractable) {
      return Drawer(
          child: SafeArea(
        child: listView,
      ));
    } else {
      return ConstrainedBox(
        constraints: const BoxConstraints.expand(width: 250),
        child: Drawer(
          child: listView,
        ),
      );
    }
  }

  List<Widget> _buildAboutBox() {
    final TextStyle textStyle = Theme.of(context).textTheme.bodyText1!;
    const url = "https://anywherelan.com";
    return <Widget>[
      SizedBox(height: 24),
      RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(style: textStyle, text: 'TODO '),
            TextSpan(
              style: textStyle.copyWith(color: Theme.of(context).colorScheme.primary),
              text: url,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  if (await canLaunch(url)) await launch(url);
                },
            ),
            TextSpan(style: textStyle, text: '.'),
          ],
        ),
      ),
    ];
  }
}

class DebugScreen extends StatefulWidget {
  DebugScreen({Key? key}) : super(key: key);

  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  Map<String, dynamic>? _debugInfo = Map();

  void _refreshDebugInfo() async {
    var debugInfo = await fetchDebugInfo(http.Client());
    if (!this.mounted) {
      return;
    }
    setState(() {
      _debugInfo = debugInfo;
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
          child: SingleChildScrollView(
            child: JsonViewerWidget(_debugInfo, openOnStart: true),
          ),
        ),
      ),
    );
  }
}

class LogsScreen extends StatefulWidget {
  LogsScreen({Key? key}) : super(key: key);

  @override
  _LogsScreenState createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _logsText = "";
  ScrollController _scrollController = ScrollController();
  bool _needScroll = true;

  _scrollToEnd() async {
    if (_needScroll && _logsText.length > 0) {
      _needScroll = false;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _refreshLogsText() async {
    var logs = await fetchLogs(http.Client());
    if (!this.mounted) {
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
    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
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
          child: SingleChildScrollView(
            controller: _scrollController,
            child: SelectableText(
              _logsText,
            ),
          ),
        ),
      ),
    );
  }
}
