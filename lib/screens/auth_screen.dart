// Log in, sign up, finish profile, removed. Ported from src/pages/Auth.jsx and App.jsx.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/api.dart' as api;
import '../services/auth_service.dart';
import '../widgets/ui.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Loading());
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: children),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with ActionState {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  bool isLogin = true;
  String notice = '';

  @override
  void dispose() {
    for (final c in [name, email, phone, password]) {
      c.dispose();
    }
    super.dispose();
  }

  void switchTab(bool login) => setState(() {
        isLogin = login;
        error = '';
        notice = '';
      });

  void submit() {
    setState(() => notice = '');
    if (!formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    final mail = email.text.trim();
    if (isLogin) {
      run(() => auth.logIn(mail, password.text));
      return;
    }
    if (password.text.length < 8) {
      setError('That password is too short. Use at least 8 characters.');
      return;
    }
    run(() => auth.signUp(name: name.text.trim(), phone: phone.text.trim(), email: mail, password: password.text));
  }

  void forgot() {
    final mail = email.text.trim();
    if (mail.isEmpty) {
      setError('Enter your email above first, and we can send you a reset link.');
      return;
    }
    run(() async {
      await context.read<AuthService>().resetPassword(mail);
      if (mounted) setState(() => notice = 'If $mail has an account, a reset link is on its way.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(children: [
      const Center(child: Logo(size: 64)),
      const SizedBox(height: 16),
      FormHead(title: isLogin ? 'Welcome back.' : 'Join Many Hands.', subtitle: communityName),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [ButtonSegment(value: true, label: Text('Log in')), ButtonSegment(value: false, label: Text('Sign up'))],
        selected: {isLogin},
        onSelectionChanged: (s) => switchTab(s.first),
      ),
      const SizedBox(height: 20),
      Form(
        key: formKey,
        child: AutofillGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([
            if (!isLogin)
              LabeledField(label: 'Your name', controller: name, maxLength: 80, required: true, autofillHints: const [AutofillHints.name]),
            LabeledField(
              label: 'Email',
              controller: email,
              maxLength: 254,
              required: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            if (!isLogin) PhoneField(controller: phone),
            PasswordField(controller: password, newPassword: !isLogin, hint: isLogin ? null : 'At least 8 characters.'),
            if (error.isNotEmpty || notice.isNotEmpty)
              Column(children: [
                ErrorNote(error),
                if (error.startsWith('That email already'))
                  TextButton(onPressed: () => switchTab(true), child: const Text('Log in instead')),
                NoticeNote(notice),
              ]),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy ? 'One moment…' : isLogin ? 'Log in' : 'Create account'),
            ),
            if (isLogin)
              TextButton(onPressed: busy ? null : forgot, child: const Text('Forgot your password?'))
            else
              const Muted('Other members will see your name, email and phone. Only you can change them.', small: true),
          ], 16)),
        ),
      ),
    ]);
  }
}

/// Safety net: the login worked, but the profile doc didn't get saved at sign-up.
class FinishProfileScreen extends StatefulWidget {
  const FinishProfileScreen({super.key});
  @override
  State<FinishProfileScreen> createState() => _FinishProfileScreenState();
}

class _FinishProfileScreenState extends State<FinishProfileScreen> with ActionState {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return _AuthFrame(children: [
      const FormHead(title: 'Almost there.', subtitle: 'Add your name and phone to finish setting up your profile.'),
      Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([
          LabeledField(label: 'Your name', controller: name, maxLength: 80, required: true),
          PhoneField(controller: phone),
          if (error.isNotEmpty) ErrorNote(error),
          FilledButton(
            onPressed: busy
                ? null
                : () {
                    if (!formKey.currentState!.validate()) return;
                    run(() => api.saveNewMember(auth.uid,
                        name: name.text.trim(), phone: phone.text.trim(), email: auth.user?.email ?? ''));
                  },
            child: Text(busy ? 'Saving…' : 'Save'),
          ),
          TextButton(onPressed: auth.logOut, child: const Text('Log out')),
        ], 16)),
      ),
    ]);
  }
}

class RemovedScreen extends StatelessWidget {
  const RemovedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _AuthFrame(children: [
      const Center(child: Logo(size: 64)),
      const SizedBox(height: 16),
      const FormHead(
        title: "You've been removed.",
        subtitle: 'An admin removed this account from the community. If you think this is a mistake, contact one of the organizers.',
      ),
      FilledButton(onPressed: context.read<AuthService>().logOut, child: const Text('Log out')),
    ]);
  }
}
