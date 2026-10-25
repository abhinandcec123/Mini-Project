import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/global_command_bar.dart';
import '../widgets/shared_location_map.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _locationRefreshTimer;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _inventory = {};
  List<dynamic> _donors = [];
  List<dynamic> _hospitals = [];
  List<dynamic> _logs = [];
  List<dynamic> _donorLocations = [];
  Map<String, dynamic> _fulfilledData = {};
  String _donorQuery = '';
  String _hospitalQuery = '';
  bool _loading = true;
  bool _refreshingDonorLocations = false;
  String? _donorLocationError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this)
      ..addListener(_handleTabChange);
    _loadAll();
  }

  void _handleTabChange() {
    if (_tabController.index == 2) {
      _refreshDonorLocations();
      _locationRefreshTimer ??= Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refreshDonorLocations(),
      );
    } else {
      _locationRefreshTimer?.cancel();
      _locationRefreshTimer = null;
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthProvider>().api;
      final results = await Future.wait([
        api.get('/admin/stats'),
        api.get('/admin/inventory'),
        api.get('/admin/donors'),
        api.get('/admin/hospitals'),
        api.get('/admin/audit-logs'),
        api.get('/admin/donor-locations'),
        api.get('/admin/fulfilled-donations'),
      ]);
      setState(() {
        _stats = results[0];
        _inventory = results[1];
        _donors = results[2];
        _hospitals = results[3];
        _logs = results[4];
        _donorLocations = results[5];
        _fulfilledData = results[6] is Map<String, dynamic> ? results[6] as Map<String, dynamic> : {};
        _donorLocationError = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load admin data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshDonorLocations() async {
    if (_refreshingDonorLocations || !mounted) return;
    _refreshingDonorLocations = true;
    try {
      final locations =
          await context.read<AuthProvider>().api.get('/admin/donor-locations');
      if (mounted) {
        setState(() {
          _donorLocations = locations;
          _donorLocationError = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _donorLocationError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _donorLocationError = 'Could not refresh donor locations.');
      }
    } finally {
      _refreshingDonorLocations = false;
    }
  }

  Future<void> _openBulkAddDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _BulkAddUsersDialog(
        onSubmit: (payload) async {
          try {
            final result = await context.read<AuthProvider>().api.post(
                  '/admin/bulk-users',
                  body: payload,
                ) as Map<String, dynamic>;
            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            if (!mounted) return;
            await _loadAll();
            final donorCount = result['created_donors_count'] ?? 0;
            final hospitalCount = result['created_hospitals_count'] ?? 0;
            final errors = (result['errors'] as List<dynamic>?) ?? [];
            _showSnack(
              'Imported $donorCount donor(s) and $hospitalCount hospital(s). '
              '${errors.length} row(s) skipped.',
            );
            if (errors.isNotEmpty && mounted) {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('CSV import results'),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: SelectableText(errors.join('\n')),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            }
          } on ApiException catch (e) {
            _showSnack(e.message);
          }
        },
      ),
    );
  }

  Future<void> _removeDonor(int id) async {
    final api = context.read<AuthProvider>().api;
    final confirmed = await _confirm('Remove this donor from the network?');
    if (!confirmed) return;
    try {
      await api.delete('/admin/donors/$id');
      await _loadAll();
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _removeHospital(int id) async {
    final api = context.read<AuthProvider>().api;
    final confirmed = await _confirm('Remove this hospital from the network?');
    if (!confirmed) return;
    try {
      await api.delete('/admin/hospitals/$id');
      await _loadAll();
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _verifyHospital(int id) async {
    try {
      final api = context.read<AuthProvider>().api;
      await api.post('/admin/hospitals/$id/verify');
      _loadAll();
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _issueTemporaryPassword(
    String accountType,
    int accountId,
    String accountName,
  ) async {
    final api = context.read<AuthProvider>().api;
    final confirmed = await _confirm(
      'Issue a new temporary password for $accountName? Their current password and existing sessions will stop working.',
    );
    if (!confirmed) return;
    try {
      final result = await api.post(
        '/admin/users/$accountType/$accountId/temporary-password',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Temporary password issued'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$accountName must use this password to sign in:'),
              const SizedBox(height: 12),
              SelectableText(
                result['temporary_password'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Copy or share it securely now. It will not be shown again, and the account holder must choose a new password at sign-in.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) await _loadAll();
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Could not issue a temporary password. Try again.');
    }
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    return result ?? false;
  }

  void _inspectRecord(String title, Map<String, dynamic> record) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: record.entries
                .where((entry) => !entry.key.contains('password'))
                .map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                          '${entry.key.replaceAll('_', ' ')}: ${entry.value ?? 'Not on file'}'),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalCommandBar(
        role: 'admin',
        profileName: context.watch<AuthProvider>().user?['full_name'] ??
            'Admin Oversight',
        onSwitchRole: (role) {
          if (role != 'admin') context.read<AuthProvider>().logout();
        },
        onLogout: () => context.read<AuthProvider>().logout(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bulk_add_btn',
        onPressed: () => _openBulkAddDialog(),
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Bulk Add (CSV)'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Fulfilled Donations'),
                Tab(text: 'Live Donor Map'),
                Tab(text: 'Donor Registry'),
                Tab(text: 'Hospital Network'),
                Tab(text: 'City Inventory'),
                Tab(text: 'Audit Security Logs'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverview(),
                          _buildFulfilledDonations(),
                          _buildDonorMap(),
                          _buildDonors(),
                          _buildHospitals(),
                          _buildInventory(),
                          _buildAuditLog(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorMap() {
    final pins = _donorLocations
        .whereType<Map<String, dynamic>>()
        .map((donor) {
          final latitude = (donor['latitude'] as num?)?.toDouble();
          final longitude = (donor['longitude'] as num?)?.toDouble();
          if (latitude == null || longitude == null) return null;
          final isTestPin = donor['location_source'] == 'test_pin';
          return SharedLocationPin(
            point: LatLng(latitude, longitude),
            label:
                '${donor['full_name']} · ${donor['blood_group']}${isTestPin ? ' · TEST PIN' : ''}',
            color:
                isTestPin ? const Color(0xFF7C3AED) : const Color(0xFF0891B2),
          );
        })
        .whereType<SharedLocationPin>()
        .toList();

    return RefreshIndicator(
      onRefresh: _refreshDonorLocations,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live donor locations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Refresh donor locations',
                onPressed: _refreshDonorLocations,
                icon: _refreshingDonorLocations
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          Text(
            '${pins.length} available donor location(s) · refreshes every 15 seconds while this tab is open.',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          if (_donorLocationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _donorLocationError!,
              style: const TextStyle(color: Color(0xFFB91C1C)),
            ),
          ],
          const SizedBox(height: 12),
          SharedLocationMap(
            pins: pins,
            height: 500,
            emptyMessage:
                'No available donors are sharing a GPS or test pin. Donors must opt in and turn availability on.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Only available donors who opted in to location sharing appear here.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('Active Donors', '${_stats['total_donors'] ?? 0}',
                  Icons.people),
              _statCard('Active Hospitals', '${_stats['total_hospitals'] ?? 0}',
                  Icons.local_hospital),
              _statCard('Open Requests', '${_stats['open_requests'] ?? 0}',
                  Icons.pending_actions),
              _statCard('Fulfilled Requests', '${_stats['fulfilled_requests'] ?? 0}',
                  Icons.check_circle),
              _statCard(
                'Completed Donations',
                '${_fulfilledData['total_completed_donations'] ?? 0}',
                Icons.volunteer_activism,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFulfilledDonations() {
    final donations =
        (_fulfilledData['completed_donations'] as List<dynamic>?) ??
        (_fulfilledData['certificates'] as List<dynamic>?) ??
        (_fulfilledData['completed_matches'] as List<dynamic>?) ??
        [];
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Completed donations (${donations.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Donation records confirmed by hospitals.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (donations.isEmpty)
            const Center(child: Text('No completed donations yet.')),
          ...donations.map((item) {
            final donation = item as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.check)),
                title: Text(donation['donor_name']?.toString() ?? 'Donor'),
                subtitle: Text(
                  '${donation['hospital_name'] ?? 'Hospital'}\n'
                  'Blood group: ${donation['blood_group'] ?? 'Unknown'}',
                ),
                isThreeLine: true,
                trailing: Text(donation['donation_date']?.toString() ?? ''),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInventory() {
    if (_inventory.isEmpty) {
      return const Center(
        child: Text('No eligible donors are currently available for matching.'),
      );
    }
    final cities = _inventory.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('City blood inventory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
              'Available, eligible donors sharing their location, grouped by city and blood group.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 4),
          const Text('Counts are eligible donors, not stored blood units.',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 11)),
          const SizedBox(height: 14),
          ...cities.map((cityEntry) {
            final groups = cityEntry.value is Map
                ? Map<String, dynamic>.from(cityEntry.value as Map)
                : <String, dynamic>{};
            final bloodGroups = groups.entries
                .where((entry) => entry.key != 'total')
                .toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cityEntry.key} · ${groups['total'] ?? 0} donor(s)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bloodGroups
                          .map((group) => Chip(
                                label: Text('${group.key}: ${group.value}'),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDonors() {
    if (_donors.isEmpty) {
      return const Center(child: Text('No donors registered yet.'));
    }
    final donors = _donors.where((donor) {
      final query = _donorQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return [
        donor['full_name'], donor['blood_group'], donor['city'],
        donor['phone'], donor['email'],
      ].any((value) => (value ?? '').toString().toLowerCase().contains(query));
    }).toList();
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), labelText: 'Search donors'),
            onChanged: (value) => setState(() => _donorQuery = value),
          ),
          const SizedBox(height: 12),
          if (donors.isEmpty)
            const Center(child: Text('No donors match this search.')),
          ...donors.map((d) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFE4E8),
                      child: Text(d['blood_group'] ?? '?',
                          style: const TextStyle(
                              color: Color(0xFFBE123C),
                              fontWeight: FontWeight.w700))),
                  title: Text(d['full_name'] ?? ''),
                  subtitle: Text(
                      '${d['city'] ?? 'Unknown city'} • ${d['total_donations'] ?? 0} donations'),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                          tooltip: 'Issue temporary password',
                          icon: const Icon(Icons.lock_reset_outlined),
                          onPressed: d['is_active'] == false
                              ? null
                              : () => _issueTemporaryPassword(
                                    'donor',
                                    d['id'],
                                    d['full_name'] ?? 'this donor',
                                  )),
                      IconButton(
                          tooltip: 'Inspect donor profile',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _inspectRecord(
                              'Donor profile', Map<String, dynamic>.from(d))),
                      IconButton(
                          tooltip: 'Revoke donor access',
                          icon: const Icon(Icons.person_remove_outlined,
                              color: Color(0xFFE11D48)),
                          onPressed: () => _removeDonor(d['id'])),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHospitals() {
    final hospitals = _hospitals.where((hospital) {
      final query = _hospitalQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return [
        hospital['name'], hospital['city'], hospital['registration_number'],
        hospital['phone'], hospital['email'],
      ].any((value) => (value ?? '').toString().toLowerCase().contains(query));
    }).toList();
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search hospitals',
                  ),
                  onChanged: (value) => setState(() => _hospitalQuery = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hospitals.isEmpty)
            const Center(child: Text('No hospitals match this search.')),
          if (hospitals.isEmpty)
            const Center(child: Text('No hospitals match this search.')),
          ...hospitals.map((h) => Card(
                child: ListTile(
                  leading: Icon(
                    Icons.local_hospital,
                    color:
                        h['is_verified'] == true ? Colors.green : Colors.grey,
                  ),
                  title: Text(h['name'] ?? ''),
                  subtitle: Text(
                      '${h['city'] ?? ''} • ${h['is_verified'] == true ? 'Verified' : 'Unverified'}'),
                  trailing: Wrap(
                    children: [
                      if (h['is_verified'] != true)
                        IconButton(
                          icon: const Icon(Icons.verified, color: Colors.blue),
                          onPressed: () => _verifyHospital(h['id']),
                        ),
                      IconButton(
                        tooltip: 'Issue temporary password',
                        icon: const Icon(Icons.lock_reset_outlined),
                        onPressed: h['is_active'] == false
                            ? null
                            : () => _issueTemporaryPassword(
                                  'hospital',
                                  h['id'],
                                  h['name'] ?? 'this hospital',
                                ),
                      ),
                      IconButton(
                        tooltip: 'Inspect hospital profile',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => _inspectRecord(
                            'Hospital profile', Map<String, dynamic>.from(h)),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeHospital(h['id']),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAuditLog() {
    if (_logs.isEmpty) {
      return const Center(child: Text('No activity recorded yet.'));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, i) {
          final l = _logs[i];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 20),
            title: Text('${l['actor_type']} • ${l['action']}'),
            subtitle: Text(l['details'] ?? ''),
            trailing: Text(
              (l['created_at'] ?? '').toString().split('T').first,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}

class _BulkAddUsersDialog extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> payload) onSubmit;

  const _BulkAddUsersDialog({required this.onSubmit});

  @override
  State<_BulkAddUsersDialog> createState() => _BulkAddUsersDialogState();
}

class _BulkAddUsersDialogState extends State<_BulkAddUsersDialog> {
  int _targetType = 0; // 0 = Donors, 1 = Hospitals
  final _csvController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _setDonorTemplate();
  }

  void _setDonorTemplate() {
    _csvController.text =
        '# Name, Phone, BloodGroup, City, Age, Latitude, Longitude\n'
        'Aarav Patel, 9876543211, O+, Mumbai, 28,,\n'
        'Neha Sharma, 9876543212, A+, Pune, 24,,\n'
        'Rohan Gupta, 9876543213, B+, Mumbai, 31,,\n'
        'Priya Nair, 9876543214, AB+, Delhi, 26,,';
  }

  void _setHospitalTemplate() {
    _csvController.text =
        '# HospitalName, Phone, City, Address, RegistrationNumber, Latitude, Longitude\n'
        'City Care Hospital, 9876500001, Mumbai, Andheri East, REG-CC-01,,\n'
        'Apex Life Clinic, 9876500002, Pune, Shivaji Nagar, REG-AL-02,,';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bulk Add Users (CSV Import)'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add multiple users at once. Initial default password will be User@123 (prompted to change upon first sign in).',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Donors (CSV)')),
                  ButtonSegment(value: 1, label: Text('Hospitals (CSV)')),
                ],
                selected: {_targetType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _targetType = selection.first;
                    if (_targetType == 0) {
                      _setDonorTemplate();
                    } else {
                      _setHospitalTemplate();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _csvController,
                maxLines: 9,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: _targetType == 0
                      ? 'CSV: Name, Phone, BloodGroup, City, Age, Latitude, Longitude (optional)'
                      : 'CSV: Name, Phone, City, Address, RegistrationNumber, Latitude, Longitude (optional)',
                  hintText: 'Paste comma-separated rows here...',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lines starting with # are ignored. Phone numbers must be 10 digits. Use coordinates or configure backend geocoding to place donors on the map.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting
              ? null
              : () async {
                  setState(() => _submitting = true);
                  final lines = _csvController.text
                      .split('\n')
                      .map((l) => l.trim())
                      .where((l) => l.isNotEmpty && !l.startsWith('#'))
                      .toList();

                  final donors = <Map<String, dynamic>>[];
                  final hospitals = <Map<String, dynamic>>[];

                  for (final line in lines) {
                    final parts = _parseCsvRow(line)
                        .map((part) => part.trim())
                        .toList();
                    if (parts.isEmpty) continue;
                    final firstColumn = parts.first
                        .replaceFirst('\uFEFF', '')
                        .toLowerCase()
                        .replaceAll(' ', '_');
                    if (firstColumn == 'name' ||
                        firstColumn == 'full_name' ||
                        firstColumn == 'hospitalname' ||
                        firstColumn == 'hospital_name' ||
                        firstColumn == 'donor_name') {
                      continue;
                    }
                    if (_targetType == 0) {
                      if (parts.length >= 3) {
                        donors.add({
                          'full_name': parts[0],
                          'phone': parts[1],
                          'blood_group': parts[2],
                          'city': parts.length > 3 ? parts[3] : '',
                          'age': parts.length > 4 ? int.tryParse(parts[4]) ?? 25 : 25,
                          if (parts.length > 5 && parts[5].isNotEmpty)
                            'latitude': double.tryParse(parts[5]),
                          if (parts.length > 6 && parts[6].isNotEmpty)
                            'longitude': double.tryParse(parts[6]),
                          'password': 'User@123',
                        });
                      }
                    } else {
                      if (parts.length >= 2) {
                        hospitals.add({
                          'name': parts[0],
                          'phone': parts[1],
                          'city': parts.length > 2 ? parts[2] : '',
                          'address': parts.length > 3 ? parts[3] : '',
                          'registration_number': parts.length > 4 ? parts[4] : '',
                          if (parts.length > 5 && parts[5].isNotEmpty)
                            'latitude': double.tryParse(parts[5]),
                          if (parts.length > 6 && parts[6].isNotEmpty)
                            'longitude': double.tryParse(parts[6]),
                          'password': 'User@123',
                        });
                      }
                    }
                  }

                  final payload = {
                    'donors': donors,
                    'hospitals': hospitals,
                  };

                  await widget.onSubmit(payload);
                  if (mounted) setState(() => _submitting = false);
                },
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.upload_file),
          label: const Text('Import CSV'),
        ),
      ],
    );
  }
}

List<String> _parseCsvRow(String row) {
  final fields = <String>[];
  final field = StringBuffer();
  var insideQuotes = false;
  var index = 0;

  while (index < row.length) {
    final character = row[index];
    if (character == '"') {
      if (insideQuotes && index + 1 < row.length && row[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        insideQuotes = !insideQuotes;
      }
    } else if (character == ',' && !insideQuotes) {
      fields.add(field.toString());
      field.clear();
    } else {
      field.write(character);
    }
    index++;
  }

  fields.add(field.toString());
  return fields;
}
