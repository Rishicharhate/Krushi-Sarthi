import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../shared/models/crop_health.dart';

/// NDVI trend chart screen.
class NdviHistoryScreen extends ConsumerWidget {
  const NdviHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(ndviHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('NDVI Trend')),
      body: AsyncValueWidget(
        value: historyAsync,
        onRetry: () => ref.invalidate(ndviHistoryProvider),
        data: (history) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('NDVI Trend', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Satellite-based vegetation index over time',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),

            SizedBox(
              height: 280,
              child: _NdviChart(data: history),
            ),

            const SizedBox(height: 24),

            Text('Observation History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            ...history.reversed.map((point) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _ndviColor(point.ndvi).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          point.ndvi.toStringAsFixed(2),
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: _ndviColor(point.ndvi)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(point.healthStatus ?? 'N/A', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          Text(DateFormatter.formatDate(point.date),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _ndviColor(double ndvi) {
    if (ndvi >= 0.6) return AppColors.statusHealthy;
    if (ndvi >= 0.3) return AppColors.statusAttention;
    return AppColors.statusCritical;
  }
}

class _NdviChart extends StatelessWidget {
  final List<NdviHistoryPoint> data;

  const _NdviChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ndvi)).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 0.2,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(value.toStringAsFixed(1),
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
                  child: Text('W${index + 1}',
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
            color: AppColors.chartNdvi,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 5, color: AppColors.chartNdvi, strokeWidth: 2, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(show: true, color: AppColors.chartNdvi.withValues(alpha: 0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              return LineTooltipItem('NDVI: ${spot.y.toStringAsFixed(2)}',
                  const TextStyle(color: AppColors.chartNdvi, fontWeight: FontWeight.w600));
            }).toList(),
          ),
        ),
      ),
    );
  }
}
