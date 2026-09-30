import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/global_command_bar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _inventory = {};
  List<dynamic> _donors = [];
  List<dynamic> _hospitals = [];
  List<dynamic> _logs = [];
  String _donorQuery = '';
  String _hospitalQuery = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
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
      ]);
      setState(() {
        _stats = results[0];
        _inventory = results[1];
        _donors = results[2];
        _hospitals = results[3];
        _logs = results[4];
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load admin data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeDonor(int id) async {
    final confirmed = await _confirm('Remove this donor from the network?');
    if (!confirmed) return;
    try {
      final api = context.read<AuthProvider>().api;
      await api.delete('/admin/donors/$id');
      _loadAll();
    } on ApiException catch (e) {
      _showSnack(e.message);
    }
  }

  Future<void> _removeHospital(int id) async {
    final confirmed = await _confirm('Remove this hospital from the network?');
    if (!confirmed) return;
    try {
      final api = context.read<AuthProvider>().api;
      await api.delete('/admin/hospitals/$id');
      _loadAll();
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
                      child: Text('${entry.key.replaceAll('_', ' ')}: ${entry.value ?? 'Not on file'}'),
                    ))
                .toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalCommandBar(
        role: 'admin',
        profileName: context.watch<AuthProvider>().user?['full_name'] ?? 'Admin Oversight',
        onExportProject: () => showProjectExportDialog(context),
        onSwitchRole: (role) {
          if (role != 'admin') context.read<AuthProvider>().logout();
        },
        onLogout: () => context.read<AuthProvider>().logout(),
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
              _statCard('Fulfilled', '${_stats['fulfilled_requests'] ?? 0}',
                  Icons.check_circle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventory() {
    if (_inventory.isEmpty) {
      return const Center(child: Text('No donor inventory data yet.'));
    }
    final entries = _inventory.entries.toList();
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('City blood inventory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Eligible and available donor reserve by blood group',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 4),
            const Text('Counts are eligible donors, not stored blood units.',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 11)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(entry.key,
                          style: const TextStyle(
                              color: Color(0xFFBE123C),
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${entry.value}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 5),
                          const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('donors', style: TextStyle(color: Color(0xFF64748B), fontSize: 10))),
                        ],
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ((entry.value as num).toDouble() / 10).clamp(0.0, 1.0),
                          minHeight: 6,
                          color: (entry.value as num) <= 2 ? const Color(0xFFE11D48) : const Color(0xFF059669),
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ),
                      const Text('Planning threshold: 10 donors',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 9)),
                    ],
                  ),
                ),
              );
            },
          ),
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
      final query = _donorQuery.toLowerCase();
      return donor['full_name'].toString().toLowerCase().contains(query) ||
          donor['blood_group'].toString().toLowerCase().contains(query) ||
          donor['city'].toString().toLowerCase().contains(query);
    }).toList();
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search donors'),
            onChanged: (value) => setState(() => _donorQuery = value),
          ),
          const SizedBox(height: 12),
          if (donors.isEmpty) const Center(child: Text('No donors match this search.')),
          ...donors.map((d) => Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFFFFE4E8), child: Text(d['blood_group'] ?? '?', style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.w700))),
                  title: Text(d['full_name'] ?? ''),
                  subtitle: Text('${d['city'] ?? 'Unknown city'} • ${d['total_donations'] ?? 0} donations'),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(tooltip: 'Inspect donor profile', icon: const Icon(Icons.visibility_outlined), onPressed: () => _inspectRecord('Donor profile', Map<String, dynamic>.from(d))),
                      IconButton(tooltip: 'Revoke donor access', icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFE11D48)), onPressed: () => _removeDonor(d['id'])),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHospitals() {
    if (_hospitals.isEmpty) {
      return const Center(child: Text('No hospitals registered yet.'));
    }
    final hospitals = _hospitals.where((hospital) {
      final query = _hospitalQuery.toLowerCase();
      return hospital['name'].toString().toLowerCase().contains(query) ||
          hospital['city'].toString().toLowerCase().contains(query) ||
          hospital['registration_number'].toString().toLowerCase().contains(query);
    }).toList();
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search hospitals'),
            onChanged: (value) => setState(() => _hospitalQuery = value),
          ),
          const SizedBox(height: 12),
          if (hospitals.isEmpty) const Center(child: Text('No hospitals match this search.')),
          ...hospitals.map((h) => Card(
            child: ListTile(
              leading: Icon(
                Icons.local_hospital,
                color: h['is_verified'] == true ? Colors.green : Colors.grey,
              ),
              title: Text(h['name'] ?? ''),
              subtitle: Text(
                  '${h['city'] ?? ''} • ${h['is_verified'] == true ? 'Verified' : 'Unverified'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (h['is_verified'] != true)
                    IconButton(
                      icon: const Icon(Icons.verified, color: Colors.blue),
                      onPressed: () => _verifyHospital(h['id']),
                    ),
                  IconButton(
                    tooltip: 'Inspect hospital profile',
                    icon: const Icon(Icons.visibility_outlined),
                    onPressed: () => _inspectRecord('Hospital profile', Map<String, dynamic>.from(h)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
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
