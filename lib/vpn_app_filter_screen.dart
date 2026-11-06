import 'dart:async';

import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seams for the screen's three platform calls. Production uses the
/// MethodChannel-backed implementations from server_interop; tests pass fakes,
/// since that channel only exists on Android.
typedef VpnAppsLoader = Future<List<VpnAppEntry>> Function();
typedef VpnFilterLoader = Future<VpnAppFilterState> Function();
typedef VpnFilterSaver = Future<String> Function(String mode, List<String> packages);

/// Per-app VPN filter ("Proxy apps"), the same UX as tinc-android's
/// AppListActivity: pick a mode and check apps.
///   "All"                - every app uses the VPN (no filter).
///   "All except selected"- checked apps bypass the VPN (deny-list, API 24+).
///   "Only selected"      - only checked apps use the VPN (allow-list).
class VpnAppFilterScreen extends StatefulWidget {
  static const String routeName = '/vpn-app-filter';

  final VpnAppsLoader loadApps;
  final VpnFilterLoader loadState;
  final VpnFilterSaver saveFilter;

  const VpnAppFilterScreen({
    super.key,
    this.loadApps = getInstalledApps,
    this.loadState = getAppFilter,
    this.saveFilter = setAppFilter,
  });

  @override
  State<VpnAppFilterScreen> createState() => _VpnAppFilterScreenState();
}

class _VpnAppFilterScreenState extends State<VpnAppFilterScreen> {
  List<VpnAppEntry> _apps = const [];
  String _mode = 'none';
  Set<String> _selected = {};
  String _query = '';
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apps = await widget.loadApps();
      final state = await widget.loadState();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        _mode = state.mode;
        _selected = state.packages.toSet();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text("Failed to load app filter: $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Marks the selection dirty, so the save action lights up.
  void _setMode(String mode) {
    setState(() {
      _mode = mode;
      _dirty = true;
    });
  }

  void _toggle(VpnAppEntry app) {
    setState(() {
      if (_selected.contains(app.pkg)) {
        _selected.remove(app.pkg);
      } else {
        _selected.add(app.pkg);
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final result = await widget.saveFilter(_mode, _selected.toList());
    if (!mounted) return;
    final ok = result == '' || result == 'restart_required';
    if (ok) setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
        content: Text(
          result == ''
              ? "Saved. VPN routing updated."
              : result == 'restart_required'
              ? "Saved. Restarting the VPN to apply the filter…"
              : "Failed to save app filter: $result",
        ),
      ),
    );
    if (result != 'restart_required') return;

    // A live VPN cannot take a new app filter in place: re-establishing the
    // TUN while it is up breaks routing on Android (the old default route is
    // retired with "No such device" and never restored). Restart the whole
    // server instead — the clean establish() at startup applies the filter.
    final container = ProviderScope.containerOf(context);
    await stopServer();
    final startError = await initServer();
    if (!mounted) return;
    if (startError != '') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text("Failed to restart the VPN: $startError"),
        ),
      );
      return;
    }
    unawaited(refreshProvidersRepeated(container));
  }

  String get _modeHelp {
    switch (_mode) {
      case 'denylist':
        return "Checked apps bypass the VPN; everything else goes through it.";
      case 'allowlist':
        return "Only checked apps use the VPN; everything else bypasses it.";
      default:
        return "Every app uses the VPN connection.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _query.isEmpty
        ? _apps
        : [
            for (final a in _apps)
              if (a.label.toLowerCase().contains(_query.toLowerCase()) ||
                  a.pkg.toLowerCase().contains(_query.toLowerCase()))
                a,
          ];

    return AppShell(
      selected: AppSection.settings,
      appBar: AppBar(
        title: const Text('Proxy apps'),
        actions: [
          // The button doubles as the dirty indicator: it is only active when
          // there are unsaved changes.
          IconButton(
            icon: Icon(Icons.save, color: _dirty ? null : Colors.grey),
            tooltip: 'Save',
            onPressed: (_dirty && !_loading) ? _save : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'none', label: Text('All')),
                      ButtonSegment(value: 'denylist', label: Text('All except selected')),
                      ButtonSegment(value: 'allowlist', label: Text('Only selected')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => _setMode(s.first),
                    style: ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(_modeHelp, style: Theme.of(context).textTheme.bodySmall)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search apps',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (q) => setState(() => _query = q),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(child: Text('No apps found'))
                      : ListView.builder(
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final app = shown[i];
                            return CheckboxListTile(
                              dense: true,
                              title: Text(app.label),
                              subtitle: Text(app.pkg),
                              secondary: const Icon(Icons.apps_rounded),
                              value: _selected.contains(app.pkg),
                              onChanged: _mode == 'none' ? null : (_) => _toggle(app),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
