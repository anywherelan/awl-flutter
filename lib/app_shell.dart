import 'package:anywherelan/drawer.dart';
import 'package:flutter/material.dart';

enum AppSection { overview, settings, blockedPeers, diagnostics }

class AppShell extends StatelessWidget {
  final AppSection? selected;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const AppShell({
    super.key,
    required this.selected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasPermanentDrawer = constraints.maxWidth > 1100;
        return Scaffold(
          appBar: appBar,
          drawer: hasPermanentDrawer ? null : MyDrawer(selected: selected),
          floatingActionButton: floatingActionButton,
          body: SafeArea(
            bottom: false,
            child: hasPermanentDrawer
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MyDrawer(selected: selected, isRetractable: false),
                      Expanded(child: body),
                    ],
                  )
                : body,
          ),
        );
      },
    );
  }
}
