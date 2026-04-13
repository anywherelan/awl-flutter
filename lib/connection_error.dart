import 'package:anywherelan/providers.dart';
import 'package:anywherelan/server_interop/server_interop.dart' show initServer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget showDefaultServerConnectionError(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  return ServerConnectionError(
    onStartServer: kIsWeb
        ? null
        : () async {
            var startResponse = await initServer();

            if (startResponse != "") {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text(startResponse)),
              );
            } else {
              await refreshProvidersRepeated(container);
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
            Icon(Icons.cloud_off, size: 75, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Connection lost', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Unable to reach the server. '
              'Please make sure the server is running and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                if (onRetry != null) FilledButton(onPressed: onRetry, child: const Text('Retry')),
                if (onStartServer != null)
                  OutlinedButton(onPressed: onStartServer, child: const Text('Start Server')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
