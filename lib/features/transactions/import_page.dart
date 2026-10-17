import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_sheet.dart';
import '../../core/widgets/common.dart';
import '../../services/import/statement_importer.dart';
import '../../services/import/statement_parser.dart';
import '../../state/finance_controller.dart';
import '../auth/auth_widgets.dart';
import 'category_picker_sheet.dart';

/// Importação de extratos OFX, CSV (RF1) e PDF (RF2), com revisão antes de
/// gravar e remoção de duplicidades.
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _importer = StatementImporter();
  ImportPreview? _preview;
  String? _error;
  bool _loading = false;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      // O Android filtra por MIME type e não conhece o do OFX; por isso o
      // seletor aceita qualquer arquivo e a extensão é validada no preview.
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;
      final file = files.first;
      if (!mounted) return;
      final finance = context.read<FinanceController>();
      final preview = await _importer.preview(
        fileName: file.name,
        bytes: await file.xFile.readAsBytes(),
        existingKeys: finance.existingKeys,
        suggestCategory: (description, type) => finance.suggestCategory(description, type)?.id,
      );
      setState(() => _preview = preview);
      if (preview.candidates.isEmpty) {
        setState(() => _error = 'Nenhum lançamento válido foi encontrado no arquivo.');
      }
    } on StatementFormatException catch (e) {
      // Descarta a prévia do arquivo anterior para não misturar com o erro.
      setState(() {
        _preview = null;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _preview = null;
        _error = 'Não foi possível abrir o arquivo. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final count = await context.read<FinanceController>().importStatement(_preview!);
    if (!mounted) return;
    Navigator.pop(context);
    showMessage(context, '$count transações importadas.');
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final selected = preview?.candidates.where((c) => c.selected).length ?? 0;
    return Scaffold(
      appBar: flowAppBar('Importar extrato'),
      bottomNavigationBar: preview == null || preview.candidates.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton(
                  onPressed: selected == 0 ? null : _confirm,
                  child: Text('Importar $selected transações'),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Selecione o extrato do seu banco nos formatos OFX, CSV ou PDF.', style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Lançamentos repetidos ou já cadastrados são identificados automaticamente.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pick,
                  icon: _loading
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  label: Text(preview == null ? 'Escolher arquivo' : 'Escolher outro arquivo'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              borderColor: AppColors.error,
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.error))),
              ]),
            ),
          ],
          if (preview != null && preview.candidates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(preview.fileName, style: AppTextStyles.subtitle, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
              _Chip('${preview.candidates.length} lançamentos', AppColors.accent),
              if (preview.duplicates > 0) _Chip('${preview.duplicates} já cadastrados', AppColors.warning),
              if (preview.duplicatesInFile > 0) _Chip('${preview.duplicatesInFile} repetidos no arquivo', AppColors.warning),
              if (preview.invalidLines > 0) _Chip('${preview.invalidLines} linhas inválidas ignoradas', AppColors.error),
            ]),
            const SizedBox(height: AppSpacing.sm),
            for (final c in preview.candidates) ...[_CandidateTile(candidate: c, onChanged: () => setState(() {})), const SizedBox(height: 6)],
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.onChanged});

  final ImportCandidate candidate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final finance = context.read<FinanceController>();
    final c = candidate;
    final category = finance.category(c.categoryId);
    return AppCard(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      borderColor: c.duplicate ? AppColors.warning : null,
      child: Row(children: [
        Checkbox(
          value: c.selected,
          activeColor: AppColors.primary,
          onChanged: (v) {
            c.selected = v ?? false;
            onChanged();
          },
        ),
        InkWell(
          onTap: () async {
            final picked = await showCategoryPicker(context, type: c.type, selectedId: c.categoryId);
            if (picked != null) {
              c.categoryId = picked.id;
              onChanged();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: CategoryAvatar(category: category, size: 32),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.entry.description, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            Text(
              '${Fmt.date(c.entry.date)} · ${category?.name ?? 'Toque no ícone para categorizar'}'
              '${c.duplicate ? ' · já cadastrada' : ''}',
              style: AppTextStyles.caption.copyWith(color: c.duplicate ? AppColors.warning : AppColors.textTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        Text(
          Fmt.money(c.entry.amountCents, signed: true),
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w500,
            color: c.entry.amountCents < 0 ? AppColors.textValue : AppColors.income,
          ),
        ),
      ]),
    );
  }
}
