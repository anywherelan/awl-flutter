import 'package:anywherelan/app_shell.dart';
import 'package:anywherelan/common.dart';
import 'package:anywherelan/entities.dart';
import 'package:anywherelan/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adapter for [InvitesView] that reads [invitesProvider] and wires the
/// create/revoke calls. The pure presentation logic lives in [InvitesView].
class InvitesScreen extends ConsumerStatefulWidget {
  static String routeName = "/invites";

  const InvitesScreen({super.key});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  /// The API call runs from inside the dialog so that a rejected request lands
  /// back in the form the user filled in, instead of closing it and reporting
  /// the failure over an empty screen.
  Future<void> _onCreate() async {
    Invite? created;
    await showCreateInviteDialog(
      context,
      onSubmit: (request) async {
        try {
          created = await ref.read(apiProvider).createInvite(request);
        } catch (e) {
          return e.toString().replaceFirst('Exception: ', '');
        }
        ref.invalidate(invitesProvider);
        return '';
      },
    );

    if (created == null || !mounted) return;
    await showInviteLinkDialog(context, created!);
  }

  Future<void> _onRevoke(Invite invite) async {
    final confirmed = await showRevokeInviteDialog(context, invite);
    if (!confirmed || !mounted) return;

    final response = await ref.read(apiProvider).revokeInvite(invite.id);
    ref.invalidate(invitesProvider);
    if (!mounted || response.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        content: Text('Failed to revoke invite link: $response'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(invitesProvider);
    // While loading, and on an empty list, a create button here would duplicate
    // the empty state's own call to action.
    final hasInvites = invites.valueOrNull?.isNotEmpty ?? false;

    // Where "Create link" goes is a question of width, and its two homes are on
    // opposite sides of the Scaffold — the FAB belongs to [AppShell], the
    // header row to the view — so the breakpoint is decided once, here, outside
    // [AppShell] and therefore without counting the permanent drawer above
    // 1100px; both sides of that boundary are wide either way.
    return LayoutBuilder(
      builder: (context, constraints) {
        // The same 800px breakpoint the home screen switches layouts at.
        final wide = constraints.maxWidth > 800;

        return AppShell(
          selected: AppSection.invites,
          appBar: AppBar(title: const Text('Invite links')),
          // On a phone the button stays a FAB: it is thumb-reachable there,
          // and the vertical space a header row costs is worth more.
          floatingActionButton: !wide && hasInvites
              ? FloatingActionButton.extended(
                  onPressed: _onCreate,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Create link'),
                )
              : null,
          body: InvitesView(
            invites: invites.valueOrNull,
            error: invites.hasError ? invites.error.toString().replaceFirst('Exception: ', '') : null,
            showCreateInHeader: wide && hasInvites,
            onCreate: _onCreate,
            onRevoke: _onRevoke,
            onShowLink: (invite) => showInviteLinkDialog(context, invite),
          ),
        );
      },
    );
  }
}

/// Pure presentation widget for the invite links screen. Receives all data via
/// constructor params; never reads global services. Tests target this widget
/// directly with fixture data.
class InvitesView extends StatelessWidget {
  final List<Invite>? invites;
  final String? error;
  final Future<void> Function()? onCreate;
  final Future<void> Function(Invite)? onRevoke;
  final Future<void> Function(Invite)? onShowLink;

  /// Whether "Create link" is rendered as a fixed header row above the list
  /// instead of as the screen's floating action button. Passed in rather than
  /// measured here so the two never disagree — see [InvitesScreen.build].
  final bool showCreateInHeader;

  /// Clock the "expires in …" lines are measured against. Defaults to the wall
  /// clock; see [inviteExpiryText].
  final DateTime? now;

  const InvitesView({
    super.key,
    required this.invites,
    this.error,
    this.showCreateInHeader = false,
    this.onCreate,
    this.onRevoke,
    this.onShowLink,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error!, style: TextStyle(color: colorScheme.error)),
        ),
      );
    }
    if (invites == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // On an empty screen the empty state already explains what a link is and
    // offers the only button worth having; a header would say both twice.
    final isEmpty = invites!.isEmpty;
    final withHeader = showCreateInHeader && !isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (withHeader) _buildHeader(context),
            Expanded(
              child: ListView(
                // The bottom inset is clearance for the FAB, so it goes away
                // with it.
                padding: EdgeInsets.fromLTRB(16, 16, 16, withHeader ? 16 : 88),
                children: [
                  if (!isEmpty) ...invites!.map((i) => _buildCard(context, i)) else _buildEmptyState(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fixed above the scrolling list, so the one action of this screen is always
  /// on screen and always on the same axis as the status pills below it.
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Whoever opens an invite link is added automatically, with the settings you choose.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () => onCreate?.call(),
                icon: const Icon(Icons.add_link),
                label: const Text('Create link'),
              ),
            ],
          ),
        ),
        // Inset like the cards, so it reads as this column's own rule rather
        // than a band across the window — and so the list visibly ends here
        // instead of being clipped mid-card as it scrolls under.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.link_off, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('No invite links', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'A link connects a new device without anyone pressing accept. '
            'Whoever opens it is added automatically, with the settings you choose.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add_link),
            label: const Text('Create link'),
            onPressed: () => onCreate?.call(),
          ),
        ],
      ),
    );
  }

  /// One card, one geometry: every element sits on the same left or right axis
  /// whatever the state of the link, so the pills do not shuffle sideways down
  /// the list. Dead links simply have no action row.
  Widget _buildCard(BuildContext context, Invite invite) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = invite.isActive;
    final title = inviteTitle(invite);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Top-aligned, so the pill sits at the same height on every card
              // no matter how tall the title's line box grows.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // One line, always: the label is free text, and a newline in
                  // it would open a second line in the title's own style — room
                  // for a fake status line right under the real one.
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // No dot on any invite pill: this screen does not poll, so what
                // it shows is a snapshot rather than a live signal.
                StatusPill(
                  text: inviteStatusText(invite.status),
                  color: _statusColor(context, invite.status),
                  withDot: false,
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildMeta(context, invite),
            if (invite.alias.isNotEmpty || invite.allowUsingAsExitNode) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (invite.alias.isNotEmpty)
                    // The icon names the subject (a device), the text names it
                    // — together, not twice. Deliberately not `label_outline`:
                    // that one is the *link's* label in the create form, and
                    // the alias is the one thing the label is confused with.
                    _InviteTag(
                      icon: Icons.devices_outlined,
                      text: 'name "${invite.alias}"',
                      tooltip:
                          'The device that opens this link is added as "${invite.alias}". '
                          'You can rename it later.',
                    ),
                  if (invite.allowUsingAsExitNode)
                    const _InviteTag(
                      icon: Icons.alt_route_outlined,
                      text: 'exit node allowed',
                      tooltip:
                          'The device that opens this link may route its internet traffic '
                          'through this one: SOCKS5 proxy and VPN gateway.',
                    ),
                ],
              ),
            ],
            // Laid out like a dialog's action row: the primary action last, so
            // the destructive one does not sit at the edge a cursor sweeps to.
            // The 16px gap keeps the two from reading as one segmented control.
            if (active) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                    onPressed: () => onRevoke?.call(invite),
                    child: const Text('Revoke link'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('Show link'),
                    onPressed: () => onShowLink?.call(invite),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The one line under the title: how much of the link is left, when it ended
  /// if it has, and when it was made. Three slots in a fixed order, so the line
  /// keeps its shape between a live row and a dead one; each is dropped when it
  /// has nothing to say (see [inviteUsageText] and [inviteEndedText]).
  ///
  /// The creation date is never dropped: it is what tells two otherwise
  /// identical links apart.
  Widget _buildMeta(BuildContext context, Invite invite) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final usage = inviteUsageText(invite);
    final ended = inviteEndedText(invite, now: now);

    return Text.rich(
      TextSpan(
        children: [
          if (usage.isNotEmpty) TextSpan(text: '$usage · '),
          if (invite.isActive) ...[
            TextSpan(
              text: inviteExpiryText(invite, now: now),
              // The only part of the line that can be urgent, so the only part
              // that changes colour.
              style: inviteExpiresSoon(invite, now: now) ? const TextStyle(color: warningColor) : null,
            ),
            const TextSpan(text: ' · '),
          ] else if (ended.isNotEmpty)
            TextSpan(text: '$ended · '),
          TextSpan(text: inviteCreatedText(invite.createdAt, now: now)),
        ],
      ),
      style: style,
    );
  }

  Color _statusColor(BuildContext context, String status) {
    // Expired, used up and revoked all mean the same thing — this link is
    // done — and the pill's own text says which. Revoked used to be red, which
    // put the loudest colour on the least important rows in the list; error
    // colour now only marks the action that destroys something.
    return status == inviteStatusActive ? successColor : Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// What the link hands out, at a glance: the alias it assigns and whether it
/// grants exit-node use. A plain Material [Chip] rather than a hand-rolled
/// pill, so it follows the theme and carries its own semantics.
///
/// The [tooltip] holds what a chip cannot fit, so the visible text still has to
/// stand on its own: a tooltip needs a hover, and nobody long-presses a chip
/// that looks inert.
///
/// Both tags are neutral and deliberately alike — alias and exit-node
/// permission are one category, what the link does to the device that opens it,
/// so neither outranks the other. Tinting the permission put the loudest colour
/// on dead cards, where it grants nothing.
class _InviteTag extends StatelessWidget {
  final IconData icon;
  final String text;
  final String tooltip;

  const _InviteTag({required this.icon, required this.text, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Chip(
        avatar: Icon(icon, size: 16, color: foreground),
        label: Text(text),
        labelStyle: theme.textTheme.labelSmall?.copyWith(color: foreground),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Label if the user gave one, else what the link is. Not the invite id: that
/// is a support handle, and a list of "Invite 4b33" / "Invite c04e" tells the
/// reader nothing — the creation date in the card's meta line is what actually
/// distinguishes two unlabelled links.
String inviteTitle(Invite invite) {
  if (invite.label.isNotEmpty) return invite.label;
  return invite.maxUses == 1 ? 'Single-use link' : 'Link for up to ${invite.maxUses} devices';
}

/// The use counter, stated wherever the status pill does not already imply it.
///
/// On a single-use link `Active` can only mean unused and `Used up` says it
/// outright, so the count is dropped there rather than putting "0/1 used" on
/// nearly every card. An expired or revoked one may or may not have been
/// redeemed before it died, and nothing else on the card says which. A
/// multi-use count is always real information.
String inviteUsageText(Invite invite) {
  if (invite.maxUses > 1) return '${invite.usedCount} of ${invite.maxUses} used';
  if (invite.status == inviteStatusActive || invite.status == inviteStatusUsedUp) return '';
  return invite.usedCount > 0 ? 'used' : 'not used';
}

/// When a dead link died, where that is knowable and is what killed it — today,
/// expiry alone. The backend's `InviteResponse` (`../awl/entity/api.go`) carries
/// `Revoked bool` and no `RevokedAt`, and `Used up` has no timestamp either;
/// `ExpiresAt` under a `Revoked` pill would tell a competing story.
String inviteEndedText(Invite invite, {DateTime? now}) {
  if (invite.status != inviteStatusExpired || !invite.expires) return '';
  return 'expired ${_pastMoment(invite.expiresAt, now: now)}';
}

String inviteStatusText(String status) {
  switch (status) {
    case inviteStatusActive:
      return 'Active';
    case inviteStatusExpired:
      return 'Expired';
    case inviteStatusUsedUp:
      return 'Used up';
    case inviteStatusRevoked:
      return 'Revoked';
  }
  return status;
}

/// How long the link has left, as the list states it: relative while the number
/// is one you would act on, absolute once it is not.
///
/// The screen does not poll, so a rendered countdown stands still — "expires in
/// 361d 8h 27m" is precision this line cannot back up. Under a day the relative
/// form is truthful enough and the useful one; beyond that a date ages better.
String inviteExpiryText(Invite invite, {DateTime? now}) {
  if (!invite.expires) return 'never expires';
  final left = invite.expiresAt.difference(now ?? DateTime.now());
  if (left.isNegative) return 'expired';
  if (left.inHours < 24) return 'expires in ${_timeLeftText(left)}';
  // The same date vocabulary the create form uses, so a link reads the same
  // where it is made and where it is listed.
  return 'expires ${inviteExpiryMoment(invite.expiresAt, now: now)}';
}

/// Whether the meta line says the expiry in warning colour. An hour is where
/// "send it now, or make a new one" becomes the answer.
bool inviteExpiresSoon(Invite invite, {DateTime? now}) {
  if (!invite.expires || !invite.isActive) return false;
  final left = invite.expiresAt.difference(now ?? DateTime.now());
  return !left.isNegative && left < const Duration(hours: 1);
}

/// One unit, not three: under an hour the minutes are what matter, above it the
/// hours are, and `formatDuration`'s "20h 24m 13s" is more than either question
/// asks.
String _timeLeftText(Duration left) {
  if (left.inMinutes < 1) return 'less than a minute';
  if (left.inHours < 1) return '${left.inMinutes} min';
  return '${left.inHours}h';
}

/// When the link was made. Without it two links created minutes apart with the
/// same settings are indistinguishable in the list.
String inviteCreatedText(DateTime at, {DateTime? now}) => 'created ${_pastMoment(at, now: now)}';

/// A moment that has passed, as this screen states it — the mirror of
/// [inviteExpiryMoment]: `today at 14:20`, `yesterday at 14:20`, `3 Aug`,
/// `3 Aug 2025`. The clock survives where it discriminates: two links made
/// minutes apart are a today-or-yesterday case, further back the day is enough.
String _pastMoment(DateTime at, {DateTime? now}) {
  final localAt = at.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final days = _calendarDaysBetween(localAt, localNow);

  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(localAt.hour)}:${two(localAt.minute)}';

  if (days == 0) return 'today at $time';
  if (days == -1) return 'yesterday at $time';
  final date = '${localAt.day} ${_shortMonths[localAt.month - 1]}';
  return localAt.year == localNow.year ? date : '$date ${localAt.year}';
}

/// Whole days between two local calendar dates, ignoring the time of day:
/// 23:00 and the 01:00 two hours later are a day apart, which is how a reader
/// counts them.
int _calendarDaysBetween(DateTime at, DateTime now) {
  return DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

/// "2026-07-12 14:00" in local time. Deliberately not localized: the rest of
/// the app shows raw timestamps too, and this one sits next to a shareable
/// link where an unambiguous form matters more than a pretty one.
String formatInviteDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// The moment a link dies, as the create form states it: "today at 16:20",
/// "tomorrow at 09:00", or the full [formatInviteDateTime] further out.
///
/// Short expiries are the common case — a link is usually made to be used in
/// the next few minutes — and a full date on one of those is noise.
String inviteExpiryMoment(DateTime at, {DateTime? now}) {
  final localAt = at.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final days = _calendarDaysBetween(localAt, localNow);

  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(localAt.hour)}:${two(localAt.minute)}';

  if (days == 0) return 'today at $time';
  if (days == 1) return 'tomorrow at $time';
  // Spelled out rather than the ISO form of [formatInviteDateTime]: this one
  // is read inside a sentence, where "2026-08-08 17:07" lands like a log line.
  // The ISO form stays where dates are data — the list and the link panel.
  return '${localAt.day} ${_shortMonths[localAt.month - 1]} ${localAt.year}, $time';
}

const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// What the picked duration resolves to, shown under the "Expires in" dropdown
/// — a relative duration alone is no help when the link is created now to be
/// sent later.
String inviteExpiresAtText(int expiresInSeconds, {DateTime? now}) {
  if (expiresInSeconds <= 0) return 'Never expires';
  final at = (now ?? DateTime.now()).add(Duration(seconds: expiresInSeconds));
  return inviteExpiryMoment(at, now: now);
}

/// The one thing the controls of the create form do not say themselves: an
/// invite link is a bearer secret, and these are its terms.
///
/// Deliberately *not* a restatement of every field — the name and the label are
/// on screen right above it. [maxUses] is null while the entered count is not
/// yet a usable number.
String inviteSummaryText({
  required int? maxUses,
  required int expiresInSeconds,
  required bool allowUsingAsExitNode,
  DateTime? now,
}) {
  final devices = switch (maxUses) {
    null => 'several devices',
    1 => 'one device',
    _ => 'up to $maxUses devices',
  };
  final until = expiresInSeconds > 0
      ? 'until ${inviteExpiresAtText(expiresInSeconds, now: now)}'
      : 'until it is used up or revoked';

  final buffer = StringBuffer('Anyone who has this link can join $until ($devices).');
  if (allowUsingAsExitNode) {
    buffer.write(" They'll be able to route internet traffic through this device.");
  }
  return buffer.toString();
}

/// Confirms revoking a link. Says out loud that revoking is not the same as
/// removing the peers that came in through the link — "Revoke" otherwise reads
/// as "kick them out".
Future<bool> showRevokeInviteDialog(BuildContext context, Invite invite) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Revoke invite link'),
      // Named only when the user named it: [inviteTitle]'s fallback describes
      // the link rather than identifying it, and 'The link "Single-use link"'
      // reads like a quote of nothing.
      content: Text(
        invite.label.isNotEmpty
            ? 'The link "${invite.label}" will stop working for new connections. '
                  'Devices already added through it stay.'
            : 'This link will stop working for new connections. '
                  'Devices already added through it stay.',
      ),
      // The app's confirmation shape: two text buttons, colour carrying the
      // warning rather than weight.
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Revoke link'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Asks for the settings of a new invite link and creates it through
/// [onSubmit], which returns "" on success or the message to show. The dialog
/// stays open until it succeeds, so a rejected request keeps what was typed.
Future<void> showCreateInviteDialog(
  BuildContext context, {
  required Future<String> Function(CreateInviteRequest) onSubmit,
  DateTime? now,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        CreateInviteDialog(onSubmit: onSubmit, onDone: () => Navigator.pop(context), now: now),
  );
}

/// Pure dialog for creating an invite link: builds a [CreateInviteRequest] and
/// hands it to [onSubmit], doing no I/O itself.
///
/// Reading order follows what the settings mean rather than their type: first
/// the link's own terms (how many devices, for how long), then what the device
/// that redeems it gets, then the label, which is bookkeeping for this side
/// only and stays folded away until asked for.
class CreateInviteDialog extends StatefulWidget {
  /// Performs the request; returns "" on success or the error message to show.
  final Future<String> Function(CreateInviteRequest) onSubmit;

  /// Called after a successful submit (the dialog closes itself this way).
  final VoidCallback? onDone;

  /// Clock the resolved expiry dates are measured against. Defaults to the
  /// wall clock; injectable so screenshot tests render a fixed moment.
  final DateTime? now;

  const CreateInviteDialog({super.key, required this.onSubmit, this.onDone, this.now});

  @override
  State<CreateInviteDialog> createState() => _CreateInviteDialogState();
}

class _CreateInviteDialogState extends State<CreateInviteDialog> {
  /// Value 0 means "never expires", matching the backend's ExpiresInSeconds.
  /// The backend caps the far end at 365 days.
  static const _expiryOptions = <String, int>{
    '20 minutes': 1200,
    '1 hour': 3600,
    '6 hours': 21600,
    '24 hours': 86400,
    '3 days': 259200,
    '7 days': 604800,
    '30 days': 2592000,
    'Never': 0,
  };

  /// The backend's own bounds (`entity.CreateInviteRequest`). One use is the
  /// other radio option, so the multi-use field starts at two.
  static const _minMultiUses = 2;
  static const _maxMultiUses = 100;

  final _aliasController = TextEditingController();
  final _labelController = TextEditingController();
  final _usesController = TextEditingController(text: '5');
  final _usesFocus = FocusNode();

  bool _multiUse = false;
  String _expiry = '24 hours';
  bool _allowUsingAsExitNode = false;
  bool _labelShown = false;

  String? _usesError;
  String _submitError = '';

  /// The one thing a local backend still needs guarding against: a second tap
  /// before the first round trip returns would create a second link, and
  /// nothing can delete the one that is then left in the list.
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    // Typing into the count is unambiguous intent; making the user also hit
    // the radio next to it would be the classic "entered it, nothing happened".
    _usesFocus.addListener(() {
      if (_usesFocus.hasFocus && !_multiUse) {
        setState(() => _multiUse = true);
      }
    });
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _labelController.dispose();
    _usesController.dispose();
    _usesFocus.dispose();
    super.dispose();
  }

  /// The entered count, or null while it is not a number this form accepts.
  int? get _enteredUses {
    final value = int.tryParse(_usesController.text.trim());
    if (value == null || value < _minMultiUses || value > _maxMultiUses) return null;
    return value;
  }

  void _onUsesModeChanged(bool? multiUse) {
    setState(() {
      _multiUse = multiUse ?? false;
      _usesError = null;
      // Keep the typed count: switching back and forth to compare the two
      // shapes of link should not cost the number.
      if (!_multiUse) _usesFocus.unfocus();
    });
  }

  void _onPressCreate() async {
    if (_inFlight) return;
    if (_multiUse && _enteredUses == null) {
      setState(() => _usesError = 'Enter a number from $_minMultiUses to $_maxMultiUses');
      return;
    }

    // The message belongs to the attempt that produced it: clearing it here is
    // what keeps a server error from sitting under a form the user has since
    // changed in answer to it.
    setState(() {
      _inFlight = true;
      _submitError = '';
    });

    final singleUse = !_multiUse;
    final response = await widget.onSubmit(
      CreateInviteRequest(
        maxUses: singleUse ? 1 : _enteredUses!,
        expiresInSeconds: _expiryOptions[_expiry] ?? 0,
        // The backend rejects an alias on a multi-use link outright: aliases
        // must be unique, and one cannot name several devices.
        alias: singleUse ? _aliasController.text.trim() : '',
        allowUsingAsExitNode: _allowUsingAsExitNode,
        label: _labelController.text.trim(),
      ),
    );

    if (!mounted) return;
    _inFlight = false;
    if (response.isEmpty) {
      widget.onDone?.call();
    } else {
      setState(() => _submitError = response);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `scrollable` is what keeps "Create link" reachable on a short screen: the
    // fields scroll under the action row instead of pushing it off.
    return AlertDialog(
      scrollable: true,
      title: const Text('Create invite link'),
      content: SizedBox(width: 450, child: _buildFields(context)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _onPressCreate, child: const Text('Create link')),
      ],
    );
  }

  Widget _buildFields(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Spacing carries the grouping: the terms of the link, then what the
        // device that redeems it gets, then bookkeeping. The gaps inside a
        // group stay smaller than the ones between them.
        _buildUsesField(context),
        const SizedBox(height: 12),
        _buildExpiresField(context),
        const SizedBox(height: 20),
        _buildNameField(context),
        const SizedBox(height: 4),
        ExitNodePermissionField(
          value: _allowUsingAsExitNode,
          onChanged: (value) => setState(() => _allowUsingAsExitNode = value),
        ),
        // Tight around the label button: a TextButton carries its own vertical
        // padding, so the gaps here are on top of it.
        const SizedBox(height: 4),
        _buildLabelField(context),
        const SizedBox(height: 12),
        _buildSummary(context),
        if (_submitError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Could not create the link: $_submitError',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
      ],
    );
  }

  /// Two radio options rather than a list of preset counts: single-use and
  /// "roll out a batch" are different intentions, not two points on a scale,
  /// and the count in between is a plain number the backend takes up to 100.
  Widget _buildUsesField(BuildContext context) {
    // Grouped without a label of its own: the decorator's label below is
    // ordinary visible text, and repeating it here would have it read twice.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      // Label and error come from an InputDecorator, the widget `TextField`
      // draws its own with, so "Uses" reads exactly like "Expires in" under it.
      // No border: the decorator is here for the label, not to draw a field.
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Uses',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          errorText: _usesError,
        ),
        child: RadioGroup<bool>(
          groupValue: _multiUse,
          onChanged: _onUsesModeChanged,
          // A Wrap, not a Row: at a large text scale the second option moves
          // to its own line instead of overflowing.
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildUsesOption(value: false, children: const [Text('Single use')]),
              _buildUsesOption(
                value: true,
                children: [
                  const Text('Up to'),
                  const SizedBox(width: 6),
                  SizedBox(width: 44, child: _buildUsesCountField(context)),
                  const SizedBox(width: 6),
                  const Text('devices'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsesOption({required bool value, required List<Widget> children}) {
    return InkWell(
      onTap: () => _onUsesModeChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(value: value),
          ...children,
        ],
      ),
    );
  }

  /// Underlined like every other field rather than boxed: in "Up to __ devices"
  /// it reads as a blank to fill in. Dimmed while single use is selected, since
  /// the count is then inert — but still editable, because typing in it is what
  /// picks the branch.
  Widget _buildUsesCountField(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Number of devices',
      child: TextField(
        key: const Key('inviteUsesCount'),
        controller: _usesController,
        focusNode: _usesFocus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: _multiUse
            ? null
            : theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          // The field is too narrow to hold a sentence, so it only turns red
          // and the message is rendered under the whole row.
          errorText: _usesError == null ? null : '',
          errorStyle: const TextStyle(fontSize: 0, height: 0),
        ),
        onChanged: (_) => setState(() {
          _multiUse = true;
          _usesError = null;
        }),
      ),
    );
  }

  /// Sized to its longest option instead of some fraction of the dialog: a
  /// short value stranded in a wide underline reads as a field someone forgot
  /// to fill in. What it resolves to is left to the summary below.
  Widget _buildExpiresField(BuildContext context) {
    return SizedBox(
      // Fits "20 minutes", the longest option, plus the arrow.
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: _expiry,
        decoration: const InputDecoration(labelText: 'Expires in'),
        items: [for (final name in _expiryOptions.keys) DropdownMenuItem(value: name, child: Text(name))],
        onChanged: (value) => setState(() => _expiry = value ?? 'Never'),
      ),
    );
  }

  /// The label floats permanently so that the empty field shows a hint instead
  /// of reading as a heading — and the hint is not an example but the value
  /// that is actually used when the field is left alone.
  Widget _buildNameField(BuildContext context) {
    final singleUse = !_multiUse;

    return TextField(
      controller: _aliasController,
      enabled: singleUse,
      // Same cap the backend validates, so a long name is stopped here rather
      // than coming back as a 400.
      maxLength: 100,
      decoration: InputDecoration(
        labelText: 'Name for the new device',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        // Phrased as a fallback, not as a name: a bare "Laptop" sitting in the
        // field would read as something already typed there.
        hintText: singleUse ? "Default: the device's own name" : null,
        helperText: singleUse
            ? 'Optional. How it appears in your peers list.'
            : "A link for several devices can't preset a name, so each keeps its own.",
        helperMaxLines: 2,
        // The counter is noise until it starts to matter, but hitting the cap
        // in silence is worse: the field would just stop accepting input.
        counterText: _aliasController.text.length > 80 ? null : '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  /// Folded away by default. It is the only control here that changes nothing
  /// about the link itself, and keeping it out of the way also removes the one
  /// thing it was confused with — the name of the device on the other end.
  Widget _buildLabelField(BuildContext context) {
    if (!_labelShown) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.label_outline, size: 18),
          label: const Text('Add a link label'),
          onPressed: () => setState(() => _labelShown = true),
        ),
      );
    }

    return TextField(
      controller: _labelController,
      maxLength: 100,
      autofocus: true,
      decoration: InputDecoration(
        labelText: 'Link label',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        helperText: 'Optional. Only you see this, in your list of links.',
        counterText: _labelController.text.length > 80 ? null : '',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              inviteSummaryText(
                maxUses: _multiUse ? _enteredUses : 1,
                expiresInSeconds: _expiryOptions[_expiry] ?? 0,
                allowUsingAsExitNode: _allowUsingAsExitNode,
                now: widget.now,
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a created (or re-opened) invite link: the link itself, a QR code for
/// scanning it from a phone, and what the link is good for.
Future<void> showInviteLinkDialog(BuildContext context, Invite invite) {
  return showDialog<void>(
    context: context,
    // AlertDialog, so title, content and actions share Material's own 24px
    // content edge — see the note in [showPeerQRDialog].
    builder: (context) => AlertDialog(
      title: Text(inviteTitle(invite)),
      // Scrolled by hand rather than with `scrollable: true` — see the note in
      // [showPeerQRDialog]. The QR code alone is 320px tall, which no phone
      // fits in landscape.
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(child: InviteLinkPanel(invite: invite)),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    ),
  );
}

/// Pure presentation of one invite link: what it is good for, the link itself
/// with copy/share, and its QR code.
///
/// Same running order as the two QR dialogs — terms, then link, then code —
/// because the terms are what decides whether to hand the link over at all.
class InviteLinkPanel extends StatelessWidget {
  final Invite invite;

  const InviteLinkPanel({super.key, required this.invite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // No dot, like every pill on this screen.
            StatusPill(
              text: inviteStatusText(invite.status),
              color: invite.isActive ? successColor : colorScheme.onSurfaceVariant,
              withDot: false,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // The detail view, so the raw counts and an unambiguous
                // timestamp — unlike the list, which states both in the
                // shortest true form.
                '${invite.usedCount}/${invite.maxUses} used · '
                '${invite.expires ? 'expires ${formatInviteDateTime(invite.expiresAt)}' : 'never expires'}',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const InfoNote(
          icon: Icons.key_outlined,
          tone: NoteTone.warning,
          text:
              'The other device pastes this link into "Add peer" (or scans the QR code) '
              'and is connected without a manual accept.',
        ),
        const SizedBox(height: 12),
        LinkSharePanel(link: invite.link, copiedMessage: 'Invite link copied to clipboard'),
      ],
    );
  }
}
