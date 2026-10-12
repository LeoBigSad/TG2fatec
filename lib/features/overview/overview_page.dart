import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../services/finance_stats.dart';
import '../../state/finance_controller.dart';
import '../budgets/budget_form_sheet.dart';
import '../reports/export_report_sheet.dart';
import '../shared/finance_widgets.dart';
import '../transactions/transaction_form_sheet.dart';

/// Visão Geral (Figma: Dashboard #1), com separação por mês (RF10) e por
/// ano (RF11).
class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  bool _yearly = false;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final month = finance.month;
    final txs = finance.transactions;

    final periodTxs = (_yearly ? FinanceStats.inYear(txs, month.year) : FinanceStats.inMonth(txs, month)).toList();
    final previousTxs = _yearly
        ? FinanceStats.inYear(txs, month.year - 1)
        : FinanceStats.inMonth(txs, DateTime(month.year, month.month - 1));
    final values =
        _yearly ? FinanceStats.monthlyExpenses(txs, month.year) : FinanceStats.weeklyExpenses(txs, month);
    final labels = _yearly
        ? Fmt.monthsShort.map((m) => m[0]).toList()
        : [for (var i = 1; i <= values.length; i++) 'Sem. $i'];
    final periodName = _yearly ? '${month.year}' : Fmt.months[month.month - 1];

    final statuses = finance.budgetStatuses();
    final overBudgets = statuses.where((s) => s.isOver).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        Row(children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Mês')),
              ButtonSegment(value: true, label: Text('Ano')),
            ],
            selected: {_yearly},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onPrimary,
              side: const BorderSide(color: AppColors.border),
            ),
            onSelectionChanged: (s) => setState(() => _yearly = s.first),
          ),
          const Spacer(),
          MonthSelector(value: month, yearOnly: _yearly, onChanged: (m) => finance.month = m),
          IconButton(
            tooltip: 'Exportar relatório',
            icon: const Icon(Icons.ios_share, size: 20),
            onPressed: () => showExportReportSheet(context, yearly: _yearly),
          ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        SectionHeader(
          title: 'Transações',
          actionLabel: 'Novo',
          actionIcon: Icons.add,
          onAction: () => showTransactionForm(context),
        ),
        if (periodTxs.isEmpty)
          const EmptyState(icon: Icons.sync, message: 'Detalhes das transações serão mostrados aqui')
        else ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Text('Gastos de $periodName', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  Expanded(
                    child: Text('Total ${Fmt.money(FinanceStats.expense(periodTxs))}',
                        style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text('${Fmt.money(FinanceStats.expense(previousTxs))} ${_yearly ? 'Ano anterior' : 'Último mês'}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                SpendingAreaChart(values: values, labels: labels),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final t in periodTxs.take(3)) ...[
            TransactionTile(transaction: t),
            const SizedBox(height: AppSpacing.xs),
          ],
          Center(
            child: TextButton(
              onPressed: () => widget.onNavigate(2),
              style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
              child: const Text('Ver todas'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SectionHeader(
          title: 'Orçamentos',
          actionLabel: 'Novo',
          actionIcon: Icons.add,
          onAction: () => startNewBudget(context),
        ),
        if (statuses.isEmpty)
          const EmptyState(icon: Icons.price_change_outlined, message: 'Detalhes dos orçamentos serão mostrados aqui')
        else ...[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Text('Resumo de ${Fmt.months[month.month - 1]}',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  BudgetRingsChart(
                    rings: [
                      for (final s in statuses)
                        (ratio: s.ratio, color: finance.category(s.budget.categoryId)?.color ?? AppColors.textTertiary),
                    ],
                    center: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Orçamento', style: AppTextStyles.caption),
                      Text(Fmt.money(statuses.fold(0, (s, b) => s + b.budget.limitCents)),
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ChartLegend(items: [
                      for (final s in statuses.take(6))
                        (
                          color: s.isOver
                              ? AppColors.error
                              : finance.category(s.budget.categoryId)?.color ?? AppColors.textTertiary,
                          label: finance.category(s.budget.categoryId)?.name ?? '—',
                          trailing: Fmt.percent(s.ratio),
                        ),
                    ]),
                  ),
                ]),
                for (final s in overBudgets) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        'Você estourou o orçamento de ${finance.category(s.budget.categoryId)?.name ?? 'uma categoria'}',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final s in statuses.take(3)) ...[
            BudgetStatusCard(status: s),
            const SizedBox(height: AppSpacing.xs),
          ],
          Center(
            child: TextButton(
              onPressed: () => widget.onNavigate(3),
              style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
              child: const Text('Ver todos'),
            ),
          ),
        ],
      ],
    );
  }
}
