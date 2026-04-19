import 'dart:async';

import 'package:anywherelan/add_peer.dart';
import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/blocked_peers_screen.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/diagnostics_screen.dart';
import 'package:anywherelan/drawer.dart';
import 'package:anywherelan/notifications.dart' as notif;
import 'package:anywherelan/peer_settings_screen.dart';
import 'package:anywherelan/peers_list_tab.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:anywherelan/settings_screen.dart';
import 'package:anywherelan/status_tab.dart';
import 'package:anywherelan/theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';

final _container = ProviderContainer();

void main() async {
  if (kIsWeb) {
    await initApp();
    await refreshProviders(_container).catchError((_) {});
  } else {
    initAndroid();
  }

  runApp(UncontrolledProviderScope(container: _container, child: MyApp()));
}

Future<void> initAndroid() async {
  while (true) {
    var dialogTitle = "";
    var dialogBody = "";
    var stopLoop = false;
    var startError = await initApp();
    if (isServerRunning()) {
      await refreshProviders(_container);
      unawaited(refreshProvidersRepeated(_container));
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
            ),
          ],
        );
      },
    );

    if (stopLoop) return;
    await Future.delayed(Duration(seconds: 6));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'Anywherelan',
      navigatorKey: notif.navigatorKey,
      theme: buildAppTheme(),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (context) => HomeScreen(title: 'Anywherelan'),
        DiagnosticsScreen.routeName: (context) => DiagnosticsScreen(),
        DebugScreen.routeName: (context) => DebugScreen(),
        LogsScreen.routeName: (context) => LogsScreen(),
        AppSettingsScreen.routeName: (context) => AppSettingsScreen(),
        BlockedPeersScreen.routeName: (context) => BlockedPeersScreen(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        final segments = uri.pathSegments;
        if (segments.length == 3 && segments[0] == 'peers' && segments[2] == 'settings') {
          return MaterialPageRoute(settings: settings, builder: (context) => KnownPeerSettingsScreen());
        }
        return null;
      },
    );

    if (kIsWeb) {
      return OverlaySupport(child: app);
    }
    return app;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  static String routeName = "/";

  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late final notif.NotificationsService _notificationsService;

  @override
  void initState() {
    super.initState();

    _notificationsService = notif.NotificationsService(ref.read(apiProvider));
    _notificationsService.init();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(vsync: this, length: 2, initialIndex: 1);
    _tabController.addListener(() {
      // to trigger build and refresh FloatingActionButton
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();

    WidgetsBinding.instance.removeObserver(this);
    _notificationsService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        ref.read(pollingPolicyProvider.notifier).state = PollingPolicy.paused;
        _notificationsService.setTimerIntervalLong();
        break;
      case AppLifecycleState.resumed:
        ref.read(pollingPolicyProvider.notifier).state = PollingPolicy.active;
        _notificationsService.setTimerIntervalShort();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
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
            title: _buildAppBarTitle(),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: [
                Tab(text: 'Status'),
                Tab(text: 'Peers'),
              ],
            ),
          ),
          drawer: MyDrawer(selected: AppSection.overview),
          body: SafeArea(
            bottom: false,
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(padding: const EdgeInsets.all(16), child: StatusPage()),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: PeersListPage()),
              ],
            ),
          ),
          floatingActionButton: actionButton,
        );
      },
    );
  }

  Widget _buildWideAdaptiveScreen(BoxConstraints constraints, BuildContext context) {
    var hasScaffoldDrawer = true;
    var spaceBetweenItems = 15.0;

    if (constraints.maxWidth > 1100) {
      hasScaffoldDrawer = false;
    }

    if (constraints.maxWidth > 2000) {
      spaceBetweenItems = 240.0;
    } else if (constraints.maxWidth > 1900) {
      spaceBetweenItems = 180.0;
    } else if (constraints.maxWidth > 1700) {
      spaceBetweenItems = 140.0;
    } else if (constraints.maxWidth > 1600) {
      spaceBetweenItems = 100.0;
    } else if (constraints.maxWidth > 1500) {
      spaceBetweenItems = 70.0;
    } else if (constraints.maxWidth > 1350) {
      spaceBetweenItems = 45.0;
    } else if (constraints.maxWidth > 1300) {
      spaceBetweenItems = 40.0;
    } else if (constraints.maxWidth > 1200) {
      spaceBetweenItems = 30.0;
    } else if (constraints.maxWidth > 1100) {
      spaceBetweenItems = 30.0;
    } else if (constraints.maxWidth > 850) {
      spaceBetweenItems = 20.0;
    }
    return Scaffold(
      appBar: AppBar(title: _buildAppBarTitle()),
      drawer: hasScaffoldDrawer ? MyDrawer(selected: AppSection.overview) : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasScaffoldDrawer) MyDrawer(selected: AppSection.overview, isRetractable: false),
            SizedBox(width: spaceBetweenItems),
            Flexible(
              flex: 4,
              child: Column(
                children: [
                  _buildPeersHeader(),
                  Expanded(child: PeersListPage(showCounter: false)),
                  SizedBox(height: 20),
                ],
              ),
            ),
            SizedBox(width: spaceBetweenItems),
            Flexible(
              flex: 3,
              child: Column(
                children: [
                  _buildDeviceHeaderSection(),
                  Expanded(child: StatusPage(showDeviceHeader: false)),
                  SizedBox(height: 20),
                ],
              ),
            ),
            SizedBox(width: spaceBetweenItems),
          ],
        ),
      ),
    );
  }

  Widget _buildPeersHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final knownPeers = ref.watch(knownPeersProvider).valueOrNull;
    final onlineCount = knownPeers?.where((p) => p.connected && p.confirmed).length ?? 0;
    final totalCount = knownPeers?.length ?? 0;
    return Padding(
      padding: EdgeInsets.only(left: 4, top: 20, bottom: 14, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Peers",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
                ),
                SizedBox(height: 2),
                totalCount > 0
                    ? buildPeersOnlineIndicator(context, onlineCount, totalCount)
                    : SizedBox(height: 13),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            icon: Icon(Icons.add_rounded, size: 22),
            label: Text("Add peer"),
            onPressed: () => showAddPeerDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceHeaderSection() {
    final peerInfo = ref.watch(myPeerInfoProvider).valueOrNull;
    return Padding(
      padding: EdgeInsets.only(left: 4, top: 20, bottom: 14, right: 4),
      child: peerInfo != null
          ? buildDeviceHeader(
              context,
              peerInfo,
              onShowQR: () => showQRDialog(context, peerInfo.peerID, peerInfo.name),
              onShowSettings: () => showSettingsDialog(context, peerInfo, false),
            )
          : SizedBox(height: Theme.of(context).textTheme.titleLarge!.fontSize! + 2 + 13),
    );
  }

  Widget _buildAppBarTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icons/awl.png', width: 32, height: 32, filterQuality: FilterQuality.high),
        SizedBox(width: 8),
        Text(widget.title),
      ],
    );
  }
}
