import 'package:intl/intl.dart';

/// Formatação de valores e datas no padrão usado nas telas do Figma.
abstract final class Fmt {
  static final _number = NumberFormat('#,##0.00', 'pt_BR');

  static const months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', //
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  static const monthsShort = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', //
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  /// `R$1.234,56`. Com [signed], valores positivos recebem `+`.
  static String money(int cents, {bool signed = false}) {
    final value = _number.format(cents.abs() / 100);
    final sign = cents < 0 ? '-' : (signed && cents > 0 ? '+' : '');
    return '${sign}R\$$value';
  }

  /// Valor sem o símbolo da moeda: `1.234,56`.
  static String amount(int cents) => _number.format(cents / 100);

  /// `Out 20`, como na lista de transações.
  static String shortDate(DateTime d) => '${monthsShort[d.month - 1]} ${d.day}';

  static String date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  static String monthYear(DateTime d) => '${months[d.month - 1]} ${d.year}';

  static String percent(double ratio) => '${(ratio * 100).round()}%';

  /// Formato de data persistido no banco (`yyyy-MM-dd`).
  static String dbDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}

extension DateOnly on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
  DateTime get monthStart => DateTime(year, month);
  DateTime get monthEnd => DateTime(year, month + 1, 0);
  bool isSameMonth(DateTime other) => year == other.year && month == other.month;
}
