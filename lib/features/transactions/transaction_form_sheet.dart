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
import '../../data/models/models.dart';
import '../../state/finance_controller.dart';
import 'category_picker_sheet.dart';

/// "Adicionar a Nova Transação" (RF5) e edição (RF3).
Future<void> showTransactionForm(BuildContext context, {FinanceTransaction? existing}) {
  return showAppSheet<void>(
    context,
    title: existing == null ? 'Adicionar a Nova Transação' : 'Editar Transação',
    builder: (_) => _TransactionForm(existing: existing),
  );
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({this.existing});

  final FinanceTransaction? existing;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _account = TextEditingController(text: widget.existing?.account);
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : Fmt.amount(widget.existing!.amountCents),
  );
  late TransactionType _type = widget.existing?.type ?? TransactionType.expense;
  late DateTime _date = widget.existing?.date ?? DateTime.now().dateOnly;
  late int? _categoryId = widget.existing?.categoryId;

  /// Categoria escolhida automaticamente (RF9) até o usuário escolher outra.
  bool _suggested = false;
  bool _categoryError = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _account, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  void _suggest() {
    if (_categoryId != null && !_suggested) return;
    final suggestion = context.read<FinanceController>().suggestCategory(_title.text, _type);
    setState(() {
      _categoryId = suggestion?.id;
      _suggested = suggestion != null;
    });
  }

  Future<void> _pickCategory() async {
    final c = await showCategoryPicker(context, type: _type, selectedId: _categoryId);
    if (c != null) {
      setState(() {
        _categoryId = c.id;
        _suggested = false;
        _categoryError = false;
      });
    }
  }

  Future<void> _save() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _categoryError = _categoryId == null);
    if (!valid || _categoryId == null) return;
    final finance = context.read<FinanceController>();
    final base = widget.existing ??
        FinanceTransaction(userId: finance.userId, type: _type, title: '', amountCents: 0, date: _date);
    setState(() => _saving = true);
    await finance.saveTransaction(base.copyWith(
      type: _type,
      title: _title.text.trim(),
      description: _description.text.trim(),
      account: _account.text.trim(),
      amountCents: MoneyInputFormatter.parse(_amount.text),
      date: _date,
      categoryId: () => _categoryId,
    ));
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, widget.existing == null ? 'Transação adicionada.' : 'Transação atualizada.');
  }

  @override
  Widget build(BuildContext context) {
    final category = context.watch<FinanceController>().category(_categoryId);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeTabs(
            value: _type,
            onChanged: (t) => setState(() {
              _type = t;
              _categoryId = null;
              _suggested = false;
              _suggest();
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          LabeledField(
            label: 'Nome da Transação',
            controller: _title,
            hint: 'Ex.: Supermercado',
            validator: (v) => Validators.required(v, 'Nome'),
            onChanged: (_) => _suggest(),
          ),
          const SizedBox(height: AppSpacing.sm),
          PickerField(
            label: 'Selecione o ícone',
            value: category?.name,
            hint: 'Categoria',
            leading: category == null ? null : CategoryAvatar(category: category, size: 24),
            onTap: _pickCategory,
            errorText: _categoryError ? 'Selecione uma categoria' : null,
          ),
          if (_suggested)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Categoria sugerida automaticamente',
                  style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
            ),
          const SizedBox(height: AppSpacing.sm),
          PickerField(
            label: 'Data',
            value: Fmt.date(_date),
            trailingIcon: Icons.calendar_today_outlined,
            onTap: () async {
              final d = await showDatePickerSheet(context, initial: _date);
              if (d != null) setState(() => _date = d);
            },
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
          const SizedBox(height: AppSpacing.sm),
          LabeledField(label: 'Conta (opcional)', controller: _account, hint: 'Ex.: Nubank, Carteira'),
          const SizedBox(height: AppSpacing.sm),
          LabeledField(
            label: 'Descrição (opcional)',
            controller: _description,
            hint: 'Observações',
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(widget.existing == null ? 'Adicionar' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}

/// Abas "Receita | Gasto" com sublinhado.
class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in TransactionType.values)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(t),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: value == t ? AppColors.textPrimary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  t.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitle.copyWith(
                    fontWeight: FontWeight.w400,
                    color: value == t ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
