import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invite_link.dart';
import 'package:anywherelan/invites_screen.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The label the quick one-time link is created with, and the key it is found
/// by when the dialog opens again. An ordinary invite label — it shows up as
/// the card's title on `/invites` like any other — so it is a hint, not a
/// contract; the reuse filter in [MyQRDialogState] checks the settings.
///
/// TODO: unused quick links pile up on `/invites`. `revoke` does not delete
/// and there is no delete endpoint, so nothing here can clean them. Planned in
/// `../awl`: prune unused invites carrying this label on server start, plus a
/// delete endpoint and "show finished links" folding on the invites screen.
const quickQRInviteLabel = 'Quick QR';

/// How long a quick one-time link lives: long enough to cover both uses of the
/// button — a device standing right here, and a link sent to someone who opens
/// it later in the day — and bounded so an unused one expires by itself.
const quickQRInviteTTL = Duration(hours: 12);

/// Shown with any link that carries no token, whoever it names — one sentence
/// in both dialogs because it is one fact.
const _tokenlessLinkNote =
    'Opening this link fills in the other side\'s "Add peer" form, '
    'but the request still has to be accepted.';

/// Shows another peer's shareable link with its QR code.
///
/// Always token-less: a token of ours grants entry to *this* device, and this
/// link names a different peer, so whoever opens it goes through an ordinary
/// friend request.
Future<void> showPeerQRDialog(BuildContext context, String peerID, String peerName) {
  return showDialog<void>(
    context: context,
    // AlertDialog, so title, content and actions share Material's own 24px
    // content edge: SimpleDialog zeroes its content's horizontal padding by
    // design, leaving anything but a SimpleDialogOption to hand-roll its own.
    builder: (context) => AlertDialog(
      title: Text('Link for "$peerName"'),
      // Scrolled by hand rather than with `scrollable: true`, this app's usual
      // way: that layout asks its content for intrinsic dimensions, and
      // `QrImageView` is built on a `LayoutBuilder`, which throws instead of
      // answering. A QR code is 320px tall, which no phone fits in landscape.
      content: SizedBox(
        // One width for every dialog of this flow.
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const InfoNote(icon: Icons.info_outline, text: _tokenlessLinkNote),
              const SizedBox(height: 12),
              LinkSharePanel(link: buildInviteLink(peerID, '', peerName)),
              const SizedBox(height: 8),
              // Worth showing on its own: a peer ID is what gets typed in by
              // hand and what logs and diagnostics speak in.
              CopyableField(
                label: 'Peer ID',
                value: peerID,
                copiedMessage: 'Peer ID copied to clipboard',
                tooltip: 'Copy peer ID',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    ),
  );
}

/// Shows this device's link, in one of two forms — see [QRMode].
Future<void> showMyQRDialog(BuildContext context, String peerID, String peerName) {
  return showDialog<void>(
    context: context,
    builder: (context) => MyQRDialog(peerID: peerID, peerName: peerName),
  );
}

/// What the QR code on screen currently means. Always opens on the harmless
/// one and the choice is never remembered: a link that lets a stranger in has
/// to be asked for each time.
enum QRMode {
  /// Who this device is. Whoever opens it still has to be accepted.
  myID,

  /// A single-use invite link: whoever opens it is added without an accept.
  oneTime,
}

/// Adapter for [MyQRDialogView]: owns the API call behind [QRMode.oneTime].
class MyQRDialog extends ConsumerStatefulWidget {
  final String peerID;
  final String peerName;

  const MyQRDialog({super.key, required this.peerID, required this.peerName});

  @override
  ConsumerState<MyQRDialog> createState() => MyQRDialogState();
}

/// Public, unlike the other adapters' states, so that the quick-link rules have
/// a name to be pointed at — [quickQRInviteLabel].
class MyQRDialogState extends ConsumerState<MyQRDialog> {
  /// Finds the quick link if one is still good, creates it otherwise. One
  /// pending quick link at a time; more than one, or any other settings, is
  /// what the invites screen is for.
  ///
  /// Fetches rather than reading [invitesProvider]: that cache is not polled,
  /// so the link it holds may already have been redeemed — and the backend is
  /// local, where a list request costs a millisecond.
  Future<QuickLinkResult> _quickLink() async {
    final api = ref.read(apiProvider);
    try {
      final invites = await api.fetchInvites();
      // Every setting the quick link is created with is restated here, because
      // the label is ordinary user-visible text that anyone can type into the
      // create form: a hand-made "Quick QR" link must not smuggle an alias or
      // exit-node rights into the one path that never grants them.
      final reusable = invites
          .where(
            (i) =>
                i.label == quickQRInviteLabel &&
                i.isActive &&
                i.maxUses == 1 &&
                i.usedCount == 0 &&
                i.alias.isEmpty &&
                !i.allowUsingAsExitNode,
          )
          .firstOrNull;

      final invite =
          reusable ??
          await api.createInvite(
            CreateInviteRequest(
              maxUses: 1,
              expiresInSeconds: quickQRInviteTTL.inSeconds,
              // The device that joins keeps the name it gives itself.
              alias: '',
              // Routing rights are granted deliberately, on the invites screen
              // or in peer settings — never by a shortcut.
              allowUsingAsExitNode: false,
              label: quickQRInviteLabel,
            ),
          );

      if (mounted) ref.invalidate(invitesProvider);
      return QuickLinkResult(invite: invite);
    } catch (e) {
      // Same unwrapping as the create form's: the API layer wraps everything
      // in an Exception, whose toString() prefix is not for the user.
      return QuickLinkResult(error: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyQRDialogView(
      peerID: widget.peerID,
      peerName: widget.peerName,
      onQuickLink: _quickLink,
      onManageLinks: () {
        // Held onto before the pop: afterwards this context is deactivated and
        // looking a Navigator up through it throws.
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushNamed(InvitesScreen.routeName);
      },
    );
  }
}

/// A quick link, or why there isn't one.
class QuickLinkResult {
  final Invite? invite;
  final String error;

  const QuickLinkResult({this.invite, this.error = ''});
}

/// Pure presentation widget for this device's link. Receives its data and its
/// one piece of I/O via constructor, so it pumps without a [ProviderContainer].
class MyQRDialogView extends StatefulWidget {
  final String peerID;
  final String peerName;
  final Future<QuickLinkResult> Function() onQuickLink;
  final VoidCallback onManageLinks;

  /// Injected so screenshots of a link's remaining life do not drift.
  final DateTime? now;

  const MyQRDialogView({
    super.key,
    required this.peerID,
    required this.peerName,
    required this.onQuickLink,
    required this.onManageLinks,
    this.now,
  });

  @override
  State<MyQRDialogView> createState() => _MyQRDialogViewState();
}

class _MyQRDialogViewState extends State<MyQRDialogView> {
  QRMode _mode = QRMode.myID;
  String _error = '';

  // TODO: close the loop. While a one-time link is on screen we hold its
  // invite ID, and `knownPeersProvider` is already polled every 3s — a peer
  // whose `inviteID` matches means the scan worked, and the QR code could
  // become "<name> joined". Today there is no confirmation at all, and the
  // user has to go and look at the peers list.
  Invite? _quickInvite;

  /// The one thing a local backend still needs guarding against: two taps
  /// arriving before the first round trip returns would create two links.
  bool _inFlight = false;

  Future<void> _onModeChanged(QRMode mode) async {
    if (mode == QRMode.myID) {
      setState(() {
        _mode = mode;
        _error = '';
      });
      return;
    }

    // Already fetched once while this dialog has been open — the link does not
    // change under us, so switching back and forth costs nothing.
    if (_quickInvite != null) {
      setState(() {
        _mode = mode;
        _error = '';
      });
      return;
    }

    if (_inFlight) return;
    _inFlight = true;
    // No spinner between here and the result: the backend is local and answers
    // in single-digit milliseconds, so a loading state would be a flicker.
    final result = await widget.onQuickLink();
    _inFlight = false;
    if (!mounted) return;

    setState(() {
      if (result.invite == null) {
        // Back to the mode that needs nothing from the backend, with the
        // reason on screen: an error stranded under an empty QR frame would
        // leave the dialog looking broken rather than unchanged.
        _mode = QRMode.myID;
        _error = result.error;
      } else {
        _mode = mode;
        _error = '';
        _quickInvite = result.invite;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oneTime = _mode == QRMode.oneTime;
    final invite = _quickInvite;
    final link = oneTime && invite != null
        ? invite.link
        : buildInviteLink(widget.peerID, '', widget.peerName);

    return AlertDialog(
      // The two modes differ by a token inside a long string and by the colour
      // of a note. The title is the largest text here and the one thing that
      // survives into a screenshot passed on to someone else, so it says which
      // of the two is on screen.
      title: Text(oneTime ? 'One-time invite link' : 'Your link'),
      // Scrolled by hand — see the note in [showPeerQRDialog].
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Centred rather than stretched to the content width: at 450 the
              // two segments become slabs with small labels adrift in them, and
              // the selected one outweighs everything else in the dialog. This
              // is a mode switch, not a field.
              Center(
                child: SegmentedButton<QRMode>(
                  segments: const [
                    ButtonSegment(value: QRMode.myID, label: Text('My ID')),
                    ButtonSegment(value: QRMode.oneTime, label: Text('One-time link')),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _onModeChanged(selection.first),
                ),
              ),
              const SizedBox(height: 12),
              // Terms first, as in every panel of this flow.
              if (oneTime && invite != null)
                InfoNote(
                  icon: Icons.key_outlined,
                  tone: NoteTone.warning,
                  text:
                      'Anyone who opens this link joins as your device, once, without your '
                      'approval. It ${inviteExpiryText(invite, now: widget.now)}.',
                )
              else
                const InfoNote(icon: Icons.info_outline, text: _tokenlessLinkNote),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 12),
              LinkSharePanel(
                link: link,
                copiedMessage: oneTime ? 'Invite link copied to clipboard' : 'Link copied to clipboard',
              ),
              const SizedBox(height: 8),
              CopyableField(
                label: 'Peer ID',
                value: widget.peerID,
                copiedMessage: 'Peer ID copied to clipboard',
                tooltip: 'Copy peer ID',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onManageLinks, child: const Text('Manage links')),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
