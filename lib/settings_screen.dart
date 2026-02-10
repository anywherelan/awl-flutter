import 'dart:async';
import 'dart:convert';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

class AppSettingsScreen extends StatefulWidget {
  static String routeName = "/settings";

  AppSettingsScreen({Key? key}) : super(key: key);

  @override
  _AppSettingsScreenState createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  Future<PickerResponse> _exportSettings() async {
    final exportedSettings = await fetchExportedServerConfig(http.Client());
    try {
      String? response;
      if (kIsWeb) {
        response = await FileSaver.instance
            .saveFile(name: "config_awl", bytes: exportedSettings, fileExtension: "json", mimeType: MimeType.json);
      } else {
        // saveAs is not implemented on web
        // see https://github.com/incrediblezayed/file_saver/issues/130
        response = await FileSaver.instance
            .saveAs(name: "config_awl", bytes: exportedSettings, fileExtension: "json", mimeType: MimeType.json);
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
    try {
      FilePickerResult? result;
      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["json"], withData: true);
      } else {
        result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["json"], withData: true);
      }

      if (result == null) {
        return PickerResponse(true, "");
      }

      final fileBytes = result.files.first.bytes;
      final fileString = utf8.decode(fileBytes!.toList());
      final fileName = result.files.first.name;

      await stopServer();
      var importResponse = await importConfig(fileString);
      var startResponse = await initServer();

      if (importResponse != "") {
        return PickerResponse(false, importResponse);
      } else if (startResponse != "") {
        return PickerResponse(false, startResponse);
      }

      fetchAllDataAfterStart();

      return PickerResponse(true, "Imported file $fileName");
    } on Exception catch (e) {
      return PickerResponse(false, "Failed to import config file: ${e.toString()}, error: ${e.toString()}");
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
            ListTile(
              title: Text(
                "Export settings",
              ),
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
                    " Server will be restarted automatically with new configuration."),
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
