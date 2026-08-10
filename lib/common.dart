import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

// Semantic status colors — fixed regardless of brand/theme seed
const errorColor = Color(0xFFBA1A1A);
const successColor = Color(0xFF1B6D2F);
const warningColor = Color(0xFFB8860B);

Color unknownStatusColor(BuildContext context) => Theme.of(context).colorScheme.secondary;

/// Compact, non-interactive status indicator. Used for labels like "Active",
/// "Connected", "Private NAT". Not a [Chip] because [Chip] is sized for
/// interactive filtering and has avatar/delete affordances we don't need.
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool withDot;

  const StatusPill({super.key, required this.text, required this.color, this.withDot = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

/// The "let them route through me" permission, as it appears in every form
/// that grants it: adding a peer, accepting an incoming request, and creating
/// an invite link.
///
/// Shared so the three cannot drift apart on control or wording, as they had.
/// A checkbox rather than a switch because these are forms applied on submit;
/// the settings screen, where the toggle acts on its own, keeps its switch.
class ExitNodePermissionField extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ExitNodePermissionField({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // `isThreeLine` puts the checkbox against the title: Material tops the
    // control only for three-line items, and cannot tell that a title plus a
    // subtitle wrapping to two lines is one. `contentPadding` is zeroed
    // because every caller embeds this in a form with its own padding.
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      isThreeLine: true,
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      // "this device" is always the one in the user's hands, here and in peer
      // settings; the other side is always named. Swap the referents and the
      // direction of a per-direction permission becomes a guess.
      title: const Text('Allow them to use this device as an exit node'),
      subtitle: Text(
        'They can route their internet traffic through this device '
        '(SOCKS5 proxy and VPN gateway).',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// A value the user is meant to take away rather than read: a link, a peer ID.
/// Rendered as a field so that seventy-odd characters of base58 read as a value
/// with a copy button on it instead of as a paragraph.
///
/// The value stays **in full and selectable**, however many lines that takes,
/// and copying is a button beside it rather than a tap on the field. Truncating
/// to one line is tidier and must not happen: on the web build served over
/// plain HTTP `Clipboard.setData` throws (`navigator.clipboard` is
/// secure-context-only), so hand-selecting the text is the only copy path that
/// works there, and it needs the whole value on screen.
///
/// The button answers in place, the tick replacing the icon for two seconds: a
/// [SnackBar] raised inside a dialog lands at the bottom of the screen, far
/// from what was clicked. It raises one anyway, for the short dialogs where the
/// two are close.
class CopyableField extends StatefulWidget {
  final String value;

  /// Names the value inside the field ("Peer ID"). Not copied — only [value]
  /// reaches the clipboard.
  final String? label;

  /// What the SnackBar says. Invite links call themselves by name there.
  final String copiedMessage;

  /// The copy button's tooltip and accessible name.
  final String tooltip;

  final TextStyle? style;

  /// A second affordance acting on the same [value], drawn beside Copy. Typed
  /// rather than a general list of trailing widgets: there is exactly one, and
  /// fixing its icon and its place here is what stops the panels that use this
  /// field from each arranging them differently.
  ///
  /// Optional because the Peer ID fields must not offer it: a bare peer id has
  /// no scheme and no deep link, so the receiving app cannot act on it. The
  /// shareable form of an identity is the link, in the same dialog above it.
  final VoidCallback? onShare;

  final String shareTooltip;

  const CopyableField({
    super.key,
    required this.value,
    required this.copiedMessage,
    required this.tooltip,
    this.label,
    this.style,
    this.onShare,
    this.shareTooltip = 'Share',
  });

  @override
  State<CopyableField> createState() => _CopyableFieldState();
}

class _CopyableFieldState extends State<CopyableField> {
  static const _tickDuration = Duration(seconds: 2);

  Timer? _tickTimer;
  bool _copied = false;

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.copiedMessage)));
    setState(() => _copied = true);
    _tickTimer?.cancel();
    _tickTimer = Timer(_tickDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        // Top-aligned: the value wraps to as many lines as it needs, and the
        // button belongs beside its first line.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.label!,
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 5),
              // TODO: a monospaced face would help — these values are base58
              // and base64url, verified by comparing the first and last few
              // characters, where Roboto's `l`, `1` and `I` are one glyph. It
              // costs an asset: `fontFamily: 'monospace'` resolves to the
              // platform font on a device and to nothing under `flutter test`,
              // so the goldens would stop showing what the user sees. Bundling
              // RobotoMono and registering it in `loadTestFonts()` is the fix.
              child: SelectableText(widget.value, style: widget.style ?? theme.textTheme.bodyMedium),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _copy,
            tooltip: widget.tooltip,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            // The same green the rest of the app uses for a good outcome. Not
            // a state the button can be left in, so no selected styling.
            icon: Icon(_copied ? Icons.check : Icons.content_copy),
            color: _copied ? successColor : colorScheme.onSurfaceVariant,
          ),
          if (widget.onShare != null)
            IconButton(
              onPressed: widget.onShare,
              tooltip: widget.shareTooltip,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.share),
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

/// One `awl://` link as every place that shows one presents it: the link in a
/// [CopyableField] with Copy and Share on it, the QR code under it.
///
/// Three callers — this device's QR, a peer's QR, an invite link — used to
/// carry their own copy of this row.
///
/// Copy and Share belong to the field, not to the dialog's action row, the way
/// "Scan QR" belongs to the add-peer input — and they sit *inside* it. Beside
/// it, Share cost the field 48px of width, leaving it visibly narrower than the
/// Peer ID field stacked under it, and floated centred against a value that
/// wraps to six lines on a phone.
class LinkSharePanel extends StatelessWidget {
  final String link;
  final String copiedMessage;

  const LinkSharePanel({super.key, required this.link, this.copiedMessage = 'Link copied to clipboard'});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CopyableField(
          value: link,
          copiedMessage: copiedMessage,
          tooltip: 'Copy link',
          onShare: () => SharePlus.instance.share(ShareParams(text: link)),
          shareTooltip: 'Share link',
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            // Tight in name only: `BoxConstraints.enforce` clamps it to the
            // space the dialog actually has, so the code shrinks to fit a
            // phone instead of overflowing. 320 is what it takes on a desktop.
            constraints: const BoxConstraints.tightFor(width: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // White, not the surface colour: the modules are drawn black, so
              // a transparent background is unscannable on a dark theme. The
              // padding is the quiet zone scanners need; the border keeps the
              // white square from floating edgeless on a light background.
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: QrImageView(
              data: link,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
              semanticsLabel: 'QR code of the link',
            ),
          ),
        ),
      ],
    );
  }
}

/// Tone of an [InfoNote]: plain explanation, or the terms of something the
/// reader is about to hand out.
enum NoteTone { neutral, warning }

/// A short block of explanation attached to what sits above or below it —
/// the shape the create form's summary established, reused wherever a screen
/// has to say what a thing *means* rather than what it is.
class InfoNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final NoteTone tone;

  const InfoNote({super.key, required this.icon, required this.text, this.tone = NoteTone.neutral});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warning = tone == NoteTone.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning ? warningColor.withValues(alpha: 0.12) : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: warning ? warningColor : colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

final zeroGoTime = DateTime.fromMicrosecondsSinceEpoch(-62135596800000000, isUtc: true);

String formatDurationRough(Duration duration) {
  if (duration.inDays.abs() >= 1) {
    return '${duration.inDays.abs()}d';
  }
  return formatDuration(duration);
}

String formatDuration(Duration duration) {
  if (duration.inMicroseconds == 0) {
    return "–";
  }

  var seconds = duration.inSeconds > 0 ? duration.inSeconds : duration.inSeconds * -1;
  final days = seconds ~/ Duration.secondsPerDay;
  seconds -= days * Duration.secondsPerDay;
  final hours = seconds ~/ Duration.secondsPerHour;
  seconds -= hours * Duration.secondsPerHour;
  final minutes = seconds ~/ Duration.secondsPerMinute;
  seconds -= minutes * Duration.secondsPerMinute;

  final List<String> tokens = [];
  if (days != 0) {
    tokens.add('${days}d');
  }
  if (tokens.isNotEmpty || hours != 0) {
    tokens.add('${hours}h');
  }
  if (tokens.isNotEmpty || minutes != 0) {
    tokens.add('${minutes}m');
  }

  if (tokens.isEmpty) {
    tokens.add('0m');
  }

  return tokens.join(' ');
}

String formatNetworkStats(int total, double rate) {
  var totalStr = byteCountIEC(total);
  var rateStr = byteCountIEC(rate.round());

  return "$rateStr/s · $totalStr total";
}

String byteCountIEC(int b) {
  String format(double n) {
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  const unit = 1024;
  if (b < unit) {
    return "$b B";
  }
  int div = unit;
  int exp = 0;

  for (var n = b / unit; n >= unit; n = n / unit) {
    div *= unit;
    exp++;
  }

  double val = b / div;

  return "${format(val)} ${"KMGTPE"[exp]}iB";
}
