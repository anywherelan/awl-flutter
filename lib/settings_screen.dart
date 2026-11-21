import 'dart:async';
import 'dart:convert';

import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  static String routeName = "/settings";

  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  Future<PickerResponse> _exportSettings() async {
    try {
      final exportedSettings = await ref.read(apiProvider).fetchExportedServerConfig();
      String? response;
      if (kIsWeb) {
        response = await FileSaver.instance.saveFile(
          name: "config_awl",
          bytes: exportedSettings,
          fileExtension: "json",
          mimeType: MimeType.json,
        );
      } else {
        // saveAs is not implemented on web
        // see https://github.com/incrediblezayed/file_saver/issues/130
        response = await FileSaver.instance.saveAs(
          name: "config_awl",
          bytes: exportedSettings,
          fileExtension: "json",
          mimeType: MimeType.json,
        );
      }

      if (response == null) {
        // cancelled on android
        return PickerResponse(false, "");
      } else if (response == "Downloads") {
        // web
        return PickerResponse(true, "");
      } else if (response != "") {
        // android
        return PickerResponse(true, "Settings have been exported to file ${basename(response)}");
      }

      return PickerResponse(false, response);
    } on Exception catch (e) {
      return PickerResponse(false, "Failed to save config: ${e.toString()}");
    }
  }

  Future<PickerResponse> _importSettings() async {
    final container = ProviderScope.containerOf(this.context);
    try {
      FilePickerResult? result;
      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ["json"],
          withData: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ["json"],
          withData: true,
        );
      }

      if (result == null) {
        return PickerResponse(true, "");
      }

      final fileBytes = result.files.first.bytes;
      final fileString = utf8.decode(fileBytes!.toList());
      final fileName = result.files.first.name;

      // Importing into a stopped server is the ordinary case on a fresh install.
      if (isServerRunning()) await stopServer();
      var importResponse = await importConfig(fileString);
      var startResponse = await initServer();

      if (importResponse != "") {
        return PickerResponse(false, importResponse);
      } else if (startResponse != "") {
        return PickerResponse(false, startResponse);
      }

      unawaited(refreshProvidersRepeated(container));

      return PickerResponse(true, "Imported file $fileName");
    } on Exception catch (e) {
      return PickerResponse(false, "Failed to import config file: ${e.toString()}, error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: AppSection.settings,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // The settings are read from the running server, so without one
          // there is nothing to export.
          ValueListenableBuilder<bool>(
            valueListenable: isServerAvailable,
            builder: (context, isAvailable, _) => ListTile(
              title: Text("Export settings"),
              subtitle: isAvailable ? null : const Text("Needs a running server."),
              enabled: isAvailable,
              selected: false,
              leading: const Icon(Icons.import_export),
              onTap: () async {
                var result = await _exportSettings();
                if (!context.mounted) return;
                if (result.message != "") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: result.success
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      content: Text(result.message),
                    ),
                  );
                }
              },
            ),
          ),
          if (!kIsWeb)
            ListTile(
              title: Text("Import settings"),
              subtitle: Text(
                "This action will overwrite current settings, therefore it is recommended to export them first."
                " Server will be restarted automatically with new configuration.",
              ),
              enabled: true,
              selected: false,
              leading: const Icon(Icons.import_export),
              onTap: () async {
                var result = await _importSettings();
                if (!context.mounted) return;
                if (result.message != "") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: result.success
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      content: Text(result.message),
                    ),
                  );
                }
              },
            ),
          if (!kIsWeb) const _AlwaysOnVpnTile(),
          if (!kIsWeb)
            ListTile(
              title: Text("Request ignore battery optimizations"),
              enabled: true,
              selected: false,
              leading: const Icon(Icons.adb),
              onTap: () async {
                var status = await Permission.ignoreBatteryOptimizations.request();
                if (!context.mounted) return;
                if (status == PermissionStatus.granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      content: Text("Permission granted"),
                    ),
                  );
                } else if (status == PermissionStatus.denied) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      content: Text("Permission denied"),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Starting awl at boot and keeping it running is Android's Always-on VPN,
/// turned on in the system VPN settings; the app has no setting of its own for
/// it. This tile explains that and opens those settings. The status is read
/// again on return from them.
class _AlwaysOnVpnTile extends StatefulWidget {
  const _AlwaysOnVpnTile();

  @override
  State<_AlwaysOnVpnTile> createState() => _AlwaysOnVpnTileState();
}

class _AlwaysOnVpnTileState extends State<_AlwaysOnVpnTile> with WidgetsBindingObserver {
  AlwaysOnStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await alwaysOnStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  String _subtitle() {
    const howTo =
        'Start Anywherelan when the device boots and keep it running with "Always-on VPN"'
        ' in the Android VPN settings. If you also choose "Block connections without VPN",'
        ' only your Anywherelan peers are reachable, unless you use a VPN gateway.';
    // Android reports the setting only to a running VPN, so a stopped awl
    // shows just the explanation.
    if (!isServerRunning()) return howTo;
    final status = _status;
    if (status != null && status.lockdown) {
      return status.routesAllTraffic
          ? 'On. Connections without VPN are blocked; all traffic goes through the VPN gateway.'
          : 'On. Connections without VPN are blocked: only your Anywherelan peers are reachable.';
    }
    if (status?.alwaysOn ?? false) return 'On.';
    return 'Off. $howTo';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text("Always-on VPN"),
      subtitle: Text(_subtitle()),
      leading: const Icon(Icons.restart_alt),
      trailing: const Icon(Icons.open_in_new),
      onTap: () async {
        final error = await openVpnSettings();
        if (error == "" || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text("Failed to open VPN settings: $error"),
          ),
        );
      },
    );
  }
}

class PickerResponse {
  final bool success;
  final String message;

  PickerResponse(this.success, this.message);
}
