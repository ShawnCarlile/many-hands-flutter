// Small shared widgets. Ported from the web app's src/components/ui.jsx.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../logic/dates.dart';
import '../logic/errors.dart';
import '../logic/phone.dart';
import '../models.dart';
import '../theme.dart';

String firstName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.first;
}

/// Member Workload Indicator: "(1 active task)" or "(3 active tasks)".
String workloadLabel(int count) => '($count active ${count == 1 ? 'task' : 'tasks'})';

String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String formatWhen(Timestamp? timestamp) {
  if (timestamp == null) return 'Just now';
  final date = timestamp.toDate();
  final time = DateFormat.jm().format(date);
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return 'Today, $time';
  if (days == 1) return 'Yesterday, $time';
  return '${DateFormat.MMMd().format(date)}, $time';
}

/// Runs an async action and tracks its busy and error state for the button that started it.
mixin ActionState<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String error = '';

  Future<R?> run<R>(Future<R> Function() action) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      return await action();
    } catch (e) {
      debugPrint('$e');
      if (mounted) setState(() => error = friendlyError(e));
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void setError(String message) => setState(() => error = message);
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 26});
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.logoBg, borderRadius: BorderRadius.circular(size / 3.2)),
      child: Icon(Icons.back_hand_outlined, size: size * 0.58, color: c.logoMark),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.id, required this.name, this.size = 36});
  final String? id;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
    final initials = words.map((w) => w[0].toUpperCase()).join();
    final hash = (id ?? '').codeUnits.fold<int>(0, (s, c) => s + c);
    final tones = context.colors.avatars;
    final (bg, fg) = tones[hash % tones.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(initials.isEmpty ? '?' : initials,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: (size * 0.36).roundToDouble())),
      ),
    );
  }
}

/// A small rounded label. Always carries text, so meaning never depends on color alone.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.fg, required this.bg, this.icon});
  final String text;
  final Color fg, bg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(980)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class HealthBadge extends StatelessWidget {
  const HealthBadge(this.label, {super.key});
  final String label; // Covered, Thin, At risk, Orphaned, Unclaimed
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (label) {
      'Covered' => Tag(label, fg: c.coveredFg, bg: c.coveredBg, icon: Icons.check_circle_outline),
      'Thin' => Tag(label, fg: c.thinFg, bg: c.thinBg, icon: Icons.contrast),
      'At risk' => Tag(label, fg: c.riskFg, bg: c.riskBg, icon: Icons.warning_amber_rounded),
      'Orphaned' => Tag(label, fg: c.orphanFg, bg: c.orphanBg, icon: Icons.remove_circle_outline),
      _ => Tag(label, fg: c.openFg, bg: c.openBg, icon: Icons.radio_button_unchecked),
    };
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = taskStatus[status] ?? issueStatus[status] ?? status;
    final ink = Theme.of(context).colorScheme.onSurface;
    return switch (status) {
      'doing' || 'open' => Tag(text, fg: c.openFg, bg: c.openBg),
      'done' || 'resolved' => Tag(text, fg: c.coveredFg, bg: c.coveredBg),
      'in_progress' => Tag(text, fg: c.thinFg, bg: c.thinBg),
      _ => Tag(text, fg: ink, bg: c.todoBg),
    };
  }
}

/// The text says "Overdue", so the warning never depends on color alone. Takes a task or an issue.
class DueBadge extends StatelessWidget {
  const DueBadge(this.item, {super.key});
  final Dated item;
  @override
  Widget build(BuildContext context) {
    final due = item.dueDate;
    if (due == null) return const SizedBox.shrink();
    final c = context.colors;
    final when = formatDue(due);
    return isOverdue(item)
        ? Tag('Overdue · $when', fg: c.riskFg, bg: c.riskBg, icon: Icons.schedule)
        : Tag('Due $when', fg: Theme.of(context).colorScheme.onSurface, bg: c.todoBg, icon: Icons.event);
  }
}

class LockNote extends StatelessWidget {
  const LockNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final ink2 = context.colors.ink2;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.lock_outline, size: 15, color: ink2)),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(color: ink2, fontSize: 14))),
    ]);
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: c.danger, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class NoticeNote extends StatelessWidget {
  const NoticeNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(color: c.coveredBg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: c.coveredFg, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.colors.ink2)),
        ?action,
      ]),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Big page title with optional eyebrow, lede and actions, like the web app's hero sections.
class PageHero extends StatelessWidget {
  const PageHero({super.key, required this.title, this.eyebrow, this.lede, this.leading, this.actions = const []});
  final String title;
  final String? eyebrow, lede;
  final Widget? leading;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (leading != null) ...[leading!, const SizedBox(height: 12)],
        if (eyebrow != null)
          Text(eyebrow!, style: TextStyle(color: context.colors.ink2, fontWeight: FontWeight.w600, fontSize: 14)),
        Text(title, style: t.displaySmall),
        if (lede != null) ...[const SizedBox(height: 8), Text(lede!, style: t.bodyLarge?.copyWith(color: context.colors.ink2))],
        if (actions.isNotEmpty) ...[const SizedBox(height: 16), Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions)],
      ]),
    );
  }
}

/// A full-width band with a heading, on white or on the light gray.
class Band extends StatelessWidget {
  const Band({super.key, this.title, this.sub, this.header, required this.children, this.alt = false});
  final String? title, sub;
  final Widget? header;
  final List<Widget> children;
  final bool alt;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: alt ? context.colors.bgAlt : null,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (header != null) ...[header!, const SizedBox(height: 6)],
        if (title != null) Text(title!, style: Theme.of(context).textTheme.headlineSmall),
        if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: TextStyle(color: context.colors.ink2))),
        if (title != null || sub != null) const SizedBox(height: 16),
        ..._spaced(children, 12),
      ]),
    );
  }
}

List<Widget> _spaced(List<Widget> items, double gap) => [
      for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
    ];

List<Widget> spaced(List<Widget> items, [double gap = 12]) => _spaced(items, gap);

/// Asks once more before anything is deleted or thrown away. The safe choice comes second.
class ConfirmRow extends StatelessWidget {
  const ConfirmRow({
    super.key,
    required this.question,
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
    this.confirmLabel = 'Delete',
    this.cancelLabel = 'Keep it',
  });
  final String question;
  final VoidCallback onConfirm, onCancel;
  final bool busy;
  final String confirmLabel, cancelLabel;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.riskBg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question, style: TextStyle(color: c.riskFg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white),
            onPressed: busy ? null : onConfirm,
            child: Text(confirmLabel),
          ),
          OutlinedButton(onPressed: busy ? null : onCancel, child: Text(cancelLabel)),
        ]),
      ]),
    );
  }
}

/// Shows a "Discard changes?" dialog. Returns true when the person chooses to discard.
Future<bool> confirmDiscard(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard changes?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
      ],
    ),
  );
  return result ?? false;
}

class FormHead extends StatelessWidget {
  const FormHead({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(children: [
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: context.colors.ink2)),
          ),
      ]),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      );
}

/// Password field with a Show/Hide button, so people can check what they typed before submitting.
class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.label = 'Password', this.hint, this.newPassword = false});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool newPassword;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool shown = false;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(widget.label),
      TextFormField(
        controller: widget.controller,
        obscureText: !shown,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
        validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
        decoration: InputDecoration(
          helperText: widget.hint,
          suffixIcon: TextButton(
            onPressed: () => setState(() => shown = !shown),
            child: Text(shown ? 'Hide' : 'Show', semanticsLabel: shown ? 'Hide password' : 'Show password'),
          ),
        ),
      ),
    ]);
  }
}

/// Phone field that formats as you type and stops at 10 digits.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, this.label = 'Phone'});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [PhoneInputFormatter()],
        decoration: const InputDecoration(hintText: phonePlaceholder, helperText: '10-digit US number.'),
        validator: (v) => isValidPhone(v ?? '') ? null : 'Enter a 10-digit phone number, like $phonePlaceholder',
      ),
    ]);
  }
}

/// A labeled text field for forms.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.maxLength,
    this.maxLines = 1,
    this.required = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint, helper;
  final int? maxLength;
  final int maxLines;
  final bool required;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label),
      TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: maxLines > 1 ? 3 : 1,
        keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
        textCapitalization: keyboardType == TextInputType.emailAddress ? TextCapitalization.none : TextCapitalization.sentences,
        autofillHints: autofillHints,
        onChanged: onChanged,
        decoration: InputDecoration(hintText: hint, helperText: helper, counterText: ''),
        validator: required ? (v) => (v ?? '').trim().isEmpty ? 'Fill this in.' : null : null,
      ),
    ]);
  }
}

/// A segmented choice built on Material's SegmentedButton.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.label, this.enabled = true});
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (label != null) FieldLabel(label!),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [for (final e in options.entries) ButtonSegment(value: e.key, label: Text(e.value, maxLines: 1))],
        selected: {value},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
      ),
    ]);
  }
}

/// A date picker field that stores 'YYYY-MM-DD' or empty.
class DueDateField extends StatelessWidget {
  const DueDateField({super.key, required this.value, required this.onChanged, this.note});
  final String value;
  final ValueChanged<String> onChanged;
  final String? note;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FieldLabel('Due date'),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(value.isEmpty ? 'Pick a date' : formatDue(value)),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value.isEmpty ? now : parseLocal(value),
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) onChanged(toISODate(picked));
            },
          ),
        ),
        if (value.isNotEmpty) TextButton(onPressed: () => onChanged(''), child: const Text('Clear date')),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(note ?? 'Optional.', style: TextStyle(color: context.colors.ink2, fontSize: 13)),
      ),
    ]);
  }
}

/// A rounded tappable card.
class TapCard extends StatelessWidget {
  const TapCard({super.key, required this.child, this.onTap, this.color, this.border});
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: border != null ? BorderSide(color: border!, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(18), child: child)),
    );
  }
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.small = false, this.maxLines});
  final String text;
  final bool small;
  final int? maxLines;
  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        style: TextStyle(color: context.colors.ink2, fontSize: small ? 13 : 15),
      );
}
