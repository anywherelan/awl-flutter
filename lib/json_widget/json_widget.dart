import 'package:flutter/material.dart';

// Highly modified fork of https://github.com/demdog/flutter_json_widget

class JsonViewerWidget extends StatelessWidget {
  final Map<String, dynamic> jsonObj;
  final bool? notRoot;
  final bool openOnStart;

  // Keys forced closed even when openOnStart is true
  // Dirty hack, because json viewer is too slow even on desktop
  static const _forceClosedKeys = {"RoutingTable", "KnownPeers", "ByProtocol"};

  const JsonViewerWidget(this.jsonObj, {super.key, this.notRoot, required this.openOnStart});

  @override
  Widget build(BuildContext context) {
    final column = Column(crossAxisAlignment: CrossAxisAlignment.start, children: _getList());
    if (notRoot ?? false) {
      return Container(padding: const EdgeInsets.only(left: 14.0), child: column);
    }
    return SelectionArea(child: column);
  }

  List<Widget> _getList() {
    List<Widget> list = [];
    for (final entry in jsonObj.entries) {
      final ex = _isExtensible(entry.value);
      final initialOpen = ex && openOnStart && !_forceClosedKeys.contains(entry.key);
      list.add(_JsonObjectEntryWidget(entry: entry, initialOpen: initialOpen, openOnStart: openOnStart));
      list.add(const SizedBox(height: 4));
    }
    return list;
  }

  static Widget getContentWidget(dynamic content, bool openOnStart) {
    if (content is List) {
      return JsonArrayViewerWidget(content, notRoot: true, openOnStart: openOnStart);
    } else {
      return JsonViewerWidget(content, notRoot: true, openOnStart: openOnStart);
    }
  }

  static bool _isInkWell(dynamic content) {
    if (content == null || content is int || content is String || content is bool || content is double) {
      return false;
    }
    if (content is List) return content.isNotEmpty;
    return true;
  }

  static bool _isExtensible(dynamic content) {
    return content != null && content is! int && content is! String && content is! bool && content is! double;
  }

  static String _getTypeName(dynamic content) {
    if (content is int) return 'int';
    if (content is String) return 'String';
    if (content is bool) return 'bool';
    if (content is double) return 'double';
    if (content is List) return 'List';
    return 'Object';
  }
}

class _JsonObjectEntryWidget extends StatefulWidget {
  final MapEntry<String, dynamic> entry;
  final bool initialOpen;
  final bool openOnStart;

  const _JsonObjectEntryWidget({required this.entry, required this.initialOpen, required this.openOnStart});

  @override
  State<_JsonObjectEntryWidget> createState() => _JsonObjectEntryWidgetState();
}

class _JsonObjectEntryWidgetState extends State<_JsonObjectEntryWidget> {
  late bool open;

  @override
  void initState() {
    super.initState();
    open = widget.initialOpen;
  }

  void _toggle() => setState(() => open = !open);

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final ex = JsonViewerWidget._isExtensible(entry.value);
    final ink = JsonViewerWidget._isInkWell(entry.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ex
                ? GestureDetector(
                    onTap: _toggle,
                    child: open
                        ? Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[700])
                        : Icon(Icons.arrow_right, size: 16, color: Colors.grey[700]),
                  )
                : const Icon(Icons.arrow_right, color: Color.fromARGB(0, 0, 0, 0), size: 16),
            (ex && ink)
                ? Flexible(
                    fit: FlexFit.loose,
                    child: InkWell(
                      onTap: _toggle,
                      child: Text(entry.key, style: TextStyle(color: Colors.purple[900])),
                    ),
                  )
                : Text(
                    entry.key,
                    style: TextStyle(color: entry.value == null ? Colors.grey : Colors.purple[900]),
                  ),
            Text(':', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 3),
            _buildValueWidget(entry),
          ],
        ),
        if (open) JsonViewerWidget.getContentWidget(entry.value, widget.openOnStart),
      ],
    );
  }

  Widget _buildValueWidget(MapEntry entry) {
    if (entry.value == null) {
      return Expanded(
        child: Text('undefined', style: TextStyle(color: Colors.grey)),
      );
    } else if (entry.value is int) {
      return Expanded(
        child: Text(entry.value.toString(), style: TextStyle(color: Colors.teal)),
      );
    } else if (entry.value is String) {
      return Expanded(
        child: Text('"${entry.value}"', style: TextStyle(color: Colors.redAccent)),
      );
    } else if (entry.value is bool) {
      return Expanded(
        child: Text(entry.value.toString(), style: TextStyle(color: Colors.purple)),
      );
    } else if (entry.value is double) {
      return Expanded(
        child: Text(entry.value.toString(), style: TextStyle(color: Colors.teal)),
      );
    } else if (entry.value is List) {
      if (entry.value.isEmpty) return Text('Array[0]', style: TextStyle(color: Colors.grey));
      return InkWell(
        onTap: _toggle,
        child: Text(
          'Array<${JsonViewerWidget._getTypeName(entry.value[0])}>[${entry.value.length}]',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return InkWell(
      onTap: _toggle,
      child: Text('Object', style: TextStyle(color: Colors.grey)),
    );
  }
}

class JsonArrayViewerWidget extends StatelessWidget {
  final List<dynamic> jsonArray;
  final bool? notRoot;
  final bool openOnStart;

  const JsonArrayViewerWidget(this.jsonArray, {super.key, this.notRoot, required this.openOnStart});

  @override
  Widget build(BuildContext context) {
    final column = Column(crossAxisAlignment: CrossAxisAlignment.start, children: _getList());
    if (notRoot ?? false) {
      return Container(padding: const EdgeInsets.only(left: 14.0), child: column);
    }
    return column;
  }

  List<Widget> _getList() {
    List<Widget> list = [];
    for (int i = 0; i < jsonArray.length; i++) {
      final content = jsonArray[i];
      final ex = JsonViewerWidget._isExtensible(content);
      list.add(
        _JsonArrayEntryWidget(
          index: i,
          content: content,
          initialOpen: ex && openOnStart,
          openOnStart: openOnStart,
        ),
      );
      list.add(const SizedBox(height: 4));
    }
    return list;
  }
}

class _JsonArrayEntryWidget extends StatefulWidget {
  final int index;
  final dynamic content;
  final bool initialOpen;
  final bool openOnStart;

  const _JsonArrayEntryWidget({
    required this.index,
    required this.content,
    required this.initialOpen,
    required this.openOnStart,
  });

  @override
  State<_JsonArrayEntryWidget> createState() => _JsonArrayEntryWidgetState();
}

class _JsonArrayEntryWidgetState extends State<_JsonArrayEntryWidget> {
  late bool open;

  @override
  void initState() {
    super.initState();
    open = widget.initialOpen;
  }

  void _toggle() => setState(() => open = !open);

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final i = widget.index;
    final ex = JsonViewerWidget._isExtensible(content);
    final ink = JsonViewerWidget._isInkWell(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ex
                ? GestureDetector(
                    onTap: _toggle,
                    child: open
                        ? Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[700])
                        : Icon(Icons.arrow_right, size: 16, color: Colors.grey[700]),
                  )
                : const Icon(Icons.arrow_right, color: Color.fromARGB(0, 0, 0, 0), size: 16),
            (ex && ink)
                ? InkWell(
                    onTap: _toggle,
                    child: Text('[$i]', style: TextStyle(color: Colors.purple[900])),
                  )
                : Text('[$i]', style: TextStyle(color: content == null ? Colors.grey : Colors.purple[900])),
            Text(':', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 3),
            _buildValueWidget(content, i),
          ],
        ),
        if (open) JsonViewerWidget.getContentWidget(content, widget.openOnStart),
      ],
    );
  }

  Widget _buildValueWidget(dynamic content, int index) {
    if (content == null) {
      return Expanded(
        child: Text('undefined', style: TextStyle(color: Colors.grey)),
      );
    } else if (content is int) {
      return Expanded(
        child: Text(content.toString(), style: TextStyle(color: Colors.teal)),
      );
    } else if (content is String) {
      return Expanded(
        child: Text('"$content"', style: TextStyle(color: Colors.redAccent)),
      );
    } else if (content is bool) {
      return Expanded(
        child: Text(content.toString(), style: TextStyle(color: Colors.purple)),
      );
    } else if (content is double) {
      return Expanded(
        child: Text(content.toString(), style: TextStyle(color: Colors.teal)),
      );
    } else if (content is List) {
      if (content.isEmpty) return Text('Array[0]', style: TextStyle(color: Colors.grey));
      return InkWell(
        onTap: _toggle,
        child: Text(
          'Array<${JsonViewerWidget._getTypeName(content)}>[${content.length}]',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return InkWell(
      onTap: _toggle,
      child: Text('Object', style: TextStyle(color: Colors.grey)),
    );
  }
}
