import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../state/session_controller.dart';
import '../account/account_page.dart';
import '../calculators/calculators_page.dart';
import '../categories/categories_page.dart';
import '../reports/export_report_sheet.dart';
import '../transactions/imports_page.dart';

/// Menu lateral (Figma: Menu).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;

    void open(Widget page) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    return Drawer(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadius.xl))),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close, color: AppColors.textTertiary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person_outline, color: AppColors.onPrimary, size: 30),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Olá, ${user?.firstName ?? ''}!', style: AppTextStyles.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '“A primeira moeda que você economiza é a semente da árvore da riqueza.”\n'
              '— inspirado em O Homem Mais Rico da Babilônia',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            _MenuButton(icon: Icons.account_circle_outlined, label: 'Perfil', onTap: () => open(const AccountPage())),
            _MenuButton(
                icon: Icons.calculate_outlined, label: 'Calculadora de Horas', onTap: () => open(const CalculatorsPage())),
            _MenuButton(
                icon: Icons.beach_access_outlined,
                label: 'Calculadora de Férias',
                onTap: () => open(const CalculatorsPage(initialTab: 1))),
            _MenuButton(icon: Icons.category_outlined, label: 'Categorias', onTap: () => open(const CategoriesPage())),
            _MenuButton(icon: Icons.upload_file_outlined, label: 'Extratos importados', onTap: () => open(const ImportsPage())),
            _MenuButton(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Exportar relatório',
              onTap: () {
                // O drawer sai da árvore ao fechar; usa o contexto do Navigator.
                final host = Navigator.of(context).context;
                Navigator.pop(context);
                showExportReportSheet(host);
              },
            ),
            _MenuButton(
              icon: Icons.logout,
              label: 'Sair',
              onTap: () async {
                final session = context.read<SessionController>();
                if (await confirmDialog(context,
                    title: 'Sair', message: 'Deseja sair da sua conta?', confirmLabel: 'Sair', destructive: false)) {
                  await session.logout();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(40),
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.textTertiary),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
    );
  }
}
