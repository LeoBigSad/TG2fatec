import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../services/finance_stats.dart';
import '../../state/finance_controller.dart';
import '../shared/finance_widgets.dart';

/// Home (Figma: Home).
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final hidden = finance.hideValues;
    final monthTxs = FinanceStats.inMonth(finance.transactions, finance.month).toList();
    final income = FinanceStats.income(monthTxs);
    final expense = FinanceStats.expense(monthTxs);
    final statuses = finance.budgetStatuses();
    final recent = monthTxs.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        _SummaryCard(income: income, expense: expense, hidden: hidden),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: 'Visão Geral', actionLabel: 'Ver tudo', onAction: () => onNavigate(1)),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _CategoryCard(transactions: monthTxs, hidden: hidden)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardTitle('Receitas vs Despesas'),
                      const SizedBox(height: AppSpacing.sm),
                      IncomeExpenseBars(income: income, expense: expense),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: 'Lançamentos Recentes', actionLabel: 'Ver tudo', onAction: () => onNavigate(2)),
        if (recent.isEmpty)
          const EmptyState(icon: Icons.sync_alt, message: 'Detalhes das transações serão mostrados aqui')
        else
          for (final t in recent) ...[
            TransactionTile(transaction: t, showMenu: false, hidden: hidden),
            const SizedBox(height: AppSpacing.xs),
          ],
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: 'Orçamento', actionLabel: 'Ver tudo', onAction: () => onNavigate(3)),
        if (statuses.isEmpty)
          const EmptyState(icon: Icons.price_change_outlined, message: 'Detalhes dos orçamentos serão mostrados aqui')
        else
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: BudgetDonut(statuses: statuses, hidden: hidden),
          ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        Text('Este mês', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.income, required this.expense, required this.hidden});

  final int income;
  final int expense;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('Resumo financeiro', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ),
            MonthSelector(value: finance.month, onChanged: (m) => finance.month = m),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Expanded(child: _Figure(label: 'Receitas', color: AppColors.income, cents: income, hidden: hidden)),
            Expanded(child: _Figure(label: 'Despesas', color: AppColors.expense, cents: expense, hidden: hidden)),
          ]),
          const SizedBox(height: AppSpacing.md),
          _Figure(
            label: 'Saldo',
            color: AppColors.textMuted,
            cents: income - expense,
            hidden: hidden,
            valueColor: AppColors.balance,
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.color, required this.cents, required this.hidden, this.valueColor});

  final String label;
  final Color color;
  final int cents;
  final bool hidden;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: color)),
        MoneyText(cents, hidden: hidden, style: AppTextStyles.value.copyWith(color: valueColor)),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.transactions, required this.hidden});

  final List<FinanceTransaction> transactions;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final byCategory = FinanceStats.expensesByCategory(transactions);
    final total = byCategory.fold(0, (s, e) => s + e.value);
    final top = byCategory.take(3).toList();
    final otherTotal = byCategory.skip(3).fold(0, (s, e) => s + e.value);

    Color colorOf(int? id) => finance.category(id)?.color ?? AppColors.textTertiary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Despesas por categoria'),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: DonutChart(
              size: 110,
              thickness: 16,
              slices: [
                for (final e in byCategory) ChartSlice(label: '', value: e.value.toDouble(), color: colorOf(e.key)),
              ],
              center: MoneyText(total, hidden: hidden, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ChartLegend(items: [
            for (final e in top)
              (
                color: colorOf(e.key),
                label: finance.category(e.key)?.name ?? 'Sem categoria',
                trailing: Fmt.percent(total == 0 ? 0 : e.value / total),
              ),
            if (otherTotal > 0)
              (color: AppColors.textTertiary, label: 'Outras', trailing: Fmt.percent(otherTotal / total)),
          ]),
        ],
      ),
    );
  }
}
