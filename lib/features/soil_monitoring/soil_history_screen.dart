import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../shared/models/soil_data.dart';

/// Soil history charts with parameter and period selection.
class SoilHistoryScreen extends ConsumerWidget {
  const SoilHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedParam = ref.watch(selectedSoilParamProvider);
    final selectedPeriod = ref.watch(selectedSoilPeriodProvider);
    final historyAsync = ref.watch(soilHistoryProvider);

    final params = ['Moisture', 'Temperature', 'pH'];
    final periods = [AppConstants.period24h, AppConstants.period7d, AppConstants.period30d];

    return Scaffold(
      appBar: AppBar(title: const Text('Soil History')),
      body: Column(
        children: [
          // ── Parameter Selector ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: params.map((p) {
                final isSelected = p == selectedParam;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(p),
                      selected: isSelected,
                      onSelected: (_) => ref.read(selectedSoilParamProvider.notifier).state = p,
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primaryGreen : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Period Selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: periods.map((p) {
                final isSelected = p == selectedPeriod;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(p),
                    selected: isSelected,
                    onSelected: (_) => ref.read(selectedSoilPeriodProvider.notifier).state = p,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Chart Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$selectedParam History',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Chart ──
          Expanded(
            child: AsyncValueWidget(
              value: historyAsync,
              onRetry: () => ref.invalidate(soilHistoryProvider),
              data: (history) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
                child: _SoilLineChart(data: history, param: selectedParam),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoilLineChart extends StatelessWidget {
  final List<SoilHistoryPoint> data;
  final String param;

  const _SoilLineChart({required this.data, required this.param});

  Color get _lineColor => switch (param) {
    'Temperature' => AppColors.chartTemperature,
    'pH' => AppColors.chartPh,
    _ => AppColors.chartMoisture,
  };

  String get _unit => switch (param) {
    'Temperature' => '°C',
    'pH' => '',
    _ => '%',
  };

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getInterval(),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${value.toStringAsFixed(param == 'pH' ? 1 : 0)}$_unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormatter.formatDayOfWeek(data[index].timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: _lineColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _lineColor.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(param == 'pH' ? 1 : 0)}$_unit',
                TextStyle(color: _lineColor, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  double _getInterval() => switch (param) {
    'pH' => 0.5,
    'Temperature' => 5,
    _ => 20,
  };
}
