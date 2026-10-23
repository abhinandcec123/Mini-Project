import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/donor.dart';
import '../models/blood_request.dart';
import '../widgets/donor_card.dart';

/// AI donor ranking view (distance, reliability, eligibility, availability
/// weights) with a "Send Request to Donor" action per candidate.
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
  double _maxDistance = 50;
  final List<double> _weights = [35, 30, 20, 15];

  void _setWeight(int index, double value) {
    setState(() {
      final remaining = 100 - value;
      final otherIndices = List.generate(4, (i) => i).where((i) => i != index).toList();
      final otherTotal = otherIndices.fold<double>(0, (sum, i) => sum + _weights[i]);
      _weights[index] = value;
      for (final i in otherIndices) {
        _weights[i] = otherTotal == 0 ? remaining / 3 : _weights[i] / otherTotal * remaining;
      }
    });
  }

  double _score(Map<String, dynamic> candidate) {
    final donor = Donor.fromJson(candidate['donor']);
    final distance = (candidate['distance_km'] as num?)?.toDouble();
    final components = [
      donor.isAvailable ? 1.0 : 0.0,
      distance == null ? 0.5 : (1 - distance / _maxDistance).clamp(0.0, 1.0),
      donor.isEligibleNow ? 1.0 : 0.0,
      (donor.reliabilityScore / 100).clamp(0.0, 1.0),
    ];
    return List.generate(4, (i) => components[i] * _weights[i]).reduce((a, b) => a + b);
  }

  List<Map<String, dynamic>> get _rankedCandidates {
    return _candidates.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => _score(b).compareTo(_score(a)));
  }

  void _runIntakeDrill() {
    var handoffs = 0;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _IntakeDrillDialog(
            onAdvance: () => setDialogState(() => handoffs++),
            handoffs: handoffs,
          );
        },
      ),
    );
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
      setState(() => _candidates = result);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load donor recommendations.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dispatch(int donorId) async {
    try {
      final api = context.read<AuthProvider>().api;
      await api
          .post('/hospital/requests/${widget.request.id}/dispatch/$donorId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to donor.')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
                      _AlgorithmControls(
                        weights: _weights,
                        radiusKm: _maxDistance,
                        onWeightChanged: _setWeight,
                        onRadiusChanged: (value) => setState(() => _maxDistance = value),
                        onRadiusCommitted: (_) => _load(),
                        onRunDrill: _runIntakeDrill,
                      ),
                      const SizedBox(height: 16),
                      if (_rankedCandidates.isEmpty)
                        const _NoCandidates()
                      else ...[
                        _CandidateSpotlight(
                          candidate: _rankedCandidates.first,
                          score: _score(_rankedCandidates.first),
                          weights: _weights,
                          onDispatch: () => _dispatch(Donor.fromJson(_rankedCandidates.first['donor']).id),
                        ),
                        const SizedBox(height: 20),
                        const Text('FALLBACK QUEUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        for (var i = 1; i < _rankedCandidates.length; i++)
                          DonorRankCard(
                            donor: Donor.fromJson(_rankedCandidates[i]['donor']),
                            score: _score(_rankedCandidates[i]),
                            distanceKm: (_rankedCandidates[i]['distance_km'] as num?)?.toDouble(),
                            alreadyDispatched: _rankedCandidates[i]['already_dispatched'] == true,
                            onDispatch: () => _dispatch(Donor.fromJson(_rankedCandidates[i]['donor']).id),
                          ),
                      ],
                    ],
                  ),
                  ),
    );
  }
}

class _AlgorithmControls extends StatelessWidget {
  final List<double> weights;
  final double radiusKm;
  final void Function(int index, double value) onWeightChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<double> onRadiusCommitted;
  final VoidCallback onRunDrill;

  const _AlgorithmControls({required this.weights, required this.radiusKm, required this.onWeightChanged, required this.onRadiusChanged, required this.onRadiusCommitted, required this.onRunDrill});

  static const labels = ['Availability', 'Proximity', 'Eligibility', 'Reliability'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TRIAGE ALGORITHM INSPECTOR', style: TextStyle(color: Color(0xFF67E8F9), fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Score weights · ${weights.fold<double>(0, (a, b) => a + b).round()}% total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (var i = 0; i < labels.length; i++)
            Row(
              children: [
                SizedBox(width: 98, child: Text(labels[i], style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11))),
                Expanded(child: Slider(value: weights[i].clamp(0, 100), min: 0, max: 70, divisions: 70, onChanged: (value) => onWeightChanged(i, value))),
                SizedBox(width: 35, child: Text('${weights[i].round()}%', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
              ],
            ),
          const Divider(color: Color(0xFF334155), height: 18),
          Row(
            children: [
              Text('Radius ${radiusKm.round()} km', style: const TextStyle(color: Colors.white, fontSize: 11)),
              Expanded(child: Slider(value: radiusKm, min: 5, max: 50, divisions: 9, onChanged: onRadiusChanged, onChangeEnd: onRadiusCommitted)),
              const Icon(Icons.radar, color: Color(0xFF06B6D4), size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onRunDrill,
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text('Run Emergency Intake Drill'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF67E8F9), side: const BorderSide(color: Color(0xFF155E75))),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeDrillDialog extends StatelessWidget {
  final int handoffs;
  final VoidCallback onAdvance;

  const _IntakeDrillDialog({required this.handoffs, required this.onAdvance});

  static const donors = ['Candidate #1 · Maya Chen', 'Candidate #2 · Daniel Ortiz', 'Candidate #3 · Amira Khan', 'Candidate #4 · Luca Martin'];

  @override
  Widget build(BuildContext context) {
    final activeIndex = handoffs.clamp(0, donors.length - 1);
    return AlertDialog(
      title: const Row(children: [Icon(Icons.emergency, color: Color(0xFFE11D48)), SizedBox(width: 8), Text('Emergency intake drill')]),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SIMULATION · no donor notifications will be sent', style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (var i = 0; i < donors.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 15, backgroundColor: i < handoffs ? const Color(0xFFDCFCE7) : i == activeIndex ? const Color(0xFFFFE4E8) : const Color(0xFFF1F5F9), child: Text('${i + 1}', style: const TextStyle(fontSize: 10))),
                title: Text(donors[i], style: const TextStyle(fontSize: 12)),
                trailing: Text(i < handoffs ? 'DECLINED' : i == activeIndex ? 'CONTACTING' : 'QUEUED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: i < handoffs ? const Color(0xFFD97706) : i == activeIndex ? const Color(0xFFE11D48) : const Color(0xFF64748B))),
              ),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: handoffs / donors.length, minHeight: 7, color: const Color(0xFF06B6D4), backgroundColor: const Color(0xFFE2E8F0))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          onPressed: handoffs >= donors.length ? null : onAdvance,
          icon: const Icon(Icons.skip_next, size: 17),
          label: Text(handoffs >= donors.length ? 'Drill complete' : 'Simulate handoff'),
        ),
      ],
    );
  }
}

class _CandidateSpotlight extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final double score;
  final List<double> weights;
  final VoidCallback onDispatch;

  const _CandidateSpotlight({required this.candidate, required this.score, required this.weights, required this.onDispatch});

  @override
  Widget build(BuildContext context) {
    final donor = Donor.fromJson(candidate['donor']);
    final distance = (candidate['distance_km'] as num?)?.toDouble();
    final eta = distance == null ? null : (distance / 30 * 60 + 5).round();
    final values = [
      donor.isAvailable ? 1.0 : 0.0,
      distance == null ? 0.5 : (1 - distance / 50).clamp(0.0, 1.0),
      donor.isEligibleNow ? 1.0 : 0.0,
      (donor.reliabilityScore / 100).clamp(0.0, 1.0),
    ];
    return Card(
      color: const Color(0xFFFFFBF5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFFCD34D))),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.workspace_premium, color: Color(0xFFD97706)),
              const SizedBox(width: 7),
              const Expanded(child: Text('CANDIDATE #1', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.w800))),
              Text('${score.toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF047857), fontSize: 24, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFFE11D48), child: Text(donor.bloodGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(donor.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const Text('Compatible blood group', style: TextStyle(color: Color(0xFF64748B), fontSize: 11))])),
              if (distance != null) Text('${distance.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            if (eta != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Approx. travel estimate: ~$eta min', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
            const SizedBox(height: 14),
            for (var i = 0; i < values.length; i++) ...[
              Row(children: [Expanded(child: Text('${_AlgorithmControls.labels[i]} · ${weights[i].round()}%', style: const TextStyle(fontSize: 10, color: Color(0xFF475569)))), Text('${(values[i] * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))]),
              const SizedBox(height: 4),
              ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: values[i], minHeight: 5, color: const Color(0xFF06B6D4), backgroundColor: const Color(0xFFE2E8F0))),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 5),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: candidate['already_dispatched'] == true ? null : onDispatch, icon: const Icon(Icons.send_outlined, size: 17), label: Text(candidate['already_dispatched'] == true ? 'Already dispatched' : 'Send Request'))),
          ],
        ),
      ),
    );
  }
}

class _NoCandidates extends StatelessWidget {
  const _NoCandidates();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 45),
        child: Column(children: [Icon(Icons.person_search_outlined, size: 38, color: Color(0xFF94A3B8)), SizedBox(height: 10), Text('No compatible donors found within this radius.')]),
      );
}
