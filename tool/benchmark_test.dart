// Medição de desempenho para o RNF3 (respostas em menos de 2 s com até
// 10 mil transações). Não faz parte da suíte normal de testes; execute com:
//
//   flutter test tool/benchmark_test.dart
//
// Roda na máquina de desenvolvimento, com SQLite via FFI e sem SQLCipher.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tg2fatec/data/app_database.dart';
import 'package:tg2fatec/data/models/models.dart';
import 'package:tg2fatec/data/repositories.dart';
import 'package:tg2fatec/services/finance_stats.dart';
import 'package:tg2fatec/services/import/statement_importer.dart';
import 'package:tg2fatec/services/password_hasher.dart';
import 'package:tg2fatec/services/report_exporter.dart';
import 'package:tg2fatec/state/finance_controller.dart';
import 'package:tg2fatec/state/session_controller.dart';

import '../test/support/fake_session_storage.dart';

const _transactions = 10000;
const _runs = 5;

const _descriptions = [
  'Supermercado Carrefour', 'Uber viagem', 'Farmacia Droga Raia', 'iFood restaurante', 'Netflix',
  'Posto Ipiranga combustivel', 'Renner roupas', 'Salao de beleza', 'Internet Vivo', 'Padaria Pao Quente',
];

/// Executa [action] [_runs] vezes e retorna a mediana em milissegundos.
Future<int> _median(Future<void> Function() action) async {
  final times = <int>[];
  for (var i = 0; i < _runs; i++) {
    final sw = Stopwatch()..start();
    await action();
    times.add(sw.elapsedMilliseconds);
  }
  times.sort();
  return times[_runs ~/ 2];
}

String _csv() {
  final b = StringBuffer('Data;Descrição;Valor\n');
  for (var i = 0; i < _transactions; i++) {
    final date = DateTime(2026, 1, 1).add(Duration(days: i % 365));
    final day = date.day.toString().padLeft(2, '0'), month = date.month.toString().padLeft(2, '0');
    final value = (i % 7 == 0) ? '${1000 + i % 500},00' : '-${10 + i % 300},${(i * 7) % 100}'.padRight(4, '0');
    b.writeln('$day/$month/2026;${_descriptions[i % _descriptions.length]} $i;$value');
  }
  return b.toString();
}

void main() {
  sqfliteFfiInit();

  test('desempenho com $_transactions transações', () async {
    final db = await AppDatabase.openWith(databaseFactoryFfiNoIsolate);
    final audit = AuditLog(db);
    final session = SessionController(
      users: UserRepository(db),
      storage: FakeSessionStorage(),
      audit: audit,
      hasher: const PasswordHasher(iterations: 10),
    );
    final finance = FinanceController(repository: FinanceRepository(db), audit: audit);
    await session.register(name: 'Teste', email: 'perf@teste.com', phone: '11999999999', password: 'senha1234');
    await finance.loadFor(session.user!.id);

    final bytes = Uint8List.fromList(utf8.encode(_csv()));
    final importer = StatementImporter();
    late ImportPreview preview;
    Future<ImportPreview> doPreview() => importer.preview(
          fileName: 'extrato.csv',
          bytes: bytes,
          existingKeys: finance.existingKeys,
          suggestCategory: (d, t) => finance.suggestCategory(d, t)?.id,
        );

    final results = <String, int>{};
    results['Leitura e revisão do extrato CSV'] = await _median(() async => preview = await doPreview());

    final sw = Stopwatch()..start();
    await finance.importStatement(preview);
    results['Gravação das transações no banco (1 execução)'] = sw.elapsedMilliseconds;
    expect(finance.transactions, hasLength(_transactions));

    results['Carga das transações do banco'] = await _median(() async {
      await finance.loadFor(null);
      await finance.loadFor(session.user!.id);
    });

    final month = DateTime(2026, 6);
    final budget = Budget(
      userId: finance.userId,
      categoryId: finance.categories.firstWhere((c) => c.name == 'Mercado').id!,
      limitCents: 50000,
      startDate: DateTime(2026),
      repeatMonthly: true,
    );
    results['Indicadores do mês e do ano (Home e Visão Geral)'] = await _median(() async {
      final m = FinanceStats.inMonth(finance.transactions, month).toList();
      FinanceStats.income(m);
      FinanceStats.expense(m);
      FinanceStats.expensesByCategory(m);
      FinanceStats.weeklyExpenses(finance.transactions, month);
      FinanceStats.monthlyExpenses(finance.transactions, 2026);
      FinanceStats.budgetStatuses([budget], finance.transactions, month);
    });

    final suggestion = await _median(() async => finance.suggestCategory('Supermercado Carrefour 99999', TransactionType.expense));
    results['Sugestão de categoria (1 descrição)'] = suggestion;

    FinanceReport report(ReportPeriod p) => FinanceReport(
          period: p,
          reference: month,
          userName: 'Teste',
          allTransactions: finance.transactions,
          categories: finance.categoryById,
        );
    results['Relatório mensal em PDF'] = await _median(() => ReportExporter.build(report(ReportPeriod.month), ReportFormat.pdf));
    results['Relatório anual em planilha CSV'] = await _median(() => ReportExporter.build(report(ReportPeriod.year), ReportFormat.csv));
    final pdfSw = Stopwatch()..start();
    await ReportExporter.build(report(ReportPeriod.year), ReportFormat.pdf);
    results['Relatório anual em PDF (1 execução)'] = pdfSw.elapsedMilliseconds;

    // ignore: avoid_print
    results.forEach((k, v) => print('RESULTADO | $k | $v ms'));
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
