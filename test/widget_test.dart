import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tg2fatec/app.dart';
import 'package:tg2fatec/data/app_database.dart';
import 'package:tg2fatec/data/repositories.dart';
import 'package:tg2fatec/services/password_hasher.dart';
import 'package:tg2fatec/state/finance_controller.dart';
import 'package:tg2fatec/state/session_controller.dart';

import 'support/fake_session_storage.dart';

void main() {
  sqfliteFfiInit();

  late SessionController session;
  late FinanceController finance;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.runAsync(() async {
      await initializeDateFormatting('pt_BR');
      final db = await AppDatabase.open(name: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
      final audit = AuditLog(db);
      session = SessionController(
        users: UserRepository(db),
        storage: FakeSessionStorage(),
        audit: audit,
        hasher: const PasswordHasher(iterations: 10),
      );
      finance = FinanceController(repository: FinanceRepository(db), audit: audit);
    });
    await tester.pumpWidget(App(session: session, finance: finance));
    await tester.runAsync(session.restore);
    await tester.pumpAndSettle();
  }

  testWidgets('sem sessão, mostra a tela de login do Figma', (tester) async {
    await pumpApp(tester);

    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
  });

  testWidgets('login valida e-mail e senha antes de enviar', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Senha obrigatório'), findsOneWidget);
  });

  testWidgets('após cadastro, abre a Home com as quatro abas', (tester) async {
    await pumpApp(tester);

    await tester.runAsync(() => session.register(
          name: 'Ana Souza',
          email: 'ana@example.com',
          phone: '11912345678',
          password: 'senha1234',
        ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('Resumo financeiro'), findsOneWidget);
    for (final tab in ['Home', 'Visão Geral', 'Transações', 'Orçamento']) {
      expect(find.widgetWithText(NavigationDestination, tab), findsOneWidget);
    }
  });
}
