import 'package:anywherelan/api.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import '../fixtures/fixture_reader.dart';
import 'mock_http_client.dart';

/// A few lines in the shape the backend writes them: a peer's name, its peer
/// ID and an address, which is what the export warning is about.
const sampleLogs =
    "2026-04-10 08:24:50.52\tINFO\tawl/service/status\tpeer 'awl-tester' connected, direction outbound, "
    "address /ip4/203.0.113.45/udp/4001/quic-v1\n"
    "2026-04-10 08:24:51.07\tINFO\tawl/service/status\tsuccessfully exchanged status info (outbound) with "
    "awl-tester (12D3KooWJMUjt9b5T1umzgzjLv5yG2ViuuF4qjmN65tsRXZGS1p8)\n"
    "2026-04-10 08:25:12.65\tINFO\tdht/RtRefreshManager\tstarting refreshing cpl 1 with key CIQAAA2A "
    "(routing table size was 49)\n"
    "2026-04-10 08:25:13.40\tWARN\tawl/dns\tsend request to upstream dns: i/o timeout";

const sampleDebugInfo = '{"General": {"Version": "dev", "Uptime": "2h33m10s"}, "KnownPeers": []}';

/// The backend behind the two diagnostics screens. [down] makes it refuse
/// every connection, the way a stopped server does.
class DiagnosticsBackend {
  final client = MockHttpClient();
  bool down = false;
  String logs = sampleLogs;

  DiagnosticsBackend() {
    serverAddress = 'http://test.local';
    when(() => client.get(any())).thenAnswer((invocation) async {
      final uri = invocation.positionalArguments.single as Uri;
      if (down) throw http.ClientException('Connection refused', uri);
      switch (uri.path) {
        case getDebugLogPath:
          return http.Response(logs, 200);
        case getP2pDebugInfoPath:
          return http.Response(sampleDebugInfo, 200);
        case getMyPeerInfoPath:
          return http.Response(loadFixture('my_peer_info.json'), 200);
      }
      throw StateError('unexpected GET ${uri.path}');
    });
  }
}
