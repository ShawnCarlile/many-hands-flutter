// Issue and member search. Ported from the web app's src/lib/filter.js.
import '../models.dart';

const issueViews = {'active': 'Active', 'resolved': 'Resolved', 'all': 'All'};

List<String> _words(String search) =>
    search.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

List<Issue> filterIssues(List<Issue> issues, {String view = 'active', String search = ''}) {
  final words = _words(search);
  return issues.where((issue) {
    if (view == 'active' && issue.status == 'resolved') return false;
    if (view == 'resolved' && issue.status != 'resolved') return false;
    final text = '${issue.title} ${issue.description}'.toLowerCase();
    return words.every(text.contains);
  }).toList();
}

// A word made only of digits and phone punctuation also matches by digits, so
// "5551234", "555-1234" and "(555) 123" all find (555) 123-4567.
final _phoneWord = RegExp(r'^[\d()+\-.]+$');
String _digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');

List<Member> filterMembers(List<Member> members, String search) {
  final words = _words(search);
  if (words.isEmpty) return members;
  return members.where((m) {
    final text = '${m.name} ${m.email} ${m.phone}'.toLowerCase();
    final phoneDigits = _digitsOf(m.phone);
    return words.every((word) {
      if (text.contains(word)) return true;
      final wordDigits = _phoneWord.hasMatch(word) ? _digitsOf(word) : '';
      return wordDigits.isNotEmpty && phoneDigits.contains(wordDigits);
    });
  }).toList();
}
