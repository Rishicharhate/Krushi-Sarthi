import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/recommendation.dart';

/// These are the exact categories backend/app/ml/tabular/fertilizer_rec.pkl
/// was trained on (see backend/notebooks/data/fertilizer_prediction.csv) —
/// deliberately not AppConstants.soilTypes, which is a different, broader
/// taxonomy used for Farm.soilType and doesn't match this model's vocabulary.
const _kSoilTypes = ['Black', 'Clayey', 'Loamy', 'Red', 'Sandy'];
const _kCropTypes = [
  'Barley', 'Cotton', 'Ground Nuts', 'Maize', 'Millets',
  'Oil seeds', 'Paddy', 'Pulses', 'Sugarcane', 'Tobacco', 'Wheat',
];

/// Fertilizer recommendation form — POST /api/recommend/fertilizer
/// (backend/app/ml/tabular/fertilizer_rec.pkl; see docs/STATUS.md Phase 3).
class FertilizerRecommendationScreen extends ConsumerStatefulWidget {
  const FertilizerRecommendationScreen({super.key});

  @override
  ConsumerState<FertilizerRecommendationScreen> createState() =>
      _FertilizerRecommendationScreenState();
}

class _FertilizerRecommendationScreenState extends ConsumerState<FertilizerRecommendationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _temperature = TextEditingController();
  final _humidity = TextEditingController();
  final _moisture = TextEditingController();
  final _nitrogen = TextEditingController();
  final _potassium = TextEditingController();
  final _phosphorous = TextEditingController();
  String _soilType = _kSoilTypes.first;
  String _cropType = _kCropTypes.first;

  bool _loading = false;
  String? _error;
  FertilizerRecommendation? _result;

  @override
  void dispose() {
    for (final c in [_temperature, _humidity, _moisture, _nitrogen, _potassium, _phosphorous]) {
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
      final result = await repo.recommendFertilizer(
        temperature: double.parse(_temperature.text.trim()),
        humidity: double.parse(_humidity.text.trim()),
        moisture: double.parse(_moisture.text.trim()),
        nitrogen: double.parse(_nitrogen.text.trim()),
        potassium: double.parse(_potassium.text.trim()),
        phosphorous: double.parse(_phosphorous.text.trim()),
        soilType: _soilType,
        cropType: _cropType,
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
      appBar: AppBar(title: const Text('Fertilizer Recommendation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: DropdownButtonFormField<String>(
                    initialValue: _soilType,
                    decoration: const InputDecoration(labelText: 'Soil Type'),
                    items: _kSoilTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _soilType = v!),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: DropdownButtonFormField<String>(
                    initialValue: _cropType,
                    decoration: const InputDecoration(labelText: 'Crop Type'),
                    items: _kCropTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _cropType = v!),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _NumberField(controller: _temperature, label: 'Temperature (°C)', hint: '20-40')),
                  const SizedBox(width: 12),
                  Expanded(child: _NumberField(controller: _humidity, label: 'Humidity (%)', hint: '50-70')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _NumberField(controller: _moisture, label: 'Moisture (%)', hint: '25-65')),
                  Expanded(child: _NumberField(controller: _nitrogen, label: 'Nitrogen (N)', hint: '0-40')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _NumberField(controller: _potassium, label: 'Potassium (K)', hint: '0-20')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _NumberField(controller: _phosphorous, label: 'Phosphorous (P)', hint: '0-45')),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.science_rounded),
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
  final FertilizerRecommendation result;
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
                const Icon(Icons.science_rounded, color: AppColors.earthBrown, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Recommended: ${result.fertilizer}',
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
