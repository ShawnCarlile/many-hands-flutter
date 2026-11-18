// Your profile and its editor. Ported from src/pages/Me.jsx and EditProfile.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../logic/errors.dart';
import '../logic/phone.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/ui.dart';
import 'member_screens.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final data = context.watch<DataService>();
    final theme = context.watch<ThemeController>();
    final member = auth.member;
    if (member == null) return const Scaffold(body: Loading());
    final myIssues = data.issues.where((i) => i.ownerId == auth.uid).toList();
    final myTasks = stableSorted(data.tasks.where((t) => t.assigneeId == auth.uid), bySoonestDue);

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        PageHero(
          leading: Avatar(id: auth.uid, name: member.name, size: 96),
          title: 'Hi, ${firstName(member.name)}.',
          lede: 'Thanks for pitching in with $communityName.',
          actions: [FilledButton(onPressed: () => context.push('/me/edit'), child: const Text('Edit profile'))],
        ),
        Band(children: [
          DetailRows(member: member),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: theme.isDark(context),
            onChanged: theme.setDark,
          ),
          if (auth.isAdmin)
            TextButton.icon(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Open the admin page ›'),
            ),
        ]),
        Band(
          alt: true,
          title: 'My issues.',
          children: myIssues.isEmpty
              ? [
                  EmptyNote("You haven't started an issue yet.",
                      action: TextButton(onPressed: () => context.push('/issue-new'), child: const Text('Start one'))),
                ]
              : [for (final i in myIssues) IssueCard(issue: i)],
        ),
        Band(
          title: 'My tasks.',
          children: [
            if (myTasks.isEmpty)
              EmptyNote('Nothing on your plate.', action: TextButton(onPressed: () => context.go('/'), child: const Text('See open tasks')))
            else
              ...[for (final t in myTasks) MyTaskCard(task: t)],
            TextButton(onPressed: auth.logOut, child: Text('Log out', style: TextStyle(color: context.colors.ink2))),
          ],
        ),
      ]),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with ActionState {
  final formKey = GlobalKey<FormState>();
  late final auth = context.read<AuthService>();
  late final name = TextEditingController(text: auth.member?.name ?? '');
  late final email = TextEditingController(text: auth.member?.email ?? '');
  late final phone = TextEditingController(text: formatPhone(auth.member?.phone));
  final password = TextEditingController();
  bool needsPassword = false;
  String notice = '';

  @override
  void dispose() {
    for (final c in [name, email, phone, password]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    setState(() => notice = '');
    if (!formKey.currentState!.validate()) return;
    final newEmail = email.text.trim();
    run(() async {
      var sentLink = false;
      if (newEmail.toLowerCase() != (auth.authEmail ?? '').toLowerCase()) {
        try {
          await auth.changeEmail(newEmail, needsPassword ? password.text : null);
          sentLink = true;
        } catch (e) {
          final code = errorCode(e);
          // Firebase wants a recent login before an email change. Ask for the password, right here.
          if (code == 'requires-recent-login') {
            setState(() => needsPassword = true);
            setError('For your security, enter your password to change your email.');
            return;
          }
          if (code == 'wrong-password' || code == 'invalid-credential') {
            setError("That password isn't right. Try again.");
            return;
          }
          setError(friendlyError(e));
          return;
        }
      }
      await api.updateMember(auth.uid, {'name': name.text.trim(), 'phone': phone.text.trim(), 'email': auth.authEmail});
      if (!mounted) return;
      if (sentLink) {
        setState(() {
          needsPassword = false;
          password.clear();
          email.text = auth.authEmail ?? '';
          notice = 'Saved. We sent a link to $newEmail. Your email changes after you click it and log in again.';
        });
        return;
      }
      context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final member = auth.member;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(child: Avatar(id: auth.uid, name: member?.name ?? '', size: 72)),
          const SizedBox(height: 12),
          const FormHead(title: 'Your details.', subtitle: 'Only you can change these. Other members see them in the directory.'),
          ...spaced([
            LabeledField(label: 'Name', controller: name, maxLength: 80, required: true, autofillHints: const [AutofillHints.name]),
            LabeledField(
              label: 'Email',
              controller: email,
              maxLength: 254,
              required: true,
              keyboardType: TextInputType.emailAddress,
              helper: 'You also use this to log in. It has to be one nobody else uses.',
            ),
            PhoneField(controller: phone),
            if (needsPassword) PasswordField(controller: password),
            if (error.isNotEmpty) ErrorNote(error),
            if (notice.isNotEmpty) NoticeNote(notice),
            FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Saving…' : 'Save')),
          ], 18),
        ]),
      ),
    );
  }
}
