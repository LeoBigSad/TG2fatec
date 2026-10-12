import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ChartSlice {
  const ChartSlice({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;
}

/// Gráfico de rosca com texto no centro (Home: "Despesas por categoria").
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, required this.center, this.size = 140, this.thickness = 22});

  final List<ChartSlice> slices;
  final Widget center;
  final double size;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final hasData = slices.any((s) => s.value > 0);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: hasData && slices.length > 1 ? 2 : 0,
              centerSpaceRadius: size / 2 - thickness,
              sections: hasData
                  ? [
                      for (final s in slices.where((s) => s.value > 0))
                        PieChartSectionData(value: s.value, color: s.color, radius: thickness, showTitle: false),
                    ]
                  : [PieChartSectionData(value: 1, color: AppColors.divider, radius: thickness, showTitle: false)],
            ),
          ),
          center,
        ],
      ),
    );
  }
}

/// Legenda em lista: bolinha colorida, nome e percentual.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<({Color color, String label, String trailing})> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: i.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(i.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
              ),
              Text(i.trailing, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
            ]),
          ),
      ],
    );
  }
}

/// Duas barras: receitas x despesas (Home).
class IncomeExpenseBars extends StatelessWidget {
  const IncomeExpenseBars({super.key, required this.income, required this.expense, this.height = 140});

  final int income;
  final int expense;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxY = math.max(income, expense).toDouble();
    BarChartGroupData group(int x, int value, Color color) => BarChartGroupData(x: x, barRods: [
          BarChartRodData(
            toY: value.toDouble(),
            color: color,
            width: 34,
            borderRadius: BorderRadius.zero,
          ),
        ]);
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY,
          alignment: BarChartAlignment.spaceEvenly,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(value == 0 ? 'Receitas' : 'Despesas',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                ),
              ),
            ),
          ),
          barGroups: [group(0, income, AppColors.income), group(1, expense, AppColors.expense)],
        ),
      ),
    );
  }
}

/// Gráfico de área dos gastos ao longo do período (Visão Geral).
class SpendingAreaChart extends StatelessWidget {
  const SpendingAreaChart({super.key, required this.values, required this.labels, this.height = 160});

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxY = values.fold<int>(0, math.max).toDouble();
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          // Margem nas pontas para os rótulos do eixo não serem cortados.
          minX: -0.4,
          maxX: values.length - 0.6,
          gridData: FlGridData(
            drawHorizontalLine: false,
            verticalInterval: 1,
            getDrawingVerticalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1, dashArray: [3, 3]),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    'R\$${(s.y / 100).toStringAsFixed(2).replaceAll('.', ',')}',
                    AppTextStyles.caption.copyWith(color: AppColors.onPrimary),
                  ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 18,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length || value != i.toDouble()) return const SizedBox.shrink();
                  return Text(labels[i], style: AppTextStyles.caption.copyWith(color: AppColors.disabled));
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i].toDouble())],
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.income,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.income.withValues(alpha: 0.45), AppColors.accent.withValues(alpha: 0.35)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anéis concêntricos, um por orçamento (Visão Geral: "Resumo do mês").
class BudgetRingsChart extends StatelessWidget {
  const BudgetRingsChart({super.key, required this.rings, required this.center, this.size = 150});

  final List<({double ratio, Color color})> rings;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingsPainter(rings),
        child: Center(child: center),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings);

  final List<({double ratio, Color color})> rings;

  @override
  void paint(Canvas canvas, Size size) {
    if (rings.isEmpty) return;
    final c = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    const stroke = 6.0, gap = 4.0;
    for (var i = 0; i < rings.length && i < 6; i++) {
      final radius = maxRadius - stroke / 2 - i * (stroke + gap);
      if (radius < 20) break;
      final rect = Rect.fromCircle(center: c, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = AppColors.divider);
      final ratio = rings[i].ratio;
      if (ratio > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * ratio.clamp(0, 1),
          false,
          paint..color = ratio > 1 ? AppColors.error : rings[i].color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.rings != rings;
}
