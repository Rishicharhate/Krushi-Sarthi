import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../shared/models/market_price.dart';

/// Mandi (APMC) prices from Agmarknet — GET /api/market/prices.
/// Defaults to the active farm's crop; the search box looks up any commodity.
class MarketPricesScreen extends ConsumerStatefulWidget {
  const MarketPricesScreen({super.key});

  @override
  ConsumerState<MarketPricesScreen> createState() => _MarketPricesScreenState();
}

class _MarketPricesScreenState extends ConsumerState<MarketPricesScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(marketCommodityProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pricesAsync = ref.watch(marketPricesProvider);
    final activeFarm = ref.watch(activeFarmProvider);
    final commodity = ref.watch(marketCommodityProvider).trim();
    final showing = commodity.isNotEmpty ? commodity : (activeFarm?.crop ?? 'your crop');

    return Scaffold(
      appBar: AppBar(title: const Text('Mandi Prices')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(marketCommodityProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search a commodity (e.g. Onion, Wheat)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: commodity.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          ref.read(marketCommodityProvider.notifier).state = '';
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing latest reported prices for $showing',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: AsyncValueWidget(
              value: pricesAsync,
              onRetry: () => ref.invalidate(marketPricesProvider),
              isEmpty: (data) => data.isEmpty,
              emptyMessage:
                  'No mandi prices reported for $showing today.\nTry another commodity, or check back tomorrow.',
              data: (prices) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: prices.length + 1,
                itemBuilder: (context, index) {
                  if (index == prices.length) return const _SourceNote();
                  return _PriceCard(price: prices[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final MarketPrice price;
  const _PriceCard({required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(price.location.isEmpty ? 'Unknown market' : price.location,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        [price.state, price.arrivalDate]
                            .where((p) => p != null && p.isNotEmpty)
                            .join(' • '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (price.modalPrice != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '₹${price.modalPrice!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (price.minPrice != null && price.maxPrice != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _Range(label: 'Min', value: price.minPrice!),
                  const SizedBox(width: 20),
                  _Range(label: 'Max', value: price.maxPrice!),
                  const Spacer(),
                  Text('per quintal',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Range extends StatelessWidget {
  final String label;
  final double value;
  const _Range({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text('$label ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text('₹${value.toStringAsFixed(0)}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SourceNote extends StatelessWidget {
  const _SourceNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      child: Text(
        'Source: Agmarknet daily mandi prices (data.gov.in). Mandis shown are from '
        'across India and are not filtered to your state — check travel distance '
        'before acting on a high price elsewhere.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
