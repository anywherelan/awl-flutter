import 'package:anywherelan/server_interop/server_interop.dart' show initServer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data_service.dart' show fetchAllDataAfterStart;

Widget showDefaultServerConnectionError(BuildContext context) {
  return ServerConnectionError(
    onStartServer: kIsWeb
        ? null
        : () async {
            var startResponse = await initServer();

            if (startResponse != "") {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(startResponse)));
            } else {
              await fetchAllDataAfterStart();
            }
          },
  );
}

class ServerConnectionError extends StatelessWidget {
  final VoidCallback? onStartServer;
  final VoidCallback? onRetry;

  const ServerConnectionError({super.key, this.onRetry, this.onStartServer});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 75, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Connection lost', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Unable to reach the server. '
              'Please make sure the server is running and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                if (onRetry != null) ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
                if (onStartServer != null) OutlinedButton(onPressed: onStartServer, child: const Text('Start Server')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
