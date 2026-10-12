import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'app_sheet.dart';

/// Calendário em bottom sheet (Figma: "Selecione a Data").
Future<DateTime?> showDatePickerSheet(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
  DateTime? last,
}) {
  var selected = initial ?? DateTime.now();
  final firstDate = first ?? DateTime(2000);
  final lastDate = last ?? DateTime(DateTime.now().year + 10);
  if (selected.isBefore(firstDate)) selected = firstDate;
  if (selected.isAfter(lastDate)) selected = lastDate;

  return showAppSheet<DateTime>(
    context,
    title: 'Selecione a Data',
    showBack: true,
    showClose: false,
    builder: (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary, onPrimary: AppColors.onPrimary),
            ),
            child: CalendarDatePicker(
              initialDate: selected,
              firstDate: firstDate,
              lastDate: lastDate,
              onDateChanged: (d) => selected = d,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Selecionar')),
      ],
    ),
  );
}
