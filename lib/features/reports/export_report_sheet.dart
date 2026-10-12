import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../services/report_exporter.dart';
import '../../state/finance_controller.dart';
import '../../state/session_controller.dart';

/// Exportação de relatórios mensais e anuais em PDF ou planilha (RF20).
Future<void> showExportReportSheet(BuildContext context, {bool yearly = false}) {
  return showAppSheet<void>(
    context,
    title: 'Exportar Relatório',
    builder: (_) => _ExportForm(yearly: yearly),
  );
}

class _ExportForm extends StatefulWidget {
  const _ExportForm({required this.yearly});

  final bool yearly;

  @override
  State<_ExportForm> createState() => _ExportFormState();
}

class _ExportFormState extends State<_ExportForm> {
  late ReportPeriod _period = widget.yearly ? ReportPeriod.year : ReportPeriod.month;
  late DateTime _reference = context.read<FinanceController>().month;
  ReportFormat _format = ReportFormat.pdf;
  bool _busy = false;

  FinanceReport _report() {
    final finance = context.read<FinanceController>();
    return FinanceReport(
      period: _period,
      reference: _reference,
      userName: context.read<SessionController>().user?.name ?? '',
      allTransactions: finance.transactions,
      categories: finance.categoryById,
    );
  }

  Future<void> _run(Future<void> Function(FinanceReport report, Uint8List bytes, String fileName) action) async {
    setState(() => _busy = true);
    try {
      final report = _report();
      final bytes = await ReportExporter.build(report, _format);
      await action(report, bytes, '${report.fileBaseName}.${ReportExporter.extension(_format)}');
    } catch (_) {
      if (mounted) showMessage(context, 'Não foi possível gerar o relatório.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _run((report, bytes, fileName) async {
        final dir = await getTemporaryDirectory();
        final file = File(p.join(dir.path, fileName));
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: ReportExporter.mimeType(_format))],
          subject: report.title,
        ));
      });

  Future<void> _save() => _run((report, bytes, fileName) async {
        final uri = await FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: ReportExporter.mimeType(_format),
          type: FileType.custom,
          allowedExtensions: [ReportExporter.extension(_format)],
        );
        if (uri != null && mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(const SnackBar(content: Text('Relatório salvo.')));
        }
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Período', style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.month, label: Text('Mensal')),
              ButtonSegment(value: ReportPeriod.year, label: Text('Anual')),
            ],
            selected: {_period},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const Spacer(),
          MonthSelector(
            value: _reference,
            yearOnly: _period == ReportPeriod.year,
            onChanged: (d) => setState(() => _reference = d),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        Text('Formato', style: AppTextStyles.fieldLabel),
        RadioGroup<ReportFormat>(
          groupValue: _format,
          onChanged: (v) => setState(() => _format = v!),
          child: const Column(children: [
            RadioListTile(
              value: ReportFormat.pdf,
              contentPadding: EdgeInsets.zero,
              title: Text('PDF'),
              activeColor: AppColors.primary,
            ),
            RadioListTile(
              value: ReportFormat.csv,
              contentPadding: EdgeInsets.zero,
              title: Text('Planilha (CSV, abre no Excel)'),
              activeColor: AppColors.primary,
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Compartilhar'),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Salvar no aparelho'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
        ),
      ],
    );
  }
}
