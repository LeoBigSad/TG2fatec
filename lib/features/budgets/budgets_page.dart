import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/category_catalog.dart';
import '../../state/finance_controller.dart';
import '../shared/finance_widgets.dart';
import 'budget_form_sheet.dart';

/// Aba de orçamentos (RF12; Figma: Budget #1, Empty e Error).
class BudgetsPage extends StatefulWidget {
  const BudgetsPage({super.key});

  @override
  State<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends State<BudgetsPage> {
  /// Orçamento destacado no carrossel; `null` mostra todos.
  int? _selectedBudgetId;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final statuses = finance.budgetStatuses();
    final visible = _selectedBudgetId == null
        ? statuses
        : statuses.where((s) => s.budget.id == _selectedBudgetId).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: MonthSelector(value: finance.month, onChanged: (m) => finance.month = m),
        ),
        Center(child: BudgetDonut(statuses: statuses)),
        const SizedBox(height: AppSpacing.md),
        SectionHeader(
          title: 'Orçamentos',
          actionLabel: 'Novo',
          actionIcon: Icons.add,
          onAction: () => startNewBudget(context),
        ),
        if (statuses.isNotEmpty) ...[
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, i) {
                final s = statuses[i];
                final c = finance.category(s.budget.categoryId);
                final selected = s.budget.id == _selectedBudgetId;
                return SizedBox(
                  width: 92,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xxs),
                    borderColor: selected ? AppColors.textPrimary : (s.isOver ? AppColors.error : null),
                    onTap: () => setState(() => _selectedBudgetId = selected ? null : s.budget.id),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(CategoryIcons.of(c?.iconKey ?? 'other'), color: c?.color, size: 20),
                      Text(c?.name ?? '—', style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                      Text(Fmt.money(s.budget.limitCents), style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (statuses.isEmpty)
          EmptyState(
            icon: Icons.price_change_outlined,
            message: 'Detalhes dos orçamentos serão mostrados aqui',
            action: FilledButton.icon(
              onPressed: () => startNewBudget(context),
              icon: const Icon(Icons.add),
              label: const Text('Criar orçamento'),
            ),
          ),
        for (final s in visible) ...[BudgetStatusCard(status: s), const SizedBox(height: AppSpacing.xs)],
        if (_selectedBudgetId != null)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _selectedBudgetId = null),
              style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
              child: const Text('Ver todos'),
            ),
          ),
      ],
    );
  }
}
