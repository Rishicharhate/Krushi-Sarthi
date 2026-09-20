/// Government agriculture scheme model.
class GovernmentScheme {
  final String id;
  final String name;
  final String description;
  final String eligibility;
  final String benefits;
  final List<String> documents;
  final String? applicationUrl;
  final String? applicationProcess;
  final String category;
  final String? state;
  final DateTime updatedAt;

  const GovernmentScheme({
    required this.id,
    required this.name,
    required this.description,
    required this.eligibility,
    required this.benefits,
    required this.documents,
    this.applicationUrl,
    this.applicationProcess,
    this.category = 'General',
    this.state,
    required this.updatedAt,
  });

  factory GovernmentScheme.fromJson(Map<String, dynamic> json) {
    return GovernmentScheme(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      eligibility: json['eligibility'] as String,
      benefits: json['benefits'] as String,
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      applicationUrl: json['application_url'] as String?,
      applicationProcess: json['application_process'] as String?,
      category: json['category'] as String? ?? 'General',
      state: json['state'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'eligibility': eligibility,
    'benefits': benefits,
    'documents': documents,
    'application_url': applicationUrl,
    'application_process': applicationProcess,
    'category': category,
    'state': state,
    'updated_at': updatedAt.toIso8601String(),
  };
}
