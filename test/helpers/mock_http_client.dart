import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

/// Call once in `setUpAll` (or before first use of `any<Uri>()`/`any<http.BaseRequest>()`)
/// so mocktail knows how to construct fallback values for these argument types.
void registerHttpFallbacks() {
  registerFallbackValue(Uri());
  registerFallbackValue(_FakeRequest());
}

class _FakeRequest extends Fake implements http.BaseRequest {}
