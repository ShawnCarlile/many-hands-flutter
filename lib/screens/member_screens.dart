// Member directory and profile. Ported from src/pages/Members.jsx and MemberProfile.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../logic/filter.dart';
import '../logic/phone.dart';
import '../models.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final search = TextEditingController();
  final focus = FocusNode();

  @override
  void dispose() {
    search.dispose();
    focus.dispose();
    super.dispose();
  }

  // Clearing puts focus back in the box, ready for the next search.
  void clearSearch() {
    setState(search.clear);
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final members = context.watch<DataService>().members;
    final q = search.text.trim();
    final shown = filterMembers(members, q);
    final c = context.colors;

    return TabPage(title: 'Members', children: [
      PageHero(
        eyebrow: communityName,
        title: 'Members.',
        lede: '${plural(members.length, 'person', 'people')} pitching in. Select anyone to see their profile.',
      ),
      Band(alt: true, children: [
        if (members.isNotEmpty) ...[
          TextField(
            controller: search,
            focusNode: focus,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Search by name, email or phone',
              prefixIcon: const Icon(Icons.search),
              fillColor: c.surface,
              suffixIcon: q.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: clearSearch),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Muted(q.isNotEmpty ? 'Showing ${shown.length} of ${members.length}' : plural(members.length, 'member', 'members'), small: true),
        ],
        if (shown.isEmpty && q.isNotEmpty)
          EmptyNote(
            'No members match "$q". Check the spelling, or try part of a name, an email, or a phone number.',
            action: TextButton(onPressed: clearSearch, child: const Text('Clear search')),
          ),
        for (final m in shown)
          TapCard(
            onTap: () => context.push(m.id == uid ? '/me' : '/member/${m.id}'),
            child: Row(children: [
              Avatar(id: m.id, name: m.name, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name, style: Theme.of(context).textTheme.titleMedium),
                  Muted(m.email, maxLines: 1),
                  Muted(displayPhone(m.phone)),
                ]),
              ),
              if (m.id == uid) Tag('You', fg: c.accent, bg: c.accentSoft),
            ]),
          ),
      ]),
    ]);
  }
}

/// Name, email and phone, with tappable email and phone.
class DetailRows extends StatelessWidget {
  const DetailRows({super.key, required this.member});
  final Member member;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final email = member.email.trim();
    final hasPhone = phoneDigits(member.phone).length == 10;
    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(width: 80, child: Muted(label)),
            Expanded(child: value),
          ]),
        );
    Widget link(String text, Uri uri) => InkWell(
          onTap: () => launchUrl(uri),
          child: Text(text, style: TextStyle(color: c.accent, fontWeight: FontWeight.w600)),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: c.bgAlt, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        row('Name', Text(member.name)),
        const Divider(),
        row('Email', email.isNotEmpty ? link(email, Uri(scheme: 'mailto', path: email)) : const Muted('Not provided')),
        const Divider(),
        row('Phone',
            hasPhone ? link(displayPhone(member.phone), phoneUri(member.phone)) : Muted(member.phone.isEmpty ? 'Not provided' : member.phone)),
      ]),
    );
  }
}

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key, required this.memberId});
  final String memberId;
  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> with ActionState {
  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().uid;
    final data = context.watch<DataService>();
    if (data.loading) return const Scaffold(body: Loading());
    if (widget.memberId == uid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/me');
      });
      return const Scaffold(body: Loading());
    }
    final member = data.memberById(widget.memberId);
    if (member == null) {
      return Scaffold(appBar: AppBar(), body: const PageHero(title: "We can't find that member."));
    }
    final first = firstName(member.name);
    final email = member.email.trim();
    final hasPhone = phoneDigits(member.phone).length == 10;
    final theirIssues = data.issues.where((i) => i.ownerId == member.id).toList();
    final theirTasks = stableSorted(data.tasks.where((t) => t.assigneeId == member.id), bySoonestDue);

    void startConversation() => run(() async {
          final id = await api.openConversation(uid, member.id);
          if (mounted) GoRouter.of(this.context).push('/conversation/${Uri.encodeComponent(id)}');
        });

    return Scaffold(
      appBar: AppBar(title: Text(member.name)),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        PageHero(
          leading: Avatar(id: member.id, name: member.name, size: 96),
          title: '${member.name}.',
          lede: 'Member of $communityName',
          actions: [LockNote('Only $first can edit this profile.')],
        ),
        Band(children: [
          DetailRows(member: member),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: busy ? null : startConversation,
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(busy ? 'Opening…' : 'Message'),
            ),
            if (hasPhone)
              OutlinedButton.icon(onPressed: () => launchUrl(phoneUri(member.phone)), icon: const Icon(Icons.call), label: const Text('Call')),
            if (email.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'mailto', path: email)),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Email'),
              ),
          ]),
          ErrorNote(error),
        ]),
        Band(
          alt: true,
          title: "$first's issues.",
          children: theirIssues.isEmpty ? [const EmptyNote('No issues yet.')] : [for (final i in theirIssues) IssueCard(issue: i)],
        ),
        Band(
          title: "$first's tasks.",
          children: [
            if (theirTasks.isEmpty) const EmptyNote('No tasks yet.') else ...[for (final t in theirTasks) MyTaskCard(task: t)],
            Muted("You can comment on $first's tasks, but only $first can change them."),
          ],
        ),
      ]),
    );
  }
}
