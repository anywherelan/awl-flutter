import 'package:anywherelan/common.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/peer_settings_screen.dart' show KnownPeerSettingsScreen;
import 'package:flutter/material.dart';

class PeersListPage extends StatefulWidget {
  PeersListPage({Key? key}) : super(key: key);

  @override
  _PeersListPageState createState() => _PeersListPageState();
}

class _PeersListPageState extends State<PeersListPage> {
  List<KnownPeer>? _knownPeers;
  Map<String?, bool> _expandedState = Map();

  void _onNewKnownPeers(List<KnownPeer>? newPeers) async {
    if (!this.mounted) {
      return;
    }
    setState(() {
      _knownPeers = newPeers;
    });
  }

  @override
  void initState() {
    super.initState();

    _knownPeers = knownPeersDataService.getData();
    knownPeersDataService.subscribe(_onNewKnownPeers);
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
    knownPeersDataService.unsubscribe(_onNewKnownPeers);
  }

  @override
  Widget build(BuildContext context) {
    if (_knownPeers == null || _knownPeers!.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints.expand(height: 80),
        child: Container(
          margin: EdgeInsets.only(top: 10),
          alignment: Alignment.topCenter,
          child: Text(
            "No known peers",
            style: Theme.of(context).textTheme.headline6,
          ),
        ),
      );
    }

    var expansionList = ExpansionPanelList(
      expandedHeaderPadding: EdgeInsets.only(top: 5, bottom: 5),
      expansionCallback: (int index, bool isExpanded) {
        setState(() {
          var peer = _knownPeers![index];
          _expandedState[peer.peerID] = !isExpanded;
        });
      },
      children: _knownPeers!.map<ExpansionPanel>((KnownPeer item) {
        var isExpanded = _expandedState[item.peerID];
        if (isExpanded == null) {
          isExpanded = false;
          _expandedState[item.peerID] = false;
        }

        return ExpansionPanel(
          headerBuilder: (BuildContext context, bool isExpanded) {
            return _buildRowTitle(context, item);
          },
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 24, 24),
            child: _buildExpansionPanelBody(item),
          ),
          isExpanded: isExpanded,
          canTapOnHeader: true,
        );
      }).toList(),
    );

    return SingleChildScrollView(
      child: expansionList,
    );
  }

  Widget _buildRowTitle(BuildContext context, KnownPeer peer) {
    Text trailingText;
    if (peer.declined) {
      trailingText = Text("Rejected", style: TextStyle(color: redColor));
    } else if (!peer.confirmed) {
      trailingText = Text("Not accepted", style: TextStyle(color: unknownColor));
    } else if (!peer.connected) {
      trailingText = Text("Disconnected", style: TextStyle(color: redColor));
    } else {
      trailingText = Text("Connected", style: TextStyle(color: greenColor));
    }

    var isThreeLine = false;
    var subtitle = peer.ipAddr;
    if (peer.domainName.isNotEmpty) {
      subtitle = subtitle + "\n" + peer.domainName + ".awl";
      isThreeLine = true;
    }

    return ListTile(
      title: Text(
        peer.displayName,
        style: Theme.of(context).textTheme.headline6,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      isThreeLine: isThreeLine,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          trailingText,
        ],
      ),
    );
  }

  Widget _buildExpansionPanelBody(KnownPeer item) {
    return Column(
      children: [
        if (!item.connected && item.confirmed)
          _buildBodyItem(Icons.visibility_outlined, "Last seen",
              "${formatDuration(item.lastSeen.difference(DateTime.now()))} ago"),
        if (item.connections.isNotEmpty)
          _buildBodyItem(Icons.place_outlined, "Connection", item.connections.join('\n\n')),
        if (item.version.isNotEmpty) _buildBodyItem(Icons.label_outlined, "Version", item.version),
        if (item.networkStats.totalIn != 0)
          _buildBodyItem(Icons.cloud_download_outlined, "Download rate", item.networkStats.inAsString()),
        if (item.networkStats.totalOut != 0)
          _buildBodyItem(Icons.cloud_upload_outlined, "Upload rate", item.networkStats.outAsString()),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              icon: Icon(
                Icons.qr_code,
                color: Colors.black87,
              ),
              label: Text("SHOW ID"),
              onPressed: () async {
                knownPeersDataService.unsubscribe(_onNewKnownPeers);
                await showQRDialog(context, item.peerID, item.displayName);
                knownPeersDataService.subscribe(_onNewKnownPeers);
              },
            ),
            SizedBox(width: 15),
            OutlinedButton.icon(
              icon: Icon(
                Icons.settings,
                color: Colors.black87,
              ),
              label: Text("SETTINGS"),
              onPressed: () async {
                // TODO: пробрасывать peerID через путь, чтобы был абсолютный адрес
                knownPeersDataService.unsubscribe(_onNewKnownPeers);
                await Navigator.of(context).pushNamed(KnownPeerSettingsScreen.routeName, arguments: item.peerID);
                knownPeersDataService.subscribe(_onNewKnownPeers);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBodyItem(IconData icon, String label, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon),
              SizedBox(width: 10),
              Text(label),
              SizedBox(width: 35),
            ],
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SelectableText(text),
          )
        ],
      ),
    );
  }
}
