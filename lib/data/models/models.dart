import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';

enum TransactionType {
  income('income', 'Receita'),
  expense('expense', 'Gasto');

  const TransactionType(this.key, this.label);
  final String key;
  final String label;

  static TransactionType fromKey(String key) =>
      values.firstWhere((t) => t.key == key, orElse: () => expense);
}

/// Origem de uma transação: digitada manualmente ou importada de extrato.
enum TransactionSource { manual, ofx, csv, pdf }

class AppUser {
  const AppUser({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.passwordHash,
    required this.passwordSalt,
    required this.createdAt,
    required this.consentAt,
  });

  final int? id;
  final String name;
  final String email;
  final String phone;
  final String passwordHash;
  final String passwordSalt;
  final DateTime createdAt;

  /// Momento do consentimento com os termos (LGPD).
  final DateTime consentAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  AppUser copyWith({String? name, String? email, String? phone, String? passwordHash, String? passwordSalt}) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        passwordHash: passwordHash ?? this.passwordHash,
        passwordSalt: passwordSalt ?? this.passwordSalt,
        createdAt: createdAt,
        consentAt: consentAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'created_at': createdAt.toIso8601String(),
        'consent_at': consentAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int,
        name: m['name'] as String,
        email: m['email'] as String,
        phone: m['phone'] as String,
        passwordHash: m['password_hash'] as String,
        passwordSalt: m['password_salt'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        consentAt: DateTime.parse(m['consent_at'] as String),
      );
}

class FinanceCategory {
  const FinanceCategory({
    this.id,
    required this.userId,
    required this.name,
    required this.iconKey,
    required this.color,
    required this.type,
  });

  final int? id;
  final int userId;
  final String name;
  final String iconKey;
  final Color color;
  final TransactionType type;

  FinanceCategory copyWith({String? name, String? iconKey, Color? color, TransactionType? type}) => FinanceCategory(
        id: id,
        userId: userId,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
        color: color ?? this.color,
        type: type ?? this.type,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'icon': iconKey,
        'color': color.toARGB32(),
        'type': type.key,
      };

  factory FinanceCategory.fromMap(Map<String, Object?> m) => FinanceCategory(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        name: m['name'] as String,
        iconKey: m['icon'] as String,
        color: Color(m['color'] as int),
        type: TransactionType.fromKey(m['type'] as String),
      );
}

class FinanceTransaction {
  const FinanceTransaction({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.description = '',
    required this.amountCents,
    required this.date,
    this.categoryId,
    this.account = '',
    this.source = TransactionSource.manual,
    this.importId,
  });

  final int? id;
  final int userId;
  final TransactionType type;
  final String title;
  final String description;

  /// Valor sempre positivo, em centavos; o sinal vem de [type].
  final int amountCents;
  final DateTime date;
  final int? categoryId;
  final String account;
  final TransactionSource source;
  final int? importId;

  bool get isExpense => type == TransactionType.expense;
  int get signedCents => isExpense ? -amountCents : amountCents;

  FinanceTransaction copyWith({
    TransactionType? type,
    String? title,
    String? description,
    int? amountCents,
    DateTime? date,
    int? Function()? categoryId,
    String? account,
  }) =>
      FinanceTransaction(
        id: id,
        userId: userId,
        type: type ?? this.type,
        title: title ?? this.title,
        description: description ?? this.description,
        amountCents: amountCents ?? this.amountCents,
        date: date ?? this.date,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        account: account ?? this.account,
        source: source,
        importId: importId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type.key,
        'title': title,
        'description': description,
        'amount_cents': amountCents,
        'date': Fmt.dbDate(date),
        'category_id': categoryId,
        'account': account,
        'source': source.name,
        'import_id': importId,
      };

  factory FinanceTransaction.fromMap(Map<String, Object?> m) => FinanceTransaction(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        type: TransactionType.fromKey(m['type'] as String),
        title: m['title'] as String,
        description: (m['description'] as String?) ?? '',
        amountCents: m['amount_cents'] as int,
        date: DateTime.parse(m['date'] as String),
        categoryId: m['category_id'] as int?,
        account: (m['account'] as String?) ?? '',
        source: TransactionSource.values.byName(m['source'] as String),
        importId: m['import_id'] as int?,
      );
}

class Budget {
  const Budget({
    this.id,
    required this.userId,
    required this.categoryId,
    required this.limitCents,
    required this.startDate,
    this.endDate,
    this.repeatMonthly = false,
  });

  final int? id;
  final int userId;
  final int categoryId;
  final int limitCents;
  final DateTime startDate;
  final DateTime? endDate;

  /// Orçamento recorrente: vale para todo mês a partir de [startDate].
  final bool repeatMonthly;

  Budget copyWith({int? categoryId, int? limitCents, DateTime? startDate, DateTime? Function()? endDate, bool? repeatMonthly}) =>
      Budget(
        id: id,
        userId: userId,
        categoryId: categoryId ?? this.categoryId,
        limitCents: limitCents ?? this.limitCents,
        startDate: startDate ?? this.startDate,
        endDate: endDate != null ? endDate() : this.endDate,
        repeatMonthly: repeatMonthly ?? this.repeatMonthly,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'category_id': categoryId,
        'limit_cents': limitCents,
        'start_date': Fmt.dbDate(startDate),
        'end_date': endDate == null ? null : Fmt.dbDate(endDate!),
        'repeat_monthly': repeatMonthly ? 1 : 0,
      };

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        categoryId: m['category_id'] as int,
        limitCents: m['limit_cents'] as int,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: m['end_date'] == null ? null : DateTime.parse(m['end_date'] as String),
        repeatMonthly: m['repeat_monthly'] == 1,
      );
}

/// Um extrato importado (agrupa as transações criadas pela importação).
class StatementImport {
  const StatementImport({
    this.id,
    required this.userId,
    required this.fileName,
    required this.source,
    required this.importedAt,
    required this.count,
  });

  final int? id;
  final int userId;
  final String fileName;
  final TransactionSource source;
  final DateTime importedAt;
  final int count;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'file_name': fileName,
        'source': source.name,
        'imported_at': importedAt.toIso8601String(),
        'count': count,
      };

  factory StatementImport.fromMap(Map<String, Object?> m) => StatementImport(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        fileName: m['file_name'] as String,
        source: TransactionSource.values.byName(m['source'] as String),
        importedAt: DateTime.parse(m['imported_at'] as String),
        count: m['count'] as int,
      );
}
