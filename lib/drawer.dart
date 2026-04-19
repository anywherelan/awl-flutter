import 'dart:async';

import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/blocked_peers_screen.dart';
import 'package:anywherelan/diagnostics_screen.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:anywherelan/settings_screen.dart' show AppSettingsScreen;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MyDrawer extends ConsumerStatefulWidget {
  final AppSection? selected;
  final bool isRetractable;

  const MyDrawer({super.key, this.selected, this.isRetractable = true});

  @override
  ConsumerState<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends ConsumerState<MyDrawer> {
  static const _sectionOrder = [
    AppSection.overview,
    AppSection.settings,
    AppSection.blockedPeers,
    AppSection.diagnostics,
  ];

  @override
  Widget build(BuildContext context) {
    final serverGatedEnabled = kIsWeb || isServerRunning();
    final selectedIndex = widget.selected != null ? _sectionOrder.indexOf(widget.selected!) : null;

    final destinations = <NavigationDrawerDestination>[
      const NavigationDrawerDestination(
        icon: Icon(Icons.hub_outlined),
        selectedIcon: Icon(Icons.hub),
        label: Text('Overview'),
      ),
      const NavigationDrawerDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.block_outlined),
        selectedIcon: const Icon(Icons.block),
        enabled: serverGatedEnabled,
        label: const Text('Blocked peers'),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.bug_report_outlined),
        selectedIcon: const Icon(Icons.bug_report),
        enabled: serverGatedEnabled,
        label: const Text('Diagnostics'),
      ),
    ];

    final children = <Widget>[
      if (widget.isRetractable) const SizedBox(height: 12),
      if (!kIsWeb)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _serverAction(context)),
      if (!kIsWeb && isServerRunning())
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: _restartAction(context)),
      if (!kIsWeb)
        const Padding(padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8), child: Divider(height: 1)),
      ...destinations,
      const Padding(padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8), child: Divider(height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text('About Anywherelan', style: Theme.of(context).textTheme.labelLarge),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationIcon: Image.asset(
                'assets/icons/awl.png',
                width: 48,
                height: 48,
                filterQuality: FilterQuality.high,
              ),
              applicationName: 'Anywherelan',
              applicationVersion: 'April 2026',
              applicationLegalese: '© 2026 The Anywherelan Authors',
              children: _buildAboutBox(),
            );
          },
        ),
      ),
    ];

    final drawer = NavigationDrawer(
      selectedIndex: (selectedIndex != null && selectedIndex >= 0) ? selectedIndex : null,
      onDestinationSelected: (index) => _navigateToSection(context, _sectionOrder[index]),
      children: children,
    );

    if (widget.isRetractable) {
      return drawer;
    }
    return SizedBox(width: 240, child: drawer);
  }

  Widget _serverAction(BuildContext context) {
    final running = isServerRunning();
    return ListTile(
      leading: Icon(running ? Icons.stop_circle_outlined : Icons.play_circle_outline),
      title: Text(running ? 'Stop' : 'Start', style: Theme.of(context).textTheme.labelLarge),
      onTap: () async {
        final container = ProviderScope.containerOf(context);
        _closeDrawerIfModal(context);
        var message = '';
        var isError = false;
        if (isServerRunning()) {
          await stopServer();
          message = 'Server stopped';
          unawaited(refreshProviders(container).catchError((_) {}));
        } else {
          final startResponse = await initServer();
          if (startResponse == '') {
            message = 'Server started';
            unawaited(refreshProvidersRepeated(container));
          } else {
            message = 'Failed to start server: $startResponse';
            isError = true;
          }
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            content: Text(message),
          ),
        );
      },
    );
  }

  Widget _restartAction(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.refresh),
      title: Text('Restart', style: Theme.of(context).textTheme.labelLarge),
      onTap: () async {
        final container = ProviderScope.containerOf(context);
        _closeDrawerIfModal(context);
        if (isServerRunning()) await stopServer();
        final startResponse = await initServer();
        if (!context.mounted) return;
        if (startResponse == '') {
          unawaited(refreshProvidersRepeated(container));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              content: const Text('Server restarted'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.error,
              content: Text('Failed to start server: $startResponse'),
            ),
          );
        }
      },
    );
  }

  void _navigateToSection(BuildContext context, AppSection section) {
    _closeDrawerIfModal(context);
    if (section == widget.selected) return;
    final navigator = Navigator.of(context);
    if (section == AppSection.overview) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    final routeName = _routeFor(section);
    if (widget.selected == null || widget.selected == AppSection.overview) {
      navigator.pushNamed(routeName);
    } else {
      navigator.pushReplacementNamed(routeName);
    }
  }

  static String _routeFor(AppSection section) {
    switch (section) {
      case AppSection.overview:
        return '/';
      case AppSection.settings:
        return AppSettingsScreen.routeName;
      case AppSection.blockedPeers:
        return BlockedPeersScreen.routeName;
      case AppSection.diagnostics:
        return DiagnosticsScreen.routeName;
    }
  }

  void _closeDrawerIfModal(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
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
