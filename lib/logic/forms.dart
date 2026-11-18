// Unsaved-changes detection for the issue and task forms. Ported from src/lib/forms.js.
// Text is trimmed, and empty and null both mean "nothing", so a field that was only
// touched (typed into and erased, or given trailing spaces) doesn't count.
String _normalize(Object? value) => value == null ? '' : value.toString().trim();

bool hasUnsavedChanges(Map<String, Object?> initial, Map<String, Object?> current) {
  final keys = {...initial.keys, ...current.keys};
  return keys.any((k) => _normalize(initial[k]) != _normalize(current[k]));
}
