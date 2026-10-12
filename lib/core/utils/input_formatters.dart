import 'package:flutter/services.dart';

import 'formatters.dart';

/// Campo de valor monetário: os dígitos digitados são tratados como centavos
/// (`1`, `12`, `123` → `0,01`, `0,12`, `1,23`).
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final cents = int.parse(digits.length > 13 ? digits.substring(0, 13) : digits);
    final text = Fmt.amount(cents);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Converte o texto do campo (`1.234,56`) em centavos.
  static int parse(String text) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }
}

/// Máscara de telefone brasileiro: `(11) 91234-5678`.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    final text = format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  static String format(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (digits.length == 11 && i == 7 || digits.length < 11 && i == 6) b.write('-');
      b.write(digits[i]);
    }
    return b.toString();
  }

  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');
}
