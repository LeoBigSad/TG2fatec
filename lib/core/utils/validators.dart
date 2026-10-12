import 'input_formatters.dart';

abstract final class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? required(String? v, [String field = 'Campo']) =>
      (v == null || v.trim().isEmpty) ? '$field obrigatório' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    return _email.hasMatch(v.trim()) ? null : 'E-mail inválido';
  }

  /// Mínimo de 8 caracteres, com ao menos uma letra e um número.
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 8) return 'A senha deve ter ao menos 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use letras e números';
    }
    return null;
  }

  static String? phone(String? v) {
    final digits = PhoneInputFormatter.digitsOf(v ?? '');
    if (digits.isEmpty) return 'Informe o telefone';
    return digits.length >= 10 ? null : 'Telefone inválido';
  }

  static String? positiveMoney(int cents) => cents > 0 ? null : 'Informe um valor';
}
