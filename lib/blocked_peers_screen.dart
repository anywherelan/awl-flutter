import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BlockedPeersScreen extends ConsumerStatefulWidget {
  static String routeName = "/blocked_peers";

  const BlockedPeersScreen({super.key});

  @override
  ConsumerState<BlockedPeersScreen> createState() => _BlockedPeersScreenState();
}

class _BlockedPeersScreenState extends ConsumerState<BlockedPeersScreen> {
  late final Future<List<BlockedPeer>> _blockedPeers = ref.read(apiProvider).fetchBlockedPeers();

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selected: AppSection.blockedPeers,
      appBar: AppBar(title: const Text('Blocked peers')),
      body: FutureBuilder<List<BlockedPeer>>(
        future: _blockedPeers,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final declinedPeers = snapshot.data!;
            List<Widget> peersWidgets = [];
            for (var peer in declinedPeers) {
              peersWidgets.add(_buildPeerCard(context, peer));
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectableText(
                    "All incoming requests from these peers are blocked. "
                    "Send friend invitation to a peer to remove it from the list.",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), children: peersWidgets),
                ),
              ],
            );
          } else if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(15.0), child: Text('Error: ${snapshot.error}'));
          }

          return Padding(padding: const EdgeInsets.all(15), child: const CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildPeerCard(BuildContext context, BlockedPeer peer) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(peer.displayName, style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: 10.0),
            SelectableText(
              "Peer ID ${peer.peerId}",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 6.0),
            SelectableText(
              "Blocked on ${peer.createdAt.toString()}",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
