// US phone numbers, always stored and shown as (555) 123-4567.
// Ported from the web app's src/lib/phone.js. firestore.rules checks the same shape.
import 'package:flutter/services.dart';

const phonePlaceholder = '(555) 123-4567';
final _phonePattern = RegExp(r'^\(\d{3}\) \d{3}-\d{4}$');

/// Up to 10 digits. Drops a leading 1 (country code), since US area codes never start with 1.
String phoneDigits(String? value) {
  var d = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('1')) d = d.substring(1);
  return d.length > 10 ? d.substring(0, 10) : d;
}

/// Formats as the user types, so partial input looks right too: (555, (555) 12, (555) 123-4.
String formatPhone(String? value) {
  final d = phoneDigits(value);
  if (d.isEmpty) return '';
  if (d.length <= 3) return '($d';
  if (d.length <= 6) return '(${d.substring(0, 3)}) ${d.substring(3)}';
  return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
}

bool isValidPhone(String value) => _phonePattern.hasMatch(value);

/// Older entries saved before formatting get cleaned up if they have 10 digits.
String displayPhone(String? value) => phoneDigits(value).length == 10 ? formatPhone(value) : (value ?? '');

Uri phoneUri(String? value) {
  final d = phoneDigits(value);
  return Uri.parse(d.length == 10 ? 'tel:+1$d' : 'tel:${value ?? ''}');
}

/// A TextField formatter that keeps the field in (555) 123-4567 shape.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = formatPhone(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
