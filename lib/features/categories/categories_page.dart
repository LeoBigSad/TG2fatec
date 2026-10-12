import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../data/category_catalog.dart';
import '../../data/models/models.dart';
import '../../state/finance_controller.dart';

/// Gerenciamento de categorias de despesa e receita (RF6, RF7 e RF8).
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            title: Text('Categorias', style: AppTextStyles.heading),
            bottom: const TabBar(
              labelColor: AppColors.textPrimary,
              indicatorColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [Tab(text: 'Despesas'), Tab(text: 'Receitas')],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Nova categoria',
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            onPressed: () => showCategoryForm(
              context,
              type: DefaultTabController.of(context).index == 0 ? TransactionType.expense : TransactionType.income,
            ),
            child: const Icon(Icons.add),
          ),
          body: const TabBarView(children: [
            _CategoryList(type: TransactionType.expense),
            _CategoryList(type: TransactionType.income),
          ]),
        );
      }),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final categories = finance.categoriesOf(type);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 88),
      children: [
        if (categories.isEmpty) const EmptyState(icon: Icons.category_outlined, message: 'Nenhuma categoria.'),
        for (final c in categories) ...[
          AppCard(
            onTap: () => showCategoryForm(context, existing: c, type: type),
            child: Row(children: [
              CategoryAvatar(category: c),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                  Text('${finance.transactionCountFor(c)} transações', style: AppTextStyles.caption),
                ]),
              ),
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary),
                onPressed: () => _delete(context, c),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  Future<void> _delete(BuildContext context, FinanceCategory c) async {
    final finance = context.read<FinanceController>();
    final count = finance.transactionCountFor(c);
    final budgets = finance.budgets.where((b) => b.categoryId == c.id).length;
    final details = [
      if (count > 0) '$count transações ficarão sem categoria',
      if (budgets > 0) '$budgets orçamento(s) desta categoria serão excluídos',
    ];
    if (await confirmDialog(context,
        title: 'Excluir categoria',
        message: 'Deseja excluir "${c.name}"?${details.isEmpty ? '' : '\n\n${details.join('.\n')}.'}')) {
      await finance.deleteCategory(c);
      if (context.mounted) showMessage(context, 'Categoria excluída.');
    }
  }
}

Future<void> showCategoryForm(BuildContext context, {FinanceCategory? existing, required TransactionType type}) {
  return showAppSheet<void>(
    context,
    title: existing == null ? 'Nova Categoria' : 'Editar Categoria',
    builder: (_) => _CategoryForm(existing: existing, type: type),
  );
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.existing, required this.type});

  final FinanceCategory? existing;
  final TransactionType type;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late String _icon = widget.existing?.iconKey ?? 'other';
  late Color _color = widget.existing?.color ?? categoryPalette.first;
  late TransactionType _type = widget.existing?.type ?? widget.type;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final finance = context.read<FinanceController>();
    final name = _name.text.trim();
    final duplicate = finance.categoriesOf(_type).any(
          (c) => c.id != widget.existing?.id && c.name.toLowerCase() == name.toLowerCase(),
        );
    if (duplicate) {
      showMessage(context, 'Já existe uma categoria com esse nome.', error: true);
      return;
    }
    final category = widget.existing?.copyWith(name: name, iconKey: _icon, color: _color, type: _type) ??
        FinanceCategory(userId: finance.userId, name: name, iconKey: _icon, color: _color, type: _type);
    await finance.saveCategory(category);
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, widget.existing == null ? 'Categoria criada.' : 'Categoria atualizada.');
  }

  @override
  Widget build(BuildContext context) {
    final preview = FinanceCategory(userId: 0, name: '', iconKey: _icon, color: _color, type: _type);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: CategoryAvatar(category: preview, size: 56)),
          const SizedBox(height: AppSpacing.md),
          LabeledField(label: 'Nome', controller: _name, validator: (v) => Validators.required(v, 'Nome')),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(value: TransactionType.expense, label: Text('Despesa')),
              ButtonSegment(value: TransactionType.income, label: Text('Receita')),
            ],
            selected: {_type},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onPrimary,
            ),
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Ícone', style: AppTextStyles.fieldLabel),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            for (final e in CategoryIcons.all.entries)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _icon = e.key),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _icon == e.key ? _color.withValues(alpha: 0.25) : AppColors.surface,
                  child: Icon(e.value, size: 20, color: _icon == e.key ? _color : AppColors.textSecondary),
                ),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text('Cor', style: AppTextStyles.fieldLabel),
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
            for (final c in categoryPalette)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == c ? AppColors.textPrimary : Colors.transparent, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _save, child: Text(widget.existing == null ? 'Criar' : 'Salvar')),
        ],
      ),
    );
  }
}
