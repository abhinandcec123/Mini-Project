import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/current_location_service.dart';
import '../services/certificate_service.dart';
import '../models/blood_request.dart';
import '../widgets/request_card.dart';
import '../widgets/global_command_bar.dart';
import '../widgets/shared_location_map.dart';

class DonorPortalScreen extends StatefulWidget {
  const DonorPortalScreen({super.key});

  @override
  State<DonorPortalScreen> createState() => _DonorPortalScreenState();
}

class _DonorPortalScreenState extends State<DonorPortalScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<RequestMatch> _matches = [];
  List<dynamic> _certificates = [];
  int _tab = 0;
  bool _showSafetyNotice = true;
  bool _locationBusy = false;
  LatLng? _selectedTestPin;
  final Set<String> _downloadingCertificates = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final profile = await api.get('/donor/me');
      final requests = await api.get('/donor/requests');
      final certs = await api.get('/donor/certificates');
      setState(() {
        _profile = profile;
        _matches =
            (requests as List).map((e) => RequestMatch.fromJson(e)).toList();
        _certificates = certs;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load your data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    if (value) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Share your current location?'),
          content: const Text(
            'Share a one-time GPS reading or a clearly marked test pin with hospitals while you are available. LifePulse does not track you in the background. Turning availability off removes your shared pin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (consent != true) return;
      if (!mounted) return;
    }

    setState(() => _locationBusy = true);
    try {
      final api = context.read<AuthProvider>().api;
      if (value) {
        if (_profile?['gps_location_source'] != 'test_pin') {
          final position = await CurrentLocationService.getCurrentPosition();
          await api.put('/donor/location', body: {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy_m': position.accuracy,
          });
        }
      }
      final updated = await api.post(
        '/donor/availability',
        body: {'is_available': value},
      );
      setState(() => _profile = updated);
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _saveTestPin() async {
    final pin = _selectedTestPin;
    if (pin == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save test location?'),
        content: const Text(
          'This map pin is simulated, not your GPS location. While you are available, hospitals and admins may use it for matching and distance tests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save test pin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _locationBusy = true);
    try {
      final updated = await context.read<AuthProvider>().api.put(
        '/donor/location/pin',
        body: {'latitude': pin.latitude, 'longitude': pin.longitude},
      );
      if (mounted) {
        setState(() {
          _profile = updated;
          _selectedTestPin = null;
        });
      }
      _showSnack('Test pin saved. It is shared only while you are available.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not save test pin: $e');
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _refreshSharedLocation() async {
    setState(() => _locationBusy = true);
    try {
      final api = context.read<AuthProvider>().api;
      final position = await CurrentLocationService.getCurrentPosition();
      final updated = await api.put('/donor/location', body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy_m': position.accuracy,
      });
      if (mounted) setState(() => _profile = updated);
      _showSnack('Shared GPS location refreshed.');
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _downloadCertificate(Map<String, dynamic> certificate) async {
    final certificateId = certificate['id'].toString();
    setState(() => _downloadingCertificates.add(certificateId));
    try {
      await CertificateService.download({
        ...certificate,
        'donor_name': _profile?['full_name'] ?? 'LifePulse donor',
      });
      _showSnack('Donation certificate downloaded.');
    } catch (e) {
      _showSnack('Could not download certificate: $e');
    } finally {
      if (mounted) {
        setState(() => _downloadingCertificates.remove(certificateId));
      }
    }
  }

  Future<void> _respond(RequestMatch match, String action) async {
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/donor/requests/${match.id}/$action');
      _showSnack(action == 'accept'
          ? 'Request accepted — thank you!'
          : 'Request declined.');
      _loadAll();
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            if (_showSafetyNotice)
              _SafetyNotice(
                onDismiss: () => setState(() => _showSafetyNotice = false),
              ),
            _DonorTopBar(
              profile: _profile,
              onRefresh: _loadAll,
              onSignOut: () => context.read<AuthProvider>().logout(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadAll)
                      : RefreshIndicator(
                          onRefresh: _loadAll,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final horizontalPadding =
                                  constraints.maxWidth >= 800 ? 30.0 : 16.0;
                              final availableWidth =
                                  constraints.maxWidth - horizontalPadding * 2;
                              final columnCount = availableWidth >= 1050
                                  ? 3
                                  : availableWidth >= 650
                                      ? 2
                                      : 1;
                              const cardSpacing = 14.0;
                              final cardWidth = (availableWidth -
                                      cardSpacing * (columnCount - 1)) /
                                  columnCount;
                              final profile = _profile ?? {};

                              return ListView(
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  22,
                                  horizontalPadding,
                                  32,
                                ),
                                children: [
                                  _ProfileHeader(
                                    profile: _profile,
                                    onToggle: _toggleAvailability,
                                    busy: _locationBusy,
                                  ),
                                  const SizedBox(height: 16),
                                  _VitalsAndImpactPanel(profile: profile),
                                  const SizedBox(height: 16),
                                  _LocationSharingCard(
                                    profile: profile,
                                    busy: _locationBusy,
                                    onRefresh: _refreshSharedLocation,
                                  ),
                                  const SizedBox(height: 16),
                                  _DonorLocationMapCard(
                                    profile: profile,
                                    selectedPin: _selectedTestPin,
                                    busy: _locationBusy,
                                    onMapTap: (point) => setState(
                                      () => _selectedTestPin = point,
                                    ),
                                    onSavePin: _saveTestPin,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: cardSpacing,
                                    runSpacing: cardSpacing,
                                    children: [
                                      SizedBox(
                                        width: cardWidth,
                                        child: _ReadinessCard(
                                          isAvailable:
                                              profile['is_available'] == true,
                                          onToggle: _toggleAvailability,
                                          busy: _locationBusy,
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _EligibilityCard(
                                          isEligible:
                                              profile['is_eligible_now'] ==
                                                  true,
                                          lastDonationDate:
                                              profile['last_donation_date'],
                                        ),
                                      ),
                                      SizedBox(
                                        width: cardWidth,
                                        child: _ReliabilityCard(
                                          score: (profile['reliability_score']
                                                      as num?)
                                                  ?.toDouble() ??
                                              0,
                                          totalDonations:
                                              profile['total_donations'] ?? 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SegmentedButton<int>(
                                    segments: const [
                                      ButtonSegment(
                                          value: 0, label: Text('Requests')),
                                      ButtonSegment(
                                          value: 1,
                                          label: Text('Certificates')),
                                    ],
                                    selected: {_tab},
                                    onSelectionChanged: (selection) =>
                                        setState(() => _tab = selection.first),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_tab == 0) ..._buildRequestsList(),
                                  if (_tab == 1) ..._buildCertificatesList(),
                                ],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRequestsList() {
    if (_matches.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
              child:
                  Text('No emergency requests yet. We\'ll notify you here.')),
        )
      ];
    }
    return _matches
        .map((m) => MatchCard(
              match: m,
              onAccept:
                  m.status == 'pending' ? () => _respond(m, 'accept') : null,
              onDecline:
                  m.status == 'pending' ? () => _respond(m, 'decline') : null,
            ))
        .toList();
  }

  List<Widget> _buildCertificatesList() {
    if (_certificates.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
              child: Text('Your donation certificates will appear here.')),
        )
      ];
    }
    return _certificates.map<Widget>((c) {
      final certificateId = c['id'].toString();
      final isDownloading = _downloadingCertificates.contains(certificateId);
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const Icon(Icons.workspace_premium, color: Colors.amber),
          title: Text(c['hospital_name'] ?? ''),
          subtitle: Text(
              '${c['units_donated']} unit(s) • ${(c['donation_date'] ?? '').toString().split('T').first}'),
          trailing: IconButton(
            tooltip: 'Download certificate PDF',
            onPressed: isDownloading ? null : () => _downloadCertificate(c),
            icon: isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
          ),
        ),
      );
    }).toList();
  }
}

class _VitalsAndImpactPanel extends StatelessWidget {
  final Map<String, dynamic> profile;

  const _VitalsAndImpactPanel({required this.profile});

  @override
  Widget build(BuildContext context) {
    final donations = (profile['total_donations'] as num?)?.toInt() ?? 0;
    final eligible = profile['is_eligible_now'] == true;
    final lastDonation = profile['last_donation_date'] == null
        ? null
        : DateTime.tryParse(profile['last_donation_date'].toString());
    final recoveryDays = lastDonation == null
        ? 0
        : (90 - DateTime.now().difference(lastDonation.toLocal()).inDays)
            .clamp(0, 90);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Health & impact',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('SAMPLE VITALS',
                      style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Illustrative values only; not a medical record.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _VitalTile(
                    label: 'Hemoglobin',
                    value: '14.8',
                    unit: 'g/dL',
                    icon: Icons.bloodtype_outlined),
                _VitalTile(
                    label: 'Blood pressure',
                    value: '120/80',
                    unit: 'mmHg',
                    icon: Icons.monitor_heart_outlined),
                _VitalTile(
                    label: 'Weight',
                    value: '--',
                    unit: 'not on file',
                    icon: Icons.monitor_weight_outlined),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ImpactPill(
                    icon: Icons.volunteer_activism_outlined,
                    label:
                        '$donations lifetime donation${donations == 1 ? '' : 's'}'),
                _ImpactPill(
                  icon: eligible
                      ? Icons.verified_outlined
                      : Icons.hourglass_bottom,
                  label: eligible
                      ? 'Eligible now'
                      : '$recoveryDays recovery day(s) remaining',
                ),
                const _ImpactPill(
                    icon: Icons.favorite_border,
                    label: 'Lives supported: tracked after completion'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const _VitalTile(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFE11D48)),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(unit,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ImpactPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ImpactPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF059669)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF065F46),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  final VoidCallback onDismiss;

  const _SafetyNotice({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEAF5FC),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.health_and_safety_outlined,
                    color: Color(0xFF256A9B), size: 18),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Safety notice: this platform coordinates donor requests; all donations remain subject to standard clinical screening.',
                    style: TextStyle(color: Color(0xFF315B7A), fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss safety notice',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 17),
                  color: const Color(0xFF315B7A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonorTopBar extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  const _DonorTopBar({
    required this.profile,
    required this.onRefresh,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return GlobalCommandBar(
      role: 'donor',
      profileName: profile?['full_name'] ?? 'Donor Portal',
      onExportProject: () => showProjectExportDialog(context),
      onSwitchRole: (role) {
        if (role != 'donor') onSignOut();
      },
      onLogout: onSignOut,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final ValueChanged<bool> onToggle;
  final bool busy;

  const _ProfileHeader({
    required this.profile,
    required this.onToggle,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final donor = profile ?? {};
    final name = donor['full_name'] ?? 'Donor';
    final city = donor['city']?.toString();
    final phone = donor['phone']?.toString();
    final maskedPhone = phone != null && phone.length > 4
        ? '${'*' * (phone.length - 4)}${phone.substring(phone.length - 4)}'
        : phone;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE6EE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08172A40), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final identity = Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBE123C)),
                ),
                child: Center(
                  child: Text(
                    donor['blood_group'] ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 9,
                      runSpacing: 7,
                      children: [
                        Text(
                          name.toString(),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF172033),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const _StatusPill(
                          icon: Icons.verified_outlined,
                          label: 'Registered donor',
                          color: Color(0xFF059669),
                          tint: Color(0xFFE7F8F4),
                        ),
                        _StatusPill(
                          icon: Icons.bloodtype_outlined,
                          label: donor['blood_group'] ?? '?',
                          color: const Color(0xFFBE123C),
                          tint: const Color(0xFFFFEAF0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (city != null && city.isNotEmpty)
                          _ProfileDetail(
                            icon: Icons.location_on_outlined,
                            label: city,
                          ),
                        if (maskedPhone != null)
                          _ProfileDetail(
                            icon: Icons.phone_outlined,
                            label: '$maskedPhone (masked)',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          return isWide
              ? identity
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 18),
                    _AvailabilityControl(
                      isAvailable: donor['is_available'] == true,
                      onToggle: onToggle,
                      busy: busy,
                    )
                  ],
                );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color tint;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileDetail({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF718096)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      ],
    );
  }
}

class _AvailabilityControl extends StatelessWidget {
  final bool isAvailable;
  final ValueChanged<bool> onToggle;
  final bool busy;

  const _AvailabilityControl({
    required this.isAvailable,
    required this.onToggle,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle,
            size: 11,
            color: isAvailable
                ? const Color(0xFF05A88B)
                : const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          isAvailable ? 'Available for requests' : 'Not available',
          style: const TextStyle(
              color: Color(0xFF263449), fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Switch.adaptive(
          value: isAvailable,
          onChanged: busy ? null : onToggle,
        ),
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  final bool isAvailable;
  final ValueChanged<bool> onToggle;
  final bool busy;

  const _ReadinessCard({
    required this.isAvailable,
    required this.onToggle,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      eyebrow: '1. REAL-TIME READINESS STATUS',
      icon: Icons.monitor_heart_outlined,
      accent: const Color(0xFF009F88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle,
                  size: 13,
                  color: isAvailable
                      ? const Color(0xFF05B494)
                      : const Color(0xFF94A3B8)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  isAvailable ? 'Available' : 'Unavailable',
                  style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 19,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Switch.adaptive(
                value: isAvailable,
                onChanged: busy ? null : onToggle,
              ),
            ],
          ),
          Text(
            isAvailable
                ? 'Hospitals can include you in compatible donor matches.'
                : 'You are hidden from new donor matches while unavailable.',
            style: const TextStyle(
                color: Color(0xFF64748B), height: 1.45, fontSize: 13),
          ),
          const Spacer(),
          const Divider(height: 22),
          const _PanelFooter(
            icon: Icons.bolt,
            text: 'Availability controls matching eligibility',
          ),
        ],
      ),
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  final bool isEligible;
  final String? lastDonationDate;

  const _EligibilityCard({
    required this.isEligible,
    required this.lastDonationDate,
  });

  @override
  Widget build(BuildContext context) {
    final parsedDate =
        lastDonationDate == null ? null : DateTime.tryParse(lastDonationDate!);
    final daysSince = parsedDate == null
        ? null
        : DateTime.now().difference(parsedDate.toLocal()).inDays.clamp(0, 90);
    final progress = daysSince == null ? 1.0 : daysSince / 90;
    final daysRemaining = daysSince == null ? 0 : 90 - daysSince;

    return _DashboardPanel(
      eyebrow: '2. DONATION ELIGIBILITY STATUS',
      icon: Icons.health_and_safety_outlined,
      accent: const Color(0xFF0A9A85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEligible ? 'Eligible to donate' : 'Recovery period',
            style: TextStyle(
                color: isEligible
                    ? const Color(0xFF059669)
                    : const Color(0xFFB7791F),
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            parsedDate == null
                ? 'No previous donation date recorded'
                : isEligible
                    ? '90-day interval complete'
                    : '$daysRemaining days remaining in recovery interval',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              color: const Color(0xFF00A98F),
              backgroundColor: const Color(0xFFE6EDF2),
            ),
          ),
          const Spacer(),
          const Divider(height: 22),
          const _PanelFooter(
            icon: Icons.info_outline,
            text: 'Whole blood donations use a 90-day interval',
          ),
        ],
      ),
    );
  }
}

class _ReliabilityCard extends StatelessWidget {
  final double score;
  final int totalDonations;

  const _ReliabilityCard({
    required this.score,
    required this.totalDonations,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedScore = score.clamp(0, 100).toDouble();
    return _DashboardPanel(
      eyebrow: '3. RELIABILITY SCORE',
      icon: Icons.insights_outlined,
      accent: const Color(0xFFE11D48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${normalizedScore.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: Color(0xFF172033),
                fontSize: 34,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: normalizedScore / 100,
              minHeight: 8,
              color: const Color(0xFFE11D48),
              backgroundColor: const Color(0xFFE9E8FC),
            ),
          ),
          const Spacer(),
          const Divider(height: 22),
          _PanelFooter(
            icon: Icons.favorite_outline,
            text: '$totalDonations completed donation(s)',
          ),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  final String eyebrow;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _DashboardPanel({
    required this.eyebrow,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDDE6EE)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07172A40), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  eyebrow,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PanelFooter extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PanelFooter({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF7A899A)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _DonorLocationMapCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final LatLng? selectedPin;
  final bool busy;
  final ValueChanged<LatLng> onMapTap;
  final VoidCallback onSavePin;

  const _DonorLocationMapCard({
    required this.profile,
    required this.selectedPin,
    required this.busy,
    required this.onMapTap,
    required this.onSavePin,
  });

  @override
  Widget build(BuildContext context) {
    final savedLatitude = profile['gps_location_source'] == 'test_pin'
        ? (profile['saved_pin_latitude'] as num?)?.toDouble()
        : (profile['current_latitude'] as num?)?.toDouble();
    final savedLongitude = profile['gps_location_source'] == 'test_pin'
        ? (profile['saved_pin_longitude'] as num?)?.toDouble()
        : (profile['current_longitude'] as num?)?.toDouble();
    final savedPin = savedLatitude != null && savedLongitude != null
        ? LatLng(savedLatitude, savedLongitude)
        : null;
    final isSharing = profile['is_available'] == true &&
        profile['location_sharing_enabled'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your location map',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              isSharing
                  ? 'Your pin is visible to hospitals and admins while available.'
                  : 'Only you can see this map until you turn availability on.',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 12),
            SharedLocationMap(
              pins: [
                if (savedPin != null)
                  SharedLocationPin(
                    point: savedPin,
                    label: profile['gps_location_source'] == 'test_pin'
                        ? 'Your saved test pin'
                        : 'Your shared GPS pin',
                    color: const Color(0xFF0891B2),
                  ),
              ],
              selectedPoint: selectedPin,
              onTap: onMapTap,
              emptyMessage: 'Your location pin will appear here.',
            ),
            if (selectedPin != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected test pin: ${selectedPin!.latitude.toStringAsFixed(5)}, ${selectedPin!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Test pins are simulated locations, not GPS. Tap the map to place or move one.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: selectedPin == null || busy ? null : onSavePin,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.push_pin_outlined),
                  label: const Text('Save test pin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSharingCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool busy;
  final VoidCallback onRefresh;

  const _LocationSharingCard({
    required this.profile,
    required this.busy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isSharing = profile['is_available'] == true &&
        profile['location_sharing_enabled'] == true;
    final accuracy = (profile['location_accuracy_m'] as num?)?.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isSharing ? Icons.location_on : Icons.location_off,
              color: isSharing ? const Color(0xFF16845B) : Colors.blueGrey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location sharing',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSharing
                        ? '${profile['location_source'] == 'test_pin' ? 'Your test pin' : 'Your GPS pin'} is shared with hospitals while available${accuracy == null || profile['location_source'] == 'test_pin' ? '' : ' · ±${accuracy.round()} m accuracy'}. No background tracking.'
                        : 'Your location pin is not shared. Turning availability off hides it from hospitals.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSharing)
              IconButton(
                tooltip: 'Refresh GPS location',
                onPressed: busy ? null : onRefresh,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
          ],
        ),
      ),
    );
  }
}
