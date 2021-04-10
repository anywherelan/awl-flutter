import 'package:flutter/material.dart';
import 'package:peerlanflutter/peers_list_tab.dart';
import 'package:peerlanflutter/info_tab.dart';
import 'package:peerlanflutter/connections_tab.dart';
import 'package:peerlanflutter/drawer.dart';
import 'package:peerlanflutter/add_peer.dart';
import 'package:peerlanflutter/settings_screen.dart';
import 'package:peerlanflutter/peer_settings_screen.dart';
import 'package:peerlanflutter/notifications.dart';
import 'package:peerlanflutter/data_service.dart';
import 'package:peerlanflutter/server_interop/server_interop.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// TODO
//  - в настройках приложения возможность указать адрес сервера. Для этого также понадобится в конфиге сервера добавить опцию "AllowCORS bool"
//  - обработка ошибок сети в api.dart
// DONE  - ! придумать что-то с таймерами. отключать фоновую работу при переходе на новые route, когда на другой вкладке, когда приложение свернуто
//  - шрифты везде побольше, особенно логи и debug info
//  - ? кнопка 'Add new peer' появляется с какой-то слишком длинной задержкой -- только при свайпах по табам
// DONE  - на сервере не создавать папки peerstore и не обращаться к exe для поиска пути в init()
//  - на сервере добавить API для рестарта программы - для импорта конфига например. связано с автообновлением
// DONE  - в списке пиров отображать доступные и проброшенные порты - для этого надо обновить АПИ
// DONE  - примитивное отображение connections
// DONE  - кнопка поделиться peerID - вернуть. Сделать как на скрине, см тф
// DONE  - info_tab: uptime меньше 1 минуты не пишется. Надо выводить 0m
//  - плохо открывается Debug info - возможно надо перенести парсинг json в isolation. Либо дело в большом кол-ве SelectableText
// DONE  - у только добавленных пиров отображается отрицательный last seen
//  - I/Choreographer(26731): Skipped 40 frames!  The application may be doing too much work on its main thread.
//  - лог должен сохраняться между принудительными рестартами внутри программы
//  - экспорт конфига из браузера (file picker). см https://stackoverflow.com/a/29650941 || https://rodolfohernan20.blogspot.com/2019/12/upload-files-to-server-with-flutter-web.html
//        || https://github.com/flutter/flutter/issues/36281#issuecomment-514608895
//  - найти во флаттере какое-нибудь событие 'onAppClose', подписаться на него чтобы правильно завершать сервер --- наверное лучше делать это со стороны джавы
//  - server: перенести static пакет и остальное по-максимуму из cmd/peerlan-tray, чтобы можно было переиспользовать для серверного билда (например с build tag)
// DONE  - добавить иконки у списка пиров как у инфо о пире
//  - project layout. все файлы с UI вынести в отдельную папку,
//  -
//  -
//  -

void main() async {
  await initApp();

  var futures = <Future>[];
  futures.add(myPeerInfoDataService.fetchData());
  futures.add(knownPeersDataService.fetchData());
  await Future.wait(futures);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    globalTheme = ThemeData.light();
    globalTheme = ThemeData(
      primarySwatch: Colors.green,
      visualDensity: VisualDensity.adaptivePlatformDensity,
//      textTheme: TextTheme(
//        headline1: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
//        headline6: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic),
//        bodyText1: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
//        bodyText2: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
//      ),
    );

//    globalTheme = ThemeData.light().copyWith(primatextTheme: TextTheme());

    final app = MaterialApp(
      title: 'Peerlan Demo',
      navigatorKey: navigatorKey,
//      onUnknownRoute:,
      theme: globalTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => MyHomePage(title: 'Peerlan Demo'),
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
  TabController? _tabController;
  final _notificationsService = NotificationsService();

  @override
  void initState() {
    super.initState();

    _notificationsService.init();
    WidgetsBinding.instance!.addObserver(this);

    _tabController = TabController(vsync: this, length: 3)
      ..addListener(() {
        _tabChangeListener();
        // хак, чтобы вызвать build и обновить FloatingActionButton
        setState(() {});
      });

    _tabChangeListener();
  }

  @override
  void dispose() {
//    _tabController.removeListener(_handleTabIndex);
    _tabController!.dispose();

    WidgetsBinding.instance!.removeObserver(this);
    _notificationsService.close();
    super.dispose();

    print("dispose MyHomePage"); // REMOVE
  }

  void _tabChangeListener() {
    myPeerInfoDataService.disableTimer();
    knownPeersDataService.disableTimer();
    switch (_tabController!.index) {
      case 0:
        myPeerInfoDataService.enableTimer();
        break;
      case 1:
        knownPeersDataService.enableTimer();
        break;
      case 2:
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
    if (_tabController!.index == 1) {
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
            Tab(text: 'Info'),
            Tab(text: 'Peers'),
            Tab(text: 'Connections'),
          ],
        ),
      ),
      drawer: MyDrawer(),
      body: SafeArea(
          bottom: false,
          child: TabBarView(controller: _tabController, children: [
            MyInfoPage(),
            PeersListPage(),
            ConnectionsPage(),
          ])),
      // TODO: попробовать перенести в PeersListPage, отображая как-нибудь поверх
      // https://stackoverflow.com/a/53399707
      floatingActionButton: actionButton,
    );
  }
}
