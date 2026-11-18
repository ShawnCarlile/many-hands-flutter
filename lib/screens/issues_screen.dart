// Ported from src/pages/Issues.jsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../logic/filter.dart';
import '../services/data_service.dart';
import '../widgets/cards.dart';
import '../widgets/shell.dart';
import '../widgets/ui.dart';

class IssuesScreen extends StatefulWidget {
  const IssuesScreen({super.key});
  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  // Resolved issues are hidden by default so the list shows what still needs work.
  String view = 'active';
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issues = context.watch<DataService>().issues;
    final q = search.text.trim();
    final shown = filterIssues(issues, view: view, search: q);
    final filtering = view != 'all' || q.isNotEmpty;

    String emptyText() {
      if (issues.isEmpty) return 'No issues yet. Start the first one.';
      if (q.isNotEmpty) return 'No ${view == 'all' ? '' : '${issueViews[view]!.toLowerCase()} '}issues match "$q".';
      if (view == 'resolved') return 'Nothing has been resolved yet.';
      return 'No active issues. Everything is resolved.';
    }

    return TabPage(
      title: 'Issues',
      fab: FloatingActionButton.extended(
        onPressed: () => context.push('/issue-new'),
        icon: const Icon(Icons.add),
        label: const Text('New issue'),
      ),
      children: [
        const PageHero(eyebrow: communityName, title: 'Issues.', lede: 'Everything the group is working on right now.'),
        if (issues.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: search,
                decoration: InputDecoration(
                  hintText: 'Search issues',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: () => setState(search.clear)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Segmented(label: 'Show', options: issueViews, value: view, onChanged: (v) => setState(() => view = v)),
              const SizedBox(height: 8),
              Muted(filtering ? 'Showing ${shown.length} of ${issues.length}' : plural(issues.length, 'issue', 'issues'), small: true),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: shown.isEmpty
                ? [
                    EmptyNote(
                      emptyText(),
                      action: filtering && issues.isNotEmpty
                          ? TextButton(
                              onPressed: () => setState(() {
                                search.clear();
                                view = 'all';
                              }),
                              child: const Text('Show all issues'),
                            )
                          : null,
                    ),
                  ]
                : spaced([for (final i in shown) IssueCard(issue: i)]),
          ),
        ),
      ],
    );
  }
}
