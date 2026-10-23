import 'dart:math' as math;

import 'package:flutter/material.dart';

class DevicePreviewController extends ChangeNotifier {
  bool _mobilePreview = false;

  bool get mobilePreview => _mobilePreview;

  void toggle() {
    _mobilePreview = !_mobilePreview;
    notifyListeners();
  }
}

class DevicePreviewScope extends InheritedNotifier<DevicePreviewController> {
  const DevicePreviewScope({
    super.key,
    required DevicePreviewController controller,
    required super.child,
  }) : super(notifier: controller);

  static DevicePreviewController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DevicePreviewScope>();
    assert(scope != null, 'DevicePreviewScope is missing from the widget tree.');
    return scope!.notifier!;
  }
}

class DevicePreviewHost extends StatefulWidget {
  final Widget child;

  const DevicePreviewHost({super.key, required this.child});

  @override
  State<DevicePreviewHost> createState() => _DevicePreviewHostState();
}

class _DevicePreviewHostState extends State<DevicePreviewHost> {
  final DevicePreviewController _controller = DevicePreviewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DevicePreviewScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.mobilePreview) return widget.child;
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(430.0, constraints.maxWidth - 32);
              final height = math.min(860.0, constraints.maxHeight - 32);
              return ColoredBox(
                color: const Color(0xFFE2E8F0),
                child: Center(
                  child: Container(
                    width: width,
                    height: height,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF334155), width: 5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x26020617), blurRadius: 28, offset: Offset(0, 14)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: widget.child,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GlobalCommandBar extends StatelessWidget implements PreferredSizeWidget {
  final String role;
  final String profileName;
  final VoidCallback? onNewRequest;
  final ValueChanged<String>? onSwitchRole;
  final VoidCallback onLogout;
  final VoidCallback? onShowRadar;
  final VoidCallback? onShowAlgorithm;

  const GlobalCommandBar({
    super.key,
    required this.role,
    required this.profileName,
    this.onSwitchRole,
    required this.onLogout,
    this.onNewRequest,
    this.onShowRadar,
    this.onShowAlgorithm,
  });

  @override
  Size get preferredSize => const Size.fromHeight(112);

  @override
  Widget build(BuildContext context) {
    final activeColor = switch (role) {
      'donor' => const Color(0xFF059669),
      'admin' => const Color(0xFF0F172A),
      _ => const Color(0xFFE11D48),
    };
    final preview = DevicePreviewScope.of(context);
    final mobilePreview = preview.mobilePreview;

    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    return Row(
                      children: [
                        const Icon(Icons.water_drop, color: Color(0xFFE11D48), size: 25),
                        const SizedBox(width: 8),
                        const Text('LifePulse', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
                        const SizedBox(width: 8),
                        Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF059669), shape: BoxShape.circle)),
                        const Spacer(),
                        if (!compact && onNewRequest != null) ...[
                          FilledButton.icon(
                            onPressed: onNewRequest,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New Emergency Request'),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Chip(
                          avatar: Icon(Icons.security, color: activeColor, size: 17),
                          label: Text(profileName.isEmpty ? roleLabel(role) : profileName, overflow: TextOverflow.ellipsis),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: preview.toggle,
                          icon: Icon(mobilePreview ? Icons.desktop_windows_outlined : Icons.phone_iphone_outlined, size: 17),
                          label: Text(mobilePreview ? 'Desktop view' : 'Mobile preview'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            backgroundColor: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (compact)
                          IconButton(tooltip: 'Sign out', onPressed: onLogout, icon: const Icon(Icons.logout, size: 19))
                        else
                          IconButton(tooltip: 'Sign out', onPressed: onLogout, icon: const Icon(Icons.logout, size: 19)),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (onShowRadar != null) _CommandTab(label: 'Radar Map', icon: Icons.radar, onTap: onShowRadar!),
                    if (onShowAlgorithm != null) _CommandTab(label: 'AI Algorithm', icon: Icons.auto_awesome_outlined, onTap: onShowAlgorithm!),
                    if (onNewRequest != null)
                      TextButton.icon(onPressed: onNewRequest, icon: const Icon(Icons.add, size: 17), label: const Text('New Request')),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        ),
      ),
    );
  }

  static String roleLabel(String role) => switch (role) {
        'donor' => 'Donor Portal',
        'admin' => 'Admin Oversight',
        _ => 'Hospital ER',
      };
}

class _CommandTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CommandTab({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF475569);
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: const TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}
