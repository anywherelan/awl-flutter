import 'dart:async';
import 'dart:io';

import 'package:anywherelan/api.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/server_interop/server_interop.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
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
        response = await FileSaver.instance.saveFile("config_awl", exportedSettings, "json", mimeType: MimeType.JSON);
      } else {
        final params = SaveFileDialogParams(data: exportedSettings, fileName: "config_awl.json");
        response = await FlutterFileDialog.saveFile(params: params);
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
    final params = OpenFileDialogParams(
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
      var importResponse = await importConfig(content);
      var startResponse = await initServer();

      if (importResponse != "") {
        return PickerResponse(false, importResponse);
      } else if (startResponse != "") {
        return PickerResponse(false, startResponse);
      }

      fetchAllData();
      return PickerResponse(true, "Imported file $filePath");
    } on PlatformException catch (e) {
      return PickerResponse(false, "Failed to pick config file: ${e.message}, ${e.details}");
    }
  }

  // web + android implementation by file_picker package. one downside is that it requests storage permission on android
  // while flutter_file_dialog does not.
  // Future<PickerResponse> _importSettingsFlutterPicker() async {
  //   try {
  //     FilePickerResult? result;
  //     if (kIsWeb) {
  //       result =
  //           await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ["json"], withData: true);
  //     } else {
  //       result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  //     }
  //
  //     if (result == null) {
  //       return PickerResponse(true, "");
  //     }
  //
  //     final fileBytes = result.files.first.bytes;
  //     final fileString = utf8.decode(fileBytes!.toList());
  //     final fileName = result.files.first.name;
  //
  //     await stopServer();
  //     var response = await importConfig(fileString);
  //     await initServer();
  //
  //     if (response != "") {
  //       return PickerResponse(false, response);
  //     }
  //
  //     return PickerResponse(true, "Imported file $fileName");
  //   } on Exception catch (e) {
  //     return PickerResponse(false, "Failed to import config file: ${e.toString()}");
  //   }
  // }

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
