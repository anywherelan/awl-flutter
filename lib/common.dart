import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

const redColor = Color.fromRGBO(214, 37, 69, 1);
const warnColor = Color.fromRGBO(231, 163, 45, 1);
const greenColor = Color.fromRGBO(82, 189, 44, 1);
const unknownColor = Color.fromRGBO(136, 77, 185, 1);

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
                Flexible(
                  fit: FlexFit.loose,
                  child: SelectableText(peerID),
                ),
                RawMaterialButton(
                  elevation: 0.0,
                  child: Icon(Icons.content_copy),
                  constraints: BoxConstraints.tightFor(
                    width: 40.0,
                    height: 50.0,
                  ),
                  shape: CircleBorder(),
                  onPressed: () {
                    var data = ClipboardData(text: peerID);
                    Clipboard.setData(data);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Peer ID copied to clipboard"),
                    ));
                  },
                ),
                RawMaterialButton(
                  elevation: 0.0,
                  child: Icon(Icons.share),
                  constraints: BoxConstraints.tightFor(
                    width: 40.0,
                    height: 50.0,
                  ),
                  shape: CircleBorder(),
                  onPressed: () {
                    Share.share(peerID);
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
                child: QrImage(
                  data: peerID,
                  version: QrVersions.auto,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                child: TextButton(
                  child: Text(
                    "CLOSE",
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          )
        ],
      );
    },
  );
}

final zeroGoTime = DateTime.fromMicrosecondsSinceEpoch(-62135596800000000, isUtc: true);

String formatDuration(Duration duration) {
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

//  tokens.add('${seconds}s');

  if (tokens.isEmpty) {
    tokens.add('0m');
  }

  return tokens.join(' ');
}

String formatNetworkStats(int total, double rate) {
  var totalStr = byteCountIEC(total);
  var rateStr = byteCountIEC(rate.round());

  return "$rateStr/s ($totalStr)";
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
