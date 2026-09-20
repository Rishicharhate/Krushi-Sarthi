import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../shared/models/environment_data.dart';

/// Environment history charts.
class EnvironmentHistoryScreen extends ConsumerWidget {
  const EnvironmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedParam = ref.watch(selectedEnvParamProvider);
    final selectedPeriod = ref.watch(selectedEnvPeriodProvider);
    final historyAsync = ref.watch(environmentHistoryProvider);

    final params = ['Temperature', 'Humidity'];
    final periods = [AppConstants.period24h, AppConstants.period7d, AppConstants.period30d];

    return Scaffold(
      appBar: AppBar(title: const Text('Environmental History')),
      body: Column(
        children: [
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
                      onSelected: (_) => ref.read(selectedEnvParamProvider.notifier).state = p,
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: periods.map((p) {
                final isSelected = p == selectedPeriod;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(label: Text(p), selected: isSelected,
                    onSelected: (_) => ref.read(selectedEnvPeriodProvider.notifier).state = p),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('$selectedParam History',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: AsyncValueWidget(
              value: historyAsync,
              onRetry: () => ref.invalidate(environmentHistoryProvider),
              data: (history) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 24, 16),
                child: _EnvLineChart(data: history, param: selectedParam),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvLineChart extends StatelessWidget {
  final List<EnvironmentHistoryPoint> data;
  final String param;

  const _EnvLineChart({required this.data, required this.param});

  Color get _lineColor => param == 'Humidity' ? AppColors.chartMoisture : AppColors.chartTemperature;
  String get _unit => param == 'Humidity' ? '%' : '°C';

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data available'));

    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
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
                child: Text('${value.toInt()}$_unit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                  child: Text(DateFormatter.formatDayOfWeek(data[index].timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                radius: 4, color: _lineColor, strokeWidth: 2, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(show: true, color: _lineColor.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }
}
