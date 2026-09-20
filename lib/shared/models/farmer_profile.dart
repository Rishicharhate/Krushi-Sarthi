/// Farmer profile model.
class FarmerProfile {
  final String? id;
  final String name;
  final String mobile;
  final String? village;
  final String? district;
  final String? state;
  final String? avatarUrl;

  const FarmerProfile({
    this.id,
    required this.name,
    required this.mobile,
    this.village,
    this.district,
    this.state,
    this.avatarUrl,
  });

  factory FarmerProfile.fromJson(Map<String, dynamic> json) {
    return FarmerProfile(
      id: json['id'] as String?,
      name: json['name'] as String,
      mobile: json['mobile'] as String,
      village: json['village'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'village': village,
    'district': district,
    'state': state,
    'avatar_url': avatarUrl,
  };

  FarmerProfile copyWith({
    String? id,
    String? name,
    String? mobile,
    String? village,
    String? district,
    String? state,
    String? avatarUrl,
  }) {
    return FarmerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      village: village ?? this.village,
      district: district ?? this.district,
      state: state ?? this.state,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
