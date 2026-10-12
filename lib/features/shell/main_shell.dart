import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../state/finance_controller.dart';
import '../budgets/budgets_page.dart';
import '../home/home_page.dart';
import '../overview/overview_page.dart';
import '../transactions/transactions_page.dart';
import 'alerts_page.dart';
import 'app_drawer.dart';

/// Estrutura principal: barra inferior com Home, Visão Geral, Transações e
/// Orçamento, e menu lateral.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final alerts = finance.budgetAlerts.length;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          if (_index == 0)
            IconButton(
              tooltip: finance.hideValues ? 'Mostrar valores' : 'Ocultar valores',
              icon: Icon(finance.hideValues ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: finance.toggleHideValues,
            ),
          IconButton(
            tooltip: 'Alertas de orçamento',
            icon: Badge(
              isLabelVisible: alerts > 0,
              label: Text('$alerts'),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsPage())),
          ),
        ],
      ),
      body: finance.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : IndexedStack(
              index: _index,
              children: [
                HomePage(onNavigate: _go),
                OverviewPage(onNavigate: _go),
                const TransactionsPage(),
                const BudgetsPage(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.insert_chart_outlined), selectedIcon: Icon(Icons.insert_chart), label: 'Visão Geral'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Transações'),
          NavigationDestination(icon: Icon(Icons.price_change_outlined), selectedIcon: Icon(Icons.price_change), label: 'Orçamento'),
        ],
      ),
    );
  }
}
