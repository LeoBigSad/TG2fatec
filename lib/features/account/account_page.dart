import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../state/session_controller.dart';
import 'personal_info_page.dart';

/// Perfil (Figma: account #1).
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(40),
      foregroundColor: AppColors.textSecondary,
      side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
    );
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl - 8),
        children: [
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: CircleAvatar(
              radius: 58,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person_outline, color: AppColors.onPrimary, size: 72),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Olá, ${session.user?.firstName ?? ''}!', textAlign: TextAlign.center, style: AppTextStyles.heading.copyWith(fontWeight: FontWeight.w400)),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            style: buttonStyle,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalInfoPage())),
            child: const Text('Informações Pessoais'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: buttonStyle,
            onPressed: () async {
              if (await confirmDialog(context,
                  title: 'Sair', message: 'Deseja sair da sua conta?', confirmLabel: 'Sair', destructive: false)) {
                await session.logout();
              }
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
