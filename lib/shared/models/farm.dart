/// Farm data model.
class Farm {
  final String id;
  final String name;
  final String? location;
  final double area;
  final String? areaUnit;
  final String crop;
  final DateTime? sowingDate;
  final String? soilType;
  final bool isActive;

  const Farm({
    required this.id,
    required this.name,
    this.location,
    required this.area,
    this.areaUnit = 'Acres',
    required this.crop,
    this.sowingDate,
    this.soilType,
    this.isActive = false,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      area: (json['area'] as num).toDouble(),
      areaUnit: json['area_unit'] as String? ?? 'Acres',
      crop: json['crop'] as String,
      sowingDate: json['sowing_date'] != null
          ? DateTime.parse(json['sowing_date'] as String)
          : null,
      soilType: json['soil_type'] as String?,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'area': area,
    'area_unit': areaUnit,
    'crop': crop,
    'sowing_date': sowingDate?.toIso8601String(),
    'soil_type': soilType,
    'is_active': isActive,
  };

  Farm copyWith({
    String? id,
    String? name,
    String? location,
    double? area,
    String? areaUnit,
    String? crop,
    DateTime? sowingDate,
    String? soilType,
    bool? isActive,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      area: area ?? this.area,
      areaUnit: areaUnit ?? this.areaUnit,
      crop: crop ?? this.crop,
      sowingDate: sowingDate ?? this.sowingDate,
      soilType: soilType ?? this.soilType,
      isActive: isActive ?? this.isActive,
    );
  }
}
