import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/disease_result.dart';

/// Disease result screen showing AI analysis output.
class DiseaseResultScreen extends ConsumerWidget {
  const DiseaseResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(diseaseDetectionProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis Result')),
        body: const Center(child: Text('No result available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Analysis Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Result Header ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: result.isHealthy
                          ? AppColors.statusHealthyBg
                          : AppColors.statusCriticalBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 40,
                      color: result.isHealthy ? AppColors.statusHealthy : AppColors.statusCritical,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (result.crop != null)
                    Text('Crop: ${result.crop}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    result.disease,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _certaintyColor(result).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _certaintyLabel(result),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _certaintyColor(result),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Model score: ${result.confidence.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (result.caution != null) ...[
            Card(
              color: AppColors.statusAttentionBg,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_rounded, color: AppColors.statusAttention),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(result.caution!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Disease Information ──
          if (result.description != null) ...[
            _Section(
              title: 'Disease Information',
              icon: Icons.info_outline_rounded,
              child: Text(result.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
          ],

          if (result.symptoms != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Symptoms',
              icon: Icons.local_hospital_rounded,
              child: Text(result.symptoms!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
          ],

          if (result.recommendation != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Recommendation',
              icon: Icons.lightbulb_outline_rounded,
              child: Text(result.recommendation!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
          ],

          if (result.alternatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Other Possibilities',
              icon: Icons.compare_arrows_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final alt in result.alternatives) ...[
                    Text(
                      '${alt.disease} (${alt.confidence.toStringAsFixed(0)}%)',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (alt.symptoms != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: Text(alt.symptoms!, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],

          if (result.feedbackEnabled && result.scanId != null) ...[
            const SizedBox(height: 12),
            _FeedbackCard(key: ValueKey(result.scanId), scanId: result.scanId!),
          ],

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () {
              ref.read(diseaseDetectionProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Analyze Another Image'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Uses the backend's certainty tier (see backend/app/ml/disease/cascade.py),
  /// which also checks the gap to the runner-up, not just the top score.
  String _certaintyLabel(DiseaseResult result) {
    switch (_tier(result)) {
      case 'high':
        return 'High confidence';
      case 'medium':
        return 'Likely match';
      default:
        return 'Low confidence';
    }
  }

  Color _certaintyColor(DiseaseResult result) {
    switch (_tier(result)) {
      case 'high':
        return AppColors.statusHealthy;
      case 'medium':
        return AppColors.statusAttention;
      default:
        return AppColors.statusCritical;
    }
  }

  // History rows and mock data carry no tier; fall back to the backend's
  // calibrated thresholds (70% = high, 50% = medium).
  String _tier(DiseaseResult result) {
    if (result.certainty != null) return result.certainty!;
    if (result.confidence >= 70) return 'high';
    if (result.confidence >= 50) return 'medium';
    return 'low';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Testing builds only (backend FEEDBACK_MODE): "was this right?" -> if not,
/// the tester types/picks the real disease. Answers feed
/// backend/app/ml/disease/retrain.py; farmers never see this card because
/// the production server never sets feedback_enabled.
class _FeedbackCard extends ConsumerStatefulWidget {
  final String scanId;
  const _FeedbackCard({super.key, required this.scanId});

  @override
  ConsumerState<_FeedbackCard> createState() => _FeedbackCardState();
}

enum _FeedbackStep { ask, correct, sending, done }

class _FeedbackCardState extends ConsumerState<_FeedbackCard> {
  _FeedbackStep _step = _FeedbackStep.ask;
  DiseaseLabel? _picked;
  bool _notInList = false;
  final _note = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send({required bool isCorrect}) async {
    setState(() => _step = _FeedbackStep.sending);
    try {
      final count = await submitDiseaseFeedback(
        ref,
        scanId: widget.scanId,
        isCorrect: isCorrect,
        trueLabel: isCorrect || _notInList ? null : _picked?.label,
        note: _notInList ? _note.text.trim() : null,
      );
      setState(() {
        _step = _FeedbackStep.done;
        _message = 'Saved. $count labelled photo${count == 1 ? '' : 's'} ready for retraining.';
      });
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() {
        _step = isCorrect ? _FeedbackStep.ask : _FeedbackStep.correct;
        _message = data is Map && data['detail'] != null ? data['detail'].toString() : 'Could not save feedback.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.statusAttention),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_rounded, size: 20, color: AppColors.statusAttention),
                const SizedBox(width: 8),
                Text('Testing mode — model feedback',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ..._body(theme),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    switch (_step) {
      case _FeedbackStep.ask:
        return [
          Text('Was this diagnosis correct?', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _send(isCorrect: true),
                  icon: const Icon(Icons.thumb_up_rounded),
                  label: const Text('Yes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _step = _FeedbackStep.correct;
                    _message = null;
                  }),
                  icon: const Icon(Icons.thumb_down_rounded),
                  label: const Text('No'),
                ),
              ),
            ],
          ),
        ];
      case _FeedbackStep.correct:
        final labels = ref.watch(diseaseLabelsProvider);
        return [
          Text('What was it? Start typing the disease or crop.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          if (!_notInList)
            labels.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load the disease list.'),
              data: (all) => Autocomplete<DiseaseLabel>(
                displayStringForOption: (l) => l.displayName,
                optionsBuilder: (value) {
                  final q = value.text.toLowerCase();
                  return all.where((l) =>
                      l.displayName.toLowerCase().contains(q) || (l.crop ?? '').toLowerCase().contains(q));
                },
                onSelected: (l) => setState(() => _picked = l),
                fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(hintText: 'e.g. spider mites', isDense: true),
                  onChanged: (_) => setState(() => _picked = null),
                ),
              ),
            ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _notInList,
            onChanged: (v) => setState(() => _notInList = v ?? false),
            title: const Text("It's not in the list"),
          ),
          if (_notInList)
            TextField(
              controller: _note,
              decoration: const InputDecoration(hintText: 'Describe what it was', isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: (_notInList ? _note.text.trim().isNotEmpty : _picked != null)
                ? () => _send(isCorrect: false)
                : null,
            child: const Text('Submit correction'),
          ),
        ];
      case _FeedbackStep.sending:
        return [const LinearProgressIndicator()];
      case _FeedbackStep.done:
        return [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.statusHealthy),
              const SizedBox(width: 8),
              Text('Thanks — feedback recorded.', style: theme.textTheme.bodyMedium),
            ],
          ),
        ];
    }
  }
}
