/// Cálculos trabalhistas (RF17, RF18 e RF19). Valores brutos estimados, sem
/// descontos de INSS e IRRF.
library;

class OvertimeResult {
  const OvertimeResult({
    required this.hourlyRate,
    required this.weekdayValue,
    required this.holidayValue,
    required this.nightBonus,
    required this.dsrValue,
  });

  final double hourlyRate;

  /// Horas extras em dias úteis (adicional de 50%).
  final double weekdayValue;

  /// Horas extras em domingos e feriados (adicional de 100%).
  final double holidayValue;

  /// Adicional noturno de 20% sobre as horas extras noturnas.
  final double nightBonus;

  /// Reflexo das horas extras no descanso semanal remunerado.
  final double dsrValue;

  double get total => weekdayValue + holidayValue + nightBonus + dsrValue;
}

OvertimeResult calculateOvertime({
  required double baseSalary,
  required double monthlyHours,
  double weekdayHours = 0,
  double holidayHours = 0,
  double nightHours = 0,
  int workingDays = 0,
  int restDays = 0,
}) {
  if (monthlyHours <= 0) throw ArgumentError('Carga horária deve ser maior que zero');
  final rate = baseSalary / monthlyHours;
  final weekday = weekdayHours * rate * 1.5;
  final holiday = holidayHours * rate * 2.0;
  final night = nightHours * rate * 1.5 * 0.2;
  final dsr = workingDays > 0 ? (weekday + holiday + night) / workingDays * restDays : 0.0;
  return OvertimeResult(
    hourlyRate: rate,
    weekdayValue: weekday,
    holidayValue: holiday,
    nightBonus: night,
    dsrValue: dsr,
  );
}

class VacationResult {
  const VacationResult({
    required this.vacationPay,
    required this.oneThird,
    required this.allowance,
    required this.allowanceOneThird,
  });

  /// Remuneração dos dias de férias gozados.
  final double vacationPay;

  /// Adicional constitucional de 1/3.
  final double oneThird;

  /// Abono pecuniário (venda de até 10 dias).
  final double allowance;
  final double allowanceOneThird;

  double get total => vacationPay + oneThird + allowance + allowanceOneThird;
}

/// [acquiredMonths] é o número de meses trabalhados no período aquisitivo
/// (12 para férias integrais; menos que isso para férias proporcionais).
VacationResult calculateVacation({
  required double baseSalary,
  double averageExtras = 0,
  int acquiredMonths = 12,
  int soldDays = 0,
}) {
  if (acquiredMonths < 1 || acquiredMonths > 12) throw ArgumentError('Meses devem estar entre 1 e 12');
  if (soldDays < 0 || soldDays > 10) throw ArgumentError('É possível vender no máximo 10 dias');
  final remuneration = baseSalary + averageExtras;
  final entitledDays = 30 * acquiredMonths / 12;
  final daily = remuneration / 30;
  final sold = soldDays > entitledDays / 3 ? entitledDays / 3 : soldDays.toDouble();
  final vacationPay = daily * (entitledDays - sold);
  final allowance = daily * sold;
  return VacationResult(
    vacationPay: vacationPay,
    oneThird: vacationPay / 3,
    allowance: allowance,
    allowanceOneThird: allowance / 3,
  );
}
