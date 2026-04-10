import 'dart:convert';
import 'dart:io';

/// Loads a fixture file from `test/fixtures/`. Returns the raw string contents.
String loadFixture(String name) {
  return File('test/fixtures/$name').readAsStringSync();
}

/// Loads a fixture and decodes it as JSON.
dynamic loadFixtureJson(String name) {
  return jsonDecode(loadFixture(name));
}
