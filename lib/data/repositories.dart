import 'package:sqflite_sqlcipher/sqlite_api.dart';

import 'category_catalog.dart';
import 'models/models.dart';

class UserRepository {
  UserRepository(this._db);
  final Database _db;

  Future<AppUser?> byId(int id) => _one('id = ?', [id]);
  Future<AppUser?> byEmail(String email) => _one('email = ?', [email.trim()]);
  Future<AppUser?> byPhone(String digits) => _one('phone = ?', [digits]);

  Future<AppUser?> _one(String where, List<Object?> args) async {
    final rows = await _db.query('users', where: where, whereArgs: args, limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  /// Cria o usuário com as categorias padrão.
  Future<AppUser> create(AppUser user) => _db.transaction((txn) async {
        final id = await txn.insert('users', user.toMap()..remove('id'));
        final batch = txn.batch();
        for (final c in defaultCategories(id)) {
          batch.insert('categories', c.toMap()..remove('id'));
        }
        await batch.commit(noResult: true);
        return AppUser.fromMap({...user.toMap(), 'id': id});
      });

  Future<void> update(AppUser user) =>
      _db.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);

  /// Remove o usuário e, em cascata, todos os seus dados (direito ao esquecimento).
  Future<void> delete(int id) => _db.delete('users', where: 'id = ?', whereArgs: [id]);
}

class FinanceRepository {
  FinanceRepository(this._db);
  final Database _db;

  // Categorias

  Future<List<FinanceCategory>> categories(int userId) async =>
      (await _db.query('categories', where: 'user_id = ?', whereArgs: [userId], orderBy: 'name'))
          .map(FinanceCategory.fromMap)
          .toList();

  Future<int> insertCategory(FinanceCategory c) => _db.insert('categories', c.toMap()..remove('id'));

  Future<void> updateCategory(FinanceCategory c) =>
      _db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);

  Future<void> deleteCategory(int id) => _db.delete('categories', where: 'id = ?', whereArgs: [id]);

  // Transações

  Future<List<FinanceTransaction>> transactions(int userId) async =>
      (await _db.query('transactions', where: 'user_id = ?', whereArgs: [userId], orderBy: 'date DESC, id DESC'))
          .map(FinanceTransaction.fromMap)
          .toList();

  Future<int> insertTransaction(FinanceTransaction t) => _db.insert('transactions', t.toMap()..remove('id'));

  Future<void> updateTransaction(FinanceTransaction t) =>
      _db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  Future<void> deleteTransaction(int id) => _db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  // Extratos importados

  Future<List<StatementImport>> imports(int userId) async =>
      (await _db.query('imports', where: 'user_id = ?', whereArgs: [userId], orderBy: 'imported_at DESC'))
          .map(StatementImport.fromMap)
          .toList();

  /// Grava o extrato e suas transações numa única transação do banco.
  Future<void> insertImport(StatementImport import, List<FinanceTransaction> items) =>
      _db.transaction((txn) async {
        final importId = await txn.insert('imports', import.toMap()..remove('id'));
        final batch = txn.batch();
        for (final t in items) {
          batch.insert('transactions', (t.toMap()..remove('id'))..['import_id'] = importId);
        }
        await batch.commit(noResult: true);
      });

  /// Remove o extrato e, em cascata, as transações importadas por ele.
  Future<void> deleteImport(int id) => _db.delete('imports', where: 'id = ?', whereArgs: [id]);

  // Orçamentos

  Future<List<Budget>> budgets(int userId) async =>
      (await _db.query('budgets', where: 'user_id = ?', whereArgs: [userId], orderBy: 'id'))
          .map(Budget.fromMap)
          .toList();

  Future<int> insertBudget(Budget b) => _db.insert('budgets', b.toMap()..remove('id'));

  Future<void> updateBudget(Budget b) => _db.update('budgets', b.toMap(), where: 'id = ?', whereArgs: [b.id]);

  Future<void> deleteBudget(int id) => _db.delete('budgets', where: 'id = ?', whereArgs: [id]);
}

/// Registro de auditoria das operações críticas (RNF6).
class AuditLog {
  AuditLog(this._db);
  final Database _db;

  Future<void> record(int? userId, String action, [String details = '']) => _db.insert('audit_logs', {
        'user_id': userId,
        'action': action,
        'details': details,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<List<Map<String, Object?>>> entries({int? userId}) => _db.query(
        'audit_logs',
        where: userId == null ? null : 'user_id = ?',
        whereArgs: userId == null ? null : [userId],
        orderBy: 'id DESC',
      );
}
