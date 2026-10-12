import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../state/finance_controller.dart';
import '../categories/categories_page.dart';

/// Grade de categorias com ícone (Figma: "Selecionar o Ícone").
Future<FinanceCategory?> showCategoryPicker(
  BuildContext context, {
  required TransactionType type,
  int? selectedId,
  String title = 'Selecionar o Ícone',
}) {
  int? selected = selectedId;
  return showAppSheet<FinanceCategory>(
    context,
    title: title,
    showBack: true,
    showClose: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final categories = ctx.watch<FinanceController>().categoriesOf(type);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in categories)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => setState(() => selected = c.id),
                    child: SizedBox(
                      width: 76,
                      child: Column(children: [
                        CategoryAvatar(category: c, size: 44, selected: selected == c.id),
                        const SizedBox(height: 4),
                        Text(c.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: selected == c.id ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: selected == c.id ? FontWeight.w600 : null,
                            )),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CategoriesPage())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Gerenciar categorias'),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, categories.where((c) => c.id == selected).firstOrNull),
              child: const Text('Selecionar'),
            ),
          ],
        );
      },
    ),
  );
}
