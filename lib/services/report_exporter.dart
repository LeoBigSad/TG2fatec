import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/formatters.dart';
import '../data/models/models.dart';
import 'finance_stats.dart';

enum ReportPeriod { month, year }

enum ReportFormat { pdf, csv }

/// Dados de um relatório mensal ou anual (RF20).
class FinanceReport {
  FinanceReport({
    required this.period,
    required this.reference,
    required this.userName,
    required List<FinanceTransaction> allTransactions,
    required this.categories,
  }) : transactions = (period == ReportPeriod.month
                ? FinanceStats.inMonth(allTransactions, reference)
                : FinanceStats.inYear(allTransactions, reference.year))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

  final ReportPeriod period;
  final DateTime reference;
  final String userName;
  final List<FinanceTransaction> transactions;
  final Map<int, FinanceCategory> categories;

  String get title => period == ReportPeriod.month
      ? 'Relatório de ${Fmt.monthYear(reference)}'
      : 'Relatório anual de ${reference.year}';

  String get fileBaseName => period == ReportPeriod.month
      ? 'relatorio_${reference.year}_${reference.month.toString().padLeft(2, '0')}'
      : 'relatorio_${reference.year}';

  int get income => FinanceStats.income(transactions);
  int get expense => FinanceStats.expense(transactions);

  String categoryName(int? id) => categories[id]?.name ?? 'Sem categoria';
}

abstract final class ReportExporter {
  static const _rowsPerTable = 35;

  static Future<Uint8List> build(FinanceReport report, ReportFormat format) => switch (format) {
        ReportFormat.pdf => _pdf(report),
        ReportFormat.csv => Future.value(_csv(report)),
      };

  static String extension(ReportFormat format) => format == ReportFormat.pdf ? 'pdf' : 'csv';

  static String mimeType(ReportFormat format) => format == ReportFormat.pdf ? 'application/pdf' : 'text/csv';

  /// Planilha CSV com `;` e BOM, para abrir corretamente no Excel em português.
  static Uint8List _csv(FinanceReport r) {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final b = StringBuffer('﻿')
      ..writeln('Data;Tipo;Título;Descrição;Categoria;Conta;Valor');
    for (final t in r.transactions) {
      b.writeln([
        Fmt.date(t.date),
        t.type.label,
        esc(t.title),
        esc(t.description),
        esc(r.categoryName(t.categoryId)),
        esc(t.account),
        Fmt.amount(t.signedCents),
      ].join(';'));
    }
    b
      ..writeln()
      ..writeln(';;;;;Receitas;${Fmt.amount(r.income)}')
      ..writeln(';;;;;Despesas;${Fmt.amount(-r.expense)}')
      ..writeln(';;;;;Saldo;${Fmt.amount(r.income - r.expense)}');
    return Uint8List.fromList(utf8.encode(b.toString()));
  }

  static Future<Uint8List> _pdf(FinanceReport r) {
    final doc = pw.Document(title: r.title, author: r.userName);
    final byCategory = FinanceStats.expensesByCategory(r.transactions);
    final headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10);
    const cellStyle = pw.TextStyle(fontSize: 9);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      // O padrão da biblioteca é 20 páginas; um relatório anual com milhares
      // de transações ultrapassa esse limite.
      maxPages: 1000,
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(r.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('${r.userName} · gerado em ${Fmt.date(DateTime.now())}', style: cellStyle),
        pw.SizedBox(height: 12),
      ]),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}', style: cellStyle),
      ),
      build: (_) => [
        pw.Row(children: [
          _summary('Receitas', Fmt.money(r.income), PdfColor.fromInt(0xFF34C759)),
          _summary('Despesas', Fmt.money(r.expense), PdfColor.fromInt(0xFFFF383C)),
          _summary('Saldo', Fmt.money(r.income - r.expense), PdfColor.fromInt(0xFF6155F5)),
        ]),
        pw.SizedBox(height: 16),
        if (byCategory.isNotEmpty) ...[
          pw.Text('Despesas por categoria', style: headerStyle),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Categoria', 'Valor', '%'],
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
            data: [
              for (final e in byCategory)
                [r.categoryName(e.key), Fmt.money(e.value), Fmt.percent(r.expense == 0 ? 0 : e.value / r.expense)],
            ],
          ),
          pw.SizedBox(height: 16),
        ],
        pw.Text('Transações', style: headerStyle),
        pw.SizedBox(height: 6),
        if (r.transactions.isEmpty)
          pw.Text('Nenhuma transação no período.', style: cellStyle)
        else
          // Uma tabela única com milhares de linhas é relaida a cada página
          // (custo quadrático); blocos menores mantêm a geração linear.
          for (var i = 0; i < r.transactions.length; i += _rowsPerTable)
            pw.TableHelper.fromTextArray(
              headers: ['Data', 'Título', 'Categoria', 'Valor'],
              headerStyle: headerStyle,
              cellStyle: cellStyle,
              columnWidths: const {
                0: pw.FixedColumnWidth(62),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FixedColumnWidth(80),
              },
              cellAlignments: {3: pw.Alignment.centerRight},
              data: [
                for (final t in r.transactions.skip(i).take(_rowsPerTable))
                  [Fmt.date(t.date), t.title, r.categoryName(t.categoryId), Fmt.money(t.signedCents, signed: true)],
              ],
            ),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _summary(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: pw.TextStyle(color: color, fontSize: 10)),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );
}
