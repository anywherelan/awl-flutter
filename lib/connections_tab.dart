import 'package:flutter/material.dart';

class ConnectionsPage extends StatefulWidget {
  ConnectionsPage({Key? key}) : super(key: key);

  @override
  _ConnectionsPageState createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  @override
  void initState() {
    super.initState();
    print("init ConnectionsPage"); // REMOVE
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(height: 10),
      Center(child: Text("// TODO: remove or redesign this page", style: Theme.of(context).textTheme.headline5)),
      SizedBox(height: 10),
    ]);
  }
}
