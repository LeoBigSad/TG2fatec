import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tg2fatec/data/app_database.dart';
import 'package:tg2fatec/data/models/models.dart';
import 'package:tg2fatec/data/repositories.dart';
import 'package:tg2fatec/services/import/statement_importer.dart';
import 'package:tg2fatec/services/password_hasher.dart';
import 'package:tg2fatec/state/finance_controller.dart';
import 'package:tg2fatec/state/session_controller.dart';

import 'support/fake_session_storage.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late SessionController session;
  late FinanceController finance;
  late FakeSessionStorage storage;
  late DateTime now;

  setUp(() async {
    db = await AppDatabase.openWith(databaseFactoryFfiNoIsolate);
    storage = FakeSessionStorage();
    now = DateTime(2025, 10, 20, 10);
    final audit = AuditLog(db);
    session = SessionController(
      users: UserRepository(db),
      storage: storage,
      audit: audit,
      hasher: const PasswordHasher(iterations: 10),
      clock: () => now,
    );
    finance = FinanceController(repository: FinanceRepository(db), audit: audit);
    await session.register(name: 'Ana Souza', email: 'ana@example.com', phone: '(11) 91234-5678', password: 'senha1234');
    await finance.loadFor(session.user!.id);
  });

  tearDown(() => db.close());

  test('cadastro cria categorias padrão e guarda só o hash da senha', () async {
    expect(finance.categories.map((c) => c.name), containsAll(['Mercado', 'Transporte', 'Salário']));
    final row = (await db.query('users')).single;
    expect(row['password_hash'], isNot('senha1234'));
    expect(row['phone'], '11912345678');
  });

  test('e-mail duplicado é recusado', () async {
    expect(
      () => session.register(name: 'Outra', email: 'ANA@example.com', phone: '11999999999', password: 'senha1234'),
      throwsA(isA<AuthException>()),
    );
  });

  test('login, senha errada e sessão expirada por inatividade', () async {
    await session.logout();
    await expectLater(session.login('ana@example.com', 'errada123'), throwsA(isA<AuthException>()));
    await session.login('ana@example.com', 'senha1234');
    expect(session.isLoggedIn, isTrue);

    now = now.add(const Duration(minutes: 16));
    await session.checkInactivity();
    expect(session.isLoggedIn, isFalse);
    expect(session.consumeExpiredFlag(), isTrue);
  });

  test('armazenamento seguro ilegível leva ao login em vez de travar o app', () async {
    storage.unreadable = true;
    await session.restore();
    expect(session.restoring, isFalse);
    expect(session.isLoggedIn, isTrue, reason: 'sessão atual em memória não é afetada');
    expect(storage.userId, isNull);
  });

  test('recuperação de senha pelo telefone', () async {
    final user = await session.findByContact('(11) 91234-5678');
    expect(user?.email, 'ana@example.com');
    await session.resetPassword(user!.id!, 'novaSenha99');
    await session.logout();
    await session.login('ana@example.com', 'novaSenha99');
    expect(session.isLoggedIn, isTrue);
  });

  test('CRUD de transação e log de auditoria imutável', () async {
    final mercado = finance.categories.firstWhere((c) => c.name == 'Mercado');
    await finance.saveTransaction(FinanceTransaction(
      userId: finance.userId,
      type: TransactionType.expense,
      title: 'Supermercado',
      amountCents: 5000,
      date: DateTime(2025, 10, 10),
      categoryId: mercado.id,
    ));
    expect(finance.transactions, hasLength(1));

    final t = finance.transactions.single;
    await finance.saveTransaction(t.copyWith(amountCents: 6000));
    expect(finance.transactions.single.amountCents, 6000);

    await finance.deleteTransaction(finance.transactions.single);
    expect(finance.transactions, isEmpty);

    final actions = (await AuditLog(db).entries()).map((e) => e['action']);
    expect(actions, containsAll(['transaction_created', 'transaction_updated', 'transaction_deleted']));
    expect(() => db.delete('audit_logs'), throwsA(anything));
  });

  test('importação marca duplicadas e exclusão do extrato remove as transações', () async {
    const csv = 'Data;Descrição;Valor\n10/10/2025;Uber viagem;-23,50\n10/10/2025;Uber viagem;-23,50\n11/10/2025;Salario;5000,00\n';
    final importer = StatementImporter();
    final preview = await importer.preview(
      fileName: 'extrato.csv',
      bytes: Uint8List.fromList(csv.codeUnits),
      existingKeys: finance.existingKeys,
      suggestCategory: (d, t) => finance.suggestCategory(d, t)?.id,
    );
    expect(preview.candidates, hasLength(2));
    expect(preview.duplicatesInFile, 1);
    expect(finance.category(preview.candidates.first.categoryId)?.name, 'Transporte');

    expect(await finance.importStatement(preview), 2);
    expect(finance.transactions, hasLength(2));
    expect(finance.imports.single.count, 2);

    final again = await importer.preview(
      fileName: 'extrato.csv',
      bytes: Uint8List.fromList(csv.codeUnits),
      existingKeys: finance.existingKeys,
      suggestCategory: (d, t) => null,
    );
    expect(again.duplicates, 2);
    expect(again.candidates.where((c) => c.selected), isEmpty);

    await finance.deleteImport(finance.imports.single);
    expect(finance.transactions, isEmpty);
  });

  test('excluir categoria remove seus orçamentos e deixa transações sem categoria', () async {
    final roupas = finance.categories.firstWhere((c) => c.name == 'Roupas');
    await finance.saveTransaction(FinanceTransaction(
      userId: finance.userId,
      type: TransactionType.expense,
      title: 'Camiseta',
      amountCents: 8000,
      date: DateTime(2025, 10, 1),
      categoryId: roupas.id,
    ));
    await finance.saveBudget(Budget(userId: finance.userId, categoryId: roupas.id!, limitCents: 50000, startDate: DateTime(2025, 10)));
    await finance.deleteCategory(roupas);
    expect(finance.budgets, isEmpty);
    expect(finance.transactions.single.categoryId, isNull);
  });

  test('excluir a conta apaga todos os dados do usuário', () async {
    await finance.saveTransaction(FinanceTransaction(
      userId: finance.userId,
      type: TransactionType.income,
      title: 'Salário',
      amountCents: 100,
      date: DateTime(2025, 10, 1),
    ));
    await expectLater(session.deleteAccount('errada123'), throwsA(isA<AuthException>()));
    await session.deleteAccount('senha1234');
    expect(session.isLoggedIn, isFalse);
    for (final table in ['users', 'categories', 'transactions', 'budgets']) {
      expect(await db.query(table), isEmpty, reason: table);
    }
    expect(storage.userId, isNull);
  });
}
