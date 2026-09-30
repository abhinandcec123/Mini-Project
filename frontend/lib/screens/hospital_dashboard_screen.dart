import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/blood_request.dart';
import '../utils/constants.dart';
import '../widgets/request_card.dart';
import '../widgets/global_command_bar.dart';
import 'ai_recommendation_screen.dart';
import 'request_detail_screen.dart';

class HospitalDashboardScreen extends StatefulWidget {
  const HospitalDashboardScreen({super.key});

  @override
  State<HospitalDashboardScreen> createState() =>
      _HospitalDashboardScreenState();
}

class _HospitalDashboardScreenState extends State<HospitalDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<BloodRequest> _requests = [];
  String? _priorityFilter;
  final GlobalKey _radarKey = GlobalKey();

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
      final result = await api.get('/hospital/requests',
          query:
              _priorityFilter != null ? {'priority': _priorityFilter} : null);
      setState(() => _requests =
          (result as List).map((e) => BloodRequest.fromJson(e)).toList());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load requisitions.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateModal() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateRequestSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: GlobalCommandBar(
        role: 'hospital',
        profileName: user?['name'] ?? 'Hospital ER',
        onNewRequest: _openCreateModal,
        onExportProject: () => _showUnavailableExport(context),
        onSwitchRole: (role) {
          if (role != 'hospital') context.read<AuthProvider>().logout();
        },
        onLogout: () => context.read<AuthProvider>().logout(),
        onShowRadar: () => Scrollable.ensureVisible(
          _radarKey.currentContext!,
          duration: const Duration(milliseconds: 300),
        ),
        onShowAlgorithm: _requests.isEmpty
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AiRecommendationScreen(request: _requests.first),
                )),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateModal,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip('All', null),
                  ...AppConstants.priorities.map((p) => _filterChip(p, p)),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                          children: [
                            _FacilitySummary(
                              name: user?['name'] ?? 'Hospital facility',
                              verified: user?['is_verified'] == true,
                              activeRequests: _requests.length,
                              unitsRequested: _requests.fold<int>(
                                0,
                                (total, request) => total + request.unitsNeeded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _GeodesicRadar(key: _radarKey),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Active requisitions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text('${_requests.length} total',
                                    style: const TextStyle(
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_requests.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(
                                  child: Text(
                                      'No requisitions yet. Create one to begin matching.'),
                                ),
                              )
                            else
                              ..._requests.map((request) => RequestCard(
                                    request: request,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RequestDetailScreen(
                                              request: request),
                                        ),
                                      );
                                      _load();
                                    },
                                  )),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _priorityFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label[0].toUpperCase() + label.substring(1)),
        selected: selected,
        onSelected: (_) {
          setState(() => _priorityFilter = value);
          _load();
        },
      ),
    );
  }
}

void _showUnavailableExport(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Project source'),
      content: const Text('The project source is available in the workspace. A runtime ZIP exporter is not configured for this build.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}

class _FacilitySummary extends StatelessWidget {
  final String name;
  final bool verified;
  final int activeRequests;
  final int unitsRequested;

  const _FacilitySummary({
    required this.name,
    required this.verified,
    required this.activeRequests,
    required this.unitsRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_hospital,
                      color: Color(0xFFE11D48)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      const Text('Emergency coordination center',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: verified ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    verified ? 'VERIFIED FACILITY' : 'VERIFICATION PENDING',
                    style: TextStyle(
                      color: verified ? const Color(0xFF047857) : const Color(0xFFB45309),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _FacilityDetail(icon: Icons.workspace_premium_outlined, label: 'Trauma tier not on file'),
                _FacilityDetail(icon: Icons.phone_in_talk_outlined, label: '24/7 helpline not configured'),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                _MetricValue(label: 'Active requests', value: '$activeRequests', icon: Icons.bloodtype_outlined),
                const _MetricValue(label: 'Nearby compatible', value: '--', icon: Icons.people_outline),
                _MetricValue(label: 'Units en route', value: '$unitsRequested', icon: Icons.local_shipping_outlined),
                const _MetricValue(label: 'Average ETA', value: '--', icon: Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricValue(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFE11D48), size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

class _FacilityDetail extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FacilityDetail({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _GeodesicRadar extends StatefulWidget {
  const _GeodesicRadar({super.key});

  @override
  State<_GeodesicRadar> createState() => _GeodesicRadarState();
}

class _GeodesicRadarState extends State<_GeodesicRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 18,
            top: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DONOR RADAR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('DEMO RADAR · 5 / 15 / 30 / 50 km',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) => SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(painter: _RadarPainter(progress: _sweep.value)),
              ),
            ),
          ),
          const Positioned(
            right: 16,
            bottom: 12,
            child: Wrap(
              children: [
                _RadarLegend(color: Color(0xFF06B6D4), label: 'Exact match'),
                SizedBox(width: 10),
                _RadarLegend(color: Color(0xFFD97706), label: 'Compatible'),
                SizedBox(width: 10),
                Text('Illustrative pins', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _RadarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
        ],
      );
}

class _RadarPainter extends CustomPainter {
  final double progress;

  const _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 5);
    final radius = size.width * 0.40;
    final ringPaint = Paint()
      ..color = const Color(0xFF164E63)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawCircle(center, radius * ring / 4, ringPaint);
    }
    final pinOffsets = [
      const Offset(-0.55, -0.15),
      const Offset(0.55, -0.38),
      const Offset(0.2, 0.63),
      const Offset(-0.18, 0.32),
      const Offset(0.78, 0.1),
    ];
    final pinColors = [
      const Color(0xFF06B6D4),
      const Color(0xFFD97706),
      const Color(0xFF06B6D4),
      const Color(0xFFD97706),
      const Color(0xFF06B6D4),
    ];
    for (var i = 0; i < pinOffsets.length; i++) {
      final offset = pinOffsets[i];
      final point = Offset(center.dx + offset.dx * radius, center.dy + offset.dy * radius);
      canvas.drawCircle(point, 4, Paint()..color = pinColors[i]);
      canvas.drawCircle(point, 7, Paint()..color = pinColors[i].withValues(alpha: 0.25));
    }
    final axisPaint = Paint()
      ..color = const Color(0xFF0E7490).withValues(alpha: 0.38)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), axisPaint);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: progress * math.pi * 2,
        endAngle: progress * math.pi * 2 + 0.7,
        colors: const [Color(0x0006B6D4), Color(0x6606B6D4)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), progress * math.pi * 2, 0.7, true, sweepPaint);
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFFE11D48));
    canvas.drawCircle(center, 10,
        Paint()..color = const Color(0xFFE11D48).withValues(alpha: 0.22));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}

class _CreateRequestSheet extends StatefulWidget {
  const _CreateRequestSheet();

  @override
  State<_CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class _CreateRequestSheetState extends State<_CreateRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _patientName = TextEditingController();
  final _caseId = TextEditingController();
  final _diagnosis = TextEditingController();
  final _units = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String _bloodGroup = AppConstants.bloodGroups.first;
  String _priority = 'normal';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _patientName.dispose();
    _caseId.dispose();
    _diagnosis.dispose();
    _units.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final caseDetails = [
        if (_caseId.text.trim().isNotEmpty) 'Case ID: ${_caseId.text.trim()}',
        if (_diagnosis.text.trim().isNotEmpty) 'Diagnosis: ${_diagnosis.text.trim()}',
        if (_notes.text.trim().isNotEmpty) 'Reason: ${_notes.text.trim()}',
      ].join(' | ');
      await api.post('/hospital/requests', body: {
        'patient_name': _patientName.text.trim(),
        'blood_group': _bloodGroup,
        'units_needed': int.tryParse(_units.text) ?? 1,
        'priority': _priority,
        'notes': caseDetails.isEmpty ? null : caseDetails,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = context.watch<AuthProvider>().user ?? {};
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.emergency, color: Color(0xFFE11D48)),
                SizedBox(width: 8),
                Text('Emergency requisition',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Hospital facility'),
              child: Row(
                children: [
                  const Icon(Icons.local_hospital_outlined, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(hospital['name'] ?? 'Current hospital account')),
                  const Icon(Icons.lock_outline, size: 15, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _patientName,
              decoration: const InputDecoration(labelText: 'Patient name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _caseId,
              decoration: const InputDecoration(labelText: 'Patient case ID'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _diagnosis,
              decoration: const InputDecoration(labelText: 'Diagnosis'),
            ),
            const SizedBox(height: 12),
            const Text('Blood type',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.bloodGroups.map((group) {
                final selected = _bloodGroup == group;
                return ChoiceChip(
                  label: Text(group),
                  selected: selected,
                  onSelected: (_) => setState(() => _bloodGroup = group),
                  selectedColor: const Color(0xFFFFE4E8),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFFBE123C)
                        : const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                      color: selected
                          ? const Color(0xFFFDA4AF)
                          : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                    child: Text('Units required',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: 'Decrease units',
                  onPressed: () {
                    final count = int.tryParse(_units.text) ?? 1;
                    if (count > 1) setState(() => _units.text = '${count - 1}');
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _units,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    validator: (v) {
                      final count = int.tryParse(v ?? '');
                      return count == null || count < 1 || count > 10
                          ? '1-10'
                          : null;
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Increase units',
                  onPressed: () {
                    final count = int.tryParse(_units.text) ?? 1;
                    if (count < 10) {
                      setState(() => _units.text = '${count + 1}');
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Urgency',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                ('critical', 'CRITICAL', '<1h', Color(0xFFE11D48)),
                ('urgent', 'HIGH', '<4h', Color(0xFFD97706)),
                ('medium', 'MEDIUM', 'Routine triage', Color(0xFF0891B2)),
                ('normal', 'ROUTINE', 'Scheduled', Color(0xFF64748B)),
              ].map((tier) {
                final selected = _priority == tier.$1;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _priority = tier.$1),
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tier.$2, style: TextStyle(color: selected ? tier.$4 : const Color(0xFF334155), fontWeight: FontWeight.w800, fontSize: 10)),
                      Text(tier.$3, style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                  selectedColor: tier.$4.withValues(alpha: 0.13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: selected ? tier.$4 : const Color(0xFFE2E8F0)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Reason for transfusion'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Deploy Requisition'),
            ),
          ],
        ),
      ),
    );
  }
}
