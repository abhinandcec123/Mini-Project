import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/donor.dart';
import '../models/blood_request.dart';
import '../widgets/donor_card.dart';
import '../utils/location_format.dart';

/// AI donor ranking view with an automatically advancing ranked queue.
class AiRecommendationScreen extends StatefulWidget {
  final BloodRequest request;
  const AiRecommendationScreen({super.key, required this.request});

  @override
  State<AiRecommendationScreen> createState() => _AiRecommendationScreenState();
}

class _AiRecommendationScreenState extends State<AiRecommendationScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _candidates = [];
  Map<String, dynamic>? _hospitalProfile;
  double _maxDistance = 50;
  final List<double> _weights = [35, 30, 20, 15];

  void _setWeight(int index, double value) {
    setState(() {
      final remaining = 100 - value;
      final otherIndices =
          List.generate(4, (i) => i).where((i) => i != index).toList();
      final otherTotal =
          otherIndices.fold<double>(0, (sum, i) => sum + _weights[i]);
      _weights[index] = value;
      for (final i in otherIndices) {
        _weights[i] = otherTotal == 0
            ? remaining / 3
            : _weights[i] / otherTotal * remaining;
      }
    });
  }

  double _score(Map<String, dynamic> candidate) {
    final rankedScore = (candidate['score'] as num?)?.toDouble();
    if (rankedScore != null) return rankedScore;
    final donor = Donor.fromJson(candidate['donor']);
    final distance = (candidate['distance_km'] as num?)?.toDouble();
    final components = [
      donor.isAvailable ? 1.0 : 0.0,
      distance == null ? 0.5 : (1 - distance / _maxDistance).clamp(0.0, 1.0),
      donor.isEligibleNow ? 1.0 : 0.0,
      (donor.reliabilityScore / 100).clamp(0.0, 1.0),
    ];
    return List.generate(4, (i) => components[i] * _weights[i])
        .reduce((a, b) => a + b);
  }

  List<Map<String, dynamic>> get _rankedCandidates {
    final candidates = _candidates.cast<Map<String, dynamic>>().toList();
    int pendingFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aPending = a['match_status'] == 'pending';
      final bPending = b['match_status'] == 'pending';
      if (aPending != bPending) return aPending ? -1 : 1;
      return 0;
    }
    candidates.sort((a, b) {
      final byQueue = pendingFirst(a, b);
      if (byQueue != 0) return byQueue;
      if (widget.request.priority == 'critical') {
        final aDistance = (a['distance_km'] as num?)?.toDouble();
        final bDistance = (b['distance_km'] as num?)?.toDouble();
        if (aDistance == null && bDistance == null) {
          return _score(b).compareTo(_score(a));
        }
        if (aDistance == null) return 1;
        if (bDistance == null) return -1;
        final byDistance = aDistance.compareTo(bDistance);
        return byDistance != 0 ? byDistance : _score(b).compareTo(_score(a));
      }
      return _score(b).compareTo(_score(a));
    });
    return candidates;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final result = await api.get(
        '/hospital/requests/${widget.request.id}/candidates',
        query: {'max_distance_km': _maxDistance},
      );
      final hospitalProfile = await api.get('/hospital/me');
      setState(() {
        _candidates = result;
        _hospitalProfile = hospitalProfile;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load donor recommendations.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Matches — ${widget.request.patientName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      _AlgorithmSummary(
                        priority: widget.request.priority,
                        radiusKm: _maxDistance,
                      ),
                      const SizedBox(height: 16),
                      if (_rankedCandidates.isEmpty)
                        const _NoCandidates()
                      else ...[
                        _CandidateGeoMap(
                          candidates: _rankedCandidates.take(6).toList(),
                          hospitalProfile: _hospitalProfile,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ranked dispatch contacts one donor at a time. If they decline or do not respond, the next donor is contacted automatically.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 18),
                        _CandidateSpotlight(
                          candidate: _rankedCandidates.first,
                          score: _score(_rankedCandidates.first),
                          weights: _weights,
                          priority: widget.request.priority,
                        ),
                        const SizedBox(height: 20),
                        const Text('RANKED QUEUE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        for (var i = 1; i < _rankedCandidates.length; i++)
                          DonorRankCard(
                            donor:
                                Donor.fromJson(_rankedCandidates[i]['donor']),
                            score: _score(_rankedCandidates[i]),
                            distanceKm:
                                (_rankedCandidates[i]['distance_km'] as num?)
                                    ?.toDouble(),
                            matchStatus: _rankedCandidates[i]['match_status']?.toString(),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _AlgorithmSummary extends StatelessWidget {
  final String priority;
  final double radiusKm;

  const _AlgorithmSummary({required this.priority, required this.radiusKm});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          priority == 'critical'
              ? 'CRITICAL TRIAGE · Nearest eligible donors are contacted first; distance takes priority.'
              : 'RANKED MATCHING · Availability 35% · Distance 30% · Eligibility 20% · Reliability 15% · ${radiusKm.round()} km radius',
          style: const TextStyle(
            color: Color(0xFFBAF6FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _AlgorithmControls extends StatelessWidget {
  final List<double> weights;
  final double radiusKm;
  final void Function(int index, double value) onWeightChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<double> onRadiusCommitted;

  const _AlgorithmControls(
      {required this.weights,
      required this.radiusKm,
      required this.onWeightChanged,
      required this.onRadiusChanged,
      required this.onRadiusCommitted});

  static const labels = [
    'Availability',
    'Proximity',
    'Eligibility',
    'Reliability'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TRIAGE ALGORITHM INSPECTOR',
              style: TextStyle(
                  color: Color(0xFF67E8F9),
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              'Score weights · ${weights.fold<double>(0, (a, b) => a + b).round()}% total',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (var i = 0; i < labels.length; i++)
            Row(
              children: [
                SizedBox(
                    width: 98,
                    child: Text(labels[i],
                        style: const TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 11))),
                Expanded(
                    child: Slider(
                        value: weights[i].clamp(0, 100),
                        min: 0,
                        max: 70,
                        divisions: 70,
                        onChanged: (value) => onWeightChanged(i, value))),
                SizedBox(
                    width: 35,
                    child: Text('${weights[i].round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))),
              ],
            ),
          const Divider(color: Color(0xFF334155), height: 18),
          Row(
            children: [
              Text('Radius ${radiusKm.round()} km',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              Expanded(
                  child: Slider(
                      value: radiusKm,
                      min: 5,
                      max: 50,
                      divisions: 9,
                      onChanged: onRadiusChanged,
                      onChangeEnd: onRadiusCommitted)),
              const Icon(Icons.radar, color: Color(0xFF06B6D4), size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateGeoMap extends StatelessWidget {
  final List<Map<String, dynamic>> candidates;
  final Map<String, dynamic>? hospitalProfile;

  const _CandidateGeoMap({
    required this.candidates,
    required this.hospitalProfile,
  });

  @override
  Widget build(BuildContext context) {
    final donorPoints = <(int, LatLng)>[];
    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      final donor = Donor.fromJson(candidate['donor']);
      var latitude = donor.latitude;
      var longitude = donor.longitude;
      if (latitude == null || longitude == null) {
        latitude = donor.effectiveLatitude;
        longitude = donor.effectiveLongitude;
      }
      if (latitude != null && longitude != null) {
        donorPoints.add((i, LatLng(latitude, longitude)));
      }
    }

    final hospitalLatitude = (hospitalProfile?['latitude'] as num?)?.toDouble();
    final hospitalLongitude =
        (hospitalProfile?['longitude'] as num?)?.toDouble();
    final hospitalPoint = hospitalLatitude != null &&
            hospitalLongitude != null
        ? LatLng(hospitalLatitude, hospitalLongitude)
        : null;
    final points = [
      ...donorPoints.map((donor) => donor.$2),
      if (hospitalPoint != null) hospitalPoint,
    ];

    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            hospitalPoint == null
                ? 'Add a hospital location and donor registered-area coordinates to show them on the map.'
                : 'No matched donors have registered-area coordinates yet.',
            style: const TextStyle(color: Color(0xFF475569)),
          ),
        ),
      );
    }

    final avgLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final avgLng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Registered-area pins · Red: hospital · Teal: top candidate · Amber: other candidates',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
        Container(
          height: 260,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(avgLat, avgLng),
              initialZoom: 9,
              initialCameraFit: points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(36),
                    )
                  : null,
              minZoom: 3,
              maxZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.lifepulse_ai',
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < donorPoints.length; i++)
                    Marker(
                      point: donorPoints[i].$2,
                      width: 28,
                      height: 28,
                      child: Tooltip(
                        message: () {
                          final donor = Donor.fromJson(
                            candidates[donorPoints[i].$1]['donor'],
                          );
                          return donor.city == null || donor.city!.isEmpty
                              ? donor.fullName
                              : '${donor.fullName} · ${donor.city}';
                        }(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: donorPoints[i].$1 == 0
                                ? const Color(0xFF0891B2)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x33000000), blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.location_on,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  if (hospitalPoint != null)
                    Marker(
                      point: hospitalPoint,
                      width: 40,
                      height: 40,
                      child: const Tooltip(
                        message: 'Hospital',
                        child: Icon(
                          Icons.local_hospital,
                          color: Color(0xFFDC2626),
                          size: 36,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CandidateSpotlight extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final double score;
  final List<double> weights;
  final String priority;

  const _CandidateSpotlight(
      {required this.candidate,
      required this.score,
      required this.weights,
      required this.priority});

  @override
  Widget build(BuildContext context) {
    final donor = Donor.fromJson(candidate['donor']);
    final distance = (candidate['distance_km'] as num?)?.toDouble();
    final values = [
      donor.isAvailable ? 1.0 : 0.0,
      distance == null
          ? 0.5
          : priority == 'critical'
              ? math.exp(-distance / 100)
              : (1 - distance / 50).clamp(0.0, 1.0),
      donor.isEligibleNow ? 1.0 : 0.0,
      (donor.reliabilityScore / 100).clamp(0.0, 1.0),
    ];
    return Card(
      color: const Color(0xFFFFFBF5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFCD34D))),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFD97706)),
              const SizedBox(width: 7),
              const Expanded(
                  child: Text('CANDIDATE #1',
                      style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 11,
                          fontWeight: FontWeight.w800))),
              Text('${score.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(
                  backgroundColor: const Color(0xFFE11D48),
                  child: Text(donor.bloodGroup,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(donor.fullName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const Text('Compatible blood group',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 11))
                  ])),
              if (distance != null)
                Text(formatDistanceKm(distance),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              Row(children: [
                Expanded(
                    child: Text(
                        '${_AlgorithmControls.labels[i]} · ${weights[i].round()}%',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF475569)))),
                Text('${(values[i] * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700))
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                      value: values[i],
                      minHeight: 5,
                      color: const Color(0xFF06B6D4),
                      backgroundColor: const Color(0xFFE2E8F0))),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.autorenew, size: 17),
                label: Text(_queueStatus(candidate['match_status']?.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _queueStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'Request sent — waiting for response';
      case 'accepted':
        return 'Accepted — preparing next donor if needed';
      case 'declined':
        return 'Declined — next donor is being contacted';
      case 'completed':
        return 'Donation completed';
      default:
        return 'First donor in the ranked dispatch queue';
    }
  }
}

class _NoCandidates extends StatelessWidget {
  const _NoCandidates();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 45),
        child: Column(children: [
          Icon(Icons.person_search_outlined,
              size: 38, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text('No compatible donors found within this radius.')
        ]),
      );
}
