import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/repositories.dart';
import 'services/database_key_store.dart';
import 'services/session_storage.dart';
import 'state/finance_controller.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final dbKey = await DatabaseKeyStore().obtain();
  final db = await AppDatabase.openEncrypted(dbKey.key, keyIsNew: dbKey.created);
  final audit = AuditLog(db);
  final session = SessionController(users: UserRepository(db), storage: SessionStorage(), audit: audit);
  final finance = FinanceController(repository: FinanceRepository(db), audit: audit);

  runApp(App(session: session, finance: finance));
  await session.restore();
}
