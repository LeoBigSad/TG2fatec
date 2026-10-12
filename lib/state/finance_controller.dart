import 'package:flutter/foundation.dart';

import '../data/models/models.dart';
import '../data/repositories.dart';
import '../services/category_suggester.dart';
import '../services/finance_stats.dart';
import '../services/import/statement_importer.dart';
import '../services/import/statement_parser.dart';

/// Dados financeiros do usuário logado: categorias, transações, orçamentos
/// e extratos importados.
class FinanceController extends ChangeNotifier {
  FinanceController({required FinanceRepository repository, required this._audit}) : _repo = repository;

  final FinanceRepository _repo;
  final AuditLog _audit;

  int? _userId;
  bool _loading = false;
  bool get loading => _loading;

  List<FinanceCategory> _categories = [];
  List<FinanceTransaction> _transactions = [];
  List<Budget> _budgets = [];
  List<StatementImport> _imports = [];

  List<FinanceCategory> get categories => _categories;
  List<FinanceTransaction> get transactions => _transactions;
  List<Budget> get budgets => _budgets;
  List<StatementImport> get imports => _imports;

  Map<int, FinanceCategory> get categoryById => {for (final c in _categories) c.id!: c};
  FinanceCategory? category(int? id) => id == null ? null : categoryById[id];
  List<FinanceCategory> categoriesOf(TransactionType type) => _categories.where((c) => c.type == type).toList();

  /// Mês exibido nas telas (seletor "Outubro").
  DateTime _month = DateTime.now();
  DateTime get month => DateTime(_month.year, _month.month);
  set month(DateTime value) {
    _month = value;
    notifyListeners();
  }

  /// Oculta valores na Home (ícone de olho).
  bool _hideValues = false;
  bool get hideValues => _hideValues;
  void toggleHideValues() {
    _hideValues = !_hideValues;
    notifyListeners();
  }

  Future<void> loadFor(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    if (userId == null) {
      _categories = [];
      _transactions = [];
      _budgets = [];
      _imports = [];
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    await _reload();
    _loading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    final id = _userId!;
    final results = await Future.wait([
      _repo.categories(id),
      _repo.transactions(id),
      _repo.budgets(id),
      _repo.imports(id),
    ]);
    _categories = results[0] as List<FinanceCategory>;
    _transactions = results[1] as List<FinanceTransaction>;
    _budgets = results[2] as List<Budget>;
    _imports = results[3] as List<StatementImport>;
  }

  Future<void> _mutate(Future<void> Function() action, String auditAction, [String details = '']) async {
    await action();
    await _audit.record(_userId, auditAction, details);
    await _reload();
    notifyListeners();
  }

  int get userId => _userId!;

  // Transações (RF3, RF5)

  Future<void> saveTransaction(FinanceTransaction t) => t.id == null
      ? _mutate(() => _repo.insertTransaction(t), 'transaction_created')
      : _mutate(() => _repo.updateTransaction(t), 'transaction_updated', 'id=${t.id}');

  Future<void> deleteTransaction(FinanceTransaction t) =>
      _mutate(() => _repo.deleteTransaction(t.id!), 'transaction_deleted', 'id=${t.id}');

  // Categorias (RF6, RF7, RF8)

  Future<void> saveCategory(FinanceCategory c) => c.id == null
      ? _mutate(() => _repo.insertCategory(c), 'category_created')
      : _mutate(() => _repo.updateCategory(c), 'category_updated', 'id=${c.id}');

  Future<void> deleteCategory(FinanceCategory c) =>
      _mutate(() => _repo.deleteCategory(c.id!), 'category_deleted', 'id=${c.id}');

  int transactionCountFor(FinanceCategory c) => _transactions.where((t) => t.categoryId == c.id).length;

  CategorySuggester get suggester => CategorySuggester(_categories, _transactions);

  /// Sugestão de categoria (RF9).
  FinanceCategory? suggestCategory(String description, TransactionType type) => suggester.suggest(description, type);

  // Orçamentos (RF12 a RF16)

  Future<void> saveBudget(Budget b) => b.id == null
      ? _mutate(() => _repo.insertBudget(b), 'budget_created')
      : _mutate(() => _repo.updateBudget(b), 'budget_updated', 'id=${b.id}');

  Future<void> deleteBudget(Budget b) => _mutate(() => _repo.deleteBudget(b.id!), 'budget_deleted', 'id=${b.id}');

  List<BudgetStatus> budgetStatuses([DateTime? month]) =>
      FinanceStats.budgetStatuses(_budgets, _transactions, month ?? this.month);

  /// Alertas de orçamento do mês atual (RF14).
  List<BudgetStatus> get budgetAlerts =>
      budgetStatuses(DateTime.now()).where((s) => s.isOver || s.isWarning).toList();

  int? suggestBudget(int categoryId) => FinanceStats.suggestBudget(categoryId, _transactions, DateTime.now());

  // Extratos (RF1 a RF4)

  Set<String> get existingKeys => {
        for (final t in _transactions) ParsedEntry.duplicateKey(t.date, t.signedCents, t.title),
      };

  Future<int> importStatement(ImportPreview preview) async {
    final selected = preview.candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return 0;
    final items = [
      for (final c in selected)
        FinanceTransaction(
          userId: userId,
          type: c.type,
          title: c.entry.description,
          amountCents: c.entry.amountCents.abs(),
          date: c.entry.date,
          categoryId: c.categoryId,
          source: preview.source,
        ),
    ];
    final import = StatementImport(
      userId: userId,
      fileName: preview.fileName,
      source: preview.source,
      importedAt: DateTime.now(),
      count: items.length,
    );
    await _mutate(() => _repo.insertImport(import, items), 'statement_imported',
        '${preview.source.name}: ${items.length} transações');
    return items.length;
  }

  Future<void> deleteImport(StatementImport i) =>
      _mutate(() => _repo.deleteImport(i.id!), 'statement_deleted', 'id=${i.id}');
}
