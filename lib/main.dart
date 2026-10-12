import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/repositories.dart';
import 'services/session_storage.dart';
import 'state/finance_controller.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final db = await AppDatabase.open();
  final audit = AuditLog(db);
  final session = SessionController(users: UserRepository(db), storage: SessionStorage(), audit: audit);
  final finance = FinanceController(repository: FinanceRepository(db), audit: audit);

  runApp(App(session: session, finance: finance));
  await session.restore();
}
