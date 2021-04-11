import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:anywherelan/data_service.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/common.dart';

class PeersListPage extends StatefulWidget {
  PeersListPage({Key? key}) : super(key: key);

  @override
  _PeersListPageState createState() => _PeersListPageState();
}

class _PeersListPageState extends State<PeersListPage> {
  final _biggerFont = const TextStyle(fontSize: 18.0);

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
    print("init PeersListPage"); // REMOVE
  }

  @override
  void deactivate() {
    super.deactivate();
    // TODO: что делать в случае `In some cases, the framework will reinsert the State object into another part of the tree`
  }

  @override
  void dispose() {
    super.dispose();
    knownPeersDataService.unsubscribe(_onNewKnownPeers);
  }

  @override
  Widget build(BuildContext context) {
    if (_knownPeers == null) {
      return Container();
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
            return _buildRowTitle(item);
          },
          body: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 600), child: _buildExpansionPanelBody(item)),
          ),
          isExpanded: isExpanded,
          canTapOnHeader: true,
        );
      }).toList(),
    );

    return SingleChildScrollView(
      child: Container(
        child: expansionList,
      ),
    );

//    return ListView.builder(
//        padding: const EdgeInsets.all(8.0),
//        itemCount: itemsCount,
//        itemBuilder: (context, i) {
//          if (i.isOdd) return Divider();
//
//          final index = i ~/ 2;
//          if (index == _knownPeers.length) {
//            // Чтобы 'Add new peer' кнопка не перегораживала последний элемент
//            return SizedBox(height: 30);
//          } else if (index > _knownPeers.length) {
//            print("WARN: index > _knownPeers.length");
//            return null;
//          }
//          return _buildRow(_knownPeers[index]);
//        });
  }

  Widget _buildRowTitle(KnownPeer peer) {
    var connected = peer.connected && peer.confirmed;
    var statusColor = connected ? Colors.green : Colors.red;

    return ListTile(
      title: Row(children: <Widget>[
        Text(
          peer.name,
          style: _biggerFont,
        ),
        SizedBox(width: 5),
        Container(
          width: 8.0,
          height: 8.0,
          decoration: new BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        )
      ]),
      subtitle: connected
          ? null
          : Text(
              peer.lastSeen.isAtSameMomentAs(zeroGoTime)
                  ? "Last seen never"
                  : "Last seen ${formatDuration(peer.lastSeen.difference(DateTime.now()))} ago",
            ),
//      trailing: _buildPopupMenu(peer),
    );
  }

  Widget _buildExpansionPanelBody(KnownPeer item) {
    return Column(
      children: [
        _buildBodyItem(Icons.devices, "Peer ID  ", item.peerID),
        _buildBodyItem(Icons.location_on, "Local address", item.ipAddr),
//        Wrap(
//          children: item.addresses.map((e) => SelectableText(e)).toList(),
//        ),
        if (item.addresses.isNotEmpty) _buildBodyItem(Icons.my_location, "Address", item.addresses.join('\n\n')),
        if (item.version.isNotEmpty) _buildBodyItem(Icons.label, "Version", item.version),
        if (item.networkStats.totalIn != 0)
          _buildBodyItem(Icons.cloud_download, "Download rate", item.networkStats.inAsString()),
        if (item.networkStats.totalOut != 0)
          _buildBodyItem(Icons.cloud_upload, "Upload rate", item.networkStats.outAsString()),
        Padding(
          padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 5, bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              RaisedButton.icon(
                icon: qrCodeImage,
                label: Text("Show ID"),
                onPressed: () async {
                  knownPeersDataService.unsubscribe(_onNewKnownPeers);
                  await showQRDialog(context, item.peerID, item.name);
                  knownPeersDataService.subscribe(_onNewKnownPeers);
                },
              ),
              SizedBox(width: 15),
              RaisedButton.icon(
                icon: Icon(Icons.settings),
                label: Text("Settings"),
                onPressed: () async {
                  // TODO: пробрасывать peerID через путь, чтобы был абсолютный адрес
                  knownPeersDataService.unsubscribe(_onNewKnownPeers);
                  await Navigator.of(context).pushNamed('/peer_settings', arguments: item.peerID);
                  knownPeersDataService.subscribe(_onNewKnownPeers);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyItem(IconData icon, String label, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon),
              SizedBox(width: 10),
              Text(label),
              // TODO: может быть неровный отступ т.к текст слева разной длины, например если строка с портами длинная
              SizedBox(width: 65),
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
