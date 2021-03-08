import 'package:flutter/material.dart';
import 'package:peerlanflutter/api.dart';
import 'package:peerlanflutter/json_widget/json_widget.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:peerlanflutter/server_interop/server_interop.dart';

class MyDrawer extends StatefulWidget {
  @override
  _MyDrawerState createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
//            DrawerHeader(
//              child: Text(
//                "Peerlan",
//                style: textTheme.headline5,
//              ),
//            ),
            ListTile(
              title: Text(
                "Peerlan",
                style: textTheme.headline5,
              ),
            ),
            const Divider(),
            if (!kIsWeb)
              ListTile(
                title: Text(
                  "Restart server",
                ),
                enabled: true,
                selected: false,
                leading: const Icon(Icons.refresh),
                onTap: () async {
                  await stopServer();
                  await initServer();
                  Navigator.of(context).pop();
                  Scaffold.of(context).showSnackBar(SnackBar(
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
                "Logs",
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
              applicationName: 'Peerlan',
              applicationVersion: 'May 2020',
              applicationLegalese: '© 2020 The Peerlan Authors',
              aboutBoxChildren: _buildAboutBox(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAboutBox() {
    final TextStyle textStyle = Theme.of(context).textTheme.bodyText2;
    return <Widget>[
      SizedBox(height: 24),
      RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(style: textStyle, text: 'Peerlan is lala lalala. Learn more about Peerlan at '),
            TextSpan(style: textStyle.copyWith(color: Theme.of(context).accentColor), text: 'https://peerlan.net'),
            TextSpan(style: textStyle, text: '.'),
          ],
        ),
      ),
    ];
  }
}

class DebugScreen extends StatefulWidget {
  DebugScreen({Key key}) : super(key: key);

  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  Map<String, dynamic> _debugInfo = Map();

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
  LogsScreen({Key key}) : super(key: key);

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
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _scrollToEnd();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh log",
            onPressed: () {
              _refreshLogsText();
            },
          ),
        ],
      ),
      body: SafeArea(
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
