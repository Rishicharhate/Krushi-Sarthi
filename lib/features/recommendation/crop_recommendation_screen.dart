import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/recommendation.dart';

/// Crop recommendation form — POST /api/recommend/crop
/// (backend/app/ml/tabular/crop_rec.pkl, trained on the standard 2200-row
/// N/P/K + weather -> crop dataset; see docs/STATUS.md Phase 3).
class CropRecommendationScreen extends ConsumerStatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  ConsumerState<CropRecommendationScreen> createState() => _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends ConsumerState<CropRecommendationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _n = TextEditingController();
  final _p = TextEditingController();
  final _k = TextEditingController();
  final _temperature = TextEditingController();
  final _humidity = TextEditingController();
  final _ph = TextEditingController();
  final _rainfall = TextEditingController();

  bool _loading = false;
  String? _error;
  CropRecommendation? _result;

  @override
  void dispose() {
    for (final c in [_n, _p, _k, _temperature, _humidity, _ph, _rainfall]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final repo = ref.read(recommendationRepositoryProvider);
      final result = await repo.recommendCrop(
        nitrogen: double.parse(_n.text.trim()),
        phosphorous: double.parse(_p.text.trim()),
        potassium: double.parse(_k.text.trim()),
        temperature: double.parse(_temperature.text.trim()),
        humidity: double.parse(_humidity.text.trim()),
        ph: double.parse(_ph.text.trim()),
        rainfall: double.parse(_rainfall.text.trim()),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not get a recommendation. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crop Recommendation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _NumberField(controller: _n, label: 'Nitrogen (N)', hint: '0-140 kg/ha')),
                  const SizedBox(width: 12),
                  Expanded(child: _NumberField(controller: _p, label: 'Phosphorous (P)', hint: '5-145 kg/ha')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _NumberField(controller: _k, label: 'Potassium (K)', hint: '5-205 kg/ha')),
                  const SizedBox(width: 12),
                  Expanded(child: _NumberField(controller: _ph, label: 'Soil pH', hint: '3.5-10')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _NumberField(controller: _temperature, label: 'Temperature (°C)', hint: '8-44')),
                  const SizedBox(width: 12),
                  Expanded(child: _NumberField(controller: _humidity, label: 'Humidity (%)', hint: '14-100')),
                ]),
                const SizedBox(height: 12),
                _NumberField(controller: _rainfall, label: 'Rainfall (mm)', hint: '20-300'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.eco_rounded),
            label: Text(_loading ? 'Analyzing...' : 'Get Recommendation'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _NumberField({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        if (double.tryParse(value.trim()) == null) return 'Enter a number';
        return null;
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  final CropRecommendation result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.statusHealthyBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.eco_rounded, color: AppColors.primaryGreen, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Recommended: ${result.crop}',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Confidence: ${result.confidence.toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (result.alternatives.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Other possibilities', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              ...result.alternatives.map(
                (alt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${alt.label} — ${alt.confidence.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
