import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../state/finance_controller.dart';
import '../auth/auth_widgets.dart';
import 'import_page.dart';

/// Extratos importados, com exclusão mediante confirmação (RF4).
class ImportsPage extends StatelessWidget {
  const ImportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    return Scaffold(
      appBar: flowAppBar('Extratos importados'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportPage())),
        icon: const Icon(Icons.upload_file),
        label: const Text('Importar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (finance.imports.isEmpty)
            const EmptyState(icon: Icons.upload_file, message: 'Nenhum extrato importado ainda.'),
          for (final i in finance.imports) ...[
            AppCard(
              child: Row(children: [
                const Icon(Icons.description_outlined, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.fileName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    Text('${i.source.name.toUpperCase()} · ${i.count} transações · ${Fmt.date(i.importedAt)}',
                        style: AppTextStyles.caption),
                  ]),
                ),
                IconButton(
                  tooltip: 'Excluir extrato',
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () async {
                    if (await confirmDialog(context,
                        title: 'Excluir extrato',
                        message: 'As ${i.count} transações importadas de "${i.fileName}" também serão excluídas.')) {
                      await finance.deleteImport(i);
                      if (context.mounted) showMessage(context, 'Extrato excluído.');
                    }
                  },
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}
