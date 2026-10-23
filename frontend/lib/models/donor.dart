class Donor {
  final int id;
  final String fullName;
  final String bloodGroup;
  final int age;
  final String? gender;
  final String? city;
  final double? latitude;
  final double? longitude;
  final double? fallbackLatitude;
  final double? fallbackLongitude;
  final double? effectiveLatitude;
  final double? effectiveLongitude;
  final String? locationSource;
  final double? locationAccuracyKm;
  final double? locationAccuracyMeters;
  final bool isAvailable;
  final double reliabilityScore;
  final int totalDonations;
  final bool isEligibleNow;
  final String? lastDonationDate;
  final String? phone;
  final String? email;

  Donor({
    required this.id,
    required this.fullName,
    required this.bloodGroup,
    required this.age,
    this.gender,
    this.city,
    this.latitude,
    this.longitude,
    this.fallbackLatitude,
    this.fallbackLongitude,
    this.effectiveLatitude,
    this.effectiveLongitude,
    this.locationSource,
    this.locationAccuracyKm,
    this.locationAccuracyMeters,
    required this.isAvailable,
    required this.reliabilityScore,
    required this.totalDonations,
    required this.isEligibleNow,
    this.lastDonationDate,
    this.phone,
    this.email,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final fallbackLat = (json['fallback_latitude'] as num?)?.toDouble();
    final fallbackLng = (json['fallback_longitude'] as num?)?.toDouble();
    final effectiveLat = (json['current_latitude'] as num?)?.toDouble();
    final effectiveLng = (json['current_longitude'] as num?)?.toDouble();

    return Donor(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      age: json['age'] ?? 0,
      gender: json['gender'],
      city: json['city'],
      latitude: latitude,
      longitude: longitude,
      fallbackLatitude: fallbackLat,
      fallbackLongitude: fallbackLng,
      effectiveLatitude: effectiveLat,
      effectiveLongitude: effectiveLng,
      locationSource: json['location_source'],
      locationAccuracyKm: (json['location_accuracy_km'] as num?)?.toDouble(),
      locationAccuracyMeters: (json['location_accuracy_m'] as num?)?.toDouble(),
      isAvailable: json['is_available'] ?? false,
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble() ?? 0,
      totalDonations: json['total_donations'] ?? 0,
      isEligibleNow: json['is_eligible_now'] ?? true,
      lastDonationDate: json['last_donation_date'],
      phone: json['phone'],
      email: json['email'],
    );
  }
}
