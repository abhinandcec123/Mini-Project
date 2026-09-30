class Donor {
  final int id;
  final String fullName;
  final String bloodGroup;
  final int age;
  final String? gender;
  final String? city;
  final double? latitude;
  final double? longitude;
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
    required this.isAvailable,
    required this.reliabilityScore,
    required this.totalDonations,
    required this.isEligibleNow,
    this.lastDonationDate,
    this.phone,
    this.email,
  });

  factory Donor.fromJson(Map<String, dynamic> json) {
    return Donor(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      age: json['age'] ?? 0,
      gender: json['gender'],
      city: json['city'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
