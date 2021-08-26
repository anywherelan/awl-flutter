import 'dart:async';
import 'dart:io';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AppSettingsScreen extends StatefulWidget {
  AppSettingsScreen({Key? key}) : super(key: key);

  @override
  _AppSettingsScreenState createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  Future<PickerResponse> _exportSettings() async {
    var tempDir = await getTemporaryDirectory();

    var f = File('${tempDir.path}/config.json');
    var exportedSettings = await fetchExportedServerConfig(http.Client());

    var newFile = await f.writeAsString(exportedSettings);

    final params = SaveFileDialogParams(
      sourceFilePath: f.path,
    );

    try {
      final filePath = await FlutterFileDialog.saveFile(params: params);

      newFile.deleteSync();
      if (filePath == null) {
        return PickerResponse(true, "");
      }

      return PickerResponse(true, "Settings have been exported");
    } on PlatformException catch (e) {
      newFile.deleteSync();
      return PickerResponse(false, "Failed pick config file path: ${e.message}, ${e.details}");
    }
  }

  Future<PickerResponse> _importSettings() async {
    final params = OpenFileDialogParams(
      dialogType: OpenFileDialogType.document,
      sourceType: SourceType.photoLibrary,
      fileExtensionsFilter: <String>["json"],
    );

    try {
      final filePath = await FlutterFileDialog.pickFile(params: params);

      if (filePath == null) {
        return PickerResponse(true, "");
      }

      var f = File(filePath);
      String content = await f.readAsString();
      await stopServer();
      var response = await importConfig(content);
      await initServer();

      if (response != "") {
        return PickerResponse(false, response);
      }

      return PickerResponse(true, "Imported file $filePath");
    } on PlatformException catch (e) {
      return PickerResponse(false, "Failed to pick config file: ${e.message}, ${e.details}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            if (!kIsWeb)
              ListTile(
                title: Text(
                  "Export settings",
                ),
//                subtitle: Text(
//                    "You can restore them later."
//                ),
                enabled: true,
                selected: false,
                leading: const Icon(Icons.import_export),
                onTap: () async {
                  var result = await _exportSettings();
                  if (result.message != "") {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: result.success ? Colors.green : Colors.red,
                      content: Text(result.message),
                    ));
                  }
                },
              ),
            if (!kIsWeb)
              ListTile(
                title: Text(
                  "Import settings",
                ),
                subtitle: Text(
                    "This action will overwrite current settings, therefore it is recommended to export them first."
                    " Server will be restarted automatically."),
                enabled: true,
                selected: false,
                leading: const Icon(Icons.import_export),
                onTap: () async {
                  var result = await _importSettings();
                  if (result.message != "") {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: result.success ? Colors.green : Colors.red,
                      content: Text(result.message),
                    ));
                  }
                },
              ),
            if (!kIsWeb)
              ListTile(
                title: Text(
                  "Request ignore battery optimizations",
                ),
                enabled: true,
                selected: false,
                leading: const Icon(Icons.adb),
                onTap: () async {
                  var status = await Permission.ignoreBatteryOptimizations.request();
                  if (status == PermissionStatus.granted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.green,
                      content: Text("Permission granted"),
                    ));
                  } else if (status == PermissionStatus.denied) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: Colors.red,
                      content: Text("Permission denied"),
                    ));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class PickerResponse {
  final bool success;
  final String message;

  PickerResponse(this.success, this.message);
}
