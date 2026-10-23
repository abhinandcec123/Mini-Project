class Hospital {
  final int id;
  final String name;
  final String registrationNumber;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final double? fallbackLatitude;
  final double? fallbackLongitude;
  final double? effectiveLatitude;
  final double? effectiveLongitude;
  final String? locationSource;
  final double? locationAccuracyKm;
  final bool isVerified;

  Hospital({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.latitude,
    this.longitude,
    this.fallbackLatitude,
    this.fallbackLongitude,
    this.effectiveLatitude,
    this.effectiveLongitude,
    this.locationSource,
    this.locationAccuracyKm,
    required this.isVerified,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final fallbackLat = (json['fallback_latitude'] as num?)?.toDouble();
    final fallbackLng = (json['fallback_longitude'] as num?)?.toDouble();
    final effectiveLat = (json['effective_latitude'] as num?)?.toDouble() ?? latitude ?? fallbackLat;
    final effectiveLng = (json['effective_longitude'] as num?)?.toDouble() ?? longitude ?? fallbackLng;

    return Hospital(
      id: json['id'],
      name: json['name'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      address: json['address'],
      city: json['city'],
      latitude: latitude,
      longitude: longitude,
      fallbackLatitude: fallbackLat,
      fallbackLongitude: fallbackLng,
      effectiveLatitude: effectiveLat,
      effectiveLongitude: effectiveLng,
      locationSource: json['location_source'],
      locationAccuracyKm: (json['location_accuracy_km'] as num?)?.toDouble(),
      isVerified: json['is_verified'] ?? false,
    );
  }
}
