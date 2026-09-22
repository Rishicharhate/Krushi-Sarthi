import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/advisory.dart';

/// Ask-a-question chat for the LangGraph farm advisory agent (Phase 4).
/// POST /api/advisory/ask — see backend/app/agent/.
class AdvisoryChatScreen extends ConsumerStatefulWidget {
  const AdvisoryChatScreen({super.key});

  @override
  ConsumerState<AdvisoryChatScreen> createState() => _AdvisoryChatScreenState();
}

class _AdvisoryChatScreenState extends ConsumerState<AdvisoryChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _suggestions = [
    'Should I irrigate this week?',
    'How is my crop doing?',
    'Is my soil healthy right now?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final question = text ?? _controller.text;
    if (question.trim().isEmpty) return;
    _controller.clear();
    ref.read(advisoryChatProvider.notifier).ask(question);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(advisoryChatProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ask KrushiSarthi')),
      body: Column(
        children: [
          Expanded(
            child: state.turns.isEmpty
                ? _EmptyState(onSuggestionTap: _send, suggestions: _suggestions)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.turns.length,
                    itemBuilder: (context, index) => _TurnCard(turn: state.turns[index]),
                  ),
          ),
          if (state.sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'e.g. Should I irrigate this week?',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: state.sending ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onSuggestionTap;
  const _EmptyState({required this.suggestions, required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_rounded, size: 56, color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'Ask about your farm — irrigation, soil, or crop health.\n'
              'Answers are based on your farm\'s real weather and soil data.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions
                  .map((s) => ActionChip(label: Text(s), onPressed: () => onSuggestionTap(s)))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnCard extends StatelessWidget {
  final AdvisoryTurn turn;
  const _TurnCard({required this.turn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Question bubble ──
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(turn.question, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 8),
          // ── Answer / error / loading ──
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
              child: turn.error != null
                  ? _AnswerCard(
                      child: Text(turn.error!, style: TextStyle(color: theme.colorScheme.error)),
                    )
                  : turn.answer == null
                      ? const _AnswerCard(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _AnswerContent(answer: turn.answer!),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerContent extends StatelessWidget {
  final AdvisoryAnswer answer;
  const _AnswerContent({required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnswerCard(child: Text(answer.answer, style: theme.textTheme.bodyMedium)),
        if (answer.needsHuman && answer.safetyNote != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusAttentionBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.statusAttention, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(answer.safetyNote!,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.statusAttention)),
                ),
              ],
            ),
          ),
        ],
        if (answer.sources.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Sources (${answer.sources.length})', style: theme.textTheme.labelMedium),
            children: answer.sources
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${s.summary} — ${s.source}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final Widget child;
  const _AnswerCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}
