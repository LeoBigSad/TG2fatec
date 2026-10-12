import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg2fatec/core/utils/input_formatters.dart';
import 'package:tg2fatec/data/models/models.dart';
import 'package:tg2fatec/services/category_suggester.dart';
import 'package:tg2fatec/services/finance_stats.dart';
import 'package:tg2fatec/services/labor_calculators.dart';
import 'package:tg2fatec/services/password_hasher.dart';
import 'package:tg2fatec/services/verification_service.dart';

FinanceTransaction tx(int cents, DateTime date, {int? category, TransactionType type = TransactionType.expense, String title = 'x'}) =>
    FinanceTransaction(userId: 1, type: type, title: title, amountCents: cents, date: date, categoryId: category);

FinanceCategory cat(int id, String name, [TransactionType type = TransactionType.expense]) =>
    FinanceCategory(id: id, userId: 1, name: name, iconKey: 'other', color: Colors.black, type: type);

class _RecordingDelivery implements CodeDelivery {
  String? lastCode;

  @override
  Future<void> deliver(ContactMethod method, String destination, String code) async => lastCode = code;
}

void main() {
  group('PasswordHasher', () {
    test('PBKDF2-HMAC-SHA256 confere com o vetor de teste da RFC 7914', () {
      final out = PasswordHasher.pbkdf2('passwd'.codeUnits, 'salt'.codeUnits, 1, 64);
      expect(
        out.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '55ac046e56e3089f',
      );
    });

    test('verifica senha correta e rejeita incorreta', () async {
      const hasher = PasswordHasher(iterations: 50);
      final salt = hasher.newSalt();
      final hash = await hasher.hash('segredo123', salt);
      expect(await hasher.verify('segredo123', salt, hash), isTrue);
      expect(await hasher.verify('segredo124', salt, hash), isFalse);
    });
  });

  group('VerificationService', () {
    test('aceita o código correto uma única vez', () async {
      final delivery = _RecordingDelivery();
      final service = VerificationService(delivery);
      await service.send(ContactMethod.email, 'a@b.com');
      expect(service.verify('a@b.com', '0000' == delivery.lastCode ? '1111' : '0000'), 'Código incorreto.');
      expect(service.verify('a@b.com', delivery.lastCode!), isNull);
      expect(service.verify('a@b.com', delivery.lastCode!), isNotNull);
    });

    test('código expira em 10 minutos', () async {
      var now = DateTime(2025, 1, 1, 12);
      final delivery = _RecordingDelivery();
      final service = VerificationService(delivery, clock: () => now);
      await service.send(ContactMethod.sms, '11999999999');
      now = now.add(const Duration(minutes: 11));
      expect(service.verify('11999999999', delivery.lastCode!), contains('expirou'));
    });
  });

  group('FinanceStats', () {
    final oct = DateTime(2025, 10);
    final txs = [
      tx(10000, DateTime(2025, 10, 2), category: 1),
      tx(5000, DateTime(2025, 10, 9), category: 1),
      tx(2000, DateTime(2025, 10, 30), category: 2),
      tx(100000, DateTime(2025, 10, 5), type: TransactionType.income),
      tx(7000, DateTime(2025, 9, 15), category: 1),
    ];

    test('totais e semanas do mês', () {
      final month = FinanceStats.inMonth(txs, oct).toList();
      expect(FinanceStats.income(month), 100000);
      expect(FinanceStats.expense(month), 17000);
      expect(FinanceStats.weeklyExpenses(txs, oct), [10000, 5000, 0, 0, 2000]);
      expect(FinanceStats.expensesByCategory(month).first.key, 1);
    });

    test('orçamento recorrente, alerta e estouro', () {
      final budget = Budget(id: 1, userId: 1, categoryId: 1, limitCents: 15000, startDate: DateTime(2025, 1), repeatMonthly: true);
      final status = FinanceStats.budgetStatuses([budget], txs, oct).single;
      expect(status.spentCents, 15000);
      expect(status.isWarning, isTrue);
      expect(status.isOver, isFalse);

      final small = budget.copyWith(limitCents: 10000);
      expect(FinanceStats.budgetStatuses([small], txs, oct).single.isOver, isTrue);
    });

    test('orçamento não recorrente vale só no período', () {
      final budget = Budget(userId: 1, categoryId: 1, limitCents: 1000, startDate: DateTime(2025, 9, 1));
      expect(FinanceStats.budgetStatuses([budget], txs, oct), isEmpty);
      expect(FinanceStats.budgetStatuses([budget], txs, DateTime(2025, 9)).single.spentCents, 7000);
    });

    test('sugestão de orçamento usa a média dos meses anteriores', () {
      expect(FinanceStats.suggestBudget(1, txs, DateTime(2025, 11, 10)), 11000);
      expect(FinanceStats.suggestBudget(99, txs, DateTime(2025, 11, 10)), isNull);
    });
  });

  group('CategorySuggester', () {
    final categories = [cat(1, 'Mercado'), cat(2, 'Transporte'), cat(3, 'Salário', TransactionType.income)];

    test('usa o histórico de descrições parecidas', () {
      final history = [tx(100, DateTime(2025), category: 2, title: 'Padaria Pão Quente')];
      final s = CategorySuggester(categories, history);
      expect(s.suggest('PADARIA PAO QUENTE LTDA', TransactionType.expense)?.name, 'Transporte');
    });

    test('usa palavras-chave quando não há histórico', () {
      final s = CategorySuggester(categories, const []);
      expect(s.suggest('UBER *TRIP', TransactionType.expense)?.name, 'Transporte');
      expect(s.suggest('Carrefour Campinas', TransactionType.expense)?.name, 'Mercado');
      expect(s.suggest('SALARIO OUTUBRO', TransactionType.income)?.name, 'Salário');
      expect(s.suggest('Algo desconhecido', TransactionType.expense), isNull);
    });
  });

  group('Calculadoras', () {
    test('horas extras com adicionais legais', () {
      final r = calculateOvertime(baseSalary: 2200, monthlyHours: 220, weekdayHours: 10, holidayHours: 2, workingDays: 25, restDays: 5);
      expect(r.hourlyRate, 10);
      expect(r.weekdayValue, 150);
      expect(r.holidayValue, 40);
      expect(r.dsrValue, closeTo(38, 0.001));
      expect(r.total, closeTo(228, 0.001));
    });

    test('férias com 1/3 e abono pecuniário', () {
      final full = calculateVacation(baseSalary: 3000);
      expect(full.vacationPay, 3000);
      expect(full.oneThird, 1000);
      expect(full.total, 4000);

      final sold = calculateVacation(baseSalary: 3000, soldDays: 10);
      expect(sold.vacationPay, 2000);
      expect(sold.allowance, 1000);
      expect(sold.total, closeTo(4000, 0.001));

      expect(calculateVacation(baseSalary: 3000, acquiredMonths: 6).vacationPay, 1500);
    });
  });

  group('Formatadores', () {
    test('telefone e dinheiro', () {
      expect(PhoneInputFormatter.format('11912345678'), '(11) 91234-5678');
      expect(PhoneInputFormatter.format('1133334444'), '(11) 3333-4444');
      expect(MoneyInputFormatter.parse('1.234,56'), 123456);
    });
  });
}
