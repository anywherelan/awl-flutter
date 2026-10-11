import 'dart:math' as math;

import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adapter for [BlockedPeersView] that reads [blockedPeersProvider] and wires
/// the unblock call. The pure presentation logic lives in [BlockedPeersView].
class BlockedPeersScreen extends ConsumerStatefulWidget {
  static String routeName = "/blocked_peers";

  const BlockedPeersScreen({super.key});

  @override
  ConsumerState<BlockedPeersScreen> createState() => _BlockedPeersScreenState();
}

class _BlockedPeersScreenState extends ConsumerState<BlockedPeersScreen> {
  Future<void> _onUnblock(BlockedPeer peer) async {
    final confirmed = await showUnblockPeerDialog(context, peer);
    if (!confirmed || !mounted) return;

    String response;
    try {
      response = await ref.read(apiProvider).unblockPeer(peer.peerId);
    } catch (e) {
      response = e.toString();
    }
    if (!mounted) return;

    // Also after a failure: the likeliest reason for one is a list that went
    // stale, the peer having been unblocked from somewhere else.
    ref.invalidate(blockedPeersProvider);

    final failed = response.isNotEmpty;
    final name = blockedPeerName(peer);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: failed ? Theme.of(context).colorScheme.error : null,
        content: Text(
          failed
              ? 'Failed to unblock peer: $response'
              : (name.isNotEmpty ? '"$name" unblocked' : 'Peer unblocked'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final peers = ref.watch(blockedPeersProvider);

    return AppShell(
      selected: AppSection.blockedPeers,
      appBar: AppBar(title: const Text('Blocked peers')),
      body: BlockedPeersView(
        peers: peers.valueOrNull,
        error: peers.hasError ? peers.error.toString() : null,
        onUnblock: _onUnblock,
      ),
    );
  }
}

/// Pure presentation widget for the blocked peers screen. Receives all data via
/// constructor params; never reads global services. Tests target this widget
/// directly with fixture data.
class BlockedPeersView extends StatelessWidget {
  final List<BlockedPeer>? peers;
  final String? error;
  final Future<void> Function(BlockedPeer)? onUnblock;

  /// Clock the "blocked …" lines are measured against. Defaults to the wall
  /// clock; see [blockedSinceText].
  final DateTime? now;

  const BlockedPeersView({super.key, required this.peers, this.error, this.onUnblock, this.now});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error!, style: TextStyle(color: colorScheme.error)),
        ),
      );
    }
    if (peers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final peerList = peers!;

    // The column is capped by padding the list rather than by boxing it in: the
    // list keeps the full width, so the scrollbar sits at the window's edge and
    // the wheel scrolls from anywhere, not only from over the column.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = 16.0 + math.max(0.0, (constraints.maxWidth - listColumnMaxWidth) / 2);
        final padding = EdgeInsets.fromLTRB(gutter, 16, gutter, 16);

        if (peerList.isEmpty) {
          return ListView(padding: padding, children: [_buildEmptyState(context)]);
        }
        return ListView.builder(
          padding: padding,
          itemCount: peerList.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildCaption(context);
            return _buildCard(context, peerList[index - 1]);
          },
        );
      },
    );
  }

  /// Says the one thing the list cannot: how a peer nobody "blocked" got here.
  Widget _buildCaption(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'Peers you declined or removed. Their friend requests are declined automatically '
        'until you unblock them or add them again.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.block, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('No blocked peers', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A peer is blocked when you decline their friend request or remove them from your peers. '
            'Their requests are then declined automatically.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, BlockedPeer peer) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = blockedPeerName(peer);
    final since = blockedSinceText(peer.createdAt, now: now);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // The right inset is the button's: its label has to end where the
        // other cards' content does, and it brings padding of its own.
        padding: const EdgeInsets.fromLTRB(_cardInset, 14, _cardInset - _unblockButtonPadding, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One line, always: the name is whatever the peer called
                  // itself, and a newline in it would open a second line in
                  // the title's own style.
                  Text(
                    name.isNotEmpty ? name : 'Unnamed peer',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (since.isNotEmpty) ...[const SizedBox(height: 2), Text(since, style: metaStyle)],
                  const SizedBox(height: 2),
                  // In full, because it is what tells two peers of one name
                  // apart, and selectable rather than behind a copy button: it
                  // is read here far more often than it is taken anywhere.
                  SelectableText(peer.peerId, style: metaStyle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: _unblockButtonPadding),
              ),
              onPressed: () => onUnblock?.call(peer),
              child: const Text('Unblock peer'),
            ),
          ],
        ),
      ),
    );
  }
}

const _cardInset = 16.0;
const _unblockButtonPadding = 12.0;

/// The name a blocked peer is listed under, or "" when it has none: whatever it
/// called itself when its request was declined, or our own alias for it when it
/// was removed.
String blockedPeerName(BlockedPeer peer) => peer.displayName.trim();

/// When the peer was blocked, in the same words the invites screen dates a
/// link: `blocked today at 14:20`, `blocked 3 Aug`, `blocked 3 Aug 2025`.
/// Empty for an entry that carries no date.
String blockedSinceText(DateTime at, {DateTime? now}) {
  if (!at.isAfter(zeroGoTime)) return '';
  return 'blocked ${pastMomentText(at, now: now)}';
}

/// Confirms unblocking. Asked because it cannot be taken back from here, there
/// being no way to block a peer by its ID, and because "Unblock" otherwise
/// reads as "let them back in".
Future<bool> showUnblockPeerDialog(BuildContext context, BlockedPeer peer) async {
  final name = blockedPeerName(peer);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unblock peer'),
      content: Text(
        '${name.isNotEmpty ? '"$name"' : 'This peer'} will be able to send you friend requests again. '
        'Unblocking does not add them to your peers.',
      ),
      // Nothing is destroyed, so neither button takes the error colour.
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unblock peer')),
      ],
    ),
  );
  return confirmed == true;
}
