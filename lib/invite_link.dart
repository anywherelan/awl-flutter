/// Invite link format: `awl://invite?p=<peer_id>&t=<token>&n=<name>`
///
/// This is the Dart half of a two-implementation contract — the Go side lives
/// in `../awl/entity/invite_link.go` and both carry their own tests. Keep them
/// in step: the backend builds the links this parser reads, and this side
/// builds the token-less ones (see [buildInviteLink]).
///
/// The peer ID lives in the query, not in the authority, on purpose: it is
/// base58 and therefore case-sensitive, while hosts are historically
/// case-insensitive and get lowercased by messenger linkifiers and Android
/// intent matching (and by `Uri.parse` here), which would break peer decoding.
///
/// The token is optional. With it the link is a capability — whoever presents
/// it is added automatically; without it the link is just "here is me, with a
/// name to fill in", the shareable form of a peer ID. One format covers both
/// so that every consumer — the add form, the QR scanner, a deep link — has a
/// single input to parse.
library;

const inviteLinkScheme = 'awl';
const inviteLinkHost = 'invite';

/// The newest format we understand. It is never written into a link: adding a
/// query parameter is backwards compatible on its own (parsers ignore what
/// they do not know), so a version only has to appear the day something
/// incompatible changes. Reading it is kept from day one, so that such a link
/// can be rejected with a comprehensible message instead of a random parse
/// failure.
const inviteLinkVersion = 1;

/// The input is not an awl invite link at all, as opposed to a malformed one.
/// It is what lets the add-peer form tell "this is a peer ID" from "this link
/// is broken" (mirrors `entity.ErrNotInviteLink`).
class NotAnInviteLink implements Exception {
  const NotAnInviteLink();

  @override
  String toString() => 'not an awl invite link';
}

/// The input is an awl link, but unusable. [message] is written for the user.
class InviteLinkException implements Exception {
  final String message;

  const InviteLinkException(this.message);

  @override
  String toString() => message;
}

/// The payload of an invite link: who invites, the bearer token granting
/// automatic acceptance, and how the inviter calls itself.
class InviteLink {
  final String peerID;

  /// Grants automatic acceptance to whoever presents it. Empty for a link that
  /// only identifies its author, which is then added by hand as usual.
  final String token;

  /// The creator's display name, used to prefill the add form so the peer can
  /// be added before the creator ever comes online. Optional.
  final String name;

  const InviteLink({required this.peerID, required this.token, this.name = ''});
}

/// Renders a link; an empty token or name is left out. The query is assembled
/// by hand rather than through `Uri(queryParameters: …)` so that parameters
/// stay in the p, t, n order the format is written in, and read the same way
/// everywhere they are shown.
///
/// Escaping is plain [Uri.encodeQueryComponent], so a space in the name becomes
/// "+". Only the name can contain anything to escape at all — a peer ID is
/// base58/base32 and a token base64url — and both implementations of this
/// format read "+" back as a space.
///
/// Links *with* a token always come ready-made from the backend
/// (`Invite.link`) — it is the only side that knows them. What this builds is
/// the token-less form, the one the QR dialogs share (`qr_dialog.dart`).
String buildInviteLink(String peerID, String token, String name) {
  final params = [
    'p=${Uri.encodeQueryComponent(peerID)}',
    if (token.isNotEmpty) 't=${Uri.encodeQueryComponent(token)}',
    if (name.isNotEmpty) 'n=${Uri.encodeQueryComponent(name)}',
  ];
  return '$inviteLinkScheme://$inviteLinkHost?${params.join('&')}';
}

/// Parses a link, tolerating surrounding whitespace and newlines (links get
/// copy-pasted out of messengers).
///
/// Throws [NotAnInviteLink] when the input is not an `awl://` link, and
/// [InviteLinkException] with a user-facing message when it is one but cannot
/// be used.
InviteLink parseInviteLink(String rawLink) {
  final trimmed = rawLink.trim();
  if (trimmed.isEmpty) {
    throw const NotAnInviteLink();
  }

  final Uri parsed;
  try {
    parsed = Uri.parse(trimmed);
  } on FormatException {
    throw const NotAnInviteLink();
  }
  if (parsed.scheme.toLowerCase() != inviteLinkScheme) {
    throw const NotAnInviteLink();
  }
  if (parsed.host.toLowerCase() != inviteLinkHost) {
    throw InviteLinkException("Unknown awl link type '${parsed.host}'");
  }

  final Map<String, String> query;
  try {
    query = parsed.queryParameters;
  } on FormatException {
    throw const InviteLinkException('Invalid invite link parameters');
  }

  // A missing version means the original format, v1 — which is what every link
  // we produce is, since we never write the parameter.
  final rawVersion = query['v'] ?? '';
  if (rawVersion.isNotEmpty) {
    final version = int.tryParse(rawVersion);
    if (version == null) {
      throw InviteLinkException("Invalid invite link version '$rawVersion'");
    }
    if (version > inviteLinkVersion) {
      throw InviteLinkException(
        'This invite link was created by a newer version of anywherelan '
        '(link version $version, supported $inviteLinkVersion)',
      );
    }
  }

  // Kept exactly as written: base58 peer IDs are case-sensitive.
  final peerID = query['p'] ?? '';
  if (peerID.isEmpty) {
    throw const InviteLinkException('Invite link has no peer id');
  }
  if (!_looksLikePeerID(peerID)) {
    throw const InviteLinkException('Invite link has an invalid peer id');
  }

  // Optional: without it the link cannot be redeemed, only added by hand. A
  // link truncated by a messenger past the token therefore degrades quietly
  // into a manual add — accepted, since such a cut usually takes the peer id
  // with it, and that one is required.
  return InviteLink(peerID: peerID, token: query['t'] ?? '', name: query['n'] ?? '');
}

/// Cheap syntactic check for a peer ID: base58btc (`12D3Koo…`) or a base32
/// CIDv1 (`b…`). Full validation needs multihash decoding and stays on the
/// backend, which rejects a bad ID on `invite_peer`; this only keeps an
/// obviously mangled link from silently prefilling the form.
bool _looksLikePeerID(String value) {
  if (value.length < 32) return false;
  return RegExp(r'^[A-HJ-NP-Za-km-z1-9]+$').hasMatch(value) || RegExp(r'^b[a-z2-7]+$').hasMatch(value);
}
