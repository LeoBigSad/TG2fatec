import '../core/utils/formatters.dart';
import '../data/models/models.dart';

/// Situação de um orçamento num mês.
class BudgetStatus {
  const BudgetStatus(this.budget, this.spentCents);

  final Budget budget;
  final int spentCents;

  double get ratio => budget.limitCents == 0 ? 0 : spentCents / budget.limitCents;
  int get remainingCents => budget.limitCents - spentCents;

  /// Alerta a partir de 80% do limite (RF14).
  static const warningRatio = 0.8;

  bool get isOver => spentCents > budget.limitCents;
  bool get isWarning => !isOver && ratio >= warningRatio;
}

/// Cálculos sobre as transações e orçamentos já carregados.
abstract final class FinanceStats {
  static Iterable<FinanceTransaction> inRange(Iterable<FinanceTransaction> txs, DateTime start, DateTime end) {
    final s = start.dateOnly, e = end.dateOnly;
    return txs.where((t) => !t.date.isBefore(s) && !t.date.isAfter(e));
  }

  static Iterable<FinanceTransaction> inMonth(Iterable<FinanceTransaction> txs, DateTime month) =>
      inRange(txs, month.monthStart, month.monthEnd);

  static Iterable<FinanceTransaction> inYear(Iterable<FinanceTransaction> txs, int year) =>
      inRange(txs, DateTime(year), DateTime(year, 12, 31));

  static int income(Iterable<FinanceTransaction> txs) =>
      txs.where((t) => !t.isExpense).fold(0, (s, t) => s + t.amountCents);

  static int expense(Iterable<FinanceTransaction> txs) =>
      txs.where((t) => t.isExpense).fold(0, (s, t) => s + t.amountCents);

  /// Despesas agrupadas por categoria, da maior para a menor.
  static List<MapEntry<int?, int>> expensesByCategory(Iterable<FinanceTransaction> txs) {
    final map = <int?, int>{};
    for (final t in txs.where((t) => t.isExpense)) {
      map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amountCents;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Despesas por semana do mês (dias 1–7, 8–14, ...).
  static List<int> weeklyExpenses(Iterable<FinanceTransaction> txs, DateTime month) {
    final weeks = List<int>.filled(((month.monthEnd.day - 1) ~/ 7) + 1, 0);
    for (final t in inMonth(txs, month).where((t) => t.isExpense)) {
      weeks[(t.date.day - 1) ~/ 7] += t.amountCents;
    }
    return weeks;
  }

  static List<int> monthlyExpenses(Iterable<FinanceTransaction> txs, int year) {
    final months = List<int>.filled(12, 0);
    for (final t in inYear(txs, year).where((t) => t.isExpense)) {
      months[t.date.month - 1] += t.amountCents;
    }
    return months;
  }

  /// Intervalo em que o orçamento vale dentro do mês, ou `null` se inativo.
  static ({DateTime start, DateTime end})? budgetPeriod(Budget b, DateTime month) {
    final ms = month.monthStart, me = month.monthEnd;
    if (b.startDate.isAfter(me)) return null;
    if (b.repeatMonthly) {
      if (b.endDate != null && b.endDate!.isBefore(ms)) return null;
      return (start: ms, end: me);
    }
    final end = b.endDate ?? b.startDate.monthEnd;
    if (end.isBefore(ms)) return null;
    return (start: b.startDate.isAfter(ms) ? b.startDate : ms, end: end.isBefore(me) ? end : me);
  }

  static List<BudgetStatus> budgetStatuses(List<Budget> budgets, List<FinanceTransaction> txs, DateTime month) {
    final result = <BudgetStatus>[];
    for (final b in budgets) {
      final period = budgetPeriod(b, month);
      if (period == null) continue;
      final spent = inRange(txs, period.start, period.end)
          .where((t) => t.isExpense && t.categoryId == b.categoryId)
          .fold(0, (s, t) => s + t.amountCents);
      result.add(BudgetStatus(b, spent));
    }
    return result;
  }

  /// Sugestão de orçamento (RF13): média mensal de gastos na categoria nos
  /// últimos [months] meses fechados, arredondada para cima em R$10.
  static int? suggestBudget(int categoryId, List<FinanceTransaction> txs, DateTime now, {int months = 3}) {
    var total = 0;
    var monthsWithData = 0;
    for (var i = 1; i <= months; i++) {
      final month = DateTime(now.year, now.month - i);
      final spent = inMonth(txs, month)
          .where((t) => t.isExpense && t.categoryId == categoryId)
          .fold(0, (s, t) => s + t.amountCents);
      if (spent > 0) monthsWithData++;
      total += spent;
    }
    if (monthsWithData == 0) return null;
    final average = total / monthsWithData;
    return ((average / 1000).ceil()) * 1000;
  }
}
