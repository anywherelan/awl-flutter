import 'package:anywherelan/add_peer.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/drawer.dart';
import 'package:anywherelan/info_tab.dart';
import 'package:anywherelan/notifications.dart' as notif;
import 'package:anywherelan/peer_settings_screen.dart';
import 'package:anywherelan/peers_list_tab.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:anywherelan/settings_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

void main() async {
  if (kIsWeb) {
    await initApp();
  } else {
    initAndroid();
  }

  var futures = <Future>[];
  futures.add(myPeerInfoDataService.fetchData());
  futures.add(knownPeersDataService.fetchData());
  await Future.wait(futures);

  runApp(MyApp());
}

Future<void> initAndroid() async {
  await initApp();
  if (isServerRunning()) {
    return;
  }

  while (true) {
    await Future.delayed(Duration(seconds: 10));
    if (isServerRunning()) {
      return;
    }

    await notif.showDialog(
      builder: (context) {
        return SimpleDialog(
          title: Text("You need to accept vpn connection to use this app"),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                RaisedButton(
                  child: Text('OK'),
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                ),
              ],
            )
          ],
        );
      },
    );

    await initApp();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    notif.globalTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final app = MaterialApp(
      title: 'Anywherelan',
      navigatorKey: notif.navigatorKey,
//      onUnknownRoute:,
      theme: notif.globalTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => MyHomePage(title: 'Anywherelan'),
        '/debug': (context) => DebugScreen(),
        '/logs': (context) => LogsScreen(),
        '/settings': (context) => AppSettingsScreen(),
        '/peer_settings': (context) => KnownPeerSettingsScreen(),
      },
//      navigatorObservers: [],
//      onGenerateRoute:,
    );

    if (kIsWeb) {
      return OverlaySupport(child: app);
    }
    return app;
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final _notificationsService = notif.NotificationsService();

  @override
  void initState() {
    super.initState();

    _notificationsService.init();
    WidgetsBinding.instance!.addObserver(this);

    _tabController = TabController(vsync: this, length: 2, initialIndex: 1);
    _tabController.addListener(() {
      _tabChangeListener();
      // хак, чтобы вызвать build и обновить FloatingActionButton
      setState(() {});
    });

    _tabChangeListener();
  }

  @override
  void dispose() {
//    _tabController.removeListener(_handleTabIndex);
    _tabController.dispose();

    WidgetsBinding.instance!.removeObserver(this);
    _notificationsService.close();
    super.dispose();

    print("dispose MyHomePage"); // REMOVE
  }

  void _tabChangeListener() {
    myPeerInfoDataService.disableTimer();
    knownPeersDataService.disableTimer();
    switch (_tabController.index) {
      case 0:
        myPeerInfoDataService.enableTimer();
        break;
      case 1:
        knownPeersDataService.enableTimer();
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        myPeerInfoDataService.disableTimer();
        knownPeersDataService.disableTimer();
        _notificationsService.setTimerIntervalLong();
        break;
      case AppLifecycleState.resumed:
        _tabChangeListener();
        _notificationsService.setTimerIntervalShort();
        break;
    }

    print("didChangeAppLifecycleState $state"); // REMOVE
  }

  @override
  Widget build(BuildContext context) {
    FloatingActionButton? actionButton;
    if (_tabController.index == 1) {
      actionButton = FloatingActionButton(
        tooltip: 'Add new peer',
        onPressed: () {
          showAddPeerDialog(context);
        },
        child: Icon(Icons.add),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabs: [
            Tab(text: 'INFO'),
            Tab(text: 'PEERS'),
          ],
        ),
      ),
      drawer: MyDrawer(),
      body: SafeArea(
          bottom: false,
          child: TabBarView(controller: _tabController, children: [
            MyInfoPage(),
            PeersListPage(),
          ])),
      // TODO: попробовать перенести в PeersListPage, отображая как-нибудь поверх
      // https://stackoverflow.com/a/53399707
      floatingActionButton: actionButton,
    );
  }
}
