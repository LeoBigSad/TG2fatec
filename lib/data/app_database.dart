import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Banco SQLite local do aplicativo.
abstract final class AppDatabase {
  static const _version = 1;

  static Future<Database> open({String name = 'tg2fatec.db', DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final path = name == inMemoryDatabasePath ? name : p.join(await f.getDatabasesPath(), name);
    return f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _create(db),
      ),
    );
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE COLLATE NOCASE,
          phone TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          password_salt TEXT NOT NULL,
          created_at TEXT NOT NULL,
          consent_at TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color INTEGER NOT NULL,
          type TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TABLE imports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          file_name TEXT NOT NULL,
          source TEXT NOT NULL,
          imported_at TEXT NOT NULL,
          count INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          amount_cents INTEGER NOT NULL,
          date TEXT NOT NULL,
          category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
          account TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL,
          import_id INTEGER REFERENCES imports(id) ON DELETE CASCADE
        )''')
      ..execute('CREATE INDEX idx_transactions_user_date ON transactions(user_id, date)')
      ..execute('''
        CREATE TABLE budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
          limit_cents INTEGER NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT,
          repeat_monthly INTEGER NOT NULL DEFAULT 0
        )''')
      // Log de auditoria (RNF6): sem dados pessoais e imutável.
      ..execute('''
        CREATE TABLE audit_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          action TEXT NOT NULL,
          details TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )''')
      ..execute('''
        CREATE TRIGGER audit_logs_no_update BEFORE UPDATE ON audit_logs
        BEGIN SELECT RAISE(ABORT, 'audit_logs is append-only'); END''')
      ..execute('''
        CREATE TRIGGER audit_logs_no_delete BEFORE DELETE ON audit_logs
        BEGIN SELECT RAISE(ABORT, 'audit_logs is append-only'); END''');
    await batch.commit(noResult: true);
  }
}
