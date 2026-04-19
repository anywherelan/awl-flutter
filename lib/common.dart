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

Future<void> showQRDialog(BuildContext context, String peerID, String peerName) async {
  await showDialog(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text('Peer ID for "$peerName"'),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.0, vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(fit: FlexFit.loose, child: SelectableText(peerID)),
                IconButton(
                  icon: Icon(Icons.content_copy),
                  onPressed: () {
                    var data = ClipboardData(text: peerID);
                    Clipboard.setData(data);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Peer ID copied to clipboard")));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(text: peerID));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: Center(
              child: Container(
                constraints: BoxConstraints.tightFor(width: 350),
                alignment: Alignment.center,
                child: QrImageView(data: peerID),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: FilledButton(
                  child: Text("Close"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
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
