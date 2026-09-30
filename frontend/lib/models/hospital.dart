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
    required this.isVerified,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'],
      name: json['name'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      address: json['address'],
      city: json['city'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isVerified: json['is_verified'] ?? false,
    );
  }
}
