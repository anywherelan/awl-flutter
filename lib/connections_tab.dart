import 'package:flutter/material.dart';
import 'package:peerlanflutter/entities.dart';
import 'package:peerlanflutter/data_service.dart';

class ConnectionsPage extends StatefulWidget {
  ConnectionsPage({Key key}) : super(key: key);

  @override
  _ConnectionsPageState createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  List<ForwardedPort> _forwardedPorts;
  Map<String, String> _peerIDMapping = Map();

  void _onNewForwardedPorts(List<ForwardedPort> newForwardedPorts) async {
    if (!this.mounted) {
      return;
    }

    for (var peer in knownPeersDataService.getData()) {
      _peerIDMapping[peer.peerID] = peer.name.isNotEmpty ? peer.name : peer.peerID;
    }

    setState(() {
      _forwardedPorts = newForwardedPorts;
    });
  }

  @override
  void initState() {
    super.initState();

    for (var peer in knownPeersDataService.getData()) {
      _peerIDMapping[peer.peerID] = peer.name.isNotEmpty ? peer.name : peer.peerID;
    }

    _forwardedPorts = forwardedPortsDataService.getData();
    forwardedPortsDataService.subscribe(_onNewForwardedPorts);
    print("init ConnectionsPage"); // REMOVE
  }

  @override
  void deactivate() {
    super.deactivate();
    // TODO: что делать в случае `In some cases, the framework will reinsert the State object into another part of the tree`
  }

  @override
  void dispose() {
    forwardedPortsDataService.unsubscribe(_onNewForwardedPorts);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_forwardedPorts == null) {
      return Container();
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
      children: [
        SizedBox(height: 10),
        Center(child: Text("Forwarded ports", style: Theme.of(context).textTheme.headline5)),
        SizedBox(height: 10),
//        Align(
//          alignment: Alignment.centerLeft,
//          child:
//              ConstrainedBox(constraints: BoxConstraints(maxWidth: 620), child: Column(children: _buildInfo(context))),
//        ),
//        Column(children: _buildInfo(context))
        ..._buildInfo(context),
      ],
    );
  }

  List<Widget> _buildInfo(BuildContext context) {
    return _forwardedPorts.map<Widget>((ForwardedPort port) {
      return Row(
        children: [
          SelectableText(port.listenAddress),
          Icon(Icons.arrow_forward),
          // TODO: may overflow
          SelectableText(
            "${_peerIDMapping[port.peerID]}:${port.remotePort}",
//              maxLines: 3,
          ),
//          Flexible(
//            fit: FlexFit.loose,
//            child: SelectableText(text),
//          )
        ],
      );
    }).toList();
  }
}
