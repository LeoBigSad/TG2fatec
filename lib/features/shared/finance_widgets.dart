import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/common.dart';
import '../../data/category_catalog.dart';
import '../../data/models/models.dart';
import '../../services/finance_stats.dart';
import '../../state/finance_controller.dart';
import '../budgets/budget_form_sheet.dart';
import '../transactions/transaction_form_sheet.dart';

/// Item da lista de transações (Figma: Transaction #1).
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, this.showMenu = true, this.hidden = false});

  final FinanceTransaction transaction;
  final bool showMenu;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final t = transaction;
    final category = finance.category(t.categoryId);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs),
      onTap: showMenu ? () => showTransactionForm(context, existing: t) : null,
      child: Row(
        children: [
          CategoryAvatar(category: category),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.shortDate(t.date)} · ${category?.name ?? 'Sem categoria'}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          MoneyText(
            t.signedCents,
            signed: true,
            hidden: hidden,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
              color: t.isExpense ? AppColors.textValue : AppColors.income,
            ),
          ),
          if (showMenu)
            PopupMenuButton<String>(
              tooltip: 'Opções',
              iconColor: AppColors.textTertiary,
              iconSize: 18,
              color: AppColors.surface,
              onSelected: (v) async {
                if (v == 'edit') {
                  showTransactionForm(context, existing: t);
                } else if (await confirmDialog(context,
                    title: 'Excluir transação', message: 'Deseja excluir "${t.title}"?')) {
                  await finance.deleteTransaction(t);
                  if (context.mounted) showMessage(context, 'Transação excluída.');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit, size: 18), title: Text('Editar'))),
                PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline, size: 18), title: Text('Excluir'))),
              ],
            )
          else
            const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// Cartão de acompanhamento de um orçamento (Figma: Budget #1).
class BudgetStatusCard extends StatelessWidget {
  const BudgetStatusCard({super.key, required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final category = finance.category(status.budget.categoryId);
    final color = category?.color ?? AppColors.textTertiary;
    final over = status.isOver;
    return AppCard(
      borderColor: over ? AppColors.error : (status.isWarning ? AppColors.warning : null),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(CategoryIcons.of(category?.iconKey ?? 'other'), color: color, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(category?.name ?? 'Categoria removida', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500))),
            if (over || status.isWarning)
              Row(children: [
                Icon(over ? Icons.error_outline : Icons.warning_amber_rounded,
                    size: 16, color: over ? AppColors.error : AppColors.warning),
                const SizedBox(width: 4),
                Text(over ? 'Acima do esperado' : 'Perto do limite',
                    style: AppTextStyles.bodySmall.copyWith(color: over ? AppColors.error : AppColors.warning)),
              ]),
            PopupMenuButton<String>(
              tooltip: 'Opções',
              iconColor: AppColors.textTertiary,
              iconSize: 18,
              color: AppColors.surface,
              onSelected: (v) async {
                if (v == 'edit') {
                  showBudgetForm(context, existing: status.budget);
                } else if (await confirmDialog(context,
                    title: 'Excluir orçamento',
                    message: 'Deseja excluir o orçamento de ${category?.name ?? 'categoria'}?')) {
                  await finance.deleteBudget(status.budget);
                  if (context.mounted) showMessage(context, 'Orçamento excluído.');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit, size: 18), title: Text('Editar'))),
                PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline, size: 18), title: Text('Deletar'))),
              ],
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BudgetProgressBar(ratio: status.ratio, color: color),
                const SizedBox(height: AppSpacing.xs),
                Row(children: [
                  Expanded(child: _Amount(label: 'Gasto no mês', cents: status.spentCents, over: over)),
                  _Amount(label: 'Orçamento do mês', cents: status.budget.limitCents, alignEnd: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.cents, this.alignEnd = false, this.over = false});

  final String label;
  final int cents;
  final bool alignEnd;
  final bool over;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
        Text(Fmt.money(cents),
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: over ? AppColors.error : AppColors.textPrimary)),
      ],
    );
  }
}

/// Rosca dos orçamentos: cada orçamento ocupa uma fatia proporcional ao
/// limite, preenchida na cor da categoria conforme o gasto (Figma: Budget #1).
class BudgetDonut extends StatelessWidget {
  const BudgetDonut({super.key, required this.statuses, this.size = 170, this.hidden = false});

  final List<BudgetStatus> statuses;
  final double size;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final total = statuses.fold(0, (s, b) => s + b.budget.limitCents);
    final slices = <ChartSlice>[];
    for (final s in statuses) {
      final color = finance.category(s.budget.categoryId)?.color ?? AppColors.textTertiary;
      final spent = s.spentCents.clamp(0, s.budget.limitCents).toDouble();
      slices
        ..add(ChartSlice(label: '', value: spent, color: s.isOver ? AppColors.error : color))
        ..add(ChartSlice(label: '', value: s.budget.limitCents - spent, color: AppColors.divider));
    }
    return Column(
      children: [
        DonutChart(
          size: size,
          thickness: size * 0.2,
          slices: slices,
          center: MoneyText(total, hidden: hidden, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          alignment: WrapAlignment.center,
          children: [
            for (final s in statuses)
              Builder(builder: (_) {
                final c = finance.category(s.budget.categoryId);
                final color = s.isOver ? AppColors.error : (c?.color ?? AppColors.textTertiary);
                return Text.rich(TextSpan(children: [
                  TextSpan(text: '${Fmt.percent(s.ratio)} ', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  TextSpan(text: c?.name ?? '—', style: TextStyle(color: color)),
                ]), style: AppTextStyles.caption);
              }),
          ],
        ),
      ],
    );
  }
}
