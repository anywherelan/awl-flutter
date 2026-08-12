import 'package:anywherelan/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/samples.dart';

/// The format is a contract shared with the Go implementation
/// (`../awl/entity/invite_link.go`), which carries the same test cases. Keep
/// both in step when the format changes.
void main() {
  const peerID = samplePeerID;
  const token = sampleToken;

  group('buildInviteLink', () {
    test('renders parameters in p, t, n order', () {
      expect(buildInviteLink(peerID, token, 'Alice'), 'awl://invite?p=$peerID&t=$token&n=Alice');
    });

    test('omits an empty name', () {
      expect(buildInviteLink(peerID, token, ''), 'awl://invite?p=$peerID&t=$token');
    });

    test('omits an empty token: the link then only says who its author is', () {
      expect(buildInviteLink(peerID, '', 'Alice'), 'awl://invite?p=$peerID&n=Alice');
    });

    test('renders a bare link with neither token nor name', () {
      expect(buildInviteLink(peerID, '', ''), 'awl://invite?p=$peerID');
    });

    test('never writes the version parameter', () {
      // Regression on the decision to stop writing v=: a version only has to
      // appear the day the format breaks compatibility, and until then it is
      // four characters in every link and QR code.
      expect(buildInviteLink(peerID, token, 'Alice'), isNot(contains('v=')));
      expect(buildInviteLink(peerID, '', ''), isNot(contains('v=')));
    });

    // Mirrors TestBuildInviteLinkEscapesName on the Go side. The name is the
    // only parameter that can need escaping — a peer ID is base58/base32, a
    // token base64url.
    test('escapes the name the same way the Go side does', () {
      expect(buildInviteLink(peerID, token, 'my laptop'), contains('n=my+laptop'));

      // A literal plus is escaped, so it cannot come back as a space.
      final link = buildInviteLink(peerID, token, 'a+b');
      expect(link, contains('n=a%2Bb'));
      expect(parseInviteLink(link).name, 'a+b');
    });

    test('round-trips through the parser', () {
      final parsed = parseInviteLink(buildInviteLink(peerID, token, 'my laptop'));

      expect(parsed.peerID, peerID);
      expect(parsed.token, token);
      expect(parsed.name, 'my laptop');
    });

    // Mirrors TestParseInviteLinkRoundTrip on the Go side: a name with an
    // ampersand would split the query if it escaped wrong, and a base64url
    // token must survive with its - and _ intact.
    group('round-trips awkward values', () {
      const cases = <String, String>{
        'Alice': 'Xk9token',
        '': 'with-_dashes',
        'имя с пробелом & амперсандом': 'aGVsbG8gd29ybGQtLQ',
        // Token-less: what the QR dialogs share.
        'my laptop': '',
      };
      cases.forEach((name, token) {
        test('name "$name"', () {
          final parsed = parseInviteLink(buildInviteLink(peerID, token, name));

          expect(parsed.peerID, peerID);
          expect(parsed.token, token);
          expect(parsed.name, name);
        });
      });
    });
  });

  group('parseInviteLink', () {
    test('parses a link built by the backend', () {
      final parsed = parseInviteLink('awl://invite?p=$peerID&t=$token&n=Alice&v=1');

      expect(parsed.peerID, peerID);
      expect(parsed.token, token);
      expect(parsed.name, 'Alice');
    });

    test('keeps the peer id case-sensitive', () {
      // Regression on why the peer id lives in the query and not in the
      // authority: hosts get lowercased, base58 peer ids must not be.
      expect(parseInviteLink('awl://invite?p=$peerID&t=$token').peerID, peerID);
    });

    test('tolerates surrounding whitespace and newlines', () {
      final parsed = parseInviteLink('\n  awl://invite?p=$peerID&t=$token&v=1  \n');

      expect(parsed.peerID, peerID);
      expect(parsed.token, token);
    });

    test('accepts an uppercase scheme', () {
      expect(parseInviteLink('AWL://invite?p=$peerID&t=$token').token, token);
    });

    test('treats a missing version as v1', () {
      expect(parseInviteLink('awl://invite?p=$peerID&t=$token').peerID, peerID);
    });

    test('still accepts a link that carries v=1', () {
      // Written by earlier versions of awl, and the reason the version is
      // still read.
      expect(parseInviteLink('awl://invite?p=$peerID&t=$token&n=Alice&v=1').token, token);
    });

    test('a link without a token is valid and grants nothing', () {
      final parsed = parseInviteLink('awl://invite?p=$peerID&n=Alice');

      expect(parsed.peerID, peerID);
      expect(parsed.token, '');
      expect(parsed.name, 'Alice');
    });

    test('a bare link carries just the peer id', () {
      final parsed = parseInviteLink('awl://invite?p=$peerID');

      expect(parsed.peerID, peerID);
      expect(parsed.token, '');
      expect(parsed.name, '');
    });

    test('decodes a percent-escaped name', () {
      expect(parseInviteLink('awl://invite?p=$peerID&t=$token&n=my%20laptop').name, 'my laptop');
    });

    test('reads + in a name as a space', () {
      // That is how we write a space ourselves, and it is what the Go side
      // writes too — but percent-escaped spaces have to keep working as well,
      // hence the test above.
      expect(parseInviteLink('awl://invite?p=$peerID&t=$token&n=my+laptop').name, 'my laptop');
    });

    test('leaves the name empty when not given', () {
      expect(parseInviteLink('awl://invite?p=$peerID&t=$token&v=1').name, '');
    });

    group('is not an invite link at all', () {
      for (final input in <String>['', '   ', peerID, 'https://example.com/invite?p=1&t=2', 'garbage']) {
        test('"$input"', () {
          expect(() => parseInviteLink(input), throwsA(isA<NotAnInviteLink>()));
        });
      }
    });

    group('is a broken invite link', () {
      test('unknown awl link type', () {
        expect(
          () => parseInviteLink('awl://peer?p=$peerID&t=$token'),
          throwsA(isA<InviteLinkException>().having((e) => e.message, 'message', contains('peer'))),
        );
      });

      test('missing peer id', () {
        expect(
          () => parseInviteLink('awl://invite?t=$token&v=1'),
          throwsA(isA<InviteLinkException>().having((e) => e.message, 'message', contains('no peer id'))),
        );
      });

      test('invalid peer id', () {
        expect(
          () => parseInviteLink('awl://invite?p=not-a-peer-id&t=$token'),
          throwsA(
            isA<InviteLinkException>().having((e) => e.message, 'message', contains('invalid peer id')),
          ),
        );
      });

      // Regression on keeping the version reader alive now that nothing writes
      // it: without this test it reads as dead code and gets deleted, and the
      // day the format changes those links fail with a random parse error.
      test('newer format version', () {
        expect(
          () => parseInviteLink('awl://invite?p=$peerID&t=$token&v=2'),
          throwsA(
            isA<InviteLinkException>().having(
              (e) => e.message,
              'message',
              contains('newer version of anywherelan'),
            ),
          ),
        );
      });

      test('non-numeric version', () {
        expect(
          () => parseInviteLink('awl://invite?p=$peerID&t=$token&v=abc'),
          throwsA(isA<InviteLinkException>().having((e) => e.message, 'message', contains('version'))),
        );
      });
    });
  });
}
