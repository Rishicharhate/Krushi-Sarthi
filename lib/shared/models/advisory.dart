/// Advisory agent models (Phase 4) — mirror backend/app/schemas.py
/// AdvisoryAskOut / AdvisorySourceOut. Backed by the LangGraph agent in
/// backend/app/agent/.
class AdvisorySource {
  final String domain;
  final String summary;
  final String source;

  const AdvisorySource({required this.domain, required this.summary, required this.source});

  factory AdvisorySource.fromJson(Map<String, dynamic> json) {
    return AdvisorySource(
      domain: json['domain'] as String,
      summary: json['summary'] as String,
      source: json['source'] as String,
    );
  }
}

class AdvisoryAnswer {
  final String answer;
  final bool needsHuman;
  final String? safetyNote;
  final List<AdvisorySource> sources;

  const AdvisoryAnswer({
    required this.answer,
    required this.needsHuman,
    this.safetyNote,
    required this.sources,
  });

  factory AdvisoryAnswer.fromJson(Map<String, dynamic> json) {
    return AdvisoryAnswer(
      answer: json['answer'] as String,
      needsHuman: json['needs_human'] as bool? ?? false,
      safetyNote: json['safety_note'] as String?,
      sources: (json['sources'] as List<dynamic>? ?? [])
          .map((e) => AdvisorySource.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
