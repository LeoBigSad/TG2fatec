import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'models/models.dart';

/// Ícones disponíveis no seletor "Selecione o ícone" (Figma: New Transaction #2).
abstract final class CategoryIcons {
  static const Map<String, IconData> all = {
    'food': Icons.fastfood_outlined,
    'market': Icons.shopping_cart_outlined,
    'restaurant': Icons.restaurant,
    'clothes': Icons.checkroom,
    'transport': Icons.directions_bus_outlined,
    'health': Icons.medical_services_outlined,
    'bills': Icons.receipt_long_outlined,
    'beauty': Icons.content_cut,
    'fun': Icons.sports_esports_outlined,
    'drinks': Icons.wine_bar_outlined,
    'books': Icons.menu_book_outlined,
    'fitness': Icons.fitness_center,
    'family': Icons.family_restroom,
    'fuel': Icons.local_gas_station_outlined,
    'plants': Icons.yard_outlined,
    'money': Icons.request_quote_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'tools': Icons.handyman_outlined,
    'invest': Icons.trending_up,
    'home': Icons.home_work_outlined,
    'work': Icons.work_outline,
    'phone': Icons.smartphone,
    'other': Icons.category_outlined,
  };

  static IconData of(String key) => all[key] ?? Icons.category_outlined;
}

/// Cores sugeridas para novas categorias (extraídas do Figma).
const categoryPalette = <Color>[
  CategoryColors.alimentacao,
  Color(0xFF328325),
  Color(0xFFFF9900),
  CategoryColors.roupas,
  CategoryColors.transporte,
  CategoryColors.remedios,
  Color(0xFF8C593D),
  CategoryColors.beleza,
  Color(0xFF5584A7),
  Color(0xFF851F41),
  Color(0xFFB497E7),
  Color(0xFFC0C30F),
  AppColors.income,
  AppColors.balance,
  AppColors.textTertiary,
];

/// Categorias criadas para todo usuário novo.
List<FinanceCategory> defaultCategories(int userId) {
  FinanceCategory c(String name, String icon, Color color, [TransactionType type = TransactionType.expense]) =>
      FinanceCategory(userId: userId, name: name, iconKey: icon, color: color, type: type);
  return [
    c('Alimentação', 'food', CategoryColors.alimentacao),
    c('Mercado', 'market', const Color(0xFF328325)),
    c('Restaurante', 'restaurant', const Color(0xFFFF9900)),
    c('Roupas', 'clothes', CategoryColors.roupas),
    c('Transporte', 'transport', CategoryColors.transporte),
    c('Remédios', 'health', CategoryColors.remedios),
    c('Contas', 'bills', const Color(0xFF8C593D)),
    c('Beleza', 'beauty', CategoryColors.beleza),
    c('Entretenimento', 'fun', const Color(0xFF5584A7)),
    c('Outros', 'other', AppColors.textTertiary),
    c('Salário', 'work', AppColors.income, TransactionType.income),
    c('Investimentos', 'invest', AppColors.success, TransactionType.income),
    c('Outras receitas', 'money', AppColors.balance, TransactionType.income),
  ];
}
