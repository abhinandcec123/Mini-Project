class BloodRequest {
  final int id;
  final int hospitalId;
  final String? hospitalName;
  final String? hospitalCity;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  final String priority;
  final String? notes;
  final String status;
  final String createdAt;

  BloodRequest({
    required this.id,
    required this.hospitalId,
    this.hospitalName,
    this.hospitalCity,
    required this.patientName,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.priority,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    return BloodRequest(
      id: json['id'],
      hospitalId: json['hospital_id'],
      hospitalName: json['hospital_name'],
      hospitalCity: json['hospital_city'],
      patientName: json['patient_name'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      unitsNeeded: json['units_needed'] ?? 1,
      priority: json['priority'] ?? 'normal',
      notes: json['notes'],
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class RequestMatch {
  final int id;
  final BloodRequest? request;
  final int donorId;
  final String? donorName;
  final double? matchScore;
  final double? distanceKm;
  final String status;
  final String dispatchedAt;
  final String? respondedAt;

  RequestMatch({
    required this.id,
    this.request,
    required this.donorId,
    this.donorName,
    this.matchScore,
    this.distanceKm,
    required this.status,
    required this.dispatchedAt,
    this.respondedAt,
  });

  factory RequestMatch.fromJson(Map<String, dynamic> json) {
    return RequestMatch(
      id: json['id'],
      request: json['request'] != null ? BloodRequest.fromJson(json['request']) : null,
      donorId: json['donor_id'],
      donorName: json['donor_name'],
      matchScore: (json['match_score'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      status: json['status'] ?? 'pending',
      dispatchedAt: json['dispatched_at'] ?? '',
      respondedAt: json['responded_at'],
    );
  }
}
