import 'package:anywherelan/add_peer.dart';
import 'package:anywherelan/blocked_peers_screen.dart';
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
    await fetchAllData();
  } else {
    initAndroid();
  }

  runApp(MyApp());
}

Future<void> initAndroid() async {
  while (true) {
    var dialogTitle = "";
    var dialogBody = "";
    var stopLoop = false;
    var startError = await initApp();
    if (isServerRunning()) {
      await fetchAllData();
      return;
    } else if (startError.contains("vpn not authorized")) {
      dialogTitle = "You need to accept vpn connection to use this app";
    } else {
      dialogTitle = "Failed to start server";
      dialogBody = startError;
      stopLoop = true;
    }

    await showDialog(
      context: notif.navigatorKey.currentContext!,
      builder: (context) {
        return SimpleDialog(
          title: Text(dialogTitle),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            if (dialogBody != "") SelectableText(dialogBody),
            if (dialogBody != "") SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton(
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

    if (stopLoop) return;
    await Future.delayed(Duration(seconds: 6));
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Anywherelan',
      navigatorKey: notif.navigatorKey,
//      onUnknownRoute:,
      theme: ThemeData(
        // TODO: redesign in Material 3
        // useMaterial3: true,
        // colorSchemeSeed: Colors.green,
        // brightness: Brightness.dark,
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (context) => HomeScreen(title: 'Anywherelan'),
        DebugScreen.routeName: (context) => DebugScreen(),
        LogsScreen.routeName: (context) => LogsScreen(),
        AppSettingsScreen.routeName: (context) => AppSettingsScreen(),
        KnownPeerSettingsScreen.routeName: (context) => KnownPeerSettingsScreen(),
        BlockedPeersScreen.routeName: (context) => BlockedPeersScreen(),
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

class HomeScreen extends StatefulWidget {
  static String routeName = "/";

  HomeScreen({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final _notificationsService = notif.NotificationsService();

  @override
  void initState() {
    super.initState();

    _notificationsService.init();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(vsync: this, length: 2, initialIndex: 1);
    _tabController.addListener(() {
      _tabChangeListener();
      // to trigger build and refresh FloatingActionButton
      setState(() {});
    });

    _tabChangeListener();
  }

  @override
  void dispose() {
    _tabController.dispose();

    WidgetsBinding.instance.removeObserver(this);
    _notificationsService.close();
    super.dispose();
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
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        myPeerInfoDataService.disableTimer();
        knownPeersDataService.disableTimer();
        _notificationsService.setTimerIntervalLong();
        break;
      case AppLifecycleState.resumed:
        myPeerInfoDataService.enableTimer();
        knownPeersDataService.enableTimer();
        _notificationsService.setTimerIntervalShort();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 750) {
        myPeerInfoDataService.enableTimer();
        knownPeersDataService.enableTimer();
        return _buildWideAdaptiveScreen(constraints, context);
      }

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
              Padding(
                padding: EdgeInsets.all(16),
                child: MyInfoPage(),
              ),
              PeersListPage(),
            ])),
        floatingActionButton: actionButton,
      );
    });
  }

  Widget _buildWideAdaptiveScreen(BoxConstraints constraints, BuildContext context) {
    var hasScaffoldDrawer = true;
    var spaceBetweenItems = 15.0;

    if (constraints.maxWidth > 1000) {
      hasScaffoldDrawer = false;
    }

    if (constraints.maxWidth > 1800) {
      spaceBetweenItems = 180.0;
    } else if (constraints.maxWidth > 1700) {
      spaceBetweenItems = 160.0;
    } else if (constraints.maxWidth > 1600) {
      spaceBetweenItems = 140.0;
    } else if (constraints.maxWidth > 1500) {
      spaceBetweenItems = 120.0;
    } else if (constraints.maxWidth > 1400) {
      spaceBetweenItems = 100.0;
    } else if (constraints.maxWidth > 1300) {
      spaceBetweenItems = 70.0;
    } else if (constraints.maxWidth > 1200) {
      spaceBetweenItems = 50.0;
    } else if (constraints.maxWidth > 1100) {
      spaceBetweenItems = 40.0;
    } else if (constraints.maxWidth > 850) {
      spaceBetweenItems = 20.0;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      drawer: hasScaffoldDrawer ? MyDrawer() : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasScaffoldDrawer) MyDrawer(isRetractable: false),
            SizedBox(width: spaceBetweenItems),
            Flexible(
              flex: 4,
              child: decorateAsCard(PeersListPage()),
            ),
            SizedBox(width: spaceBetweenItems),
            Flexible(
              flex: 3,
              child: Column(
                children: [
                  decorateAsCard(MyInfoPage()),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: Icon(
                          Icons.add,
                          color: Colors.black87,
                        ),
                        label: Text("NEW PEER"),
                        onPressed: () {
                          showAddPeerDialog(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: spaceBetweenItems),
          ],
        ),
      ),
    );
  }

  Container decorateAsCard(Widget child) {
    return Container(
      child: child,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(top: 20, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 5,
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
    );
  }
}
