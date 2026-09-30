import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/blood_request.dart';
import 'ai_recommendation_screen.dart';

class RequestDetailScreen extends StatefulWidget {
  final BloodRequest request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _loading = true;
  List<RequestMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final result = await api.get('/hospital/requests/${widget.request.id}/matches');
      setState(() => _matches = (result as List).map((e) => RequestMatch.fromJson(e)).toList());
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String action) async {
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/hospital/requests/${widget.request.id}/$action');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Scaffold(
      appBar: AppBar(title: Text(req.patientName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AiRecommendationScreen(request: req)),
          );
          _load();
        },
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Find Donors'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${req.bloodGroup} • ${req.unitsNeeded} unit(s) • ${req.priority.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (req.notes != null && req.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(req.notes!),
                    ],
                    const SizedBox(height: 8),
                    Text('Status: ${req.status}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (req.status == 'open')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus('cancel'),
                      child: const Text('Cancel Request'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _updateStatus('fulfill'),
                      child: const Text('Mark Fulfilled'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Dispatched to (${_matches.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_matches.isEmpty)
              const Text('No donors contacted yet. Tap "Find Donors" to see AI-ranked matches.')
            else
              ..._matches.map((m) => Card(
                    child: ListTile(
                      title: Text('Donor #${m.donorId}'),
                      subtitle: Text(
                        '${m.status.toUpperCase()}'
                        '${m.distanceKm != null ? ' • ${m.distanceKm!.toStringAsFixed(1)} km' : ''}'
                        '${m.matchScore != null ? ' • score ${m.matchScore!.toStringAsFixed(0)}' : ''}',
                      ),
                    ),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
