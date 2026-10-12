import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../services/verification_service.dart';

/// AppBar das telas de fluxo ("< Esqueci a Senha").
PreferredSizeWidget flowAppBar(String title, {Color? background}) => AppBar(
      backgroundColor: background,
      centerTitle: false,
      titleSpacing: 0,
      title: Text(title, style: AppTextStyles.heading),
    );

/// Cartão branco que agrupa os formulários das telas de senha.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Botão principal com indicador de carregamento.
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
          : Text(label),
    );
  }
}

/// Sheet "Método de Contato" (Figma: Sign up #2 / Forgot password #3).
Future<ContactMethod?> showContactMethodSheet(BuildContext context, {ContactMethod initial = ContactMethod.email}) {
  var method = initial;
  return showAppSheet<ContactMethod>(
    context,
    title: 'Método de Contato',
    showBack: true,
    showClose: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Para a sua segurança precisamos verificar sua identidade.', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Selecione um método de contato abaixo, e nós iremos enviar um código de confirmação.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final m in ContactMethod.values)
            CheckboxListTile(
              value: method == m,
              onChanged: (_) => setState(() => method = m),
              title: Text(m.label, style: AppTextStyles.body),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
            ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton(onPressed: () => Navigator.pop(ctx, method), child: const Text('Enviar')),
        ],
      ),
    ),
  );
}
