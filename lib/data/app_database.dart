import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;
import 'package:sqflite_sqlcipher/sqlite_api.dart';

/// Banco SQLite local do aplicativo, criptografado com SQLCipher (AES-256).
abstract final class AppDatabase {
  static const _version = 1;
  static const _fileName = 'tg2fatec_secure.db';

  /// Banco sem criptografia usado pela versão inicial do app.
  static const _legacyFileName = 'tg2fatec.db';

  /// Abre o banco criptografado com [key]. Com [keyIsNew], um banco existente
  /// foi criado com outra chave (perdida) e é descartado.
  static Future<Database> openEncrypted(String key, {required bool keyIsNew}) async {
    final dir = await cipher.getDatabasesPath();
    final path = p.join(dir, _fileName);
    if (keyIsNew) await cipher.deleteDatabase(path);
    await _migrateLegacy(p.join(dir, _legacyFileName), path, key);
    return cipher.openDatabase(
      path,
      password: key,
      version: _version,
      onConfigure: _configure,
      onCreate: (db, _) => _create(db),
    );
  }

  /// Banco sem criptografia aberto por outra fábrica; usado nos testes (FFI).
  static Future<Database> openWith(DatabaseFactory factory, {String path = inMemoryDatabasePath}) =>
      factory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: _version, onConfigure: _configure, onCreate: (db, _) => _create(db)),
      );

  static Future<void> _configure(Database db) => db.execute('PRAGMA foreign_keys = ON');

  /// Copia o banco antigo, sem criptografia, para o banco criptografado e
  /// apaga o arquivo antigo, para não sobrar cópia legível dos dados.
  static Future<void> _migrateLegacy(String legacyPath, String targetPath, String key) async {
    if (!await cipher.databaseExists(legacyPath)) return;
    if (!await cipher.databaseExists(targetPath)) {
      final legacy = await cipher.openDatabase(legacyPath);
      try {
        String quoted(String s) => "'${s.replaceAll("'", "''")}'";
        await legacy.execute('ATTACH DATABASE ${quoted(targetPath)} AS encrypted KEY ${quoted(key)}');
        await legacy.rawQuery("SELECT sqlcipher_export('encrypted')");
        await legacy.execute('PRAGMA encrypted.user_version = $_version');
        await legacy.execute('DETACH DATABASE encrypted');
      } finally {
        await legacy.close();
      }
    }
    await cipher.deleteDatabase(legacyPath);
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
