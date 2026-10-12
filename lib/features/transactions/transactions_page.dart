import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../services/finance_stats.dart';
import '../../state/finance_controller.dart';
import '../shared/finance_widgets.dart';
import 'import_page.dart';
import 'transaction_form_sheet.dart';

/// Lista de transações do mês (Figma: Transaction #1 e Transactions #2).
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final q = _query.trim().toLowerCase();
    final items = FinanceStats.inMonth(finance.transactions, finance.month)
        .where((t) => q.isEmpty || t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      children: [
        Row(children: [
          Expanded(child: Text('Transações', style: AppTextStyles.subtitle)),
          PopupMenuButton<String>(
            color: AppColors.surface,
            onSelected: (v) => v == 'manual'
                ? showTransactionForm(context)
                : Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportPage())),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'manual', child: ListTile(dense: true, leading: Icon(Icons.edit, size: 18), title: Text('Manual'))),
              PopupMenuItem(
                  value: 'import',
                  child: ListTile(dense: true, leading: Icon(Icons.upload_file, size: 18), title: Text('Importar extrato'))),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(children: [
                const Icon(Icons.add, size: 18),
                const SizedBox(width: 4),
                Text('Novo', style: AppTextStyles.body),
              ]),
            ),
          ),
        ]),
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'Buscar',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                constraints: const BoxConstraints(maxHeight: 40),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
          MonthSelector(value: finance.month, onChanged: (m) => finance.month = m),
        ]),
        const SizedBox(height: AppSpacing.sm),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${items.length} transações · Receitas ${Fmt.money(FinanceStats.income(items))} · '
              'Despesas ${Fmt.money(FinanceStats.expense(items))}',
              style: AppTextStyles.caption,
            ),
          ),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.sync_alt,
            message: q.isEmpty
                ? 'Nenhuma transação em ${Fmt.monthYear(finance.month)}.'
                : 'Nenhuma transação encontrada para "$_query".',
            action: q.isEmpty
                ? FilledButton.icon(
                    onPressed: () => showTransactionForm(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar transação'),
                  )
                : null,
          ),
        for (final t in items) ...[TransactionTile(transaction: t), const SizedBox(height: AppSpacing.xs)],
      ],
    );
  }
}
