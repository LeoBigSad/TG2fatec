import 'package:flutter/material.dart';

import '../../data/category_catalog.dart';
import '../../data/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';

/// Cartão branco com borda clara, usado nas listas e resumos.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Título de seção com ação à direita ("Orçamentos    + Novo", "Ver tudo").
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.actionIcon, this.onAction});

  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.subtitle)),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: actionIcon == null ? const SizedBox.shrink() : Icon(actionIcon, size: 18),
            label: Text(actionLabel!),
            style: TextButton.styleFrom(
              foregroundColor: actionIcon == null ? AppColors.link : AppColors.textPrimary,
              textStyle: AppTextStyles.body,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: AppSpacing.sm), action!],
        ],
      ),
    );
  }
}

/// Ícone circular da categoria, com fundo na cor da categoria.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 36, this.selected = false});

  final FinanceCategory? category;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = category?.color ?? AppColors.textTertiary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: selected ? Border.all(color: color, width: 2) : null,
      ),
      child: Icon(CategoryIcons.of(category?.iconKey ?? 'other'), size: size * 0.55, color: color),
    );
  }
}

/// Valor monetário que pode ser ocultado (olho da Home).
class MoneyText extends StatelessWidget {
  const MoneyText(this.cents, {super.key, this.style, this.signed = false, this.hidden = false});

  final int cents;
  final TextStyle? style;
  final bool signed;
  final bool hidden;

  @override
  Widget build(BuildContext context) =>
      Text(hidden ? 'R\$ •••••' : Fmt.money(cents, signed: signed), style: style ?? AppTextStyles.value);
}

/// Seletor de mês ("Outubro ˅"); com [yearOnly], escolhe apenas o ano.
class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.value, required this.onChanged, this.yearOnly = false});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool yearOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(Icons.chevron_left, -1, 'Anterior'),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => _pick(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: AppSpacing.xxs),
            child: Text(
              yearOnly ? '${value.year}' : Fmt.monthYear(value),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        _arrow(Icons.chevron_right, 1, 'Próximo'),
      ],
    );
  }

  Widget _arrow(IconData icon, int delta, String tooltip) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        color: AppColors.textSecondary,
        icon: Icon(icon),
        onPressed: () => onChanged(yearOnly ? DateTime(value.year + delta) : DateTime(value.year, value.month + delta)),
      );

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: Text(yearOnly ? 'Selecione o ano' : 'Selecione o mês', style: AppTextStyles.subtitle),
        children: [
          SizedBox(
            width: 300,
            height: 320,
            child: ListView(
              children: [
                for (var i = 0; i < (yearOnly ? 10 : 36); i++)
                  Builder(builder: (_) {
                    final d = yearOnly ? DateTime(now.year - i) : DateTime(now.year, now.month - i);
                    final selected = yearOnly ? d.year == value.year : d.isSameMonth(value);
                    return ListTile(
                      dense: true,
                      selected: selected,
                      selectedColor: AppColors.textPrimary,
                      title: Text(yearOnly ? '${d.year}' : Fmt.monthYear(d),
                          style: AppTextStyles.body.copyWith(fontWeight: selected ? FontWeight.w600 : null)),
                      trailing: selected ? const Icon(Icons.check, size: 18) : null,
                      onTap: () => Navigator.pop(ctx, d),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

/// Barra de progresso do orçamento.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final over = ratio > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: ratio.clamp(0, 1).toDouble(),
        minHeight: 6,
        backgroundColor: AppColors.divider,
        color: over ? AppColors.error : color,
      ),
    );
  }
}
