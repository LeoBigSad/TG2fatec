import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/widgets/common.dart';
import '../../state/finance_controller.dart';
import '../auth/auth_widgets.dart';
import '../shared/finance_widgets.dart';

/// Alertas de orçamento do mês atual (RF14).
class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<FinanceController>().budgetAlerts
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    return Scaffold(
      appBar: flowAppBar('Alertas'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (alerts.isEmpty)
            const EmptyState(
              icon: Icons.notifications_off_outlined,
              message: 'Nenhum alerta. Seus orçamentos deste mês estão dentro do limite.',
            ),
          for (final s in alerts) ...[BudgetStatusCard(status: s), const SizedBox(height: AppSpacing.xs)],
        ],
      ),
    );
  }
}
