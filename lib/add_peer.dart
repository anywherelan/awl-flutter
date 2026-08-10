import 'dart:io';

import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/invite_link.dart';
import 'package:anywherelan/invites_screen.dart' show InvitesScreen;
import 'package:anywherelan/providers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:permission_handler/permission_handler.dart';

/// [initialInput] prefills the link/peer-id field — used when the form is
/// opened from an `awl://` deep link rather than by the user.
Future<void> showAddPeerDialog(BuildContext context, {String? initialInput}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AddPeerDialog(initialInput: initialInput),
  );
}

/// Adapter for [AddPeerDialogView]: owns the API call, the QR scanner and the
/// navigation the form triggers. The pure presentation logic lives in
/// [AddPeerDialogView].
class AddPeerDialog extends ConsumerStatefulWidget {
  final String? initialInput;

  const AddPeerDialog({super.key, this.initialInput});

  @override
  ConsumerState<AddPeerDialog> createState() => _AddPeerDialogState();
}

class _AddPeerDialogState extends ConsumerState<AddPeerDialog> {
  Future<String> _onSubmit(FriendRequest request) async {
    final response = await ref.read(apiProvider).sendFriendRequest(request);
    if (response == "") {
      await ref.read(knownPeersProvider.notifier).refresh();
    }
    return response;
  }

  /// Returns the scanned text, or null when scanning is unavailable, denied or
  /// cancelled. Both a peer ID and a whole invite link can be scanned — the
  /// form decides which one it got.
  Future<String?> _onScanQR() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted || !mounted) return null;

    return Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (BuildContext context) => QRScanPage()));
  }

  void _onCreateInviteLink() {
    // Grab the navigator before popping: the dialog's context is defunct afterwards.
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.pushNamed(InvitesScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return AddPeerDialogView(
      initialInput: widget.initialInput,
      onSubmit: _onSubmit,
      onScanQR: kIsWeb ? null : _onScanQR,
      onCreateInviteLink: _onCreateInviteLink,
      onDone: () => Navigator.pop(context),
    );
  }
}

/// Pure presentation widget for the add-peer dialog. Receives its callbacks via
/// constructor; never reads global services. Tests target this widget directly.
///
/// The form is progressive: it starts as a single "Link or Peer ID" field and
/// only unfolds the rest once there is something to add. Pasting an `awl://`
/// link prefills the name from it; a link that carries a token additionally
/// says so — that peer will accept us automatically, with no manual accept on
/// their side. A token-less link is the shareable form of a plain peer ID and
/// behaves exactly like one.
class AddPeerDialogView extends StatefulWidget {
  /// Prefilled link or peer ID. Set when the form is opened from an `awl://`
  /// deep link, so it starts unfolded and already parsed.
  final String? initialInput;

  /// Performs the request; returns "" on success or the server error message.
  final Future<String> Function(FriendRequest) onSubmit;

  /// Opens a QR scanner and returns its text. Null hides the scan button.
  final Future<String?> Function()? onScanQR;

  /// Navigates to the invite links screen. Null hides the shortcut.
  final VoidCallback? onCreateInviteLink;

  /// Called after a successful submit (the dialog closes itself this way).
  final VoidCallback? onDone;

  const AddPeerDialogView({
    super.key,
    this.initialInput,
    required this.onSubmit,
    this.onScanQR,
    this.onCreateInviteLink,
    this.onDone,
  });

  @override
  State<AddPeerDialogView> createState() => _AddPeerDialogViewState();
}

class _AddPeerDialogViewState extends State<AddPeerDialogView> {
  final _peerIdTextController = TextEditingController();
  final _aliasTextController = TextEditingController();
  final _ipAddrTextController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _focusAlias = FocusNode();

  String _serverError = "";
  bool _allowUsingAsExitNode = false;

  /// Parsed invite link, when the input field holds one.
  InviteLink? _invite;

  /// Set when the input looks like an awl link but cannot be used.
  String? _linkError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialInput;
    if (initial != null && initial.isNotEmpty) {
      _peerIdTextController.text = initial;
      _parseInput(initial);
    }
  }

  @override
  void dispose() {
    _peerIdTextController.dispose();
    _aliasTextController.dispose();
    _ipAddrTextController.dispose();
    _focusAlias.dispose();
    super.dispose();
  }

  void _onInputChanged(String value) {
    setState(() => _parseInput(value));
  }

  /// Re-reads the input field. Anything that is not an `awl://` link is taken
  /// as a plain peer ID — the previous way of adding a peer still works.
  ///
  /// Mutates state without notifying, so it can also run from [initState] for
  /// a prefilled link; callers outside of it wrap it in `setState`.
  void _parseInput(String value) {
    final previousName = _invite?.name ?? '';
    InviteLink? invite;
    String? linkError;
    try {
      invite = parseInviteLink(value);
    } on NotAnInviteLink {
      // Not a link: a peer ID (or still being typed).
    } on InviteLinkException catch (e) {
      linkError = e.message;
    }

    // Prefill the name from the link, but never overwrite what the user typed.
    // The name we put there ourselves is ours to take back too: swapping the
    // link (or replacing it with a bare peer id) must not leave the previous
    // creator's name attached to a different peer.
    final name = invite?.name ?? '';
    final aliasIsOurs = _aliasTextController.text.isEmpty || _aliasTextController.text == previousName;
    if (aliasIsOurs && _aliasTextController.text != name) {
      _aliasTextController.text = name;
    }

    _invite = invite;
    _linkError = linkError;
  }

  void _onPressAdd() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final invite = _invite;
    final response = await widget.onSubmit(
      FriendRequest(
        invite?.peerID ?? _peerIdTextController.text.trim(),
        _aliasTextController.text.trim(),
        _ipAddrTextController.text.trim(),
        allowUsingAsExitNode: _allowUsingAsExitNode,
        token: invite?.token ?? '',
      ),
    );
    if (!mounted) return;
    if (response == "") {
      _serverError = "";
      _formKey.currentState!.validate();
      widget.onDone?.call();
    } else {
      _serverError = response;
      _formKey.currentState!.validate();
      _serverError = "";
    }
  }

  void _scanQR() async {
    final result = await widget.onScanQR?.call();
    if (result == null || result.isEmpty || !mounted) {
      return;
    }

    _peerIdTextController.text = result;
    _onInputChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = _peerIdTextController.text.trim().isNotEmpty;
    final isInvite = _invite != null;
    // The token is what makes a link an invitation; without one the link only
    // carries an identity, and promising an automatic accept would be a lie.
    final redeemsInvite = _invite?.token.isNotEmpty ?? false;

    return AlertDialog(
      scrollable: true,
      title: const Text('Add peer'),
      content: SizedBox(width: 450, child: _buildForm(context, hasInput, isInvite, redeemsInvite)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _onPressAdd, child: const Text('Add peer')),
      ],
    );
  }

  Widget _buildForm(BuildContext context, bool hasInput, bool isInvite, bool redeemsInvite) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No per-field padding: the dialog supplies Material's 24px content
          // edge, and the gaps between fields are spacing, not padding.
          TextFormField(
            validator: (value) {
              if (value!.trim().isEmpty) {
                return 'Please enter an invite link or peer id';
              } else if (_linkError != null) {
                return _linkError;
              } else if (_serverError != "") {
                return _serverError;
              }
              return null;
            },
            controller: _peerIdTextController,
            decoration: InputDecoration(
              labelText: 'Invite link or Peer ID',
              errorText: _linkError,
              errorMaxLines: 3,
              // Scanning fills *this* field, so the button belongs to it rather
              // than to the dialog's action row — it is a way to enter the
              // value, not a way to finish the dialog.
              suffixIcon: widget.onScanQR == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scan QR code',
                      onPressed: _scanQR,
                    ),
            ),
            // An invite link runs ~110 characters and wraps to three lines
            // at this width; two would silently cut its tail off.
            maxLines: 3,
            minLines: 1,
            textInputAction: TextInputAction.next,
            onChanged: _onInputChanged,
            onFieldSubmitted: (v) {
              FocusScope.of(context).requestFocus(_focusAlias);
            },
          ),
          if (hasInput && _linkError == null) ...[
            SizedBox(height: 16),
            TextFormField(
              controller: _aliasTextController,
              focusNode: _focusAlias,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: isInvite ? 'Taken from the link, you can change it' : null,
              ),
              validator: (value) {
                if (value!.trim().isEmpty) {
                  return 'Please enter peer name';
                }
                return null;
              },
            ),
            SizedBox(height: 4),
            ExitNodePermissionField(
              value: _allowUsingAsExitNode,
              onChanged: (value) => setState(() => _allowUsingAsExitNode = value),
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _ipAddrTextController,
              decoration: InputDecoration(
                labelText: 'Local IP address',
                helperText: 'optional, example: 10.66.0.2',
              ),
              autovalidateMode: AutovalidateMode.onUnfocus,
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return null;
                }

                try {
                  // TODO: support ipv6
                  Uri.parseIPv4Address(value);
                  return null;
                } catch (e) {
                  return 'Invalid IPv4 address format';
                }
              },
            ),
            if (redeemsInvite) ...[
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You'll connect using an invite link. They'll accept you automatically "
                      "once online, with no action needed on their side.",
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
          // Navigation, not an action of this dialog, so it stays in the
          // content rather than joining Cancel and Add peer below.
          if (widget.onCreateInviteLink != null) ...[
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(Icons.add_link, size: 18),
                label: Text('Or invite someone with a link'),
                onPressed: widget.onCreateInviteLink,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      Navigator.of(context).pop(_result);
      return const Scaffold();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Invite link / PeerID QR Scanner')),
      backgroundColor: Colors.black,
      body: ReaderWidget(
        cropPercent: 0.9,
        onScan: (Code code) {
          if (_result == null && code.isValid && (code.text ?? '').isNotEmpty) {
            setState(() => _result = code.text);
          }
        },
      ),
    );
  }
}
