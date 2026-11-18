// Screens and how to reach them. Five tabs at the bottom; everything else opens on top.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/admin_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/chat_screens.dart';
import 'screens/home_screen.dart';
import 'screens/issue_detail_screen.dart';
import 'screens/issue_form_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/me_screens.dart';
import 'screens/member_screens.dart';
import 'screens/task_form_screen.dart';
import 'screens/task_screen.dart';
import 'services/auth_service.dart';
import 'widgets/shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Forms open as full-screen dialogs, like the web app's modals on a phone.
Page<void> _dialogPage(GoRouterState state, Widget child) =>
    MaterialPage<void>(key: state.pageKey, fullscreenDialog: true, child: child);

GoRouter buildRouter(AuthService auth) {
  const gates = {'/loading', '/auth', '/removed', '/finish-profile'};
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final target = switch (auth.status) {
        AuthStatus.loading => '/loading',
        AuthStatus.signedOut => '/auth',
        AuthStatus.removed => '/removed',
        AuthStatus.needsProfile => '/finish-profile',
        AuthStatus.ready => null,
      };
      if (target != null) return loc == target ? null : target;
      if (gates.contains(loc)) return '/';
      if (loc == '/admin' && !auth.isAdmin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const LoadingScreen()),
      GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
      GoRoute(path: '/removed', builder: (_, _) => const RemovedScreen()),
      GoRoute(path: '/finish-profile', builder: (_, _) => const FinishProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/issues', builder: (_, _) => const IssuesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/members', builder: (_, _) => const MembersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (_, _) => const ChatScreen())]),
        ],
      ),
      GoRoute(
        path: '/issue-new',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _dialogPage(s, const IssueFormScreen()),
      ),
      GoRoute(
        path: '/issue/:issueId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => IssueDetailScreen(issueId: s.pathParameters['issueId']!),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            pageBuilder: (_, s) => _dialogPage(s, IssueFormScreen(issueId: s.pathParameters['issueId'])),
          ),
          GoRoute(
            path: 'task-new',
            parentNavigatorKey: _rootKey,
            pageBuilder: (_, s) => _dialogPage(s, TaskFormScreen(issueId: s.pathParameters['issueId']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/task/:taskId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TaskScreen(taskId: s.pathParameters['taskId']!),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            pageBuilder: (_, s) => _dialogPage(s, TaskFormScreen(taskId: s.pathParameters['taskId'])),
          ),
        ],
      ),
      GoRoute(
        path: '/member/:memberId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => MemberProfileScreen(memberId: s.pathParameters['memberId']!),
      ),
      GoRoute(
        path: '/room/:roomId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ChatRoomScreen(roomId: s.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/conversation/:conversationId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ConversationScreen(conversationId: s.pathParameters['conversationId']!),
      ),
      GoRoute(
        path: '/me',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const MeScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            pageBuilder: (_, s) => _dialogPage(s, const EditProfileScreen()),
          ),
        ],
      ),
      GoRoute(path: '/admin', parentNavigatorKey: _rootKey, builder: (_, _) => const AdminScreen()),
    ],
  );
}
