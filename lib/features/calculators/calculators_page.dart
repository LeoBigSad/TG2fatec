import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/input_formatters.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/common.dart';
import '../../services/labor_calculators.dart';

/// Calculadoras de horas extras (RF17, RF18) e férias (RF19).
class CalculatorsPage extends StatelessWidget {
  const CalculatorsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          title: Text('Calculadoras', style: AppTextStyles.heading),
          bottom: const TabBar(
            labelColor: AppColors.textPrimary,
            indicatorColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [Tab(text: 'Horas extras'), Tab(text: 'Férias')],
          ),
        ),
        body: const TabBarView(children: [_OvertimeTab(), _VacationTab()]),
      ),
    );
  }
}

double _money(TextEditingController c) => MoneyInputFormatter.parse(c.text) / 100;
double _number(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
int _cents(double value) => (value * 100).round();

final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'[\d,]'))];
final _integer = [FilteringTextInputFormatter.digitsOnly];
const _moneyPrefix = 'R\$ ';

class _OvertimeTab extends StatefulWidget {
  const _OvertimeTab();

  @override
  State<_OvertimeTab> createState() => _OvertimeTabState();
}

class _OvertimeTabState extends State<_OvertimeTab> with AutomaticKeepAliveClientMixin {
  final _salary = TextEditingController();
  final _monthlyHours = TextEditingController(text: '220');
  final _weekday = TextEditingController();
  final _holiday = TextEditingController();
  final _night = TextEditingController();
  final _workingDays = TextEditingController(text: '25');
  final _restDays = TextEditingController(text: '5');

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    for (final c in [_salary, _monthlyHours, _weekday, _holiday, _night, _workingDays, _restDays]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final salary = _money(_salary);
    final hours = _number(_monthlyHours);
    final result = salary > 0 && hours > 0
        ? calculateOvertime(
            baseSalary: salary,
            monthlyHours: hours,
            weekdayHours: _number(_weekday),
            holidayHours: _number(_holiday),
            nightHours: _number(_night),
            workingDays: int.tryParse(_workingDays.text) ?? 0,
            restDays: int.tryParse(_restDays.text) ?? 0,
          )
        : null;
    void update(String _) => setState(() {});

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        LabeledField(
          label: 'Salário base',
          controller: _salary,
          hint: '0,00',
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          prefixText: _moneyPrefix,
          onChanged: update,
        ),
        const SizedBox(height: AppSpacing.sm),
        LabeledField(
          label: 'Carga horária mensal (horas)',
          controller: _monthlyHours,
          keyboardType: TextInputType.number,
          inputFormatters: _decimal,
          onChanged: update,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: LabeledField(
              label: 'Horas extras (50%)',
              controller: _weekday,
              hint: 'Dias úteis',
              keyboardType: TextInputType.number,
              inputFormatters: _decimal,
              onChanged: update,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LabeledField(
              label: 'Horas extras (100%)',
              controller: _holiday,
              hint: 'Domingos/feriados',
              keyboardType: TextInputType.number,
              inputFormatters: _decimal,
              onChanged: update,
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.sm),
        LabeledField(
          label: 'Horas extras noturnas (adicional de 20%)',
          controller: _night,
          hint: '0',
          keyboardType: TextInputType.number,
          inputFormatters: _decimal,
          onChanged: update,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [
          Expanded(
            child: LabeledField(
              label: 'Dias úteis no mês',
              controller: _workingDays,
              keyboardType: TextInputType.number,
              inputFormatters: _integer,
              onChanged: update,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LabeledField(
              label: 'Domingos e feriados',
              controller: _restDays,
              keyboardType: TextInputType.number,
              inputFormatters: _integer,
              onChanged: update,
              textInputAction: TextInputAction.done,
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        if (result == null)
          const EmptyState(icon: Icons.calculate_outlined, message: 'Informe o salário e a carga horária para calcular.')
        else
          _ResultCard(rows: [
            ('Valor da hora normal', _cents(result.hourlyRate)),
            ('Horas extras 50%', _cents(result.weekdayValue)),
            ('Horas extras 100%', _cents(result.holidayValue)),
            ('Adicional noturno', _cents(result.nightBonus)),
            ('Reflexo no DSR', _cents(result.dsrValue)),
          ], total: ('Total de horas extras', _cents(result.total))),
      ],
    );
  }
}

class _VacationTab extends StatefulWidget {
  const _VacationTab();

  @override
  State<_VacationTab> createState() => _VacationTabState();
}

class _VacationTabState extends State<_VacationTab> with AutomaticKeepAliveClientMixin {
  final _salary = TextEditingController();
  final _extras = TextEditingController();
  int _months = 12;
  bool _sell = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _salary.dispose();
    _extras.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final salary = _money(_salary);
    final result = salary > 0
        ? calculateVacation(
            baseSalary: salary,
            averageExtras: _money(_extras),
            acquiredMonths: _months,
            soldDays: _sell ? 10 : 0,
          )
        : null;
    void update(String _) => setState(() {});

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        LabeledField(
          label: 'Salário base',
          controller: _salary,
          hint: '0,00',
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          prefixText: _moneyPrefix,
          onChanged: update,
        ),
        const SizedBox(height: AppSpacing.sm),
        LabeledField(
          label: 'Média de horas extras e adicionais (opcional)',
          controller: _extras,
          hint: '0,00',
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          prefixText: _moneyPrefix,
          onChanged: update,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Meses trabalhados no período aquisitivo: $_months', style: AppTextStyles.fieldLabel),
        Slider(
          value: _months.toDouble(),
          min: 1,
          max: 12,
          divisions: 11,
          label: '$_months',
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _months = v.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Vender 10 dias (abono pecuniário)', style: AppTextStyles.body),
          value: _sell,
          activeTrackColor: AppColors.primary,
          onChanged: (v) => setState(() => _sell = v),
        ),
        const SizedBox(height: AppSpacing.md),
        if (result == null)
          const EmptyState(icon: Icons.beach_access_outlined, message: 'Informe o salário para calcular as férias.')
        else
          _ResultCard(rows: [
            ('Férias', _cents(result.vacationPay)),
            ('1/3 constitucional', _cents(result.oneThird)),
            if (_sell) ('Abono pecuniário', _cents(result.allowance)),
            if (_sell) ('1/3 sobre o abono', _cents(result.allowanceOneThird)),
          ], total: ('Total bruto estimado', _cents(result.total))),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.rows, required this.total});

  final List<(String, int)> rows;
  final (String, int) total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          for (final (label, cents) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary))),
                Text(Fmt.money(cents), style: AppTextStyles.body),
              ]),
            ),
          const Divider(height: AppSpacing.lg),
          Row(children: [
            Expanded(child: Text(total.$1, style: AppTextStyles.subtitle)),
            Text(Fmt.money(total.$2), style: AppTextStyles.subtitle.copyWith(color: AppColors.income)),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text('Valores brutos estimados, sem descontos de INSS e IRRF.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
