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
  String? _actionError;
  String? _actionMessage;
  String _requestStatus = 'open';
  List<RequestMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _requestStatus = widget.request.status;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthProvider>().api;
      final result =
          await api.get('/hospital/requests/${widget.request.id}/matches');
      setState(() => _matches =
          (result as List).map((e) => RequestMatch.fromJson(e)).toList());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String action) async {
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/hospital/requests/${widget.request.id}/$action');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmDonation(RequestMatch match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve completed donation?'),
        content: const Text(
          'Confirm that this donor completed the donation. This updates the donor record and issues a certificate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Approve donation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _actionError = null;
      _actionMessage = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final result = await api.post(
        '/hospital/requests/${widget.request.id}/matches/${match.id}/confirm',
      );
      if (!mounted) return;
      setState(() {
        _requestStatus = result['request']['status'];
        _actionMessage = result['request']['status'] == 'fulfilled'
            ? 'Donation approved. All units are fulfilled and a certificate has been issued.'
            : 'One donation unit approved. ${result['approved_units']} of '
                '${result['units_needed']} units approved so far.';
      });
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError = 'Could not approve this donation. Please retry.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Scaffold(
      appBar: AppBar(title: Text(req.patientName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestStatus == 'open'
            ? () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AiRecommendationScreen(request: req),
                  ),
                );
                _load();
              }
            : null,
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
                    Text(
                        '${req.bloodGroup} • ${req.unitsNeeded} unit(s) • ${req.priority.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (req.notes != null && req.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(req.notes!),
                    ],
                    const SizedBox(height: 8),
                    Text('Status: $_requestStatus',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_requestStatus == 'open')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus('cancel'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Request'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Dispatched to (${_matches.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (_actionMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _actionMessage!,
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_actionError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _actionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_matches.isEmpty)
              const Text(
                  'No donors contacted yet. Tap "Find Donors" to see AI-ranked matches.')
            else
              ..._matches.map((m) => Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text('Donor #${m.donorId}'),
                          subtitle: Text(
                            '${m.status.toUpperCase()}'
                            '${m.distanceKm != null ? ' • ${m.distanceKm!.toStringAsFixed(1)} km' : ''}'
                            '${m.matchScore != null ? ' • score ${m.matchScore!.toStringAsFixed(0)}' : ''}',
                          ),
                          trailing: m.status == 'completed'
                              ? const Tooltip(
                                  message: 'Certificate issued',
                                  child: Icon(
                                    Icons.verified,
                                    color: Color(0xFF047857),
                                  ),
                                )
                              : null,
                        ),
                        if (m.status == 'accepted')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    _loading ? null : () => _confirmDonation(m),
                                icon: const Icon(Icons.verified_outlined),
                                label: const Text('Approve completed donation'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
