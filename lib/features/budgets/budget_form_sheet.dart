import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/date_picker_sheet.dart';
import '../../data/category_catalog.dart';
import '../../data/models/models.dart';
import '../../state/finance_controller.dart';

/// "Novo": escolhe a categoria (Figma: New Budget #1) e abre o formulário.
Future<void> startNewBudget(BuildContext context) async {
  final category = await showBudgetCategorySheet(context);
  if (category == null || !context.mounted) return;
  await showBudgetForm(context, category: category);
}

/// "Selecione o Orçamento": lista de categorias de despesa com checkbox.
Future<FinanceCategory?> showBudgetCategorySheet(BuildContext context, {int? selectedId}) {
  int? selected = selectedId;
  return showAppSheet<FinanceCategory>(
    context,
    title: 'Selecione o Orçamento',
    showBack: true,
    showClose: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final categories = ctx.read<FinanceController>().categoriesOf(TransactionType.expense);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in categories)
            CheckboxListTile(
              value: selected == c.id,
              onChanged: (_) => setState(() => selected = c.id),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
              title: Row(children: [
                Icon(CategoryIcons.of(c.iconKey), size: 20, color: c.color),
                const SizedBox(width: AppSpacing.xs),
                Text(c.name, style: AppTextStyles.body),
              ]),
            ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: selected == null ? null : () => Navigator.pop(ctx, categories.firstWhere((c) => c.id == selected)),
            child: const Text('Selecionar'),
          ),
        ],
      );
    }),
  );
}

/// "Adicione um Novo Orçamento" (Figma: New Budget #2 / Budget #2) e edição (RF15).
Future<void> showBudgetForm(BuildContext context, {Budget? existing, FinanceCategory? category}) async {
  final saved = await showAppSheet<bool>(
    context,
    title: existing == null ? 'Adicione um Novo Orçamento' : 'Editar Orçamento',
    builder: (_) => _BudgetForm(existing: existing, initialCategoryId: category?.id ?? existing?.categoryId),
  );
  if (saved == true && context.mounted) {
    if (existing == null) {
      await showSuccessSheet(context, message: 'Seu orçamento foi adicionado junto com os outros.');
    } else {
      showMessage(context, 'Orçamento atualizado.');
    }
  }
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({this.existing, this.initialCategoryId});

  final Budget? existing;
  final int? initialCategoryId;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : Fmt.amount(widget.existing!.limitCents),
  );
  late int? _categoryId = widget.initialCategoryId;
  late DateTime _start = widget.existing?.startDate ?? DateTime.now().monthStart;
  late DateTime? _end = widget.existing?.endDate;
  late bool _repeat = widget.existing?.repeatMonthly ?? true;
  String? _dateError;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _dateError = _end != null && _end!.isBefore(_start) ? 'A data de fim deve ser após o início' : null);
    if (!valid || _dateError != null || _categoryId == null) return;
    final finance = context.read<FinanceController>();
    final limit = MoneyInputFormatter.parse(_amount.text);
    final budget = widget.existing?.copyWith(
          categoryId: _categoryId,
          limitCents: limit,
          startDate: _start,
          endDate: () => _end,
          repeatMonthly: _repeat,
        ) ??
        Budget(
          userId: finance.userId,
          categoryId: _categoryId!,
          limitCents: limit,
          startDate: _start,
          endDate: _end,
          repeatMonthly: _repeat,
        );
    await finance.saveBudget(budget);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final category = finance.category(_categoryId);
    final suggestion = _categoryId == null ? null : finance.suggestBudget(_categoryId!);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField(
            label: 'Nome do Orçamento',
            value: category?.name,
            leading: category == null ? null : Icon(CategoryIcons.of(category.iconKey), size: 18, color: category.color),
            onTap: () async {
              final c = await showBudgetCategorySheet(context, selectedId: _categoryId);
              if (c != null) setState(() => _categoryId = c.id);
            },
            errorText: _categoryId == null ? 'Selecione a categoria' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          LabeledField(
            label: 'Valor',
            controller: _amount,
            hint: '0,00',
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            prefixText: 'R\$ ',
            validator: (v) => Validators.positiveMoney(MoneyInputFormatter.parse(v ?? '')),
          ),
          if (suggestion != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: AppCard(
                borderColor: AppColors.accent.withValues(alpha: 0.4),
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xxs),
                child: Row(children: [
                  const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text('Sugestão: ${Fmt.money(suggestion)} (média dos últimos meses)',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
                  ),
                  TextButton(
                    onPressed: () => _amount.text = Fmt.amount(suggestion),
                    child: const Text('Usar'),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          PickerField(
            label: 'Data de Início',
            value: Fmt.date(_start),
            trailingIcon: Icons.calendar_today_outlined,
            onTap: () async {
              final d = await showDatePickerSheet(context, initial: _start);
              if (d != null) setState(() => _start = d);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          PickerField(
            label: 'Data de Fim',
            value: _end == null ? null : Fmt.date(_end!),
            hint: _repeat ? 'Sem data de fim' : 'Fim do mês de início',
            trailingIcon: _end == null ? Icons.calendar_today_outlined : Icons.close,
            errorText: _dateError,
            onTap: () async {
              if (_end != null) {
                setState(() => _end = null);
                return;
              }
              final d = await showDatePickerSheet(context, initial: _start.monthEnd, first: _start);
              if (d != null) setState(() => _end = d);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Expanded(child: Text('Repetir todos os meses', style: AppTextStyles.bodySmall)),
            Switch(
              value: _repeat,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => setState(() => _repeat = v),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: _save, child: Text(widget.existing == null ? 'Adicionar' : 'Salvar')),
        ],
      ),
    );
  }
}
