import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Bottom sheet no padrão do Figma: cantos arredondados, título central,
/// seta de voltar e/ou botão de fechar.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool showBack = false,
  bool showClose = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl + 8))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || showBack || showClose)
              SizedBox(
                height: 40,
                child: Row(children: [
                  SizedBox(
                    width: 40,
                    child: showBack
                        ? IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.textTertiary),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(title ?? '', textAlign: TextAlign.center, style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: 40,
                    child: showClose
                        ? IconButton(
                            tooltip: 'Fechar',
                            icon: const Icon(Icons.close, color: AppColors.textTertiary),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        : null,
                  ),
                ]),
              ),
            const SizedBox(height: AppSpacing.xs),
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Sheet de sucesso (Figma: New Budget #4).
Future<void> showSuccessSheet(BuildContext context, {required String message}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => Column(
      children: [
        const Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
        const SizedBox(height: AppSpacing.sm),
        Text('Sucesso', style: AppTextStyles.heading.copyWith(color: AppColors.success)),
        const SizedBox(height: AppSpacing.xs),
        Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Concluir')),
      ],
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Excluir',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: AppTextStyles.subtitle),
      content: Text(message, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style: AppTextStyles.body.copyWith(
                  color: destructive ? AppColors.error : AppColors.link, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.textPrimary,
    ));
}
